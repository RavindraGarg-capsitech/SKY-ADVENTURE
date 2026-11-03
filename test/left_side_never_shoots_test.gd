extends SceneTree

func _init() -> void:
	print("\n=== RUNNING CRITICAL VERIFICATION: LEFT-SIDE TOUCH MUST NEVER SHOOT ===")
	call_deferred("_run_tests")


func _run_tests() -> void:
	var passed = 0
	var total = 0

	# 1. Unpause and load scene
	var gm = root.get_node_or_null("GameManager")
	if gm != null:
		gm.start_game()
	else:
		paused = false

	var level_scene = load("res://level/temporary_level.tscn")
	var level = level_scene.instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	await process_frame

	var player = level.get_node_or_null("Gameplay/Player")
	assert(player != null, "Player must exist in TemporaryLevel")

	var mobile_ui = level.get_node_or_null("UI/MobileUI")
	assert(mobile_ui != null, "MobileUI must exist in TemporaryLevel")

	# Enable mobile mode
	mobile_ui.force_show = true
	mobile_ui.visible = true
	player.set_mobile_mode(true)

	var win_w = root.get_visible_rect().size.x
	var left_pos = Vector2(win_w * 0.25, 500.0)
	var right_pos = Vector2(win_w * 0.75, 500.0)

	# TEST 1: Tap left side -> NO shooting, NO bullets spawned
	total += 1
	var initial_bullet_count = get_nodes_in_group("bullets").size()

	var tap_left = InputEventScreenTouch.new()
	tap_left.index = 0
	tap_left.position = left_pos
	tap_left.pressed = true
	mobile_ui._handle_screen_touch(tap_left)
	await process_frame

	tap_left.pressed = false
	mobile_ui._handle_screen_touch(tap_left)
	await process_frame

	var post_left_bullets = get_nodes_in_group("bullets").size()
	if post_left_bullets == initial_bullet_count and not player.mobile_shooting:
		print("TEST 1 PASSED: Tap on LEFT side created ZERO bullets and did not trigger shooting.")
		passed += 1
	else:
		push_error("TEST 1 FAILED: Left tap triggered shooting! Bullet count increased or mobile_shooting true.")

	# TEST 2: Hold left side -> Movement only, NO bullets spawned
	total += 1
	var hold_left = InputEventScreenTouch.new()
	hold_left.index = 0
	hold_left.position = left_pos
	hold_left.pressed = true
	mobile_ui._handle_screen_touch(hold_left)

	var drag_left = InputEventScreenDrag.new()
	drag_left.index = 0
	drag_left.position = left_pos + Vector2(100.0, 0.0) # Move right
	mobile_ui._handle_screen_drag(drag_left)

	for frame in range(10):
		await process_frame

	var bullets_after_hold = get_nodes_in_group("bullets").size()
	var moving_right = Input.is_action_pressed("move_right")

	if moving_right and bullets_after_hold == initial_bullet_count and not player.mobile_shooting:
		print("TEST 2 PASSED: Hold and drag on LEFT side successfully controls movement ONLY with zero gunfire.")
		passed += 1
	else:
		push_error("TEST 2 FAILED: Left hold triggered gunfire or failed movement.")

	# Release left touch
	hold_left.pressed = false
	mobile_ui._handle_screen_touch(hold_left)
	await process_frame

	# TEST 3: Tap right side -> Activates shooting
	total += 1
	var bullets_before_right = get_nodes_in_group("bullets").size()
	var tap_right = InputEventScreenTouch.new()
	tap_right.index = 1
	tap_right.position = right_pos
	tap_right.pressed = true
	mobile_ui._handle_screen_touch(tap_right)

	# Allow physics step to fire
	for frame in range(4):
		await process_frame

	tap_right.pressed = false
	mobile_ui._handle_screen_touch(tap_right)
	await process_frame

	var bullets_after_right_tap = get_nodes_in_group("bullets").size()
	if bullets_after_right_tap > bullets_before_right:
		print("TEST 3 PASSED: Tap on RIGHT side successfully spawned bullet.")
		passed += 1
	else:
		push_error("TEST 3 FAILED: Right tap failed to fire.")

	# TEST 4: Hold right side -> Continuous shooting
	total += 1
	var hold_right = InputEventScreenTouch.new()
	hold_right.index = 1
	hold_right.position = right_pos
	hold_right.pressed = true
	mobile_ui._handle_screen_touch(hold_right)

	var count_before_stream = get_nodes_in_group("bullets").size()
	# Wait across multiple fire cooldown cycles (0.2s default cooldown)
	await create_timer(0.45).timeout

	var count_after_stream = get_nodes_in_group("bullets").size()
	var streamed_bullets = count_after_stream - count_before_stream

	hold_right.pressed = false
	mobile_ui._handle_screen_touch(hold_right)
	await process_frame

	if streamed_bullets >= 2 and not player.mobile_shooting:
		print("TEST 4 PASSED: Holding RIGHT side continuously streams bullets (%d fired) and stops on release." % streamed_bullets)
		passed += 1
	else:
		push_error("TEST 4 FAILED: Continuous shooting did not stream bullets or failed to stop on release.")

	# TEST 5: Left finger + Right finger simultaneously -> Move and shoot simultaneously
	total += 1
	var finger_left = InputEventScreenTouch.new()
	finger_left.index = 0
	finger_left.position = left_pos
	finger_left.pressed = true
	mobile_ui._handle_screen_touch(finger_left)

	var drag_left_sim = InputEventScreenDrag.new()
	drag_left_sim.index = 0
	drag_left_sim.position = left_pos + Vector2(100.0, 0.0)
	mobile_ui._handle_screen_drag(drag_left_sim)

	var finger_right = InputEventScreenTouch.new()
	finger_right.index = 1
	finger_right.position = right_pos
	finger_right.pressed = true
	mobile_ui._handle_screen_touch(finger_right)

	await process_frame
	var is_moving_sim = Input.is_action_pressed("move_right")
	var is_shooting_sim = player.mobile_shooting

	if is_moving_sim and is_shooting_sim:
		print("TEST 5 PASSED: Simultaneous multitouch verified — player moves and shoots at the same time.")
		passed += 1
	else:
		push_error("TEST 5 FAILED: Multitouch failure (moving=%s, shooting=%s)" % [is_moving_sim, is_shooting_sim])

	# TEST 6: Release left finger while shooting -> Shooting continues
	total += 1
	finger_left.pressed = false
	mobile_ui._handle_screen_touch(finger_left)
	await process_frame

	var moving_after_left_release = Input.is_action_pressed("move_right")
	var shooting_after_left_release = player.mobile_shooting

	if not moving_after_left_release and shooting_after_left_release:
		print("TEST 6 PASSED: Releasing left finger stops movement while right-side shooting continues uninterrupted.")
		passed += 1
	else:
		push_error("TEST 6 FAILED: Releasing left finger interrupted shooting or failed to stop movement.")

	# TEST 7: Release right finger while moving -> Shooting ceases, movement continues
	total += 1
	# Re-engage left movement
	finger_left.pressed = true
	mobile_ui._handle_screen_touch(finger_left)
	mobile_ui._handle_screen_drag(drag_left_sim)
	await process_frame

	# Release right finger
	finger_right.pressed = false
	mobile_ui._handle_screen_touch(finger_right)
	await process_frame

	var moving_after_right_release = Input.is_action_pressed("move_right")
	var shooting_after_right_release = player.mobile_shooting

	if moving_after_right_release and not shooting_after_right_release:
		print("TEST 7 PASSED: Releasing right finger ceases shooting immediately while left movement continues uninterrupted.")
		passed += 1
	else:
		push_error("TEST 7 FAILED: Releasing right finger failed to stop shooting or stopped movement.")

	# Cleanup left finger
	finger_left.pressed = false
	mobile_ui._handle_screen_touch(finger_left)
	level.queue_free()

	print("\n=== SUMMARY: %d/%d TESTS PASSED ===" % [passed, total])
	if passed == total:
		print("ALL 7 CRITICAL TOUCH DIVISION TESTS PASSED PERFECTLY!")
	quit(0 if passed == total else 1)
