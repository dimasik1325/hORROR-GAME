class_name FlarePickup
extends Interactable

## Подбираемый аварийный фальшфейер (Godot 4.6-dev)

func _ready() -> void:
	super._ready()
	prompt_message = "[E] Взять сигнальный фальшфейер"
	consume_on_interact = true


func _on_interacted_custom(player: Node3D) -> void:
	if player.has_method("add_flares"):
		player.call("add_flares", 1)
	if player.has_method("display_hud_notification"):
		player.call("display_hud_notification", "Получен фальшфейер! Зажмите [G] для броска отпугивающего огня.")
