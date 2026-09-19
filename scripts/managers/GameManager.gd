extends Node

## Глобальный менеджер игрового прогресса, квестов, скримеров и настроек (Godot 4.6-dev)

signal objective_updated(title: String, description: String, progress: String)
signal note_opened(title: String, text: String, author: String)
signal note_collected(current_count: int, total_count: int)
signal player_jumpscare_triggered(monster_node: Node3D)
signal player_died()
signal game_paused(is_paused: bool)

# --- КВЕСТЫ И СБОР ПРЕДМЕТОВ ---
var notes_collected_count: int = 0
var total_notes_target: int = 4
var current_objective_title: String = "Исследовать кордон"
var current_objective_desc: String = "Осмотрите заброшенную избу и соберите записки геодезистов."

# --- НАСТРОЙКИ ГРАФИКИ И АУДИО ---
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var ambience_volume: float = 1.0
var mouse_sensitivity: float = 0.0022
var is_fullscreen: bool = false
var vsync_enabled: bool = true
var volumetric_fog_enabled: bool = true
var sdfgi_enabled: bool = true
var ssil_enabled: bool = true
var msaa_quality: int = 2

var is_game_over: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Регистрация сбора сюжетной записки
func collect_note(note_item: ItemData) -> void:
	notes_collected_count += 1
	note_collected.emit(notes_collected_count, total_notes_target)
	
	if note_item != null:
		open_note_dialog(note_item.display_name, note_item.note_text, note_item.note_author)

	# Обновление цепочки квестов
	if notes_collected_count < total_notes_target:
		update_objective(
			"Собрать ритуальные записки",
			"Найдите все следы пропавшей экспедиции в чаще леса.",
			"%d / %d" % [notes_collected_count, total_notes_target]
		)
	else:
		update_objective(
			"Найти Алтарь Первородной Коры",
			"Все страницы собраны! Следуйте за шепотом в глубину чащи к Древу-Исполину.",
			"ГОТОВО"
		)


func open_note_dialog(title: String, text: String, author: String) -> void:
	note_opened.emit(title, text, author)


func update_objective(title: String, desc: String, progress: String = "") -> void:
	current_objective_title = title
	current_objective_desc = desc
	objective_updated.emit(title, desc, progress)


## Запуск скримера и гибели игрока
func trigger_monster_jumpscare(monster: Node3D) -> void:
	if is_game_over:
		return
	is_game_over = true
	player_jumpscare_triggered.emit(monster)


func restart_game() -> void:
	is_game_over = false
	notes_collected_count = 0
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainWorld.tscn")


func go_to_main_menu() -> void:
	is_game_over = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")


# --- ПРИМЕНЕНИЕ НАСТРОЕК ГРАФИКИ И ДВИЖКА ---
func apply_graphics_settings() -> void:
	# Оконный режим
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	# VSync
	if vsync_enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_MODE_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_MODE_DISABLED)

	# MSAA
	var viewport = get_viewport()
	if viewport:
		match msaa_quality:
			0:
				viewport.msaa_3d = Viewport.MSAA_DISABLED
			1:
				viewport.msaa_3d = Viewport.MSAA_2X
			2:
				viewport.msaa_3d = Viewport.MSAA_4X
			_:
				viewport.msaa_3d = Viewport.MSAA_2X


func apply_audio_volumes() -> void:
	var master_idx = AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(master_volume))
	
	var sfx_idx = AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(sfx_volume))

	var amb_idx = AudioServer.get_bus_index("Ambience")
	if amb_idx >= 0:
		AudioServer.set_bus_volume_db(amb_idx, linear_to_db(ambience_volume))
