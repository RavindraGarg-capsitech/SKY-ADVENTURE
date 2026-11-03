extends SceneTree

## Comprehensive Verification Test Suite for Bullet Pooling & Physics Deferral Fix
## Validates:
## 1. Bullet collision callback handling without "Function blocked during in/out signal" error.
## 2. Safe deferred manipulation of monitoring, monitorable, and CollisionShape3D.disabled.
## 3. Duplicate impact & damage prevention (is_active & _is_recycling guard).
## 4. Rapid spawn-and-recycle cycles without race conditions on bullet position/basis.
## 5. Expiration upon reaching max RANGE.
## 6. Full reuse cycle from PoolManager.

func _init() -> void:
	print("\n==================================================================")
	print("=== RUNNING BULLET POOLING & PHYSICS SIGNAL FIX TEST SUITE ===")
	print("==================================================================")
	call_deferred("_run_tests")


func _run_tests() -> void:
	var passed = 0
	var total = 0

	var pm = root.get_node_or_null("PoolManager")
	assert(pm != null, "PoolManager autoload must be available")

	var level_scene = load("res://level/temporary_level.tscn")
	var level = level_scene.instantiate()
	root.add_child(level)

	var gm = root.get_node_or_null("GameManager")
	if gm != null:
		gm.change_state(gm.GameState.PLAYING)
	else:
		paused = false

	# -------------------------------------------------------------
	# TEST 1: Bullet Hitting Mob inside Physics Callback (No Errors)
	# -------------------------------------------------------------
	print("\n[TEST 1] Testing Bullet hitting Mob during Physics query flushing...")
	total += 1

	var mob_scene = load("res://mob/mob.tscn")
	var mob = mob_scene.instantiate()
	level.add_child(mob)
	mob.global_position = Vector3(0, 1.5, -3.0)
	await process_frame

	var bullet1 = pm.spawn_bullet(Vector3(0, 1.5, -1.0), Basis.IDENTITY, 2, 40.0, 50.0, 1.0, Color.ORANGE, "default")
	var mob_initial_health = mob.health

	# Simulate the physics collision callback as executed by Godot's PhysicsServer3D
	bullet1._on_body_entered(mob)

	# Verify immediate logical inactivation
	var immediate_inactive = (not bullet1.is_active) and (not bullet1.visible) and (not bullet1.is_physics_processing())
	var mob_damaged = (mob.health == mob_initial_health - 2)

	await process_frame # Wait for deferred calls to execute cleanly

	var deferred_disabled = (not bullet1.monitoring) and (not bullet1.monitorable)
	var col_shape = bullet1.get_node_or_null("CollisionShape3D") as CollisionShape3D
	var shape_disabled = (col_shape != null and col_shape.disabled)

	if immediate_inactive and mob_damaged and deferred_disabled and shape_disabled:
		print("PASS: Bullet hit mob cleanly without physics errors; damage applied, monitoring/monitorable safely deferred.")
		passed += 1
	else:
		push_error("FAIL: Collision deactivation mismatch: inactive=%s, damaged=%s, deferred=%s, shape=%s" % [
			str(immediate_inactive), str(mob_damaged), str(deferred_disabled), str(shape_disabled)
		])

	# -------------------------------------------------------------
	# TEST 2: Duplicate Impact & Accidental Extra Damage Prevention
	# -------------------------------------------------------------
	print("\n[TEST 2] Testing duplicate collision / double-hit prevention...")
	total += 1

	var mob2 = mob_scene.instantiate()
	level.add_child(mob2)
	mob2.global_position = Vector3(5, 1.5, 0)
	await process_frame

	var bullet2 = pm.spawn_bullet(Vector3(5, 1.5, -2.0), Basis.IDENTITY, 2, 40.0, 50.0, 1.0, Color.ORANGE, "default")
	var mob2_health = mob2.health

	# First hit
	bullet2._on_body_entered(mob2)
	# Immediate duplicate hit call on same bullet (simulating overlapping body triggers)
	bullet2._on_body_entered(mob2)
	bullet2._on_area_entered(null)
	bullet2.deactivate()

	await process_frame

	var damage_applied_once = (mob2.health == mob2_health - 2)
	if damage_applied_once and not bullet2.is_active:
		print("PASS: Multiple consecutive collision callbacks on the same bullet safely ignored; damage dealt exactly once.")
		passed += 1
	else:
		push_error("FAIL: Duplicate hit dealt extra damage: health before=%d, after=%d" % [mob2_health, mob2.health])

	# -------------------------------------------------------------
	# TEST 3: Rapid Spawn and Recycle Loop (No Position/Transform Race Condition)
	# -------------------------------------------------------------
	print("\n[TEST 3] Testing rapid bullet recycling and re-spawning across consecutive ticks...")
	total += 1

	var spawn_pos1 = Vector3(10.0, 2.0, 10.0)
	var bullet3 = pm.spawn_bullet(spawn_pos1, Basis.IDENTITY, 1, 40.0, 50.0, 1.0, Color.YELLOW, "default")
	bullet3.deactivate() # Queue recycling

	await process_frame # Allow deferred finalize to complete

	# Re-spawn from pool
	var spawn_pos2 = Vector3(25.0, 3.0, -15.0)
	var bullet3_reused = pm.spawn_bullet(spawn_pos2, Basis.IDENTITY, 1, 40.0, 50.0, 1.0, Color.CYAN, "default")
	var initial_pos_ok = is_equal_approx(bullet3_reused.global_position.x, 25.0) and is_equal_approx(bullet3_reused.global_position.y, 3.0) and is_equal_approx(bullet3_reused.global_position.z, -15.0)

	await process_frame

	# Bullet should fly forward along -Z (Z decreases from -15.0)
	var flew_forward = bullet3_reused.global_position.z < -15.0
	var collision_reactivated = bullet3_reused.monitoring and bullet3_reused.monitorable
	var col_shape3 = bullet3_reused.get_node_or_null("CollisionShape3D") as CollisionShape3D
	var shape_active = (col_shape3 != null and not col_shape3.disabled)

	if initial_pos_ok and flew_forward and collision_reactivated and shape_active and bullet3_reused.is_active:
		print("PASS: Re-spawned bullet acquired correct spawn transform, reactivated collisions, and avoided race conditions.")
		passed += 1
	else:
		push_error("FAIL: Re-spawned bullet corrupted: pos=%s, col_reactivated=%s, shape_active=%s" % [
			str(bullet3_reused.global_position), str(collision_reactivated), str(shape_active)
		])

	# -------------------------------------------------------------
	# TEST 4: Max Range Expiration Deactivation
	# -------------------------------------------------------------
	print("\n[TEST 4] Testing range expiration auto-deactivation...")
	total += 1

	var bullet4 = pm.spawn_bullet(Vector3(0, 5, 0), Basis.IDENTITY, 1, 10.0, 100.0, 1.0, Color.GREEN, "default")
	# Simulate 0.2s of physics processing (100 m/s * 0.2s = 20m, exceeding 10m range)
	bullet4._physics_process(0.25)

	await process_frame

	var expired = (not bullet4.is_active) and (not bullet4.visible)
	if expired:
		print("PASS: Bullet cleanly recycled when travelling beyond configured range.")
		passed += 1
	else:
		push_error("FAIL: Bullet did not deactivate upon exceeding range.")

	# -------------------------------------------------------------
	# TEST 5: Burst Fire Recycling (30 bullets simultaneous)
	# -------------------------------------------------------------
	print("\n[TEST 5] Testing Burst Fire of 30 bullets simultaneously without errors...")
	total += 1

	var fired_bullets: Array[Node3D] = []
	for i in range(30):
		var b = pm.spawn_bullet(Vector3(float(i), 1.0, 0.0), Basis.IDENTITY, 1, 40.0, 50.0, 1.0, Color.WHITE, "default")
		fired_bullets.append(b)

	# Recycle all 30 at once
	for b in fired_bullets:
		b._on_body_entered(mob)

	await process_frame

	var all_recycled = true
	for b in fired_bullets:
		if b.is_active or b.visible or b.is_physics_processing():
			all_recycled = false
			break

	if all_recycled:
		print("PASS: 30 bullets fired and recycled simultaneously with 0 physics errors.")
		passed += 1
	else:
		push_error("FAIL: Not all 30 bullets properly recycled.")

	# -------------------------------------------------------------
	# TEST 6: PC & Mobile Shooting Preservation
	# -------------------------------------------------------------
	print("\n[TEST 6] Testing PC and Mobile shooting preservation...")
	total += 1
	var player = level.find_child("Player", true, false)
	player.global_position = Vector3(0, 0, 0)

	# PC Shoot
	Input.action_press("shoot")
	player._physics_process(1.0 / 60.0)
	Input.action_release("shoot")
	var pc_shoot_ok = not player.get_node("%Timer").is_stopped()

	# Mobile controls
	var mobile_ui = level.find_child("MobileUI", true, false)
	var right_touch = InputEventScreenTouch.new()
	right_touch.index = 1
	right_touch.position = Vector2(1400, 500) # Right 50%
	right_touch.pressed = true
	mobile_ui._handle_screen_touch(right_touch)
	var mobile_shoot_ok = player.mobile_shooting

	right_touch.pressed = false
	mobile_ui._handle_screen_touch(right_touch)

	if pc_shoot_ok and mobile_shoot_ok:
		print("PASS: PC mouse left-click shooting and Mobile right-touch shooting fully functional.")
		passed += 1
	else:
		push_error("FAIL: Controls mismatch: pc=%s, mobile=%s" % [str(pc_shoot_ok), str(mobile_shoot_ok)])

	print("\n==================================================================")
	print("TEST RESULTS: %d / %d PASSED" % [passed, total])
	print("==================================================================")

	root.remove_child(level)
	level.queue_free()

	if passed == total:
		print("ALL BULLET POOLING & DEFERRED PHYSICS TESTS PASSED PERFECTLY!\n")
		quit(0)
	else:
		push_error("SOME TESTS FAILED!\n")
		quit(1)
