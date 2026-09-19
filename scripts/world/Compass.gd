class_name Compass
extends Node3D

## Интерактивный 3D-компас детектива Уэйна (Godot 4.6-dev)
## Стрелка указывает на текущую сюжетную цель. Вблизи монстра или аномалий стрелка хаотично вибрирует!

@export var target_position: Vector3 = Vector3(30, 0, -48) # Алтарь по умолчанию
@export var anomaly_detection_radius: float = 18.0

@onready var needle_mesh: Node3D = $NeedlePivot
@onready var glass_mesh: MeshInstance3D = $GlassMesh

var _needle_rotation: float = 0.0
var _jitter_noise: float = 0.0


func _process(delta: float) -> void:
	if needle_mesh == null:
		return

	var player = get_parent()
	if player == null:
		return

	# Поиск цели из GameManager
	var game_mgr = get_node_or_null("/root/GameManager")
	var target_pos = target_position
	
	# Вычисление угла к цели в горизонтальной плоскости
	var to_target: Vector3 = (target_pos - global_position).normalized()
	to_target.y = 0.0
	
	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	
	var desired_angle: float = 0.0
	if to_target.length_squared() > 0.01 and forward.length_squared() > 0.01:
		desired_angle = forward.signed_angle_to(to_target, Vector3.UP)

	# Проверка близости монстра (эффект аномального вращения стрелки)
	var monster_near: bool = false
	var enemies = get_tree().get_nodes_in_group("Enemies")
	if not enemies.is_empty():
		var enemy = enemies[0] as Node3D
		if enemy != null and global_position.distance_to(enemy.global_position) < anomaly_detection_radius:
			monster_near = true

	# Если рядом монстр — стрелка бешено мечется
	if monster_near:
		_jitter_noise += delta * 25.0
		var jitter: float = sin(_jitter_noise) * 2.2 + cos(_jitter_noise * 3.7) * 1.5
		needle_mesh.rotation.y = lerp_angle(needle_mesh.rotation.y, needle_mesh.rotation.y + jitter * delta, delta * 15.0)
	else:
		needle_mesh.rotation.y = lerp_angle(needle_mesh.rotation.y, desired_angle, delta * 6.0)
