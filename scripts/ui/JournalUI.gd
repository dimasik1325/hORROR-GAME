class_name JournalUI
extends CanvasLayer

## Интерактивный дневник и карта расследования детектива Уэйна (Godot 4.6-dev)

@onready var panel: PanelContainer = $PanelContainer
@onready var close_button: Button = find_child("CloseBtn", true, false)
@onready var notes_summary_label: RichTextLabel = find_child("NotesSummary", true, false)

var is_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	if close_button != null:
		close_button.pressed.connect(close_journal)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal_toggle"):
		if is_open:
			close_journal()
		else:
			open_journal()
		get_viewport().set_input_as_handled()


func open_journal() -> void:
	is_open = true
	panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_update_journal_content()


func close_journal() -> void:
	is_open = false
	panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().paused = false


func _update_journal_content() -> void:
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr == null or notes_summary_label == null:
		return

	var text = "[b][color=#e0a84e]ДЕЛО: ИСЧЕЗНОВЕНИЕ ЭКСПЕДИЦИИ 'ЧЕРНЫЙ ОМУТ'[/color][/b]\n\n"
	text += "[color=#80d090]Прогресс сбора ритуальных записей:[/color] %d из %d\n\n" % [game_mgr.notes_collected_count, game_mgr.total_notes_target]
	
	if game_mgr.notes_collected_count >= 1:
		text += "• [b]Записка #1 (Кордон):[/b] Анонимное письмо с предупреждением. Кто-то знал, что я прибуду сюда.\n"
	if game_mgr.notes_collected_count >= 2:
		text += "• [b]Записка #2 (Болото/Джип):[/b] Последние слова геодезистов. Они упоминали мое имя перед гибелью.\n"
	if game_mgr.notes_collected_count >= 3:
		text += "• [b]Записка #3 (Лесопилка):[/b] Описание ритуала 'Сдирания Коры' и добровольного стирания памяти.\n"
	if game_mgr.notes_collected_count >= 4:
		text += "• [b]Записка #4 (Алтарь):[/b] Мой собственный почерк. Я — основатель культа.\n"

	notes_summary_label.text = text
