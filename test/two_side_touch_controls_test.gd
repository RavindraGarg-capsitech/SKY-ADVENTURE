extends SceneTree

func _init() -> void:
	print("\n=== RUNNING TWO-SIDE MOBILE TOUCH CONTROLS TEST SUITE ===")
	call_deferred("_run_tests")


func _run_tests() -> void:
	var passed = 0
	var total = 0

	var mob_ctrl_scene = load("res://level/temporary_level.tscn")
	var level = mob_ctrl_scene.instantiate()
	root.add_child(level)
	await process_frame

	var mobile_ui = level.get_node_or_null("UI/MobileUI")
	assert(mobile_ui != null, "MobileUI must be present in TemporaryLevel")
	mobile_ui.force_show = true
	mobile_ui.visible = true

	var joystick = mobile_ui.get_node_or_null("Joystick")
	var jump_button = mobile_ui.get_node_or_null("JumpButton")
	var fire_button = mobile_ui.get_node_or_null("ShootButton")

	# Test 1: Verify FIRE button is completely removed
	total += 1
	if fire_button == null:
		print("TEST 1 PASSED: FIRE button (ShootButton) is completely removed from mobile screen.")
		passed += 1
	else:
		push_error("TEST 1 FAILED: ShootButton node still exists in MobileUI.")

	# Test 2: Verify enlarged joystick dimensions
	total += 1
	if mobile_ui.joystick_radius >= 110.0 and mobile_ui.knob_radius >= 45.0:
		print("TEST 2 PASSED: Joystick size significantly increased (radius: %.1f, knob: %.1f)." % [mobile_ui.joystick_radius, mobile_ui.knob_radius])
		passed += 1
	else:
		push_error("TEST 2 FAILED: Joystick dimensions too small.")

	# Test 3: Left-Side Touch = Movement ONLY (never triggers shooting)
	total += 1
	var win_w = root.get_visible_rect().size.x
	var left_touch_pos = Vector2(win_w * 0.25, 600.0)

	var touch_left = InputEventScreenTouch.new()
	touch_left.index = 0
	touch_left.position = left_touch_pos
	touch_left.pressed = true
	mobile_ui._handle_screen_touch(touch_left)

	var is_shooting_on_left = Input.is_action_pressed("shoot")
	var is_joystick_active = mobile_ui.is_dragging_joystick

	if is_joystick_active and not is_shooting_on_left:
		print("TEST 3 PASSED: Left-side touch activates virtual joystick and never triggers shooting.")
		passed += 1
	else:
		push_error("TEST 3 FAILED: Left touch triggered shooting or failed to activate joystick.")

	# Test 4: Left-Side Drag = Movement Input
	total += 1
	var drag_left = InputEventScreenDrag.new()
	drag_left.index = 0
	drag_left.position = left_touch_pos + Vector2(80.0, 0.0) # Drag right
	mobile_ui._handle_screen_drag(drag_left)

	var moving_right = Input.is_action_pressed("move_right")
	if moving_right and not Input.is_action_pressed("shoot"):
		print("TEST 4 PASSED: Left-side drag steers movement without firing.")
		passed += 1
	else:
		push_error("TEST 4 FAILED: Movement input not mapped properly during drag.")

	# Test 5: Right-Side Touch = Hold to Shoot (never triggers movement)
	total += 1
	var right_touch_pos = Vector2(win_w * 0.75, 500.0)

	var touch_right = InputEventScreenTouch.new()
	touch_right.index = 1
	touch_right.position = right_touch_pos
	touch_right.pressed = true
	mobile_ui._handle_screen_touch(touch_right)

	var is_shooting_on_right = Input.is_action_pressed("shoot")
	if is_shooting_on_right:
		print("TEST 5 PASSED: Right-side touch immediately activates continuous shooting.")
		passed += 1
	else:
		push_error("TEST 5 FAILED: Right-side touch did not trigger shooting.")

	# Test 6: Simultaneous Multitouch (Moving & Shooting concurrently)
	total += 1
	var still_moving = Input.is_action_pressed("move_right")
	var still_shooting = Input.is_action_pressed("shoot")
	if still_moving and still_shooting:
		print("TEST 6 PASSED: Multitouch verified — simultaneous movement and continuous shooting active.")
		passed += 1
	else:
		push_error("TEST 6 FAILED: Independent multitouch failed (moving=%s, shooting=%s)" % [still_moving, still_shooting])

	# Test 7: Releasing Right Touch Stops Shooting without stopping movement
	total += 1
	var release_right = InputEventScreenTouch.new()
	release_right.index = 1
	release_right.position = right_touch_pos
	release_right.pressed = false
	mobile_ui._handle_screen_touch(release_right)

	var shooting_stopped = not Input.is_action_pressed("shoot")
	var movement_persists = Input.is_action_pressed("move_right")

	if shooting_stopped and movement_persists:
		print("TEST 7 PASSED: Releasing right-side touch immediately stops shooting while left movement continues.")
		passed += 1
	else:
		push_error("TEST 7 FAILED: Releasing right touch did not stop shooting or interfered with movement.")

	# Release left touch
	var release_left = InputEventScreenTouch.new()
	release_left.index = 0
	release_left.position = left_touch_pos
	release_left.pressed = false
	mobile_ui._handle_screen_touch(release_left)
	assert(not Input.is_action_pressed("move_right"), "Movement should be released on left touch lift")

	# Test 8: JumpButton Touch = Jump ONLY (does NOT trigger shooting)
	total += 1
	jump_button.position = Vector2(win_w - 200, 700)
	jump_button.size = Vector2(130, 130)

	var jump_touch_pos = jump_button.get_global_rect().get_center()
	var touch_jump = InputEventScreenTouch.new()
	touch_jump.index = 2
	touch_jump.position = jump_touch_pos
	touch_jump.pressed = true
	mobile_ui._handle_screen_touch(touch_jump)

	var jump_pressed = Input.is_action_pressed("jump")
	var jump_did_not_shoot = not Input.is_action_pressed("shoot")

	# Release jump
	touch_jump.pressed = false
	mobile_ui._handle_screen_touch(touch_jump)
	var jump_released = not Input.is_action_pressed("jump")

	if jump_pressed and jump_did_not_shoot and jump_released:
		print("TEST 8 PASSED: Tapping JumpButton triggers jumping without triggering shooting.")
		passed += 1
	else:
		push_error("TEST 8 FAILED: JumpButton touch interfered with shooting or jump action.")

	# Cleanup
	level.queue_free()

	print("\n=== SUMMARY: %d/%d TESTS PASSED ===" % [passed, total])
	if passed == total:
		print("ALL TWO-SIDE MOBILE TOUCH CONTROLS TESTS PASSED SUCCESSFULLY!")
	quit(0 if passed == total else 1)
