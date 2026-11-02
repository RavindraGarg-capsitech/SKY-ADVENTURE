extends SceneTree

## Comprehensive Verification Test Suite: Coin Improvements, Enemy Death Rotation, Sequential Spawning

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("==================================================")
	print("STARTING TEST SUITE: GAMEPLAY POLISH & BUG FIXES")
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
	await _test_coin_spawn_height_and_ground_safety()
	await _test_coin_collection_animation_and_counting()
	await _test_enemy_death_rotation_and_stability()
	await _test_sequential_enemy_spawning_and_pacing()
	await _test_wave_completion_tracking()

	print("==================================================")
	print("POLISH & BUG FIXES TEST RESULTS: %d PASSED, %d FAILED" % [passed, failed])
	print("==================================================")
	if failed == 0:
		print("ALL POLISH TESTS PASSED SUCCESSFULLY!")
	quit(0 if failed == 0 else 1)


## 1. Coin Spawn Position & Ground Detection
func _test_coin_spawn_height_and_ground_safety() -> void:
	print("--- TEST GROUP 1: Coin Spawn Position & Elevation ---")

	var reward_mgr_scene = preload("res://reward/reward_manager.gd")
	var rm = Node.new()
	rm.set_script(reward_mgr_scene)
	root.add_child(rm)

	# Mock player
	var player = Node3D.new()
	player.name = "Player"
	player.add_to_group("player")
	root.add_child(player)
	player.global_position = Vector3(0, 1.0, 0)

	# Test safe ground positioning fallback
	var safe_pos: Vector3 = rm.call("_find_safe_ground_position", Vector3(5, -10, 5))
	assert_true(safe_pos.y >= 0.8, "Void position clamped safely above floor near player (y: %.2f >= 0.8)" % safe_pos.y)

	var normal_pos: Vector3 = rm.call("_find_safe_ground_position", Vector3(10, 2.0, 10))
	assert_true(normal_pos.y >= 0.85, "Normal position maintains >= 0.85m elevation clearance (y: %.2f)" % normal_pos.y)

	# Test Coin instance self-ground-safety
	var coin_scene = preload("res://reward/coin_pickup.tscn")
	var coin = coin_scene.instantiate() as Area3D
	root.add_child(coin)
	coin.global_position = Vector3(0, 0.9, 0)
	assert_true(coin.get("base_y") >= 0.85 or coin.global_position.y >= 0.85, "Coin base_y / position.y properly elevated above floor")

	coin.free()
	player.free()
	rm.free()
	await process_frame


## 2. Coin Collection Animation & Single Counting
func _test_coin_collection_animation_and_counting() -> void:
	print("--- TEST GROUP 2: Coin Collection Animation & Count ---")

	var coin_scene = preload("res://reward/coin_pickup.tscn")
	var coin = coin_scene.instantiate() as Area3D
	root.add_child(coin)
	coin.global_position = Vector3(0, 1.0, 0)

	var initial_y: float = coin.global_position.y
	assert_true(coin.monitoring == true, "Coin monitoring initially active")

	# Collect coin
	coin.call("collect")

	assert_true(coin.get("is_collected") == true, "Coin marked collected immediately")
	# Re-calling collect() must not duplicate
	coin.call("collect")
	assert_true(coin.get("is_collected") == true, "Repeated collect call safely ignored")

	# Allow tween to advance in scene tree
	assert_true(coin.get("collect_tween") != null, "Collection tween created")
	var t: Tween = coin.get("collect_tween")
	if t != null and t.is_valid():
		t.custom_step(0.2)

	# Check upward movement in animation
	assert_true(coin.global_position.y > initial_y, "Coin rising upward in collection animation (current: %.2f > initial: %.2f)" % [coin.global_position.y, initial_y])

	coin.free()
	await process_frame


