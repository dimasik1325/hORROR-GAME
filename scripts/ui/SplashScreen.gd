class_name SplashScreen
extends Control

## Вступительный экран с анимированным логотипом игры (Godot 4.6-dev)

@onready var studio_label: Label = $VBox/StudioLabel
@onready var title_label: Label = $VBox/TitleLabel
@onready var subtitle_label: Label = $VBox/SubtitleLabel
@onready var prompt_label: Label = $PromptLabel

var _can_skip: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_animate_intro()


func _animate_intro() -> void:
	studio_label.modulate.a = 0.0
	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0
	prompt_label.modulate.a = 0.0

	var tween = create_tween().set_parallel(false)
	
	# Появление студии
	tween.tween_property(studio_label, "modulate:a", 1.0, 0.8)
	tween.tween_interval(0.6)
	
	# Появление названия игры
	tween.tween_property(title_label, "modulate:a", 1.0, 1.2)
	tween.tween_property(subtitle_label, "modulate:a", 1.0, 0.8)
	tween.tween_property(prompt_label, "modulate:a", 1.0, 0.5)
	
	tween.tween_callback(func(): _can_skip = true)
	tween.tween_interval(2.5)
	tween.tween_callback(_go_to_menu)


func _unhandled_input(event: InputEvent) -> void:
	if _can_skip and (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_go_to_menu()


func _go_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
