class_name BatteryPickup
extends Interactable

## Интерактивная батарейка для фонарика (Godot 4.6-dev)

@export var charge_restore_amount: float = 50.0


func _ready() -> void:
	super._ready()
	prompt_message = "[E] Взять батарею (+50% заряда)"
	consume_on_interact = true


func _on_interacted_custom(player: Node3D) -> void:
	if player.has_method("restore_flashlight_battery"):
		player.call("restore_flashlight_battery", charge_restore_amount)
	if player.has_method("display_hud_notification"):
		player.call("display_hud_notification", "Заряд фонаря восполнен на +%d%%!" % int(charge_restore_amount))