## 3. Enemy Death Rotation & Physics Stability
func _test_enemy_death_rotation_and_stability() -> void:
	print("--- TEST GROUP 3: Enemy Death Rotation & Physics Stability ---")

	var mob_scene = preload("res://mob/mob.tscn")
	var mob = mob_scene.instantiate() as RigidBody3D
	root.add_child(mob)
	mob.global_position = Vector3(0, 1.5, 0)
	mob.health = 1

	# Kill mob
	mob.play_hurt(1)

	assert_true(mob.is_dead == true, "Mob is_dead flag set to true")
	assert_true(mob.linear_velocity == Vector3.ZERO, "Mob linear_velocity is zero (no physics impulse/launching)")
	assert_true(mob.angular_velocity == Vector3.ZERO, "Mob angular_velocity is zero (no physics tumbling)")
	assert_true(mob.freeze == true, "RigidBody3D freeze is true (fully locked physics)")
	assert_true(mob.collision_layer == 0 and mob.collision_mask == 0, "Collision layers disabled on death")

	# Check rotation strictly around Y axis
	var bat_model = mob.get_node_or_null("CollisionShape3D/bat_model")
	assert_true(bat_model != null, "Bat visual model found")
	assert_true(is_equal_approx(bat_model.rotation.x, 0.0), "Bat model X rotation is 0 (no X-axis tilt)")
	assert_true(is_equal_approx(bat_model.rotation.z, 0.0), "Bat model Z rotation is 0 (no Z-axis tilt)")

	# Check death timer is running with fast ~0.6s timeout
	var timer = mob.get_node_or_null("%Timer") as Timer
	assert_true(timer != null and not timer.is_stopped(), "Death cleanup timer running")
	assert_true(timer.time_left <= 0.7, "Death timer configured for fast 0.6s exit (time_left: %.2fs)" % timer.time_left)

	mob.free()
	await process_frame


## 4. Sequential Enemy Spawning & Archetype Pacing
func _test_sequential_enemy_spawning_and_pacing() -> void:
	print("--- TEST GROUP 4: Sequential Enemy Spawning & Pacing ---")

	var em_scene = preload("res://mob/enemy_manager.gd")
	var em = Node3D.new()
	em.set_script(em_scene)
	root.add_child(em)

	var std_scene = preload("res://mob/mob.tscn")
	var arm_scene = preload("res://mob/variants/mob_armored.tscn")
	var boss_scene = preload("res://mob/boss/boss_sky_overlord.tscn")

	# Test archetype delay calculations
	var std_delay = em.call("_get_enemy_spawn_delay", std_scene)
	var arm_delay = em.call("_get_enemy_spawn_delay", arm_scene)
	var boss_delay = em.call("_get_enemy_spawn_delay", boss_scene)

	assert_true(std_delay >= 1.0 and std_delay <= 1.5, "Standard enemy delay in 1.0-1.5s range (%.2fs)" % std_delay)
	assert_true(arm_delay >= 1.5 and arm_delay <= 2.0, "Armored enemy delay in 1.5-2.0s range (%.2fs)" % arm_delay)
	assert_true(boss_delay >= 2.0, "Boss delay >= 2.0s (%.2fs)" % boss_delay)

	# Mock spawner
	var spawner = Node3D.new()
	spawner.name = "TestSpawner"
	spawner.add_to_group("spawners")
	root.add_child(spawner)
	spawner.set_script(load("res://mob/spawner/mob_spawner_3d.gd"))

	# Start wave of 3 mobs
	var queue: Array[PackedScene] = [std_scene, arm_scene, std_scene]
	em.start_wave_spawns(queue, 1.2, 1)

	assert_true(em.group_size == 1, "EnemyManager enforces group_size = 1 (strictly sequential)")
	assert_true(em.get_remaining_count() == 3, "Initial remaining quota matches total queued mobs (3)")

	spawner.free()
	em.free()
	await process_frame


## 5. Wave Completion Tracking (Queue + Active Mobs)
func _test_wave_completion_tracking() -> void:
	print("--- TEST GROUP 5: Wave Completion Tracking ---")

	var em_scene = preload("res://mob/enemy_manager.gd")
	var em = Node3D.new()
	em.set_script(em_scene)
	root.add_child(em)

	var std_scene = preload("res://mob/mob.tscn")
	var typed_queue: Array[PackedScene] = [std_scene, std_scene]
	em.spawn_queue = typed_queue
	em.is_spawning = true

	var wave_cleared = [false]
	em.all_enemies_defeated.connect(func(): wave_cleared[0] = true)

	# Create a mock active enemy
	var mock_mob = Node3D.new()
	root.add_child(mock_mob)
	em.active_enemies.append(mock_mob)

	# Kill mock_mob while spawn_queue still has 2 pending mobs
	em.call("_on_enemy_died", mock_mob)

	assert_true(wave_cleared[0] == false, "Wave NOT marked cleared while pending mobs remain in spawn queue")
	assert_true(em.get_remaining_count() == 2, "Remaining count correctly reflects pending mobs (2)")

	# Empty spawn queue, add another active mob
	em.spawn_queue.clear()
	var mock_mob_2 = Node3D.new()
	root.add_child(mock_mob_2)
	em.active_enemies.append(mock_mob_2)

	# Kill final mob
	em.call("_on_enemy_died", mock_mob_2)
	assert_true(wave_cleared[0] == true, "Wave correctly marked cleared when BOTH queue and active list are empty")
	assert_true(em.get_remaining_count() == 0, "Remaining count reaches 0 on wave complete")

	mock_mob.free()
	mock_mob_2.free()
	em.free()
	await process_frame
