class_name NotePickup
extends Interactable

## Интерактивная сюжетная записка в 3D мире (Godot 4.6-dev)

@export_group("Сюжетные Данные Записки")
@export var note_title: String = "Страница дневника геодезиста"
@export_multiline var full_text: String = "14 сентября. Мы углубились в Черный Омут. Деревья здесь словно наблюдают за нами. Радиоприемник ловит только глухой стон и шепот. Уэйн... если ты это читаешь, не ходи к Древу!"
@export var author_signature: String = "Геодезист Смирнов"
@export var note_index: int = 1


func _ready() -> void:
	super._ready()
	prompt_message = "[E] Прочесть " + note_title
	consume_on_interact = true


func _on_interacted_custom(player: Node3D) -> void:
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr:
		if item_data != null:
			game_mgr.collect_note(item_data)
		else:
			var temp_item = ItemData.new()
			temp_item.id = StringName("note_page_%d" % note_index)
			temp_item.display_name = note_title
			temp_item.note_text = full_text
			temp_item.note_author = author_signature
			temp_item.item_type = ItemData.ItemType.NOTE
			game_mgr.collect_note(temp_item)
