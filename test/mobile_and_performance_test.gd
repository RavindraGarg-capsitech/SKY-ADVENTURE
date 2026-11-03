extends SceneTree

func _init() -> void:
	print("\n=== RUNNING SKY ADVENTURE MOBILE & PERFORMANCE TEST SUITE ===")
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("Initial root children: ", root.get_children())
	var passed = 0
	var total = 0

	# Test 1: Project Display & Handheld Settings
	total += 1
	var orientation = ProjectSettings.get_setting("display/window/handheld/orientation")
	var emulate_touch = ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse")
	var max_fps = ProjectSettings.get_setting("application/run/max_fps")
	if (orientation == 4 or orientation == 5) and emulate_touch == true and max_fps == 60:
		print("TEST 1 PASSED: Mobile project settings configured (sensor_landscape, emulate_touch, 60 FPS cap).")
		passed += 1
	else:
		push_error("TEST 1 FAILED: Orientation=%s, emulate_touch=%s, max_fps=%s" % [str(orientation), str(emulate_touch), str(max_fps)])

	# Test 2: GraphicsManager Autoload & Presets
	total += 1
	var gm = root.get_node("GraphicsManager")
	var sm = root.get_node("SaveManager")
	var pm = root.get_node("PoolManager")

	gm.set_quality("low")
	var low_scale = root.scaling_3d_scale
	gm.set_quality("medium")
	var med_scale = root.scaling_3d_scale
	gm.set_quality("high")
	var high_scale = root.scaling_3d_scale

	if is_equal_approx(low_scale, 0.70) and is_equal_approx(med_scale, 0.85) and is_equal_approx(high_scale, 1.0) and Engine.max_fps == 60:
		print("TEST 2 PASSED: GraphicsManager presets correctly scale 3D resolution (0.70, 0.85, 1.0) and enforce 60 FPS cap.")
		passed += 1
	else:
		push_error("TEST 2 FAILED: Scales were Low=%f, Med=%f, High=%f" % [low_scale, med_scale, high_scale])

	# Test 3: SaveManager Graphics Quality Persistence
	total += 1
	gm.set_quality("low")
	if sm.graphics_quality == "low":
		print("TEST 3 PASSED: SaveManager persists graphics_quality setting.")
		passed += 1
	else:
		push_error("TEST 3 FAILED: SaveManager quality was '%s'" % sm.graphics_quality)

	# Test 4: PoolManager Bullet Zero-Allocation Recycling
	total += 1
	var b1 = pm.spawn_bullet(Vector3(0, 5, 0), Basis.IDENTITY, 2, 50.0, 50.0, 1.0, Color.YELLOW, "default")
	var initial_bullet_count = pm.bullet_pool.size()

	if b1 != null and b1.visible and b1.is_physics_processing():
		pm.recycle_bullet(b1)
		if not b1.visible and not b1.is_physics_processing():
			# Spawn again and verify it reuses b1
			var b2 = pm.spawn_bullet(Vector3(1, 5, 1), Basis.IDENTITY, 2, 50.0, 50.0, 1.0, Color.YELLOW, "default")
			if b2 == b1 and pm.bullet_pool.size() == initial_bullet_count:
				print("TEST 4 PASSED: PoolManager successfully recycled and reused bullet without instantiating new objects.")
				passed += 1
			else:
				push_error("TEST 4 FAILED: Bullet pool size changed or did not reuse recycled instance.")
		else:
			push_error("TEST 4 FAILED: Recycled bullet not hidden or physics not disabled.")
	else:
		push_error("TEST 4 FAILED: Spawned bullet invalid or inactive.")

	# Test 5: PoolManager Poof Particle Zero-Allocation Recycling
	total += 1
	var p1 = pm.spawn_poof(Vector3(0, 2, 0), 1.0)
	var initial_poof_count = pm.poof_pool.size()
	if p1 != null and p1.visible:
		p1.visible = false # simulate duration expiration
		var p2 = pm.spawn_poof(Vector3(5, 2, 5), 1.0)
		if p2 == p1 and pm.poof_pool.size() == initial_poof_count:
			print("TEST 5 PASSED: PoolManager successfully reused poof particle effect without instantiating new objects.")
			passed += 1
		else:
			push_error("TEST 5 FAILED: Poof pool did not reuse deactivated instance.")
	else:
		push_error("TEST 5 FAILED: Poof particle did not spawn or is not visible.")

	# Test 6: Mobile Controls Script and Input Mapping
	total += 1
	var mob_ctrl_script = load("res://level/mobile_controls.gd")
	var mob_ui = CanvasLayer.new()
	mob_ui.set_script(mob_ctrl_script)
	mob_ui.force_show = true

	var joy = Control.new()
	joy.name = "Joystick"
	joy.size = Vector2(300, 300)
	mob_ui.add_child(joy)

	var jump_b = Button.new()
	jump_b.name = "JumpButton"
	jump_b.position = Vector2(800, 500)
	jump_b.size = Vector2(120, 120)
	mob_ui.add_child(jump_b)

	root.add_child(mob_ui)

	# Test simulated drag
	mob_ui.joystick_center = Vector2(100, 100)
	mob_ui._apply_movement_input(Vector2(1.0, -1.0))
	var right_pressed = Input.is_action_pressed("move_right")
	var forward_pressed = Input.is_action_pressed("move_forward")
	mob_ui._reset_joystick()
	var right_released = not Input.is_action_pressed("move_right")

	if right_pressed and forward_pressed and right_released:
		print("TEST 6 PASSED: MobileControls correctly maps virtual joystick inputs to movement actions.")
		passed += 1
	else:
		push_error("TEST 6 FAILED: Input actions not mapped correctly by joystick.")

	# Test 7: Touch Exclusion for Jump Button
	total += 1
	var on_jump = mob_ui._is_point_on_jump_button(Vector2(850, 550))
	var off_jump = not mob_ui._is_point_on_jump_button(Vector2(200, 200))
	if on_jump and off_jump:
		print("TEST 7 PASSED: Jump button touch exclusion correctly isolates jump from shooting.")
		passed += 1
	else:
		push_error("TEST 7 FAILED: Jump button touch exclusion failed.")

	# Test 8: Pause Modal Graphics Quality Buttons
	total += 1
	var pause_scene = load("res://ui/pause_modal.tscn")
	var pause_modal = pause_scene.instantiate()
	root.add_child(pause_modal)

	var low_btn = pause_modal.get_node_or_null("ModalPanel/Center/Card/Margin/VBox/SettingsContainer/QualityRow/QualityButtons/LowButton")
	var high_btn = pause_modal.get_node_or_null("ModalPanel/Center/Card/Margin/VBox/SettingsContainer/QualityRow/QualityButtons/HighButton")

	if low_btn != null and high_btn != null:
		pause_modal._set_graphics_quality("high")
		var is_high = (gm.current_quality == "high")
		pause_modal._set_graphics_quality("low")
		var is_low = (gm.current_quality == "low")
		if is_high and is_low:
			print("TEST 8 PASSED: PauseModal graphics quality buttons successfully switch GraphicsManager presets.")
			passed += 1
		else:
			push_error("TEST 8 FAILED: Quality switching via PauseModal failed.")
	else:
		push_error("TEST 8 FAILED: QualityRow buttons not found in pause_modal.tscn.")

	# Cleanup test nodes
	pause_modal.queue_free()
	mob_ui.queue_free()

	print("\n=== SUMMARY: %d/%d TESTS PASSED ===" % [passed, total])
	if passed == total:
		print("ALL MOBILE OPTIMIZATIONS VERIFIED SUCCESSFULLY!")
	quit(0 if passed == total else 1)
