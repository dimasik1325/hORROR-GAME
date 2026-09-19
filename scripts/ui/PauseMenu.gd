class_name PauseMenu
extends CanvasLayer

## Внутриигровое меню паузы (Godot 4.6-dev)

@onready var panel: PanelContainer = $PanelContainer
@onready var resume_btn: Button = $PanelContainer/Margin/VBox/ResumeBtn
@onready var settings_btn: Button = $PanelContainer/Margin/VBox/SettingsBtn
@onready var restart_btn: Button = $PanelContainer/Margin/VBox/RestartBtn
@onready var quit_btn: Button = $PanelContainer/Margin/VBox/QuitBtn

@onready var settings_menu: Control = $SettingsMenu

var is_paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	if settings_menu != null:
		settings_menu.visible = false
		if settings_menu.has_signal("closed"):
			settings_menu.closed.connect(func(): panel.visible = true)

	resume_btn.pressed.connect(unpause)
	settings_btn.pressed.connect(_on_settings_pressed)
	restart_btn.pressed.connect(_on_restart_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if is_paused:
			unpause()
		else:
			pause()
		get_viewport().set_input_as_handled()


func pause() -> void:
	is_paused = true
	panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true


func unpause() -> void:
	is_paused = false
	panel.visible = false
	if settings_menu != null:
		settings_menu.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().paused = false


func _on_settings_pressed() -> void:
	panel.visible = false
	if settings_menu != null:
		settings_menu.visible = true


func _on_restart_pressed() -> void:
	unpause()
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr:
		game_mgr.restart_game()


func _on_quit_pressed() -> void:
	unpause()
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr:
		game_mgr.go_to_main_menu()
