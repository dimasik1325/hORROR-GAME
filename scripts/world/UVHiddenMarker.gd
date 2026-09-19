class_name UVHiddenMarker
extends Node3D

## Скрытая оккультная руна/стрелка культа, проявляющаяся только под ультрафиолетом [V] (Godot 4.6-dev)

@export var rune_color: Color = Color(0.6, 0.15, 0.95, 1.0)
@export var is_revealed: bool = false

@onready var rune_mesh: MeshInstance3D = $RuneMesh
@onready var rune_light: OmniLight3D = $OmniLight3D


func _ready() -> void:
	if rune_mesh != null:
		rune_mesh.visible = false
	if rune_light != null:
		rune_light.visible = false


func set_uv_illuminated(active: bool) -> void:
	if rune_mesh != null:
		rune_mesh.visible = active
	if rune_light != null:
		rune_light.visible = active
