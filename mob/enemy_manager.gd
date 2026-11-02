extends Node3D

## EnemyManager: Coordinates enemy spawning, tracking, and death notifications.

signal enemy_spawned(enemy: Node3D)
signal enemy_died(enemy: Node3D, death_position: Vector3)
signal remaining_enemies_changed(remaining: int)
signal all_enemies_defeated

var spawners: Array[Node3D] = []
var active_enemies: Array[Node3D] = []
var spawn_queue: Array[PackedScene] = []

var spawn_interval: float = 1.0
var spawn_timer: float = 0.0
var current_spawner_index: int = 0
var is_spawning: bool = false


func _ready() -> void:
	if not is_in_group("enemy_manager"):
		add_to_group("enemy_manager")
	refresh_spawners()


func refresh_spawners() -> void:
	spawners.clear()
	var spawner_nodes = get_tree().get_nodes_in_group("spawners")
	for node in spawner_nodes:
		if node is Node3D and node.has_method("spawn_mob"):
			spawners.append(node)


func _physics_process(delta: float) -> void:
	if not is_spawning or spawn_queue.is_empty():
		return

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = spawn_interval
		_spawn_next_enemy()


func start_wave_spawns(mobs: Array[PackedScene], interval: float = 1.0) -> void:
	if spawners.is_empty():
		refresh_spawners()

	spawn_queue = mobs.duplicate()
	spawn_interval = interval
	spawn_timer = 0.2
	is_spawning = true
	remaining_enemies_changed.emit(get_remaining_count())


func _spawn_next_enemy() -> void:
	if spawn_queue.is_empty():
		is_spawning = false
		return

	if spawners.is_empty():
		refresh_spawners()
		if spawners.is_empty():
			push_warning("EnemyManager: No spawners found in the scene!")
			return

	var mob_scene: PackedScene = spawn_queue.pop_front()
	var spawner: Node3D = spawners[current_spawner_index % spawners.size()]
	current_spawner_index += 1

	var new_mob: Node3D = spawner.call("spawn_mob", mob_scene, get_tree().current_scene)
	if new_mob == null:
		return

	active_enemies.append(new_mob)

	if new_mob.has_signal("died"):
		new_mob.died.connect(_on_enemy_died.bind(new_mob))

	enemy_spawned.emit(new_mob)
	remaining_enemies_changed.emit(get_remaining_count())


func _on_enemy_died(mob: Node3D) -> void:
	if not mob in active_enemies:
		return

	active_enemies.erase(mob)
	var death_pos: Vector3 = Vector3.ZERO
	if is_instance_valid(mob):
		if "death_position_recorded" in mob and mob.death_position_recorded != Vector3.ZERO:
			death_pos = mob.death_position_recorded
		else:
			death_pos = mob.global_position
	enemy_died.emit(mob, death_pos)
	remaining_enemies_changed.emit(get_remaining_count())

	if spawn_queue.is_empty() and active_enemies.is_empty():
		is_spawning = false
		all_enemies_defeated.emit()


func get_remaining_count() -> int:
	return spawn_queue.size() + active_enemies.size()


func stop_spawning() -> void:
	is_spawning = false
	spawn_queue.clear()


func clear_all() -> void:
	spawn_queue.clear()
	is_spawning = false
	for mob in active_enemies:
		if is_instance_valid(mob):
			mob.queue_free()
	active_enemies.clear()
	remaining_enemies_changed.emit(0)
