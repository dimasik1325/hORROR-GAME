class_name ThreadedMonsterAI
extends CharacterBody3D

## Искусственный Интеллект лесного чудовища "Сплетенный" (Godot 4.6-dev)
## Реализует многопоточную навигацию с динамическим избеганием препятствий (RVO2), 
## сенсорные системы зрения/слуха, механику потери из виду и процедурный поиск.

enum State {
	IDLE,        ## Ожидание/засада в чаще
	PATROL,      ## Обход контрольных точек лесного биома
	INVESTIGATE, ## Проверка источника подозрительного шума или последнего места видимости
	CHASE,       ## Прямое агрессивное преследование игрока
	SEARCH       ## Процедурное сканирование сектора после потери цели (5 сек)
}

# --- НАСТРОЙКИ СКОРОСТИ И ФИЗИКИ ---
@export_group("Движение")
@export var patrol_speed: float = 2.4
@export var investigate_speed: float = 4.2
@export var chase_speed: float = 6.8
@export var acceleration: float = 8.0
@export var rotation_speed: float = 5.0
@export var gravity: float = 9.81

# --- СЕНСОРНЫЕ НАСТРОЙКИ ---
@export_group("Зрение и Слух")
@export var vision_range: float = 28.0
@export var vision_angle_degrees: float = 110.0
@export var hearing_sensitivity: float = 1.0
@export var search_duration: float = 5.0

# --- ПАТРУЛЬНЫЕ ТОЧКИ ---
@export_group("Маршрут Патрулирования")
@export var patrol_waypoints: Array[Node3D] = []
@export var waypoint_reach_threshold: float = 1.8
@export var idle_wait_time_at_waypoint: float = 3.0

# --- УЗЛЫ ---
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var vision_ray: RayCast3D = $Sensors/VisionRayCast
@onready var scream_audio: AudioStreamPlayer3D = $Audio/ScreamAudio
@onready var footsteps_audio: AudioStreamPlayer3D = $Audio/FootstepsAudio
@onready var state_debug_label: Label3D = $StateDebugLabel

# --- АУДИО БАНКИ ---
@export_group("Аудио ИИ")
@export var chase_screams: Array[AudioStream] = []
@export var search_growls: Array[AudioStream] = []

# --- ВНУТРЕННЕЕ СОСТОЯНИЕ FSM ---
var current_state: State = State.IDLE
var player_ref: CharacterBody3D = null

var _current_waypoint_index: int = 0
var _idle_timer: float = 0.0
var _search_timer: float = 0.0
var _search_rotation_angle: float = 0.0

var _last_known_player_position: Vector3 = Vector3.ZERO
var _has_line_of_sight: bool = false
var _target_velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	_setup_navigation_agent()
	_connect_noise_listener()
	_change_state(State.PATROL)


func _setup_navigation_agent() -> void:
	if nav_agent == null:
		return
		
	nav_agent.path_desired_distance = 1.2
	nav_agent.target_desired_distance = 1.5
	nav_agent.avoidance_enabled = true
	nav_agent.radius = 0.9
	nav_agent.max_speed = chase_speed
	
	# Подключение многопоточного коллбэка избегания динамических препятствий
	nav_agent.velocity_computed.connect(_on_safe_velocity_computed)


func _connect_noise_listener() -> void:
	if SanityGlobalManager:
		SanityGlobalManager.noise_emitted.connect(_on_global_noise_heard)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	_acquire_player_reference()
	_evaluate_sensory_perception()

	match current_state:
		State.IDLE:
			_process_state_idle(delta)
		State.PATROL:
			_process_state_patrol(delta)
		State.INVESTIGATE:
			_process_state_investigate(delta)
		State.CHASE:
			_process_state_chase(delta)
		State.SEARCH:
			_process_state_search(delta)

	_apply_movement_and_rotation(delta)


# --- СЕНСОРНЫЙ АНАЛИЗ (LINE OF SIGHT И ПРОВЕРКА ОККЛЮЗИИ) ---
func _evaluate_sensory_perception() -> void:
	if player_ref == null:
		_has_line_of_sight = false
		return

	var eyes_pos: Vector3 = global_position + Vector3(0, 1.8, 0)
	var player_head_pos: Vector3 = player_ref.global_position + Vector3(0, 1.6, 0)
	var distance_to_player: float = eyes_pos.distance_to(player_head_pos)

	# 1. Проверка дальности зрения
	if distance_to_player > vision_range:
		_has_line_of_sight = false
		return

	# 2. Проверка угла конуса видимости (FOV)
	var forward_dir: Vector3 = -global_transform.basis.z.normalized()
	var to_player_dir: Vector3 = (player_head_pos - eyes_pos).normalized()
	var angle_to_player: float = rad_to_deg(forward_dir.angle_to(to_player_dir))

	if angle_to_player > (vision_angle_degrees * 0.5):
		_has_line_of_sight = false
		return

	# 3. Физический рейкаст через DirectSpaceState на проверку блокировки деревьями/камнями
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		eyes_pos,
		player_head_pos,
		1 # Слой статической геометрии и укрытий
	)
	var hit: Dictionary = space_state.intersect_ray(query)

	if hit.is_empty():
		# Прямой визуальный контакт подтвержден!
		_has_line_of_sight = true
		_last_known_player_position = player_ref.global_position

		if current_state != State.CHASE:
			_trigger_chase_scream()
			_change_state(State.CHASE)
	else:
		_has_line_of_sight = false


