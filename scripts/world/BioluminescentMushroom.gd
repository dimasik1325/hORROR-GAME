class_name BioluminescentMushroom
extends Node3D

## Биолюминесцентные грибы Чащи (Godot 4.6-dev)
## Излучают мягкий призрачный свет в болоте и под корнями Древа.

@export var glow_color: Color = Color(0.15, 0.9, 0.75, 1.0)
@export var glow_energy: float = 1.4

@onready var light: OmniLight3D = $OmniLight3D
@onready var cap_mesh: MeshInstance3D = $MushroomCap

var _pulse_seed: float = 0.0


func _ready() -> void:
	if light != null:
		light.light_color = glow_color
		light.light_energy = glow_energy
		light.omni_range = 5.0
		
		var sanity_mgr = get_node_or_null("/root/SanityGlobalManager")
		if sanity_mgr and sanity_mgr.has_method("register_light_source"):
			sanity_mgr.register_light_source(light)


func _process(delta: float) -> void:
	if light == null:
		return
	_pulse_seed += delta * 2.5
	var pulse: float = sin(_pulse_seed) * 0.25 + cos(_pulse_seed * 1.3) * 0.15
	light.light_energy = maxf(0.4, glow_energy + pulse)
