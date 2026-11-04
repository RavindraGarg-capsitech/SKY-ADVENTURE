extends SceneTree

## Comprehensive test suite for PC Mouse Shooting + Camera Rotation Concurrency
## Verifies simultaneous LMB shooting and mouse look rotation without conflict.

func _init() -> void:
	print("\n==================================================================")
	print("=== RUNNING PC MOUSE SHOOTING & CAMERA ROTATION TEST SUITE ===")
	print("==================================================================\n")
	call_deferred("_run_tests")


func _run_tests() -> void:
	var passed: int = 0
	var total: int = 0

	# 1. Unpause and start game state
	var gm = root.get_node_or_null("GameManager")
	if gm != null:
		gm.start_game()
	else:
		paused = false

	# 2. Instantiate TemporaryLevel
	var level_scene = load("res://level/temporary_level.tscn")
	var level = level_scene.instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	await process_frame

	var player = level.get_node_or_null("Gameplay/Player")
	assert(player != null, "Player must exist in TemporaryLevel")

	var cam = player.get_node("%Camera3D") as Camera3D
	assert(cam != null, "Camera3D must exist in Player")

	var mobile_ui = level.get_node_or_null("UI/MobileUI")
	assert(mobile_ui != null, "MobileUI must exist in TemporaryLevel")

	# Ensure mouse is captured for PC gameplay
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# -------------------------------------------------------------
	# TEST 1: PC Platform Detection & Mobile Auto-Hide
	# -------------------------------------------------------------
	total += 1
	var is_pc: bool = not OS.has_feature("mobile") and not (OS.get_name() in ["Android", "iOS"])
	if is_pc:
		if not mobile_ui.visible and not player.is_mobile_device:
			print("[TEST 1] PASS: Mobile controls auto-hidden on PC desktop; player.is_mobile_device is false.")
			passed += 1
		else:
			push_error("[TEST 1] FAILED: Mobile controls visible on PC or player is in mobile mode.")
	else:
		print("[TEST 1] PASS: Mobile platform detected.")
		passed += 1

	# -------------------------------------------------------------
	# TEST 2: Mouse Motion Rotates Camera When Idle (Not Shooting)
	# -------------------------------------------------------------
	total += 1
	var initial_yaw: float = player.rotation_degrees.y
	var initial_pitch: float = cam.rotation_degrees.x

	var motion1 = InputEventMouseMotion.new()
	motion1.relative = Vector2(15.0, 8.0)
	player._input(motion1)

	var expected_yaw_delta: float = 15.0 * 0.5 * player.mouse_sensitivity_factor
	var expected_pitch_delta: float = 8.0 * 0.2 * player.mouse_sensitivity_factor

	var actual_yaw: float = player.rotation_degrees.y
	var actual_pitch: float = cam.rotation_degrees.x

	if is_equal_approx(actual_yaw, initial_yaw - expected_yaw_delta) and is_equal_approx(actual_pitch, initial_pitch - expected_pitch_delta):
		print("[TEST 2] PASS: Mouse motion rotates camera yaw and pitch smoothly while idle.")
		passed += 1
	else:
		push_error("[TEST 2] FAILED: Yaw=%f (expected %f), Pitch=%f (expected %f)" % [actual_yaw, initial_yaw - expected_yaw_delta, actual_pitch, initial_pitch - expected_pitch_delta])

	# -------------------------------------------------------------
	# TEST 3: Left Mouse Button Initiates Shooting
	# -------------------------------------------------------------
	total += 1
	var initial_bullets = get_nodes_in_group("bullets").size()
	
	# Press shoot action (LMB)
	Input.action_press("shoot")
	player._physics_process(0.016)
	await process_frame

	var bullets_after_shoot = get_nodes_in_group("bullets").size()
	if bullets_after_shoot > initial_bullets:
		print("[TEST 3] PASS: Left Mouse Button shoot action immediately spawns bullets.")
		passed += 1
	else:
		push_error("[TEST 3] FAILED: Shooting action failed to spawn bullet.")

	# -------------------------------------------------------------
	# TEST 4: Simultaneous Shooting + Camera Rotation
	# -------------------------------------------------------------
	total += 1
	# While holding LMB (shoot pressed), send mouse motion events
	var yaw_before_combined = player.rotation_degrees.y
	var pitch_before_combined = cam.rotation_degrees.x

	var combined_motion = InputEventMouseMotion.new()
	combined_motion.relative = Vector2(30.0, -12.0)
	combined_motion.button_mask = 1 # LMB held
	player._input(combined_motion)

	var yaw_after_combined = player.rotation_degrees.y
	var pitch_after_combined = cam.rotation_degrees.x

	var expected_combined_yaw = yaw_before_combined - (30.0 * 0.5 * player.mouse_sensitivity_factor)
	var expected_combined_pitch = pitch_before_combined - (-12.0 * 0.2 * player.mouse_sensitivity_factor)

	var rotation_worked = is_equal_approx(yaw_after_combined, expected_combined_yaw) and is_equal_approx(pitch_after_combined, expected_combined_pitch)

	# Cooldown elapse to allow next bullet while aiming
	var timer = player.get_node("%Timer") as Timer
	timer.stop() # simulate cooldown finish
	player._physics_process(0.016)
	await process_frame

	var bullets_while_aiming = get_nodes_in_group("bullets").size()
	var shooting_worked = bullets_while_aiming > bullets_after_shoot

	if rotation_worked and shooting_worked:
		print("[TEST 4] PASS: Holding Left Mouse Button and moving mouse simultaneously rotates camera and shoots continuously!")
		passed += 1
	else:
		push_error("[TEST 4] FAILED: Concurrency failed. rotation_worked=%s, shooting_worked=%s" % [str(rotation_worked), str(shooting_worked)])

	# -------------------------------------------------------------
	# TEST 5: Bullets Fire in Newly Rotated Camera Direction
	# -------------------------------------------------------------
	total += 1
	# Rotate camera 90 degrees right
	var rotate_90 = InputEventMouseMotion.new()
	rotate_90.relative = Vector2(180.0, 0.0) # 180 * 0.5 = 90 deg
	player._input(rotate_90)

	var marker = player.get_node("%Marker3D") as Marker3D
	var marker_fwd: Vector3 = -marker.global_transform.basis.z.normalized()

	timer.stop()
	var pre_aim_bullet_count = get_nodes_in_group("bullets").size()
	player._physics_process(0.016)
	await process_frame

	var all_bullets = get_nodes_in_group("bullets")
	var latest_bullet = all_bullets[all_bullets.size() - 1] as Node3D
	var bullet_dir: Vector3 = -latest_bullet.global_transform.basis.z.normalized()

	var dot_alignment: float = marker_fwd.dot(bullet_dir)
	if dot_alignment > 0.95:
		print("[TEST 5] PASS: Bullets accurately inherit newly rotated camera direction (alignment dot=%f)." % dot_alignment)
		passed += 1
	else:
		push_error("[TEST 5] FAILED: Bullet direction misaligned with rotated camera: dot=%f" % dot_alignment)

	# -------------------------------------------------------------
	# TEST 6: Releasing LMB Stops Shooting While Camera Rotation Continues
	# -------------------------------------------------------------
	total += 1
	Input.action_release("shoot")
	timer.stop()
	var count_after_release = get_nodes_in_group("bullets").size()
	player._physics_process(0.016)
	await process_frame

	var did_not_shoot: bool = (get_nodes_in_group("bullets").size() == count_after_release)

	# Verify camera rotation still works after releasing LMB
	var pre_release_yaw = player.rotation_degrees.y
	var post_motion = InputEventMouseMotion.new()
	post_motion.relative = Vector2(10.0, 0.0)
	player._input(post_motion)
	var post_release_yaw = player.rotation_degrees.y
	var post_rotation_worked = is_equal_approx(post_release_yaw, pre_release_yaw - 5.0 * player.mouse_sensitivity_factor)

	if did_not_shoot and post_rotation_worked:
		print("[TEST 6] PASS: Releasing LMB stops shooting immediately; camera rotation continues smoothly.")
		passed += 1
	else:
		push_error("[TEST 6] FAILED: did_not_shoot=%s, post_rotation_worked=%s" % [str(did_not_shoot), str(post_rotation_worked)])

	# -------------------------------------------------------------
	# TEST 7: Reticle Does Not Intercept Mouse (mouse_filter == IGNORE)
	# -------------------------------------------------------------
	total += 1
	var reticle = player.get_node_or_null("TextureRect") as Control
	if reticle != null and reticle.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		print("[TEST 7] PASS: Crosshair Reticle has mouse_filter = MOUSE_FILTER_IGNORE (passes mouse input).")
		passed += 1
	else:
		var filter_val = reticle.mouse_filter if reticle != null else -1
		push_error("[TEST 7] FAILED: Reticle mouse_filter is %d (expected 2 - IGNORE)." % filter_val)

	# -------------------------------------------------------------
	# TEST 8: Mobile Controls Compatibility Preserved (force_show)
	# -------------------------------------------------------------
	total += 1
	mobile_ui.force_show = true
	mobile_ui.visible = true
	player.set_mobile_mode(true)

	var win_w = root.get_visible_rect().size.x
	var left_pos = Vector2(win_w * 0.25, 500.0)
	var right_pos = Vector2(win_w * 0.75, 500.0)

	var pre_mob_bullets = get_nodes_in_group("bullets").size()
	# Touch left side
	var left_touch = InputEventScreenTouch.new()
	left_touch.index = 10
	left_touch.position = left_pos
	left_touch.pressed = true
	mobile_ui._handle_screen_touch(left_touch)
	await process_frame
	var post_left_mob_bullets = get_nodes_in_group("bullets").size()

	# Release left side
	left_touch.pressed = false
	mobile_ui._handle_screen_touch(left_touch)
	await process_frame

	# Touch right side (should shoot)
	var right_touch = InputEventScreenTouch.new()
	right_touch.index = 11
	right_touch.position = right_pos
	right_touch.pressed = true
	mobile_ui._handle_screen_touch(right_touch)
	timer.stop()
	player._physics_process(0.016)
	await process_frame
	var post_right_mob_bullets = get_nodes_in_group("bullets").size()

	# Release right side
	right_touch.pressed = false
	mobile_ui._handle_screen_touch(right_touch)
	await process_frame

	var left_side_clean = (post_left_mob_bullets == pre_mob_bullets)
	var right_side_shot = (post_right_mob_bullets > post_left_mob_bullets)

	if left_side_clean and right_side_shot:
		print("[TEST 8] PASS: Mobile two-side touch isolation and controls remain 100%% intact.")
		passed += 1
	else:
		push_error("[TEST 8] FAILED: left_side_clean=%s, right_side_shot=%s" % [str(left_side_clean), str(right_side_shot)])

	# Cleanup test nodes
	level.queue_free()

	print("\n==================================================================")
	print("TEST RESULTS: %d / %d PASSED" % [passed, total])
	print("==================================================================")
	if passed == total:
		print("ALL PC MOUSE SHOOTING & CAMERA ROTATION TESTS PASSED PERFECTLY!\n")
	else:
		push_error("SOME TESTS FAILED! Check error log above.\n")

	quit(0 if passed == total else 1)
