class_name ActiveFlare
extends RigidBody3D

## Зажженный сигнальный фальшфейер (Godot 4.6-dev)
## Горит ярким алым пламенем, дымит и отпугивает монстра "Сплетенный" в радиусе 10 метров.

@export var burn_duration: float = 25.0
@export var light_energy: float = 4.8
@export var repel_radius: float = 10.0

@onready var flare_light: OmniLight3D = $OmniLight3D
@onready var spark_particles: CPUParticles3D = $SparkParticles
@onready var smoke_particles: CPUParticles3D = $SmokeParticles
@onready var burn_audio: AudioStreamPlayer3D = $BurnAudio
@onready var repel_area: Area3D = $RepelArea

var _burn_timer: float = 25.0
var _is_burning: bool = true


func _ready() -> void:
	_burn_timer = burn_duration
	if flare_light != null:
		flare_light.light_color = Color(1.0, 0.15, 0.1, 1.0)
		flare_light.light_energy = light_energy
		flare_light.shadow_enabled = true
		flare_light.omni_range = repel_radius * 1.5

		var sanity_mgr = get_node_or_null("/root/SanityGlobalManager")
		if sanity_mgr and sanity_mgr.has_method("register_light_source"):
			sanity_mgr.register_light_source(flare_light)

	if repel_area != null:
		repel_area.body_entered.connect(_on_monster_entered_zone)


func _physics_process(delta: float) -> void:
	if not _is_burning:
		return

	_burn_timer -= delta
	
	# Процедурное дрожание пламени фальшфейера
	if flare_light != null:
		var jitter = randf_range(-0.4, 0.4)
		flare_light.light_energy = light_energy + jitter

	# Отпугивание монстров в зоне горения
	_repel_monsters()

	if _burn_timer <= 0.0:
		_extinguish_flare()


func _repel_monsters() -> void:
	var enemies = get_tree().get_nodes_in_group("Enemies")
	for enemy in enemies:
		if enemy is Node3D:
			var dist = global_position.distance_to((enemy as Node3D).global_position)
			if dist <= repel_radius and enemy.has_method("stun_by_flare"):
				enemy.call("stun_by_flare", global_position, 6.0)


func _on_monster_entered_zone(body: Node3D) -> void:
	if body.is_in_group("Enemies") and body.has_method("stun_by_flare"):
		body.call("stun_by_flare", global_position, 8.0)


func _extinguish_flare() -> void:
	_is_burning = false
	if spark_particles != null:
		spark_particles.emitting = false
	if flare_light != null:
		var tween = create_tween()
		tween.tween_property(flare_light, "light_energy", 0.0, 1.5)
		tween.tween_callback(queue_free)
	else:
		queue_free()
