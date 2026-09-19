class_name RitualAltar
extends Interactable

## Древний Алтарь Первородной Коры под Древом-Исполином (Godot 4.6-dev)

@onready var altar_fire: OmniLight3D = $AltarLight
@onready var rune_particles: CPUParticles3D = $RuneParticles


func _ready() -> void:
	super._ready()
	prompt_message = "[E] Завершить Ритуал Первородной Коры"
	consume_on_interact = false


func _on_interacted_custom(player: Node3D) -> void:
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr == null:
		return

	if game_mgr.notes_collected_count < game_mgr.total_notes_target:
		if player.has_method("display_hud_notification"):
			player.call("display_hud_notification", "Алтарь безмолвен. Не хватает ритуальных страниц (%d/4)!" % game_mgr.notes_collected_count)
	else:
		# Все 4 страницы собраны! Финал расследования
		if rune_particles != null:
			rune_particles.emitting = true
		if altar_fire != null:
			altar_fire.light_energy = 6.0
			altar_fire.light_color = Color(0.9, 0.1, 0.1, 1.0)
			
		game_mgr.trigger_ritual_completion()
