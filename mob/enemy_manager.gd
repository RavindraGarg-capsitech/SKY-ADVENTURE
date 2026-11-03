extends Node3D

## EnemyManager: Coordinates enemy spawning, tracking, dynamic compositions, and death notifications.

signal enemy_spawned(enemy: Node3D)
signal enemy_died(enemy: Node3D, death_position: Vector3)
signal remaining_enemies_changed(remaining: int)
signal all_enemies_defeated

@export var default_spawn_interval: float = 1.2
@export var default_group_size: int = 1
@export var min_enemy_spacing: float = 2.4
@export var spawn_jitter_radius: float = 4.0
@export var min_player_spawn_distance: float = 10.0

var spawners: Array[Node3D] = []
var active_enemies: Array[Node3D] = []
var spawn_queue: Array[PackedScene] = []

var spawn_interval: float = 1.2
var group_size: int = 1
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
		_spawn_next_sequential()


## Starts spawning a wave of enemies one by one with controlled intervals
func start_wave_spawns(mobs: Array[PackedScene], interval: float = 1.2, burst_size: int = 1) -> void:
	if spawners.is_empty():
		refresh_spawners()

	spawn_queue = mobs.duplicate()
	spawn_interval = maxf(0.4, interval)
	group_size = 1 # Strictly sequential one-by-one spawning
	spawn_timer = 0.3
	is_spawning = true
	remaining_enemies_changed.emit(get_remaining_count())


## Returns dynamic spawn interval based on mob archetype
func _get_enemy_spawn_delay(mob_scene: PackedScene) -> float:
	if mob_scene == null:
		return spawn_interval
	var path_lower: String = mob_scene.resource_path.to_lower()
	if path_lower.contains("boss"):
		return 2.5 # Dramatic pacing for boss
	elif path_lower.contains("armored"):
		return 1.8 # Heavy enemies take longer
	elif path_lower.contains("spitter"):
		return 1.4 # Ranged enemy delay
	elif path_lower.contains("fast") or path_lower.contains("scout"):
		return 1.1 # Fast scout delay
	else:
		return 1.3 # Standard bat delay


func _spawn_next_sequential() -> void:
	if spawn_queue.is_empty():
		is_spawning = false
		return

	if spawners.is_empty():
		refresh_spawners()
		if spawners.is_empty():
			push_warning("EnemyManager: No spawners found in the scene!")
			return

	var mob_scene: PackedScene = spawn_queue.pop_front()
	_spawn_single_enemy(mob_scene)

	remaining_enemies_changed.emit(get_remaining_count())

	if spawn_queue.is_empty():
		is_spawning = false
	else:
		spawn_timer = _get_enemy_spawn_delay(spawn_queue[0])


## Backwards-compatibility alias
func _spawn_next_burst() -> void:
	_spawn_next_sequential()


func _spawn_single_enemy(mob_scene: PackedScene) -> void:
	if mob_scene == null or spawners.is_empty():
		return

	var safe_pos = _find_safe_spawn_position(mob_scene)
	var spawner: Node3D = spawners[current_spawner_index % spawners.size()]

	var new_mob: Node3D = null
	if spawner != null and spawner.has_method("spawn_mob"):
		new_mob = spawner.call("spawn_mob", mob_scene, get_tree().current_scene, safe_pos)
	else:
		new_mob = mob_scene.instantiate() as Node3D
		get_tree().current_scene.add_child(new_mob)
		new_mob.global_position = safe_pos

	if new_mob == null:
		return

	new_mob.global_position = safe_pos
	if not new_mob.is_in_group("mobs"):
		new_mob.add_to_group("mobs")

	active_enemies.append(new_mob)

	if new_mob.has_signal("died"):
		if not new_mob.died.is_connected(_on_enemy_died):
			new_mob.died.connect(_on_enemy_died.bind(new_mob))

	enemy_spawned.emit(new_mob)


