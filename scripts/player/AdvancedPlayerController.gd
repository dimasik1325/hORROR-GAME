class_name AdvancedPlayerController
extends CharacterBody3D

## Высокотехнологичный контроллер игрока от первого лица для "Эхо Чащи" (Godot 4.6-dev)
## Включает: физику инерции таежной грязи, процедурный хедбоббинг, нелинейный фонарик, 
## гибридную систему интеракций (RayCast+ShapeCast) и звуковой ландшафт шагов.

signal stamina_changed(current: float, max_val: float)
signal flashlight_battery_changed(current: float, max_val: float)
signal flashlight_toggled(is_on: bool)
signal interaction_target_changed(prompt_text: String)
signal player_stepped(surface_type: StringName, is_sprinting: bool)

# --- ПАРАМЕТРЫ ПЕРЕДВИЖЕНИЯ ---
@export_group("Физика Передвижения")
@export var walk_speed: float = 3.2
@export var sprint_speed: float = 6.8
@export var crouch_speed: float = 1.6
@export var exhausted_speed: float = 2.0
@export var jump_velocity: float = 4.0
@export var gravity: float = 9.81

# Факторы трения и ускорения на лесных грунтах
@export var standard_acceleration: float = 12.0
@export var standard_friction: float = 10.0
@export var mud_acceleration: float = 5.0
@export var mud_friction: float = 3.5

# --- СТАМИНА ---
@export_group("Система Выносливости")
@export var max_stamina: float = 100.0
@export var stamina_sprint_drain: float = 16.0 # ед./сек
@export var stamina_regen_rate: float = 12.0   # ед./сек
@export var stamina_regen_delay: float = 1.4   # задержка перед восстановлением (сек)
@export var exhaustion_recovery_threshold: float = 25.0

# --- ХЕДБОББИНГ И ДИНАМИКА КАМЕРЫ ---
@export_group("Процедурный Head Bobbing")
@export var bob_frequency_walk: float = 7.5
@export var bob_amplitude_walk_v: float = 0.045
@export var bob_amplitude_walk_h: float = 0.025
@export var bob_frequency_sprint: float = 12.5
@export var bob_amplitude_sprint_v: float = 0.085
@export var bob_amplitude_sprint_h: float = 0.045
@export var camera_tilt_amount: float = 0.035
@export var camera_tilt_speed: float = 6.0

# --- ФОНАРИК ---
@export_group("Фонарик и Батарея")
@export var max_battery_capacity: float = 100.0
@export var battery_drain_rate: float = 0.35 # ед./сек
@export var max_light_energy: float = 2.8
@export var critical_battery_threshold: float = 20.0
@export var flashlight_sway_smoothing: float = 12.0

# --- ИНТЕРАКЦИИ ---
@export_group("Интеракции")
@export var raycast_interaction_distance: float = 2.4
@export var shapecast_radius: float = 0.35

# --- УЗЛЫ СЦЕНЫ ---
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight_pivot: Node3D = $Head/Camera3D/FlashlightPivot
@onready var flashlight_spot: SpotLight3D = $Head/Camera3D/FlashlightPivot/SpotLight3D
@onready var flashlight_click_audio: AudioStreamPlayer3D = $Head/Camera3D/FlashlightPivot/ClickAudio
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRayCast
@onready var interaction_shape: ShapeCast3D = $Head/Camera3D/InteractionShapeCast
@onready var floor_detector: RayCast3D = $FloorDetectorRayCast
@onready var footstep_audio: AudioStreamPlayer3D = $Audio/FootstepAudio
@onready var breathing_audio: AudioStreamPlayer3D = $Audio/BreathingAudio

# --- АУДИО БАНКИ ПОВЕРХНОСТЕЙ ---
@export_group("Аудио Поверхностей")
@export var footsteps_mud: Array[AudioStream] = []
@export var footsteps_foliage: Array[AudioStream] = []
@export var footsteps_wood: Array[AudioStream] = []
@export var footsteps_rock: Array[AudioStream] = []

# --- ВНУТРЕННЕЕ СОСТОЯНИЕ ---
var _current_stamina: float = 100.0
var _stamina_timer: float = 0.0
var _is_exhausted: bool = false
var _is_crouching: bool = false

var _current_battery: float = 100.0
var _is_flashlight_on: bool = true
var _flicker_noise_seed: float = 0.0

var _bob_timer: float = 0.0
var _current_step_cycle: float = 0.0
var _previous_step_phase: float = 0.0

var _target_flashlight_transform: Transform3D
var _current_focused_interactable: Interactable = null

