class_name HidingSpot
extends Interactable

## Интерактивное укрытие (дупло векового дерева / шкаф) (Godot 4.6-dev)
## Позволяет игроку спрятаться от взгляда и преследования монстра.

@export var exit_offset: Vector3 = Vector3(0, 0, 1.5)
@onready var peek_camera_point: Node3D = $PeekPoint

var _is_player_hidden: bool = false
var _hidden_player_ref: Node3D = null


func _ready() -> void:
	super._ready()
	prompt_message = "[E] Спрятаться в дупле дерева"
	consume_on_interact = false


func _on_interacted_custom(player: Node3D) -> void:
	if not _is_player_hidden:
		_hide_player(player)
	else:
		_unhide_player()


func _hide_player(player: Node3D) -> void:
	_is_player_hidden = true
	_hidden_player_ref = player
	prompt_message = "[E] Выйти из укрытия"
	
	player.global_position = global_position
	player.visible = false
	player.set_physics_process(false)
	
	if player.has_method("display_hud_notification"):
		player.call("display_hud_notification", "Вы спрятались в дупле. Монстр вас не видит...")


func _unhide_player() -> void:
	if _hidden_player_ref != null:
		_hidden_player_ref.visible = true
		_hidden_player_ref.set_physics_process(true)
		_hidden_player_ref.global_position = global_position + exit_offset
		if _hidden_player_ref.has_method("display_hud_notification"):
			_hidden_player_ref.call("display_hud_notification", "Вы покинули укрытие.")

	_is_player_hidden = false
	_hidden_player_ref = null
	prompt_message = "[E] Спрятаться в дупле дерева"
