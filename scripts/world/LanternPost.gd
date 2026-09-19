class_name LanternPost
extends Node3D

## Деревянный фонарный столб с керосиновой лампой (Godot 4.6-dev)

@export var light_energy: float = 2.8
@export var light_color: Color = Color(1.0, 0.72, 0.38, 1.0)
@export var is_flickering: bool = true

@onready var lantern_light: OmniLight3D = $LanternMesh/OmniLight3D
@onready var spot_down_light: SpotLight3D = $LanternMesh/SpotLight3D

var _noise_timer: float = 0.0


func _ready() -> void:
	if lantern_light != null:
		lantern_light.light_color = light_color
		lantern_light.light_energy = light_energy
		lantern_light.shadow_enabled = true
		lantern_light.omni_range = 14.0

		var sanity_mgr = get_node_or_null("/root/SanityGlobalManager")
		if sanity_mgr and sanity_mgr.has_method("register_light_source"):
			sanity_mgr.register_light_source(lantern_light)

	if spot_down_light != null:
		spot_down_light.light_color = light_color
		spot_down_light.light_energy = light_energy * 0.8


func _process(delta: float) -> void:
	if not is_flickering or lantern_light == null:
		return

	_noise_timer += delta * 6.0
	var subtle_flicker: float = sin(_noise_timer) * 0.15 + cos(_noise_timer * 3.1) * 0.08
	lantern_light.light_energy = maxf(0.5, light_energy + subtle_flicker)
