class_name SanityPillsPickup
extends Interactable

## Травяная успокоительная настойка геодезистов (Godot 4.6-dev)
## Восстанавливает +45.0% рассудка при подборе.

@export var sanity_restore_amount: float = 45.0


func _ready() -> void:
	super._ready()
	prompt_message = "[E] Принять успокоительное (+45% Рассудка)"
	consume_on_interact = true


func _on_interacted_custom(player: Node3D) -> void:
	var sanity_mgr = get_node_or_null("/root/SanityGlobalManager")
	if sanity_mgr and sanity_mgr.has_method("modify_sanity"):
		sanity_mgr.modify_sanity(sanity_restore_amount)

	if player.has_method("display_hud_notification"):
		player.call("display_hud_notification", "Рассудок стабилизирован: +%d%%" % int(sanity_restore_amount))
