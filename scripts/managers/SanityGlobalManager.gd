class_name SanityGlobalManager
extends Node

## Глобальный менеджер Рассудка и Психологического Хоррора (Godot 4.6-dev Autoload)
## Управляет шкалой Безумия, сканированием освещенности игрока, динамической адаптацией 
## окружения (WorldEnvironment/Volumetric Fog/SDFGI) и диспетчеризацией галлюцинаций.

signal sanity_changed(new_sanity: float, delta_change: float)
signal sanity_state_critical(is_critical: bool)
signal hallucination_triggered(event_data: SanityEvent)
signal noise_emitted(origin: Vector3, radius: float, noise_type: StringName)

# --- ПАРАМЕТРЫ РАССУДКА ---
@export_group("Динамика Рассудка")
@export_range(0.0, 100.0, 0.5) var current_sanity: float = 100.0
@export var min_sanity: float = 0.0
@export var max_sanity: float = 100.0

## Скорость падения рассудка в полной темноте (ед./сек)
@export var darkness_decay_rate: float = 1.8
## Скорость восстановления у безопасных костров и мощных ламп (ед./сек)
@export var safe_light_recovery_rate: float = 3.2
## Порог критического безумия (включает жесткие шейдеры и спавн кошмаров)
@export var critical_threshold: float = 30.0

# --- ПАРАМЕТРЫ ОКРУЖЕНИЯ ---
@export_group("Параметры Окружения (Базовые -> Безумие)")
@export var normal_fog_density: float = 0.015
@export var insanity_fog_density: float = 0.085
@export var normal_fog_emission: Color = Color(0.05, 0.07, 0.09)
@export var insanity_fog_emission: Color = Color(0.18, 0.02, 0.02) # Кроваво-багровый оттенок

@export var normal_saturation: float = 0.9
@export var insanity_saturation: float = 0.35 # Обесцвечивание мира
@export var normal_contrast: float = 1.05
@export var insanity_contrast: float = 1.45   # Резкий агрессивный контраст

# --- ССЫЛКИ НА СИСТЕМЫ ---
var player_ref: CharacterBody3D = null
var world_environment_ref: WorldEnvironment = null
var postprocess_material_ref: ShaderMaterial = null

# Список зарегистрированных источников света в мире (костры, прожекторы, лампы)
var _registered_lights: Array[Light3D] = []
var _registered_sanity_events: Array[SanityEvent] = []
var _event_cooldown_tracker: Dictionary = {} # StringName -> float (timestamp)

var _is_critical_state: bool = false
var _current_light_intensity: float = 1.0
var _ambient_heartbeat_player: AudioStreamPlayer = null
var _tween_environment: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_heartbeat_audio()


func _physics_process(delta: float) -> void:
	if player_ref == null:
		_find_player()
		return

	_calculate_player_illuminance()
	_update_sanity_decay(delta)
	_evaluate_hallucination_triggers()


