class_name WorldStreamer
extends Node3D

## Высокопроизводительный многопоточный менеджер стриминга мира (Godot 4.6-dev)
## Использует WorkerThreadPool и ResourceLoader для бесшовной подгрузки 3D-чанков (64x64м)
## и динамического переключения слоев галлюцинаций (Sanity Layers) в рантайме.

signal chunk_loaded(coord: Vector2i, chunk_node: Node3D)
signal chunk_unloaded(coord: Vector2i)

# --- ПАРАМЕТРЫ СЕТКИ ЧАНКОВ ---
@export_group("Конфигурация Чанков")
## Размер стороны чанка в метрах (XZ плоскость)
@export var chunk_size: float = 64.0
## Радиус загрузки в чанках вокруг игрока (например, 2 = квадрат 5x5 чанков)
@export var load_radius: int = 2
## Радиус выгрузки (должен быть строго больше load_radius для предотвращения трешинга)
@export var unload_radius: int = 3
## Базовый путь к файлам сцен чанков (например: "res://scenes/chunks/chunk_%d_%d.tscn")
@export var chunk_scene_path_pattern: String = "res://scenes/chunks/chunk_%d_%d.tscn"
## Дефолтный процедурный чанк, если кастомный файл не найден
@export var fallback_chunk_scene: PackedScene

# --- СЛОИ БЕЗУМИЯ (VISUAL INSTANCE LAYERS) ---
@export_group("Слои Безумия (Sanity Layers)")
## Слой рендеринга для нормальных объектов (Layer 1)
@export var normal_visual_layer: int = 1
## Слой рендеринга для скрытых хоррор-объектов (куклы, тотемы, ложные тропы) (Layer 2)
@export var horror_visual_layer: int = 2
## Порог рассудка для проявления кошмаров в чанках
@export_range(0.0, 100.0, 1.0) var horror_layer_threshold: float = 40.0

# --- ССЫЛКИ И СОСТОЯНИЕ ---
var player_node: Node3D = null
var _current_player_chunk: Vector2i = Vector2i(999999, 999999)

# Активные загруженные чанки: Vector2i -> Node3D
var _active_chunks: Dictionary = {}
# Чанки в процессе загрузки: Vector2i -> String (resource path)
var _loading_chunks: Dictionary = {}
# Очередь на инстанцирование в главном потоке: Array[Dictionary]
var _instantiation_queue: Array[Dictionary] = []

# ID задач пула WorkerThreadPool
var _active_worker_tasks: Array[int] = []
var _is_horror_layer_active: bool = false
var _max_instantiations_per_frame: int = 2


func _ready() -> void:
	_connect_to_sanity_manager()
	_find_player()


func _process(_delta: float) -> void:
	if player_node == null:
		_find_player()
		return

	_update_player_chunk_coordinates()
	_poll_loading_resources()
	_process_instantiation_queue()


# --- ОТСЛЕЖИВАНИЕ ПОЗИЦИИ И РАСЧЕТ СЕТКИ ---
func _update_player_chunk_coordinates() -> void:
	var player_pos: Vector3 = player_node.global_position
	var new_chunk_coord: Vector2i = Vector2i(
		int(floor(player_pos.x / chunk_size)),
		int(floor(player_pos.z / chunk_size))
	)

	if new_chunk_coord != _current_player_chunk:
		_current_player_chunk = new_chunk_coord
		_evaluate_chunks_around_player()


func _evaluate_chunks_around_player() -> void:
	var required_coords: Array[Vector2i] = []

	# 1. Сбор координат чанков в радиусе загрузки
	for x in range(-load_radius, load_radius + 1):
		for z in range(-load_radius, load_radius + 1):
			var target_coord: Vector2i = _current_player_chunk + Vector2i(x, z)
			required_coords.append(target_coord)
			
			if not _active_chunks.has(target_coord) and not _loading_chunks.has(target_coord):
				_request_chunk_load(target_coord)

	# 2. Выгрузка чанков за пределами радиуса unload_radius
	var coords_to_unload: Array[Vector2i] = []
	for active_coord in _active_chunks.keys():
		var distance_chunks: float = (Vector2(active_coord) - Vector2(_current_player_chunk)).length()
		if distance_chunks > float(unload_radius):
			coords_to_unload.append(active_coord)

	for coord in coords_to_unload:
		_unload_chunk(coord)


# --- МНОГОПОТОЧНАЯ ПОДГРУЗКА ЧЕРЕЗ RESOURCE LOADER И THREAD POOL ---
func _request_chunk_load(coord: Vector2i) -> void:
	var chunk_path: String = chunk_scene_path_pattern % [coord.x, coord.y]
	
	if not ResourceLoader.exists(chunk_path):
		if fallback_chunk_scene != null:
			# Используем фоллбэк процедурный чанк
			_instantiation_queue.append({
				"coord": coord,
				"packed_scene": fallback_chunk_scene
			})
			return
		else:
			return

	_loading_chunks[coord] = chunk_path
	ResourceLoader.load_threaded_request(chunk_path, "PackedScene", true)