## Validates spawn positions: checks player distance, environment obstacles (trees/rocks/buildings), and ground surface
func _find_safe_spawn_position(_mob_scene: PackedScene) -> Vector3:
	var player = get_tree().get_first_node_in_group("player") as Node3D
	var player_pos: Vector3 = player.global_position if is_instance_valid(player) else Vector3.ZERO
	var current_scene = get_tree().current_scene
	var space_state: PhysicsDirectSpaceState3D = null
	if current_scene is Node3D and current_scene.get_world_3d() != null:
		space_state = current_scene.get_world_3d().direct_space_state

	# Filter spawners that have sufficient distance from player
	var available_spawners: Array[Node3D] = []
	for sp in spawners:
		if is_instance_valid(sp):
			if is_instance_valid(player):
				var sp_dist = (sp.global_position - player_pos).length()
				if sp_dist >= min_player_spawn_distance:
					available_spawners.append(sp)
			else:
				available_spawners.append(sp)

	# Fallback if player is close to all spawners: sort by furthest distance from player
	if available_spawners.is_empty():
		if spawners.is_empty():
			refresh_spawners()
		available_spawners = spawners.duplicate()
		if is_instance_valid(player) and available_spawners.size() > 1:
			available_spawners.sort_custom(func(a, b):
				return (a.global_position - player_pos).length() > (b.global_position - player_pos).length()
			)

	if available_spawners.is_empty():
		return Vector3(0, 1.5, 0)

	var spawner = available_spawners[current_spawner_index % available_spawners.size()]
	current_spawner_index += 1

	var base_origin: Vector3 = spawner.global_position
	if spawner.has_node("Marker3D"):
		base_origin = spawner.get_node("Marker3D").global_position

	# Test up to 16 candidate offsets with jitter, spacing, ground, and obstacle collision checks
	for attempt in range(16):
		var angle: float = randf() * TAU
		var dist: float = randf_range(1.5, spawn_jitter_radius)
		var test_pos: Vector3 = base_origin + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)

		# 1. Player Distance Check (Must never spawn near player or gun)
		if is_instance_valid(player):
			var d_player = (test_pos - player_pos).length()
			if d_player < min_player_spawn_distance:
				continue

		# 2. Spacing against other active enemies (No overlapping at same position)
		var too_close: bool = false
		for active in active_enemies:
			if is_instance_valid(active):
				if (active.global_position - test_pos).length() < min_enemy_spacing:
					too_close = true
					break
		if too_close:
			continue

		# 3. Ground Raycast Validation (Must detect valid island terrain floor)
		if space_state != null:
			var ray_start: Vector3 = Vector3(test_pos.x, maxf(test_pos.y + 4.0, 6.0), test_pos.z)
			var ray_end: Vector3 = Vector3(test_pos.x, -16.0, test_pos.z)
			var ground_query = PhysicsRayQueryParameters3D.create(ray_start, ray_end, 1) # Layer 1 = Environment
			var ground_hit = space_state.intersect_ray(ground_query)

			if ground_hit.is_empty() or not ground_hit.has("position"):
				# Over the void / abyss: skip
				continue

			var candidate_surface_pos: Vector3 = ground_hit.position + Vector3.UP * 1.5

			# 4. Obstacle Collision Shape Check (Trees, Rocks, Buildings, Walls)
			var shape_query = PhysicsShapeQueryParameters3D.new()
			var test_sphere = SphereShape3D.new()
			test_sphere.radius = 0.75 # Generous radius to ensure bat body & wings clear obstacles
			shape_query.shape = test_sphere
			shape_query.transform = Transform3D(Basis(), candidate_surface_pos)
			shape_query.collision_mask = 1 # Environment layer
			shape_query.collide_with_bodies = true
			shape_query.collide_with_areas = false
			var obstacles = space_state.intersect_shape(shape_query, 1)

			if not obstacles.is_empty():
				# Point intersects a tree, rock, building, or wall: skip
				continue

			# 5. Overhead Clearance Check
			var overhead_query = PhysicsRayQueryParameters3D.create(
				candidate_surface_pos,
				candidate_surface_pos + Vector3.UP * 1.5,
				1
			)
			var overhead_hit = space_state.intersect_ray(overhead_query)
			if not overhead_hit.is_empty():
				continue

			# Position passed all safety criteria
			return candidate_surface_pos

	# Fallback if all 16 attempts hit obstacles: return elevated spawner origin
	return _find_safe_ground_surface(base_origin, base_origin)


func _find_safe_ground_surface(target_pos: Vector3, fallback_origin: Vector3) -> Vector3:
	var current_scene = get_tree().current_scene
	if current_scene is Node3D and current_scene.get_world_3d() != null:
		var space_state = current_scene.get_world_3d().direct_space_state
		var ray_start: Vector3 = Vector3(target_pos.x, maxf(target_pos.y + 4.0, 6.0), target_pos.z)
		var ray_end: Vector3 = Vector3(target_pos.x, -16.0, target_pos.z)
		var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end, 1) # Layer 1 = environment
		var hit = space_state.intersect_ray(query)
		if not hit.is_empty() and hit.has("position"):
			return hit.position + Vector3.UP * 1.5

	return fallback_origin + Vector3.UP * 1.5


func _on_enemy_died(mob: Node3D) -> void:
	if not mob in active_enemies:
		return

	active_enemies.erase(mob)
	var death_pos: Vector3 = Vector3.ZERO
	if is_instance_valid(mob):
		var rec_pos = mob.get("death_position_recorded")
		if rec_pos is Vector3 and rec_pos != Vector3.ZERO:
			death_pos = rec_pos
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
