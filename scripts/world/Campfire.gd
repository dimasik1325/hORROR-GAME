class_name Campfire
extends Node3D

## Интерактивный лесной костер с реалистичным мерцанием, частицами и зоной восстановления рассудка (Godot 4.6-dev)

@export_group("Параметры Огня")
@export var base_light_energy: float = 3.5
@export var light_color: Color = Color(1.0, 0.45, 0.12, 1.0)
@export var flicker_speed: float = 14.0
@export var flicker_intensity: float = 0.65
@export var heat_radius: float = 7.0
@export var sanity_recovery_bonus: float = 4.5 # ед./сек

@onready var fire_light: OmniLight3D = $OmniLight3D
@onready var fire_particles: CPUParticles3D = $FireParticles
@onready var smoke_particles: CPUParticles3D = $SmokeParticles
@onready var crackle_audio: AudioStreamPlayer3D = $CrackleAudio
@onready var warm_zone: Area3D = $WarmZone

var _flicker_noise: float = 0.0
var _is_player_in_zone: bool = false


func _ready() -> void:
	if fire_light != null:
		fire_light.light_color = light_color
		fire_light.omni_range = heat_radius * 1.8
		fire_light.shadow_enabled = true
		
		var sanity_mgr = get_node_or_null("/root/SanityGlobalManager")
		if sanity_mgr and sanity_mgr.has_method("register_light_source"):
			sanity_mgr.register_light_source(fire_light)

	if warm_zone != null:
		warm_zone.body_entered.connect(_on_warm_zone_entered)
		warm_zone.body_exited.connect(_on_warm_zone_exited)


func _process(delta: float) -> void:
	# Реалистичное процедурное мерцание пламени
	if fire_light != null and fire_light.visible:
		_flicker_noise += delta * flicker_speed
		var noise_val: float = sin(_flicker_noise) * 0.5 + cos(_flicker_noise * 2.3) * 0.3 + sin(_flicker_noise * 5.7) * 0.2
		fire_light.light_energy = base_light_energy + (noise_val * flicker_intensity)

	# Восстановление рассудка игрока у костра
	if _is_player_in_zone:
		var sanity_mgr = get_node_or_null("/root/SanityGlobalManager")
		if sanity_mgr and sanity_mgr.has_method("modify_sanity"):
			sanity_mgr.modify_sanity(sanity_recovery_bonus * delta)


func _on_warm_zone_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		_is_player_in_zone = true


func _on_warm_zone_exited(body: Node3D) -> void:
	if body.is_in_group("Player"):
		_is_player_in_zone = false