# --- РАСЧЕТ ОСВЕЩЕННОСТИ ИГРОКА (MULTI-RAYCAST К ИСТОЧНИКАМ СВЕТА) ---
func _calculate_player_illuminance() -> void:
	if player_ref == null:
		return

	var space_state: PhysicsDirectSpaceState3D = player_ref.get_world_3d().direct_space_state
	var player_head_pos: Vector3 = player_ref.global_position + Vector3(0, 1.6, 0)
	var total_illuminance: float = 0.0

	# 1. Проверка собственного фонарика игрока
	var flashlight_on: bool = player_ref.get("_is_flashlight_on") if "_is_flashlight_on" in player_ref else false
	var battery: float = player_ref.get("_current_battery") if "_current_battery" in player_ref else 100.0
	
	if flashlight_on and battery > 0.0:
		total_illuminance += 0.65 * (battery / 100.0)

	# 2. Проверка статических и динамических источников света в мире
	for light in _registered_lights:
		if not is_instance_valid(light) or not light.visible or light.light_energy <= 0.01:
			continue

		var light_pos: Vector3 = light.global_position
		var distance: float = player_head_pos.distance_to(light_pos)
		
		# Проверка эффективного радиуса
		var max_range: float = 30.0
		if light is OmniLight3D:
			max_range = (light as OmniLight3D).omni_range
		elif light is SpotLight3D:
			max_range = (light as SpotLight3D).spot_range

		if distance > max_range:
			continue

		# Рейкаст на проверку прямой видимости источника (не перекрыт ли деревьями/камнями)
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			light_pos,
			player_head_pos,
			1 # Коллизия только с миром/статикой
		)
		var result: Dictionary = space_state.intersect_ray(query)

		# Если путь свободен (нет окклюдеров между светом и головой игрока)
		if result.is_empty():
			var attenuation: float = 1.0 - (distance / max_range)
			if light is SpotLight3D:
				var spot: SpotLight3D = light as SpotLight3D
				var to_player: Vector3 = (player_head_pos - light_pos).normalized()
				var forward: Vector3 = -spot.global_transform.basis.z
				var angle: float = rad_to_deg(forward.angle_to(to_player))
				if angle < (spot.spot_angle * 0.5):
					total_illuminance += spot.light_energy * attenuation
			else:
				total_illuminance += light.light_energy * attenuation

	_current_light_intensity = clampf(total_illuminance, 0.0, 2.0)


# --- ДИНАМИКА РАССУДКА И ТРИГГЕРЫ ---
func _update_sanity_decay(delta: float) -> void:
	var previous_sanity: float = current_sanity
	var delta_change: float = 0.0

	# Если игрок в темноте (< 0.25 света) — рассудок убывает
	if _current_light_intensity < 0.25:
		var darkness_factor: float = 1.0 - (_current_light_intensity / 0.25)
		delta_change = -darkness_decay_rate * darkness_factor * delta
	# Если игрок в безопасности у мощного света (> 0.75) — рассудок плавно восстанавливается
	elif _current_light_intensity > 0.75:
		var light_factor: float = (_current_light_intensity - 0.75) / 1.25
		delta_change = safe_light_recovery_rate * light_factor * delta

	current_sanity = clampf(current_sanity + delta_change, min_sanity, max_sanity)

	if not is_equal_approx(previous_sanity, current_sanity):
		sanity_changed.emit(current_sanity, delta_change)
		_apply_environment_changes()

	# Обработка критического порога
	var was_critical: bool = _is_critical_state
	_is_critical_state = (current_sanity <= critical_threshold)
	if was_critical != _is_critical_state:
		sanity_state_critical.emit(_is_critical_state)


# --- ПЛАВНАЯ ИНТЕРПОЛЯЦИЯ ОКРУЖЕНИЯ ЧЕРЕЗ TWEEN ---
func _apply_environment_changes() -> void:
	var insanity_factor: float = 1.0 - (current_sanity / max_sanity) # 0.0 (норма) -> 1.0 (полный психоз)

	# 1. Обновление пост-процессинг шейдера
	if postprocess_material_ref != null:
		postprocess_material_ref.set_shader_parameter("sanity_intensity", insanity_factor)
		var heartbeat_speed: float = lerpf(1.0, 3.2, insanity_factor)
		postprocess_material_ref.set_shader_parameter("heartbeat_pulse", heartbeat_speed)

	# 2. Плавная интерполяция WorldEnvironment
	if world_environment_ref != null and world_environment_ref.environment != null:
		var env: Environment = world_environment_ref.environment
		
		var target_fog: float = lerpf(normal_fog_density, insanity_fog_density, insanity_factor)
		var target_emission: Color = normal_fog_emission.lerp(insanity_fog_emission, insanity_factor)
		var target_sat: float = lerpf(normal_saturation, insanity_saturation, insanity_factor)
		var target_con: float = lerpf(normal_contrast, insanity_contrast, insanity_factor)

		if _tween_environment != null and _tween_environment.is_running():
			_tween_environment.kill()

		_tween_environment = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tween_environment.tween_property(env, "volumetric_fog_density", target_fog, 0.5)
		_tween_environment.tween_property(env, "volumetric_fog_emission", target_emission, 0.5)
		_tween_environment.tween_property(env, "adjustment_saturation", target_sat, 0.5)
		_tween_environment.tween_property(env, "adjustment_contrast", target_con, 0.5)

	# 3. Аудио сердцебиения
	if _ambient_heartbeat_player != null:
		if insanity_factor > 0.3:
			if not _ambient_heartbeat_player.playing:
				_ambient_heartbeat_player.play()
			_ambient_heartbeat_player.volume_db = lerpf(-20.0, 4.0, (insanity_factor - 0.3) / 0.7)
			_ambient_heartbeat_player.pitch_scale = lerpf(0.9, 1.4, insanity_factor)
		else:
			if _ambient_heartbeat_player.playing:
				_ambient_heartbeat_player.stop()


