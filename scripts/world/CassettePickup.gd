class_name CassettePickup
extends Interactable

## Аудиокассета с полевой записью пропавшей экспедиции (Godot 4.6-dev)

@export var tape_title: String = "Аудиозапись экспедиции #1: Последний сеанс"
@export_multiline var voice_transcript: String = "«[Шорох ленты, тяжелое дыхание]... База, ответьте! Черный Омут закрылся. Мы не можем найти дорогу назад, компасы врут! Они ходят вокруг избушки... Это не люди, они поют гимны Коре!...»"
@export var tape_index: int = 1


func _ready() -> void:
	super._ready()
	prompt_message = "[E] Прослушать " + tape_title
	consume_on_interact = true


func _on_interacted_custom(player: Node3D) -> void:
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr:
		game_mgr.open_note_dialog(tape_title, voice_transcript, "Радиозапись экспедиции")

	if player.has_method("display_hud_notification"):
		player.call("display_hud_notification", "Воспроизведение: " + tape_title)
