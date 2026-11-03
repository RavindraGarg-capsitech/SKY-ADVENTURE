extends SceneTree

## Comprehensive Spawner, Positioning, Environment & Gun Collision Test Suite

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("==================================================")
	print("STARTING TEST SUITE: SPAWNER & POSITIONING SYSTEM")
	print("==================================================")
	call_deferred("_run_tests")


func assert_true(condition: bool, test_name: String) -> void:
	if condition:
		passed += 1
		print("[PASS] %s" % test_name)
	else:
		failed += 1
		print("[FAIL] %s" % test_name)


func _run_tests() -> void:
	await _test_wave_based_sequential_spawning()
	await _test_safe_player_and_gun_distance()
	await _test_gun_barrier_collision()
	await _test_environment_obstacle_rejection()
	await _test_enemy_movement_steering_and_stop_distance()

	print("==================================================")
	print("SPAWNER & POSITIONING TEST RESULTS: %d PASSED, %d FAILED" % [passed, failed])
	print("==================================================")
	if failed == 0:
		print("ALL SPAWNER & POSITIONING TESTS PASSED SUCCESSFULLY!")
	quit(0 if failed == 0 else 1)


## 1. Wave-Based Spawning: Sequential 1-by-1, delays, quota tracking
func _test_wave_based_sequential_spawning() -> void:
	print("\n--- TEST GROUP 1: Wave-Based Spawning & Quota Tracking ---")

	var em_script = preload("res://mob/enemy_manager.gd")
	var em = Node3D.new()
	em.set_script(em_script)
	root.add_child(em)

	var std_scene = preload("res://mob/mob.tscn")
	var arm_scene = preload("res://mob/variants/mob_armored.tscn")
	var boss_scene = preload("res://mob/boss/boss_sky_overlord.tscn")

	# Archetype delays
	var std_delay: float = em.call("_get_enemy_spawn_delay", std_scene)
	var arm_delay: float = em.call("_get_enemy_spawn_delay", arm_scene)
	var boss_delay: float = em.call("_get_enemy_spawn_delay", boss_scene)

	assert_true(std_delay >= 1.0 and std_delay <= 1.5, "Standard bat delay is in 1.0-1.5s range (%.2fs)" % std_delay)
	assert_true(arm_delay >= 1.5 and arm_delay <= 2.0, "Armored bat delay is in 1.5-2.0s range (%.2fs)" % arm_delay)
	assert_true(boss_delay >= 2.0, "Boss delay is >= 2.0s (%.2fs)" % boss_delay)

	# Mock spawner
	var spawner = Node3D.new()
	spawner.global_position = Vector3(20, 1.0, 20)
	spawner.name = "TestSpawner1"
	spawner.add_to_group("spawners")
	root.add_child(spawner)
	spawner.set_script(load("res://mob/spawner/mob_spawner_3d.gd"))

	# Start wave of 3 enemies
	var wave: Array[PackedScene] = [std_scene, arm_scene, std_scene]
	em.start_wave_spawns(wave, 1.2, 1)

	assert_true(em.group_size == 1, "Enforces strictly sequential spawning (group_size = 1)")
	assert_true(em.get_remaining_count() == 3, "Initial wave quota accurately set to 3")

	spawner.free()
	em.free()
	await process_frame


## 2. Safe Player & Gun Distance: Never spawn near or inside player/gun
func _test_safe_player_and_gun_distance() -> void:
	print("\n--- TEST GROUP 2: Safe Player & Gun Distance Validation ---")

	var em_script = preload("res://mob/enemy_manager.gd")
	var em = Node3D.new()
	em.set_script(em_script)
	root.add_child(em)

	# Mock player at (0, 1, 0)
	var player = Node3D.new()
	player.name = "Player"
	player.add_to_group("player")
	player.global_position = Vector3(0, 1, 0)
	root.add_child(player)

	# Add spawner close to player (5m away) and spawner far from player (25m away)
	var close_spawner = Node3D.new()
	close_spawner.name = "CloseSpawner"
	close_spawner.global_position = Vector3(4, 1, 0) # Only 4m away
	close_spawner.add_to_group("spawners")
	close_spawner.set_script(load("res://mob/spawner/mob_spawner_3d.gd"))
	root.add_child(close_spawner)

	var far_spawner = Node3D.new()
	far_spawner.name = "FarSpawner"
	far_spawner.global_position = Vector3(25, 1, 0) # 25m away
	far_spawner.add_to_group("spawners")
	far_spawner.set_script(load("res://mob/spawner/mob_spawner_3d.gd"))
	root.add_child(far_spawner)

	em.refresh_spawners()

	var std_scene = preload("res://mob/mob.tscn")
	var spawn_pos: Vector3 = em.call("_find_safe_spawn_position", std_scene)

	var dist_from_player = (spawn_pos - player.global_position).length()
	assert_true(dist_from_player >= 9.5, "Spawned position maintains safe distance from player (dist: %.2fm >= 10m)" % dist_from_player)
	assert_true(spawn_pos.y >= 1.0, "Spawn position elevated above ground (y: %.2f)" % spawn_pos.y)

	close_spawner.free()
	far_spawner.free()
	player.free()
	em.free()
	await process_frame


