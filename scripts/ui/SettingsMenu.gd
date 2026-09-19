class_name SettingsMenu
extends Control

## Меню настроек графики, звука и управления (Godot 4.6-dev)

signal closed()

@onready var fullscreen_check: CheckBox = find_child("FullscreenCheck", true, false)
@onready var vsync_check: CheckBox = find_child("VsyncCheck", true, false)
@onready var msaa_option: OptionButton = find_child("MsaaOption", true, false)
@onready var fog_check: CheckBox = find_child("FogCheck", true, false)
@onready var sdfgi_check: CheckBox = find_child("SdfgiCheck", true, false)

@onready var master_slider: HSlider = find_child("MasterSlider", true, false)
@onready var sfx_slider: HSlider = find_child("SfxSlider", true, false)
@onready var amb_slider: HSlider = find_child("AmbSlider", true, false)

@onready var sens_slider: HSlider = find_child("SensSlider", true, false)
@onready var back_button: Button = find_child("BackButton", true, false)


func _ready() -> void:
	_setup_options()
	_load_current_values()
	if back_button != null:
		back_button.pressed.connect(_on_back_pressed)


func _setup_options() -> void:
	if msaa_option != null:
		msaa_option.clear()
		msaa_option.add_item("Выключено (Off)", 0)
		msaa_option.add_item("MSAA 2x (Рекомендуется)", 1)
		msaa_option.add_item("MSAA 4x (Ультра)", 2)


func _load_current_values() -> void:
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr == null:
		return

	if fullscreen_check:
		fullscreen_check.button_pressed = game_mgr.is_fullscreen
		fullscreen_check.toggled.connect(func(val): 
			game_mgr.is_fullscreen = val
			game_mgr.apply_graphics_settings()
		)

	if vsync_check:
		vsync_check.button_pressed = game_mgr.vsync_enabled
		vsync_check.toggled.connect(func(val):
			game_mgr.vsync_enabled = val
			game_mgr.apply_graphics_settings()
		)

	if msaa_option:
		msaa_option.selected = game_mgr.msaa_quality
		msaa_option.item_selected.connect(func(idx):
			game_mgr.msaa_quality = idx
			game_mgr.apply_graphics_settings()
		)

	if master_slider:
		master_slider.value = game_mgr.master_volume * 100.0
		master_slider.value_changed.connect(func(val):
			game_mgr.master_volume = val / 100.0
			game_mgr.apply_audio_volumes()
		)

	if sfx_slider:
		sfx_slider.value = game_mgr.sfx_volume * 100.0
		sfx_slider.value_changed.connect(func(val):
			game_mgr.sfx_volume = val / 100.0
			game_mgr.apply_audio_volumes()
		)

	if amb_slider:
		amb_slider.value = game_mgr.ambience_volume * 100.0
		amb_slider.value_changed.connect(func(val):
			game_mgr.ambience_volume = val / 100.0
			game_mgr.apply_audio_volumes()
		)

	if sens_slider:
		sens_slider.value = game_mgr.mouse_sensitivity * 10000.0
		sens_slider.value_changed.connect(func(val):
			game_mgr.mouse_sensitivity = val / 10000.0
		)


func _on_back_pressed() -> void:
	visible = false
	closed.emit()