func _poll_loading_resources() -> void:
	var completed_coords: Array[Vector2i] = []

	for coord in _loading_chunks.keys():
		var path: String = _loading_chunks[coord]
		var progress: Array = []
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path, progress)

		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var packed_scene: PackedScene = ResourceLoader.load_threaded_get(path) as PackedScene
			if packed_scene != null:
				_instantiation_queue.append({
					"coord": coord,
					"packed_scene": packed_scene
				})
			completed_coords.append(coord)
			
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			completed_coords.append(coord)

	for coord in completed_coords:
		_loading_chunks.erase(coord)


# --- ДОЗИРОВАННОЕ ИНСТАНЦИРОВАНИЕ (БЮДЖЕТ КАДРА) ---
func _process_instantiation_queue() -> void:
	var instantiations_this_frame: int = 0

	while not _instantiation_queue.is_empty() and instantiations_this_frame < _max_instantiations_per_frame:
		var item: Dictionary = _instantiation_queue.pop_front()
		var coord: Vector2i = item["coord"]
		var scene: PackedScene = item["packed_scene"]

		# Если игрок уже убежал слишком далеко, пока ресурс грузился
		var dist_to_player: float = (Vector2(coord) - Vector2(_current_player_chunk)).length()
		if dist_to_player > float(unload_radius):
			continue

		var chunk_instance: Node3D = scene.instantiate() as Node3D
		if chunk_instance != null:
			add_child(chunk_instance)
			chunk_instance.global_position = Vector3(coord.x * chunk_size, 0.0, coord.y * chunk_size)
			_active_chunks[coord] = chunk_instance
			
			# Применение текущей маски Безумия к новым объектам чанка
			_apply_sanity_layer_to_chunk(chunk_instance, _is_horror_layer_active)
			chunk_loaded.emit(coord, chunk_instance)

		instantiations_this_frame += 1


func _unload_chunk(coord: Vector2i) -> void:
	if _active_chunks.has(coord):
		var chunk_instance: Node3D = _active_chunks[coord]
		_active_chunks.erase(coord)
		chunk_unloaded.emit(coord)
		chunk_instance.queue_free()


# --- ДИНАМИЧЕСКАЯ СМЕНА СЛОЕВ БЕЗУМИЯ (VISUAL LAYERS И ХОРРОР-ОБЪЕКТЫ) ---
func _connect_to_sanity_manager() -> void:
	if SanityGlobalManager:
		SanityGlobalManager.sanity_changed.connect(_on_sanity_value_changed)


func _on_sanity_value_changed(new_sanity: float, _delta: float) -> void:
	var should_show_horror: bool = (new_sanity < horror_layer_threshold)
	
	if should_show_horror != _is_horror_layer_active:
		_is_horror_layer_active = should_show_horror
		_update_all_active_chunks_sanity(_is_horror_layer_active)


func _update_all_active_chunks_sanity(show_horror: bool) -> void:
	# Фоновая мутация визуальных слоев
	for chunk_node in _active_chunks.values():
		if is_instance_valid(chunk_node):
			_apply_sanity_layer_to_chunk(chunk_node, show_horror)


func _apply_sanity_layer_to_chunk(chunk: Node3D, show_horror: bool) -> void:
	# Рекурсивный обход узлов чанка
	var nodes_to_check: Array[Node] = [chunk]

	while not nodes_to_check.is_empty():
		var current: Node = nodes_to_check.pop_back()
		
		# Если узел помечен группой horror_manifestation
		if current.is_in_group("sanity_horror_prop"):
			if current is VisualInstance3D:
				(current as VisualInstance3D).visible = show_horror
				(current as VisualInstance3D).set_layer_mask_value(horror_visual_layer, show_horror)
			if current is CollisionObject3D:
				# Активация/деактивация коллизий ложных преград
				(current as CollisionObject3D).set_collision_layer_value(1, show_horror)
		
		# Мутация шейдеров коры деревьев при психозе
		if current is MeshInstance3D and current.is_in_group("tree_bark"):
			var mesh_inst: MeshInstance3D = current as MeshInstance3D
			for surface_idx in range(mesh_inst.get_surface_override_material_count()):
				var mat: Material = mesh_inst.get_surface_override_material(surface_idx)
				if mat is ShaderMaterial:
					(mat as ShaderMaterial).set_shader_parameter("insanity_bleed_intensity", 1.0 if show_horror else 0.0)

		for child in current.get_children():
			nodes_to_check.append(child)


func _find_player() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("Player")
	if not players.is_empty():
		player_node = players[0] as Node3D