var _mouse_sensitivity: float = 0.0022
var _current_surface_type: StringName = &"foliage"
var _inventory: Array[ItemData] = []


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_current_stamina = max_stamina
	_current_battery = max_battery_capacity
	
	if flashlight_pivot != null:
		_target_flashlight_transform = flashlight_pivot.transform

	_setup_interaction_casts()
	_update_flashlight_visuals(0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse_delta: Vector2 = (event as InputEventMouseMotion).relative
		_rotate_view(mouse_delta)
		
	elif event.is_action_pressed("flashlight_toggle"):
		toggle_flashlight()
		
	elif event.is_action_pressed("interact"):
		_try_interact()
		
	elif event.is_action_pressed("crouch_toggle"):
		_is_crouching = not _is_crouching


func _physics_process(delta: float) -> void:
	_update_stamina(delta)
	_update_surface_detection()
	_process_movement(delta)
	_process_head_bob(delta)
	_process_flashlight_sway(delta)
	_process_flashlight_battery(delta)
	_process_interactions()


# --- ОБРАБОТКА ВРАЩЕНИЯ КАМЕРЫ ---
func _rotate_view(mouse_delta: Vector2) -> void:
	rotate_y(-mouse_delta.x * _mouse_sensitivity)
	head.rotate_x(-mouse_delta.y * _mouse_sensitivity)
	head.rotation.x = clampf(head.rotation.x, deg_to_rad(-88.0), deg_to_rad(88.0))


# --- ПЕРЕДВИЖЕНИЕ И ИНЕРЦИЯ ГРЯЗИ ---
func _process_movement(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if Input.is_action_just_pressed("jump") and not _is_exhausted and not _is_crouching:
			velocity.y = jump_velocity
			_current_stamina = maxf(0.0, _current_stamina - 10.0)
			_stamina_timer = stamina_regen_delay

	# Считывание векторов ввода
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Определение скорости
	var is_sprinting: bool = Input.is_action_pressed("sprint") and input_dir.y < -0.1 and not _is_exhausted and not _is_crouching
	var target_speed: float = walk_speed

	if _is_crouching:
		target_speed = crouch_speed
	elif _is_exhausted:
		target_speed = exhausted_speed
	elif is_sprinting:
		target_speed = sprint_speed
		_current_stamina = maxf(0.0, _current_stamina - (stamina_sprint_drain * delta))
		_stamina_timer = stamina_regen_delay
		if _current_stamina <= 0.0:
			_is_exhausted = true

	# Динамический расчет трения в зависимости от типа грунта
	var current_accel: float = standard_acceleration
	var current_fric: float = standard_friction

	if _current_surface_type == &"mud":
		current_accel = mud_acceleration
		current_fric = mud_friction

	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var target_velocity: Vector3 = move_direction * target_speed

	if move_direction.length_squared() > 0.001:
		horizontal_velocity = horizontal_velocity.lerp(target_velocity, current_accel * delta)
	else:
		horizontal_velocity = horizontal_velocity.lerp(Vector3.ZERO, current_fric * delta)

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	move_and_slide()

	# Оповещение подсистемы слуха монстров при беге
	if is_sprinting and horizontal_velocity.length() > 2.5 and is_on_floor():
		if SanityGlobalManager:
			SanityGlobalManager.emit_noise(global_position, 16.0, &"player_sprint")


# --- ПРОЦЕДУРНЫЙ ХЕДБОББИНГ И НАКЛОНЫ КАМЕРЫ ---
func _process_head_bob(delta: float) -> void:
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var is_moving: bool = horizontal_speed > 0.3 and is_on_floor()

	var target_tilt: float = -Input.get_axis("move_left", "move_right") * camera_tilt_amount
	camera.rotation.z = lerp_angle(camera.rotation.z, target_tilt, camera_tilt_speed * delta)

	if not is_moving:
		_bob_timer = move_toward(_bob_timer, 0.0, delta * 2.0)
		camera.transform.origin = camera.transform.origin.lerp(Vector3.ZERO, delta * 8.0)
		return

	var is_sprinting: bool = horizontal_speed > (walk_speed + 0.5)
	var frequency: float = bob_frequency_sprint if is_sprinting else bob_frequency_walk
	var amp_v: float = bob_amplitude_sprint_v if is_sprinting else bob_amplitude_walk_v
	var amp_h: float = bob_amplitude_sprint_h if is_sprinting else bob_amplitude_walk_h

	_bob_timer += delta * frequency * (horizontal_speed / walk_speed)
	
	var bob_offset_y: float = sin(_bob_timer) * amp_v
	var bob_offset_x: float = cos(_bob_timer * 0.5) * amp_h
	camera.transform.origin = Vector3(bob_offset_x, bob_offset_y, 0.0)

	# Детекция нижней точки фазы синусоиды для шага
	var current_sine_val: float = sin(_bob_timer)
	if _previous_step_phase > 0.0 and current_sine_val <= 0.0:
		_trigger_footstep(is_sprinting)
	_previous_step_phase = current_sine_val


# --- ДИНАМИЧЕСКИЙ ФОНАРИК С ФИЗИЧЕСКИМ ПОКАЧИВАНИЕМ И ФЛИККЕРИНГОМ ---
func _process_flashlight_sway(delta: float) -> void:
	if flashlight_pivot == null:
		return
		
	# Инерционное сглаживание положения фонарика относительно камеры (физический лаг руки)
	var target_basis: Basis = camera.global_transform.basis
	flashlight_pivot.global_transform.basis = flashlight_pivot.global_transform.basis.slerp(
		target_basis, 
		flashlight_sway_smoothing * delta
	)


func _process_flashlight_battery(delta: float) -> void:
	if not _is_flashlight_on:
		return

	if _current_battery > 0.0:
		_current_battery = maxf(0.0, _current_battery - (battery_drain_rate * delta))
		flashlight_battery_changed.emit(_current_battery, max_battery_capacity)
	else:
		_is_flashlight_on = false
		flashlight_toggled.emit(false)

	_update_flashlight_visuals(delta)


func _update_flashlight_visuals(delta: float) -> void:
	if flashlight_spot == null:
		return

	if not _is_flashlight_on or _current_battery <= 0.0:
		flashlight_spot.visible = false
		return

	flashlight_spot.visible = true

	# Нелинейное затухание яркости: I = I_0 * (charge / 100)^1.6
	var battery_ratio: float = _current_battery / max_battery_capacity
	var base_intensity: float = max_light_energy * pow(battery_ratio, 1.6)

	# Эффект критического мерцания (фликкеринга) при заряде ниже 20%
	if _current_battery <= critical_battery_threshold:
		_flicker_noise_seed += delta * 45.0
		var noise_val: float = sin(_flicker_noise_seed) * cos(_flicker_noise_seed * 2.37)
		
		# Спорадические кратковременные провалы света
		if randf() < 0.08:
			base_intensity *= randf_range(0.0, 0.25)
		else:
			base_intensity *= clampf(0.5 + 0.5 * noise_val, 0.1, 1.0)

	flashlight_spot.light_energy = base_intensity


func toggle_flashlight() -> void:
	if _current_battery <= 0.0 and not _is_flashlight_on:
		# Попытка включить разряженный фонарик
		if flashlight_click_audio != null:
			flashlight_click_audio.play()
		return

	_is_flashlight_on = not _is_flashlight_on
	if flashlight_click_audio != null:
		flashlight_click_audio.play()

	flashlight_toggled.emit(_is_flashlight_on)
	_update_flashlight_visuals(0.0)


func restore_flashlight_battery(amount: float) -> bool:
	if _current_battery >= max_battery_capacity:
		return false
	_current_battery = minf(max_battery_capacity, _current_battery + amount)
	flashlight_battery_changed.emit(_current_battery, max_battery_capacity)
	_update_flashlight_visuals(0.0)
	return true


# --- СТАМИНА И ДЫХАНИЕ ---
func _update_stamina(delta: float) -> void:
	if _stamina_timer > 0.0:
		_stamina_timer -= delta
	else:
		if _current_stamina < max_stamina:
			_current_stamina = minf(max_stamina, _current_stamina + (stamina_regen_rate * delta))
			if _is_exhausted and _current_stamina >= exhaustion_recovery_threshold:
				_is_exhausted = false

	stamina_changed.emit(_current_stamina, max_stamina)

	# Управление процедурным звуком тяжелого дыхания
	if breathing_audio != null:
		if _current_stamina < 35.0:
			if not breathing_audio.playing:
				breathing_audio.play()
			var intensity_factor: float = 1.0 - (_current_stamina / 35.0)
			breathing_audio.volume_db = lerpf(-15.0, 2.0, intensity_factor)
		else:
			if breathing_audio.playing and breathing_audio.volume_db < -14.0:
				breathing_audio.stop()
			else:
				breathing_audio.volume_db = move_toward(breathing_audio.volume_db, -25.0, delta * 12.0)


# --- ГИБРИДНАЯ СИСТЕМА ИНТЕРАКЦИЙ (RAYCAST + SHAPECAST ДЛЯ ТРАВЫ) ---
func _setup_interaction_casts() -> void:
	if interaction_ray != null:
		interaction_ray.target_position = Vector3(0, 0, -raycast_interaction_distance)
		interaction_ray.collision_mask = 4 # Слой 3 (интеракции)
	
	if interaction_shape != null:
		var sphere_shape: SphereShape3D = SphereShape3D.new()
		sphere_shape.radius = shapecast_radius
		interaction_shape.shape = sphere_shape
		interaction_shape.target_position = Vector3(0, 0, -raycast_interaction_distance)
		interaction_shape.collision_mask = 4


func _process_interactions() -> void:
	var detected_interactable: Interactable = null

	# Приоритет 1: Прямой RayCast3D (точный выбор записок, ключей на столах)
	if interaction_ray != null and interaction_ray.is_colliding():
		var collider: Object = interaction_ray.get_collider()
		if collider is Interactable and (collider as Interactable).is_interactable:
			detected_interactable = collider as Interactable

	# Приоритет 2: Объемный ShapeCast3D (подбор батареек и предметов, скрытых в густой траве)
	if detected_interactable == null and interaction_shape != null and interaction_shape.is_colliding():
		var closest_dist: float = 999.0
		for i in range(interaction_shape.get_collision_count()):
			var collider: Object = interaction_shape.get_collider(i)
			if collider is Interactable and (collider as Interactable).is_interactable:
				var dist: float = global_position.distance_to((collider as Node3D).global_position)
				if dist < closest_dist:
					closest_dist = dist
					detected_interactable = collider as Interactable

	# Обработка смены таргета
	if detected_interactable != _current_focused_interactable:
		if _current_focused_interactable != null:
			_current_focused_interactable.set_focus(self, false)
			
		_current_focused_interactable = detected_interactable
		
		if _current_focused_interactable != null:
			_current_focused_interactable.set_focus(self, true)
			interaction_target_changed.emit(_current_focused_interactable.get_prompt())
		else:
			interaction_target_changed.emit("")


func _try_interact() -> void:
	if _current_focused_interactable != null and _current_focused_interactable.is_interactable:
		_current_focused_interactable.interact(self)


# --- ОПРЕДЕЛЕНИЕ ПОВЕРХНОСТИ И ПРОЦЕДУРНЫЕ ШАГИ ---
func _update_surface_detection() -> void:
	if floor_detector == null or not floor_detector.is_colliding():
		return

	var collider: Object = floor_detector.get_collider()
	if collider is Node:
		var node: Node = collider as Node
		if node.has_meta("surface_type"):
			_current_surface_type = node.get_meta("surface_type")
		elif node.is_in_group("surface_mud"):
			_current_surface_type = &"mud"
		elif node.is_in_group("surface_wood"):
			_current_surface_type = &"wood"
		elif node.is_in_group("surface_rock"):
			_current_surface_type = &"rock"
		else:
			_current_surface_type = &"foliage"


func _trigger_footstep(is_sprinting: bool) -> void:
	var sound_bank: Array[AudioStream]
	match _current_surface_type:
		&"mud":
			sound_bank = footsteps_mud
		&"wood":
			sound_bank = footsteps_wood
		&"rock":
			sound_bank = footsteps_rock
		_:
			sound_bank = footsteps_foliage

	if sound_bank.is_empty() or footstep_audio == null:
		return

	var random_clip: AudioStream = sound_bank[randi() % sound_bank.size()]
	footstep_audio.stream = random_clip
	footstep_audio.pitch_scale = randf_range(0.92, 1.08)
	footstep_audio.volume_db = randf_range(-2.0, 1.0) if is_sprinting else randf_range(-7.0, -4.0)
	footstep_audio.play()

	player_stepped.emit(_current_surface_type, is_sprinting)
	
	# Излучение акустического события для ИИ монстра
	var noise_radius: float = 14.0 if is_sprinting else 4.0
	if SanityGlobalManager:
		SanityGlobalManager.emit_noise(global_position, noise_radius, &"footstep")


# --- ИНВЕНТАРЬ И УТИЛИТЫ ---
func add_item_to_inventory(item: ItemData) -> bool:
	_inventory.append(item)
	return true


func has_item_by_id(item_id: StringName) -> bool:
	for item in _inventory:
		if item.id == item_id:
			return true
	return false


func display_hud_notification(text: String) -> void:
	interaction_target_changed.emit(text)
