@tool
class_name SanityEvent
extends Resource

## Ресурс триггера и параметров галлюцинаций для системы Безумия в "Эхо Чащи" (Godot 4.6-dev)

enum SanityEventType {
	AUDIO_WHISPER,           ## Параноидальные шепоты и шаги за спиной
	VISUAL_GLITCH,           ## Временное искажение пост-процессинга и геометрии
	WORLD_ALTERATION,        ## Активация скрытых жутких слоев окружения
	PHANTOM_SPAWN,           ## Появление фантома, исчезающего при взгляде
	LIGHT_FLICKER,           ## Принудительное угасание и мерцание фонарика
	GEOMETRY_SHIFT,          ## Смещение троп и положения деревьев
	HEARTBEAT_ACCELERATION   ## Резкий приступ паники с сужением поля зрения
}

@export_group("Триггерные Условия")
## Уникальный идентификатор события
@export var event_id: StringName = &"sanity_event_default"
## Порог рассудка (от 0.0 до 100.0), ниже которого событие может активироваться
@export_range(0.0, 100.0, 0.5) var trigger_threshold: float = 40.0
## Тип галлюцинаторного воздействия
@export var event_type: SanityEventType = SanityEventType.AUDIO_WHISPER
## Вероятность срабатывания при тике проверки (0.0 - 1.0)
@export_range(0.0, 1.0, 0.01) var spawn_probability: float = 0.35
## Время перезарядки (сек) перед повторным запуском этого же события
@export_range(1.0, 300.0, 0.5) var cooldown_seconds: float = 45.0

@export_group("Временные Параметры")
## Длительность активной фазы галлюцинации (сек)
@export_range(0.1, 60.0, 0.1) var duration: float = 6.0
## Кривая затухания/нарастания интенсивности эффекта
@export var intensity_curve: Curve

@export_group("Аудио Данные")
## Звуковой файл шепота, иллюзорных шагов или стонов
@export var audio_cue: AudioStream
## Громкость в dB
@export_range(-40.0, 10.0, 0.5) var audio_volume_db: float = 0.0
## Должен ли звук позиционироваться в 3D пространстве сзади игрока
@export var is_spatial_behind_player: bool = true

@export_group("3D Префабы и Геометрия")
## Префаб фантома или искаженной геометрии для спавна
@export var phantom_prefab: PackedScene
## Дистанция спавна от игрока в метрах
@export_range(2.0, 50.0, 0.5) var spawn_distance_meters: float = 12.0
## Угол относительно взгляда игрока (180 = строго за спиной, 45 = периферийное зрение)
@export_range(0.0, 180.0, 1.0) var spawn_angle_degrees: float = 135.0

@export_group("Параметры Окружения")
## Дополнительное локальное сгущение тумана Volumetric Fog
@export_range(0.0, 0.5, 0.005) var extra_fog_density: float = 0.08
## Множитель хроматической аберрации для шейдера
@export_range(0.0, 5.0, 0.1) var aberration_multiplier: float = 1.8

@export_group("Кастомные Данные")
## Словарь произвольных параметров для скриптовых расширений
@export var custom_parameters: Dictionary = {}


## Проверка готовности события к запуску
func can_trigger(current_sanity: float, last_triggered_timestamp: float, current_time: float) -> bool:
	if current_sanity > trigger_threshold:
		return false
	if (current_time - last_triggered_timestamp) < cooldown_seconds:
		return false
	return randf() <= spawn_probability


## Вычисление точки спавна фантома на основе позиции и ориентации игрока
func calculate_spawn_transform(player_transform: Transform3D) -> Transform3D:
	var angle_rad: float = deg_to_rad(spawn_angle_degrees)
	var sign_direction: float = 1.0 if randf() > 0.5 else -1.0
	var final_angle: float = angle_rad * sign_direction
	
	var forward: Vector3 = -player_transform.basis.z
	var spawn_direction: Vector3 = forward.rotated(Vector3.UP, final_angle).normalized()
	var spawn_position: Vector3 = player_transform.origin + (spawn_direction * spawn_distance_meters)
	
	var look_direction: Vector3 = (player_transform.origin - spawn_position).normalized()
	look_direction.y = 0.0
	if look_direction.length_squared() < 0.001:
		look_direction = Vector3.FORWARD
	else:
		look_direction = look_direction.normalized()
		
	var target_basis: Basis = Basis.looking_at(look_direction, Vector3.UP)
	return Transform3D(target_basis, spawn_position)