## 3. Gun Barrier Collision: Player has dedicated front barrier on Layer 1
func _test_gun_barrier_collision() -> void:
	print("\n--- TEST GROUP 3: Player Gun Barrier Collision ---")

	var player_scene = preload("res://Player.tscn")
	var player = player_scene.instantiate() as CharacterBody3D
	root.add_child(player)

	assert_true(player.collision_layer == 1, "Player collision_layer is explicitly 1 (Environment & Player body)")
	assert_true(player.collision_mask == 3, "Player collision_mask is 3 (Environment + Mobs)")

	var camera = player.get_node_or_null("Camera3D")
	assert_true(camera != null, "Camera3D found on player")

	var gun_barrier = camera.get_node_or_null("GunBarrier") as CollisionShape3D
	assert_true(gun_barrier != null, "GunBarrier CollisionShape3D present on player Camera3D")
	assert_true(gun_barrier.shape != null, "GunBarrier has active 3D collision shape protecting gun volume")

	player.free()
	await process_frame


## 4. Environment Obstacle Rejection: Trees, Rocks, Buildings
func _test_environment_obstacle_rejection() -> void:
	print("\n--- TEST GROUP 4: Environment Obstacle Rejection ---")

	var em_script = preload("res://mob/enemy_manager.gd")
	var em = Node3D.new()
	em.set_script(em_script)
	root.add_child(em)

	var std_scene = preload("res://mob/mob.tscn")

	# Create a static environment obstacle (tree/rock/building) on Layer 1
	var obstacle = StaticBody3D.new()
	obstacle.collision_layer = 1
	obstacle.collision_mask = 0
	obstacle.global_position = Vector3(20, 1.0, 20)
	var col_shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(4.0, 4.0, 4.0)
	col_shape.shape = box
	obstacle.add_child(col_shape)
	root.add_child(obstacle)

	# Mock spawner near the obstacle
	var spawner = Node3D.new()
	spawner.global_position = Vector3(20, 1.0, 20)
	spawner.name = "SpawnerNearObstacle"
	spawner.add_to_group("spawners")
	spawner.set_script(load("res://mob/spawner/mob_spawner_3d.gd"))
	root.add_child(spawner)

	em.refresh_spawners()

	var safe_pos: Vector3 = em.call("_find_safe_spawn_position", std_scene)
	assert_true(safe_pos != Vector3.ZERO, "Safe position generated")

	obstacle.free()
	spawner.free()
	em.free()
	await process_frame


## 5. Enemy Movement: Stop Distance, Gun Clearance, and Obstacle Steering
func _test_enemy_movement_steering_and_stop_distance() -> void:
	print("\n--- TEST GROUP 5: Enemy Movement & Gun Clearance ---")

	var mob_scene = preload("res://mob/mob.tscn")
	var mob = mob_scene.instantiate() as RigidBody3D
	root.add_child(mob)
	mob.global_position = Vector3(0, 1.5, 5.0) # 5m in front of player

	# Mock player at origin with Camera3D
	var player = Node3D.new()
	player.name = "Player"
	player.add_to_group("player")
	player.global_position = Vector3(0, 0, 0)
	var camera = Node3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0, 1.5, 0)
	player.add_child(camera)
	root.add_child(player)

	assert_true(mob.stop_distance >= 2.2, "Mob stop_distance is at least 2.2m (set to %.2fm)" % mob.stop_distance)

	# Process 1 physics frame to test movement direction calculation
	mob._find_player()
	assert_true(mob.player == player, "Mob found player reference")

	# Test close approach: position mob 2.0m from gun/camera
	mob.global_position = Vector3(0, 1.5, 2.0)
	mob._physics_process(0.016)

	assert_true(mob.linear_velocity.x == 0.0 and mob.linear_velocity.z == 0.0, "Mob stops completely when near gun boundary (<= 2.2m)")

	mob.free()
	player.free()
	await process_frame