# --- ОБРАБОТКА ШУМА (СЛУХ) ---
func _on_global_noise_heard(origin: Vector3, radius: float, _noise_type: StringName) -> void:
	if current_state == State.CHASE:
		return # Во время погони шум не отвлекает от визуального контакта

	var distance: float = global_position.distance_to(origin)
	var effective_radius: float = radius * hearing_sensitivity

	if distance <= effective_radius:
		_last_known_player_position = origin
		_change_state(State.INVESTIGATE)


# --- ЛОГИКА СОСТОЯНИЙ (FSM) ---

func _process_state_idle(delta: float) -> void:
	_target_velocity = Vector3.ZERO
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_advance_patrol_waypoint()
		_change_state(State.PATROL)


func _process_state_patrol(_delta: float) -> void:
	if patrol_waypoints.is_empty():
		_change_state(State.IDLE)
		return

	var target_wp: Node3D = patrol_waypoints[_current_waypoint_index]
	if target_wp == null:
		return

	nav_agent.target_position = target_wp.global_position

	if nav_agent.is_target_reached() or global_position.distance_to(target_wp.global_position) < waypoint_reach_threshold:
		_idle_timer = idle_wait_time_at_waypoint
		_change_state(State.IDLE)
		return

	_move_along_nav_path(patrol_speed)


func _process_state_investigate(_delta: float) -> void:
	nav_agent.target_position = _last_known_player_position

	if nav_agent.is_target_reached() or global_position.distance_to(_last_known_player_position) < 1.8:
		# Прибыл на место шума/последней точки, но никого нет -> переход к поиску
		_change_state(State.SEARCH)
		return

	_move_along_nav_path(investigate_speed)


func _process_state_chase(_delta: float) -> void:
	if _has_line_of_sight and player_ref != null:
		_last_known_player_position = player_ref.global_position
		nav_agent.target_position = player_ref.global_position
		_move_along_nav_path(chase_speed)
	else:
		# МЕХАНИКА ПОТЕРИ ИЗ ВИДУ: Игрок забежал за дерево/укрытие
		# Монстр стремительно бежит к последней известной точке
		_change_state(State.INVESTIGATE)


func _process_state_search(delta: float) -> void:
	_target_velocity = Vector3.ZERO
	_search_timer -= delta

	# Процедурное сканирование: вращение монстра на 360 градусов с осмотром кустов
	_search_rotation_angle += delta * 2.2
	var target_rotation_y: float = global_rotation.y + sin(_search_rotation_angle) * delta * 3.0
	global_rotation.y = target_rotation_y

	if _search_timer <= 0.0:
		# Игрок успешно спрятался. Возвращение к рутинному патрулированию
		_change_state(State.PATROL)


# --- НАВИГАЦИЯ И ПЕРЕМЕЩЕНИЕ С АВОЙДАНСОМ (RVO2) ---
func _move_along_nav_path(speed: float) -> void:
	if nav_agent.is_navigation_finished():
		_target_velocity = Vector3.ZERO
		return

	var next_path_pos: Vector3 = nav_agent.get_next_path_position()
	var move_dir: Vector3 = (next_path_pos - global_position).normalized()
	move_dir.y = 0.0
	
	var desired_velocity: Vector3 = move_dir * speed
	
	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(desired_velocity)
	else:
		_on_safe_velocity_computed(desired_velocity)


func _on_safe_velocity_computed(safe_velocity: Vector3) -> void:
	_target_velocity = safe_velocity


func _apply_movement_and_rotation(delta: float) -> void:
	var horiz_vel: Vector3 = Vector3(velocity.x, 0, velocity.z)
	horiz_vel = horiz_vel.lerp(_target_velocity, acceleration * delta)
	
	velocity.x = horiz_vel.x
	velocity.z = horiz_vel.z
	move_and_slide()

	# Плавный разворот в сторону вектора скорости
	if horiz_vel.length_squared() > 0.1:
		var target_look: Vector3 = -horiz_vel.normalized()
		var target_angle: float = atan2(target_look.x, target_look.z)
		global_rotation.y = lerp_angle(global_rotation.y, target_angle, rotation_speed * delta)


# --- СМЕНА СОСТОЯНИЙ И УТИЛИТЫ ---
func _change_state(new_state: State) -> void:
	current_state = new_state

	match current_state:
		State.SEARCH:
			_search_timer = search_duration
			_search_rotation_angle = 0.0
			_play_random_audio(search_growls)
		State.PATROL:
			nav_agent.max_speed = patrol_speed
		State.CHASE:
			nav_agent.max_speed = chase_speed
		State.INVESTIGATE:
			nav_agent.max_speed = investigate_speed
		_:
			pass

	if state_debug_label != null:
		state_debug_label.text = "State: " + State.keys()[current_state]


func _advance_patrol_waypoint() -> void:
	if patrol_waypoints.is_empty():
		return
	_current_waypoint_index = (_current_waypoint_index + 1) % patrol_waypoints.size()


func _acquire_player_reference() -> void:
	if player_ref != null:
		return
	var players: Array[Node] = get_tree().get_nodes_in_group("Player")
	if not players.is_empty():
		player_ref = players[0] as CharacterBody3D


func _trigger_chase_scream() -> void:
	_play_random_audio(chase_screams)


func _play_random_audio(bank: Array[AudioStream]) -> void:
	if bank.is_empty() or scream_audio == null:
		return
	scream_audio.stream = bank[randi() % bank.size()]
	scream_audio.pitch_scale = randf_range(0.85, 1.15)
	scream_audio.play()
