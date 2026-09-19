class_name DynamicWeatherSystem
extends Node3D

## Динамическая погодная система: дождь, туман, грозовые вспышки молний и гром (Godot 4.6-dev)

@export_group("Параметры Дождя")
@export var is_raining: bool = true
@export var rain_intensity: float = 1.0

@export_group("Параметры Грозы")
@export var enable_lightning: bool = true
@export var min_lightning_interval: float = 15.0
@export var max_lightning_interval: float = 40.0

@onready var rain_particles: CPUParticles3D = $RainParticles
@onready var lightning_light: DirectionalLight3D = $LightningLight
@onready var thunder_audio: AudioStreamPlayer = $ThunderAudio
@onready var rain_ambient_audio: AudioStreamPlayer = $RainAmbientAudio

var _lightning_timer: float = 10.0
var _is_flashing: bool = false
var _player_ref: Node3D = null


func _ready() -> void:
	_reset_lightning_timer()
	if lightning_light != null:
		lightning_light.visible = false
		lightning_light.light_energy = 0.0

	if rain_ambient_audio != null:
		rain_ambient_audio.play()


func _process(delta: float) -> void:
	_follow_player()

	if enable_lightning:
		_lightning_timer -= delta
		if _lightning_timer <= 0.0 and not _is_flashing:
			_trigger_lightning_strike()


func _follow_player() -> void:
	if _player_ref == null:
		var players = get_tree().get_nodes_in_group("Player")
		if not players.is_empty():
			_player_ref = players[0] as Node3D

	if _player_ref != null:
		global_position = _player_ref.global_position + Vector3(0, 8.0, 0)


func _trigger_lightning_strike() -> void:
	_is_flashing = true
	if lightning_light != null:
		lightning_light.visible = true

	# Двойная реалистичная вспышка молнии
	var tween = create_tween()
	tween.tween_property(lightning_light, "light_energy", 4.5, 0.05)
	tween.tween_property(lightning_light, "light_energy", 0.8, 0.05)
	tween.tween_property(lightning_light, "light_energy", 6.0, 0.08)
	tween.tween_property(lightning_light, "light_energy", 0.0, 0.3)
	tween.tween_callback(_play_thunder)


func _play_thunder() -> void:
	if lightning_light != null:
		lightning_light.visible = false

	if thunder_audio != null:
		thunder_audio.pitch_scale = randf_range(0.85, 1.1)
		thunder_audio.volume_db = randf_range(-2.0, 3.0)
		thunder_audio.play()

	_is_flashing = false
	_reset_lightning_timer()


func _reset_lightning_timer() -> void:
	_lightning_timer = randf_range(min_lightning_interval, max_lightning_interval)
