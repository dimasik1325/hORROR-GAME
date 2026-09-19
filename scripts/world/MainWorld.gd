extends Node3D

## Корневой скрипт сцены MainWorld для "Эхо Чащи" (Godot 4.6-dev)
## Инициализирует связи между подсистемами, освещением, пост-процессингом и менеджером Безумия.

@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var post_process_rect: ColorRect = $PostProcessLayer/PostProcessRect
@onready var directional_light: DirectionalLight3D = $DirectionalLight3D
@onready var player: CharacterBody3D = $Player
@onready var enemy: CharacterBody3D = $Enemy


func _ready() -> void:
	_register_with_sanity_manager()


func _register_with_sanity_manager() -> void:
	var sanity_mgr = get_node_or_null("/root/SanityGlobalManager")
	if sanity_mgr == null:
		return

	# Передаем ссылки на окружение и шейдер
	sanity_mgr.world_environment_ref = world_environment
	
	if post_process_rect != null and post_process_rect.material is ShaderMaterial:
		sanity_mgr.postprocess_material_ref = post_process_rect.material as ShaderMaterial

	if directional_light != null and sanity_mgr.has_method("register_light_source"):
		sanity_mgr.register_light_source(directional_light)
