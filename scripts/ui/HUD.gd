class_name GameHUD
extends CanvasLayer

## Полнофункциональный интерфейс игрока (HUD), журнал задач, ридер записок и скримеры (Godot 4.6-dev)

@onready var objective_title_label: Label = $ObjectivePanel/VBox/TitleLabel
@onready var objective_desc_label: Label = $ObjectivePanel/VBox/DescLabel
@onready var objective_progress_label: Label = $ObjectivePanel/VBox/ProgressLabel

@onready var prompt_label: Label = $CenterContainer/PromptLabel
@onready var crosshair: Control = $CenterContainer/Crosshair
@onready var notification_label: Label = $NotificationLabel

@onready var sanity_bar: ProgressBar = $StatusContainer/VBox/SanityContainer/SanityBar
@onready var stamina_bar: ProgressBar = $StatusContainer/VBox/StaminaContainer/StaminaBar
@onready var battery_bar: ProgressBar = $StatusContainer/VBox/BatteryContainer/BatteryBar

@onready var note_dialog: PanelContainer = $NoteDialog
@onready var note_title_label: Label = $NoteDialog/Margin/VBox/NoteTitle
@onready var note_author_label: Label = $NoteDialog/Margin/VBox/NoteAuthor
@onready var note_text_label: RichTextLabel = $NoteDialog/Margin/VBox/NoteText

@onready var jumpscare_overlay: Control = $JumpscareOverlay
@onready var death_screen: Control = $DeathScreen
@onready var retry_button: Button = $DeathScreen/VBox/RetryButton
@onready var menu_button: Button = $DeathScreen/VBox/MenuButton

var _notification_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_signals()
	_update_initial_hud()


func _connect_signals() -> void:
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr:
		game_mgr.objective_updated.connect(_on_objective_updated)
		game_mgr.note_opened.connect(_on_note_opened)
		game_mgr.player_jumpscare_triggered.connect(_on_player_jumpscare)

	var sanity_mgr = get_node_or_null("/root/SanityGlobalManager")
	if sanity_mgr:
		sanity_mgr.sanity_changed.connect(_on_sanity_changed)

	if retry_button != null:
		retry_button.pressed.connect(_on_retry_pressed)
	if menu_button != null:
		menu_button.pressed.connect(_on_menu_pressed)


func _update_initial_hud() -> void:
	if note_dialog != null:
		note_dialog.visible = false
	if jumpscare_overlay != null:
		jumpscare_overlay.visible = false
	if death_screen != null:
		death_screen.visible = false

	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr:
		_on_objective_updated(
			game_mgr.current_objective_title,
			game_mgr.current_objective_desc,
			"%d / %d" % [game_mgr.notes_collected_count, game_mgr.total_notes_target]
		)


func _unhandled_input(event: InputEvent) -> void:
	if note_dialog != null and note_dialog.visible:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_game"):
			close_note_dialog()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _notification_timer > 0.0:
		_notification_timer -= delta
		if _notification_timer <= 0.0 and notification_label != null:
			notification_label.visible = false


func _on_objective_updated(title: String, desc: String, progress: String) -> void:
	if objective_title_label != null:
		objective_title_label.text = "ТЕКУЩАЯ ЗАДАЧА: " + title
	if objective_desc_label != null:
		objective_desc_label.text = desc
	if objective_progress_label != null:
		objective_progress_label.text = "Собрано записок: " + progress


func _on_sanity_changed(new_sanity: float, _delta: float) -> void:
	if sanity_bar != null:
		sanity_bar.value = new_sanity


func update_stamina(current: float, max_val: float) -> void:
	if stamina_bar != null:
		stamina_bar.max_value = max_val
		stamina_bar.value = current


func update_battery(current: float, max_val: float) -> void:
	if battery_bar != null:
		battery_bar.max_value = max_val
		battery_bar.value = current


func set_interaction_prompt(prompt: String) -> void:
	if prompt_label != null:
		prompt_label.text = prompt
		prompt_label.visible = prompt != ""


func show_notification(text: String, duration: float = 3.0) -> void:
	if notification_label != null:
		notification_label.text = text
		notification_label.visible = true
		_notification_timer = duration


func _on_note_opened(title: String, text: String, author: String) -> void:
	if note_dialog == null:
		return

	note_title_label.text = title
	note_author_label.text = "Автор: " + author
	note_text_label.text = text
	note_dialog.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true


func close_note_dialog() -> void:
	if note_dialog != null:
		note_dialog.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().paused = false


func _on_player_jumpscare(_monster: Node3D) -> void:
	if jumpscare_overlay != null:
		jumpscare_overlay.visible = true

	# Краткая вспышка скримера и появление экрана смерти
	var tween = create_tween()
	tween.tween_property(jumpscare_overlay, "modulate:a", 1.0, 0.1)
	tween.tween_interval(1.2)
	tween.tween_callback(_show_death_screen)


func _show_death_screen() -> void:
	if death_screen != null:
		death_screen.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = true


func _on_retry_pressed() -> void:
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr:
		game_mgr.restart_game()


func _on_menu_pressed() -> void:
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr:
		game_mgr.go_to_main_menu()
