class_name MainMenu
extends Control

## Главное меню игры "Эхо Чащи" (Godot 4.6-dev)

@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var controls_button: Button = $VBoxContainer/ControlsButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

@onready var settings_menu: Control = $SettingsMenu
@onready var controls_dialog: PanelContainer = $ControlsDialog
@onready var close_controls_btn: Button = $ControlsDialog/Margin/VBox/CloseButton


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_connect_buttons()
	if settings_menu != null:
		settings_menu.visible = false
	if controls_dialog != null:
		controls_dialog.visible = false


func _connect_buttons() -> void:
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	controls_button.pressed.connect(_on_controls_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	if close_controls_btn != null:
		close_controls_btn.pressed.connect(func(): controls_dialog.visible = false)
		
	if settings_menu != null and settings_menu.has_signal("closed"):
		settings_menu.closed.connect(func(): settings_menu.visible = false)


func _on_play_pressed() -> void:
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr:
		game_mgr.restart_game()
	else:
		get_tree().change_scene_to_file("res://scenes/MainWorld.tscn")


func _on_settings_pressed() -> void:
	if settings_menu != null:
		settings_menu.visible = true


func _on_controls_pressed() -> void:
	if controls_dialog != null:
		controls_dialog.visible = true


func _on_quit_pressed() -> void:
	get_tree().quit()
