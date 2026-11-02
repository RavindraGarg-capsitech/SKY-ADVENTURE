extends Node3D

## EnemyManager: Coordinates enemy spawning, tracking, dynamic compositions, and death notifications.

signal enemy_spawned(enemy: Node3D)
signal enemy_died(enemy: Node3D, death_position: Vector3)
signal remaining_enemies_changed(remaining: int)
signal all_enemies_defeated

@export var default_spawn_interval: float = 1.2
@export var default_group_size: int = 2
@export var min_enemy_spacing: float = 1.6
@export var spawn_jitter_radius: float = 3.5

var spawners: Array[Node3D] = []
var active_enemies: Array[Node3D] = []
var spawn_queue: Array[PackedScene] = []

var spawn_interval: float = 1.2
var group_size: int = 2
var spawn_timer: float = 0.0
var current_spawner_index: int = 0
var is_spawning: bool = false


func _ready() -> void:
	if not is_in_group("enemy_manager"):
		add_to_group("enemy_manager")
	refresh_spawners()
	call_deferred("refresh_spawners")


func refresh_spawners() -> void:
	spawners.clear()
	var spawner_nodes = get_tree().get_nodes_in_group("spawners")
	for node in spawner_nodes:
		if node is Node3D and node.has_method("spawn_mob"):
			spawners.append(node)
	if spawners.is_empty():
		var scene_root = get_tree().current_scene
		if scene_root != null:
			var sp_container = scene_root.get_node_or_null("Gameplay/SpawnPoints")
			if sp_container != null:
				for child in sp_container.get_children():
					if child is Node3D and child.has_method("spawn_mob"):
						spawners.append(child)


func _physics_process(delta: float) -> void:
	if not is_spawning or spawn_queue.is_empty():
		return

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = spawn_interval
		_spawn_next_burst()


func start_wave_spawns(mobs: Array[PackedScene], interval: float = 1.2, burst_size: int = 2) -> void:
	if spawners.is_empty():
		refresh_spawners()

	spawn_queue = mobs.duplicate()
	spawn_interval = maxf(0.4, interval)
	group_size = maxi(1, burst_size)
	spawn_timer = 0.2
	is_spawning = true
	remaining_enemies_changed.emit(get_remaining_count())


func _spawn_next_burst() -> void:
	if spawn_queue.is_empty():
		is_spawning = false
		return

	if spawners.is_empty():
		refresh_spawners()
		if spawners.is_empty():
			push_warning("EnemyManager: No spawners found in the scene!")
			return

	var burst_count: int = mini(group_size, spawn_queue.size())
	for i in range(burst_count):
		if spawn_queue.is_empty():
			break
		var mob_scene: PackedScene = spawn_queue.pop_front()
		_spawn_single_enemy(mob_scene)

	remaining_enemies_changed.emit(get_remaining_count())
	if spawn_queue.is_empty():
		is_spawning = false


func _spawn_single_enemy(mob_scene: PackedScene) -> void:
	if mob_scene == null or spawners.is_empty():
		return

	var spawner: Node3D = spawners[current_spawner_index % spawners.size()]
	current_spawner_index += 1

	var base_origin: Vector3 = spawner.global_position
	if spawner.has_node("Marker3D"):
		base_origin = spawner.get_node("Marker3D").global_position

	# Calculate candidate position with spacing & jitter
	var candidate_pos: Vector3 = base_origin
	for attempt in range(8):
		var angle: float = randf() * TAU
		var dist: float = randf_range(1.0, spawn_jitter_radius)
		var test_pos: Vector3 = base_origin + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)

		# Check spacing against already active enemies
		var too_close: bool = false
		for active in active_enemies:
			if is_instance_valid(active):
				if (active.global_position - test_pos).length() < min_enemy_spacing:
					too_close = true
					break

		if not too_close:
			candidate_pos = test_pos
			break

	# Raycast downward to ensure the candidate position rests on top of valid island ground
	var final_pos = _find_safe_ground_surface(candidate_pos, base_origin)

	# Spawn the mob
	var new_mob: Node3D = null
	if spawner.has_method("spawn_mob"):
		new_mob = spawner.call("spawn_mob", mob_scene, get_tree().current_scene, final_pos)
	else:
		new_mob = mob_scene.instantiate() as Node3D
		get_tree().current_scene.add_child(new_mob)
		new_mob.global_position = final_pos

	if new_mob == null:
		return

	new_mob.global_position = final_pos
	if not new_mob.is_in_group("mobs"):
		new_mob.add_to_group("mobs")

	active_enemies.append(new_mob)

	if new_mob.has_signal("died"):
		if not new_mob.died.is_connected(_on_enemy_died):
			new_mob.died.connect(_on_enemy_died.bind(new_mob))

	enemy_spawned.emit(new_mob)


func _find_safe_ground_surface(target_pos: Vector3, fallback_origin: Vector3) -> Vector3:
	var current_scene = get_tree().current_scene
	if current_scene is Node3D and current_scene.get_world_3d() != null:
		var space_state = current_scene.get_world_3d().direct_space_state
		var ray_start: Vector3 = Vector3(target_pos.x, maxf(target_pos.y + 3.0, 3.0), target_pos.z)
		var ray_end: Vector3 = Vector3(target_pos.x, -10.0, target_pos.z)
		var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end, 1) # Layer 1 = environment
		var hit = space_state.intersect_ray(query)
		if not hit.is_empty() and hit.has("position"):
			return hit.position + Vector3.UP * 1.2

	# Fallback if over void or outside geometry
	return fallback_origin + Vector3.UP * 0.2


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
