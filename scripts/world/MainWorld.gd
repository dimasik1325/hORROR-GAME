extends Node3D

## Корневой скрипт сцены MainWorld для "Эхо Чащи" (Godot 4.6-dev)
## Инициализирует связи между подсистемами, освещением, пост-процессингом, HUD и менеджером Безумия.

@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var post_process_rect: ColorRect = $PostProcessLayer/PostProcessRect
@onready var directional_light: DirectionalLight3D = $DirectionalLight3D
@onready var player: CharacterBody3D = $Player
@onready var enemy: CharacterBody3D = $Enemy
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	_register_with_sanity_manager()
	_connect_hud_signals()


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


func _connect_hud_signals() -> void:
	if player != null and hud != null:
		if player.has_signal("stamina_changed") and hud.has_method("update_stamina"):
			player.stamina_changed.connect(hud.update_stamina)
		if player.has_signal("flashlight_battery_changed") and hud.has_method("update_battery"):
			player.flashlight_battery_changed.connect(hud.update_battery)
		if player.has_signal("interaction_target_changed") and hud.has_method("set_interaction_prompt"):
			player.interaction_target_changed.connect(hud.set_interaction_prompt)