# --- ОЦЕНКА И ЗАПУСК ГАЛЛЮЦИНАЦИЙ ---
func _evaluate_hallucination_triggers() -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0

	for event in _registered_sanity_events:
		if event == null:
			continue

		var last_triggered: float = _event_cooldown_tracker.get(event.event_id, -999.0)
		if event.can_trigger(current_sanity, last_triggered, current_time):
			_event_cooldown_tracker[event.event_id] = current_time
			_execute_sanity_event(event)


func _execute_sanity_event(event: SanityEvent) -> void:
	hallucination_triggered.emit(event)

	match event.event_type:
		SanityEvent.SanityEventType.AUDIO_WHISPER:
			if event.audio_cue != null and player_ref != null:
				var whisper_node: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
				whisper_node.stream = event.audio_cue
				whisper_node.volume_db = event.audio_volume_db
				whisper_node.bus = &"Ambience"
				player_ref.get_parent().add_child(whisper_node)
				
				# Размещение за спиной
				var spawn_xform: Transform3D = event.calculate_spawn_transform(player_ref.global_transform)
				whisper_node.global_transform = spawn_xform
				whisper_node.play()
				whisper_node.finished.connect(whisper_node.queue_free)

		SanityEvent.SanityEventType.PHANTOM_SPAWN:
			if event.phantom_prefab != null and player_ref != null:
				var phantom_instance: Node3D = event.phantom_prefab.instantiate() as Node3D
				if phantom_instance != null:
					player_ref.get_parent().add_child(phantom_instance)
					phantom_instance.global_transform = event.calculate_spawn_transform(player_ref.global_transform)

		SanityEvent.SanityEventType.LIGHT_FLICKER:
			if player_ref != null and player_ref.has_method("toggle_flashlight"):
				# Кратковременный сбой фонарика
				player_ref.set("_current_battery", maxf(0.0, player_ref.get("_current_battery") - 5.0))

		_:
			pass


# --- ИЗЛУЧЕНИЕ ШУМА ДЛЯ ИИ МОНСТРОВ ---
func emit_noise(origin: Vector3, radius: float, noise_type: StringName) -> void:
	noise_emitted.emit(origin, radius, noise_type)


# --- РЕГИСТРАЦИЯ И СВЯЗИ ---
func register_light_source(light: Light3D) -> void:
	if light not in _registered_lights:
		_registered_lights.append(light)


func unregister_light_source(light: Light3D) -> void:
	_registered_lights.erase(light)


func register_sanity_event(event: SanityEvent) -> void:
	if event not in _registered_sanity_events:
		_registered_sanity_events.append(event)


func modify_sanity(amount: float) -> void:
	var prev: float = current_sanity
	current_sanity = clampf(current_sanity + amount, min_sanity, max_sanity)
	sanity_changed.emit(current_sanity, current_sanity - prev)
	_apply_environment_changes()


func _find_player() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var players: Array[Node] = tree.get_nodes_in_group("Player")
	if not players.is_empty():
		player_ref = players[0] as CharacterBody3D


func _setup_heartbeat_audio() -> void:
	_ambient_heartbeat_player = AudioStreamPlayer.new()
	_ambient_heartbeat_player.bus = &"Master"
	add_child(_ambient_heartbeat_player)
