class_name Interactable
extends CollisionObject3D

## Базовый класс интерактивных объектов в мире "Эхо Чащи" (Godot 4.6-dev)
## Обеспечивает полиморфный интерфейс для взаимодействия через RayCast/ShapeCast игрока.

signal interacted(by_player: Node3D)
signal focused(by_player: Node3D)
signal unfocused(by_player: Node3D)

@export_group("Параметры Интеракции")
## Текст подсказки при наведении курсора (например: "[E] Взять батарейку", "[E] Прочесть дневник")
@export var prompt_message: String = "[E] Осмотреть"
## Развернутое текстовое описание при первичном фокусе
@export var examine_description: String = ""
## Активен ли объект для взаимодействия в текущий момент
@export var is_interactable: bool = true
## Требуется ли удерживать клавишу (Hold Interaction)
@export var is_hold_interaction: bool = false
## Время удержания в секундах
@export_range(0.1, 5.0, 0.1) var hold_duration: float = 1.0
## Уничтожать/удалять ли узел после успешного взаимодействия
@export var consume_on_interact: bool = false

@export_group("Связанные Ресурсы")
## Ресурс предмета, если объект представляет собой подбираемый предмет
@export var item_data: ItemData
## Необходимый ID ключа/предмета в инвентаре игрока для успешного открытия/активации
@export var required_key_id: StringName = &""

@export_group("Аудио Обратная Связь")
## Звук при успешном взаимодействии
@export var interaction_audio: AudioStream
## Звук при неудачной попытке (например, запертая дверь)
@export var locked_audio: AudioStream

var _is_being_focused: bool = false
var _current_hold_progress: float = 0.0


func _ready() -> void:
	# Убедимся, что объект находится на слое интеракций (слой 3 / маска 4)
	set_collision_layer_value(3, true)


## Вызывается игроком при нажатии клавиши взаимодействия
func interact(player: Node3D) -> void:
	if not is_interactable:
		_play_audio(locked_audio)
		return

	# Проверка на наличие необходимого ключа в инвентаре игрока
	if required_key_id != &"":
		var has_key: bool = false
		if player.has_method("has_item_by_id"):
			has_key = player.call("has_item_by_id", required_key_id)
		
		if not has_key:
			_play_audio(locked_audio)
			if player.has_method("display_hud_notification"):
				player.call("display_hud_notification", "Заперто. Требуется подходящий ключ...")
			return

	_play_audio(interaction_audio)
	
	# Если привязан ресурс предмета — передаем его игроку
	if item_data != null and player.has_method("add_item_to_inventory"):
		var added: bool = player.call("add_item_to_inventory", item_data)
		if not added:
			if player.has_method("display_hud_notification"):
				player.call("display_hud_notification", "Инвентарь переполнен!")
			return

	interacted.emit(player)
	_on_interacted_custom(player)

	if consume_on_interact:
		queue_free()


## Виртуальный метод для переопределения в наследниках (двери, переключатели, алтари)
func _on_interacted_custom(_player: Node3D) -> void:
	pass


## Вызывается контроллером игрока при наведении прицела
func set_focus(player: Node3D, active: bool) -> void:
	if active and not _is_being_focused:
		_is_being_focused = true
		focused.emit(player)
		_apply_highlight(true)
	elif not active and _is_being_focused:
		_is_being_focused = false
		_current_hold_progress = 0.0
		unfocused.emit(player)
		_apply_highlight(false)


## Получение строки подсказки
func get_prompt() -> String:
	if not is_interactable:
		return "Недоступно"
	if item_data != null:
		return "[E] Взять " + item_data.display_name
	return prompt_message


## Визуальный отклик на наведение (шейдерный контур или подсветка)
func _apply_highlight(enable: bool) -> void:
	# Поиск VisualInstance3D дочерних узлов для подсветки
	for child in get_children():
		if child is VisualInstance3D:
			child.set_layer_mask_value(4, enable) # Слой 4 для Outline Pass


func _play_audio(stream: AudioStream) -> void:
	if stream == null:
		return
	var audio_player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	audio_player.stream = stream
	audio_player.bus = &"SFX"
	audio_player.unit_size = 5.0
	audio_player.max_distance = 25.0
	get_parent().add_child(audio_player)
	audio_player.global_position = global_position
	audio_player.play()
	audio_player.finished.connect(audio_player.queue_free)
