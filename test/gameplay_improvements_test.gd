extends SceneTree

## Comprehensive test suite for SKY ADVENTURE Gameplay Improvements & Bug Fixes:
## 1. 8-Directional Damage Indicator relative to camera view.
## 2. Increased Jump Height & Physics (Tap vs Hold, Floor Stability).
## 3. Moving Platform carrying player (AnimatableBody3D with sync_to_physics).

func _init() -> void:
	print("\n=== RUNNING SKY ADVENTURE GAMEPLAY IMPROVEMENTS TEST SUITE ===")
	call_deferred("_run_tests")


func _run_tests() -> void:
	var passed = 0
	var total = 0

	# -------------------------------------------------------------
	# TEST GROUP 1: 8-Directional Damage Indicator Angle Mapping
	# -------------------------------------------------------------
	print("\n--- TEST GROUP 1: 8-Way Directional Angle Mapping ---")
	total += 1
	var DmgInd = load("res://ui/damage_indicator.gd")
	var t_front = DmgInd.angle_to_direction_index(0.0)
	var t_front_right = DmgInd.angle_to_direction_index(PI / 4.0)
	var t_right = DmgInd.angle_to_direction_index(PI / 2.0)
	var t_back_right = DmgInd.angle_to_direction_index(3.0 * PI / 4.0)
	var t_back1 = DmgInd.angle_to_direction_index(PI)
	var t_back2 = DmgInd.angle_to_direction_index(-PI)
	var t_back_left = DmgInd.angle_to_direction_index(-3.0 * PI / 4.0)
	var t_left = DmgInd.angle_to_direction_index(-PI / 2.0)
	var t_front_left = DmgInd.angle_to_direction_index(-PI / 4.0)

	if t_front == 0 and t_front_right == 1 and t_right == 2 and t_back_right == 3 \
		and t_back1 == 4 and t_back2 == 4 and t_back_left == 5 and t_left == 6 and t_front_left == 7:
		print("TEST 1 PASSED: All 8 directional angles map cleanly and accurately to Direction enums.")
		passed += 1
	else:
		push_error("TEST 1 FAILED: Angle mapping incorrect: front=%d, fr=%d, r=%d, br=%d, b=%d, bl=%d, l=%d, fl=%d" % [
			t_front, t_front_right, t_right, t_back_right, t_back1, t_back_left, t_left, t_front_left
		])

	# -------------------------------------------------------------
	# TEST GROUP 2: Full Four-Side Red Overlay Geometry & Coverage
	# -------------------------------------------------------------
	print("\n--- TEST GROUP 2: Full Four-Side Red Overlay Geometry & Anchors ---")
	total += 1
	var player_scene = load("res://Player.tscn")
	var player = player_scene.instantiate() as CharacterBody3D
	root.add_child(player)
	player.global_position = Vector3(0, 0, 0)

	var indicator = DmgInd.new()
	root.add_child(indicator)

	# Verify 4 full-edge continuous strips exist
	var top_rect: TextureRect = indicator.sides.get(DmgInd.Side.TOP)
	var bottom_rect: TextureRect = indicator.sides.get(DmgInd.Side.BOTTOM)
	var left_rect: TextureRect = indicator.sides.get(DmgInd.Side.LEFT)
	var right_rect: TextureRect = indicator.sides.get(DmgInd.Side.RIGHT)

	var sides_exist = (top_rect != null and bottom_rect != null and left_rect != null and right_rect != null)

	# Verify full width/height span and 20% inward coverage
	var top_anchors = (is_equal_approx(top_rect.anchor_left, 0.0) and is_equal_approx(top_rect.anchor_right, 1.0) and is_equal_approx(top_rect.anchor_top, 0.0) and is_equal_approx(top_rect.anchor_bottom, 0.20))
	var bottom_anchors = (is_equal_approx(bottom_rect.anchor_left, 0.0) and is_equal_approx(bottom_rect.anchor_right, 1.0) and is_equal_approx(bottom_rect.anchor_top, 0.80) and is_equal_approx(bottom_rect.anchor_bottom, 1.0))
	var left_anchors = (is_equal_approx(left_rect.anchor_left, 0.0) and is_equal_approx(left_rect.anchor_right, 0.20) and is_equal_approx(left_rect.anchor_top, 0.0) and is_equal_approx(left_rect.anchor_bottom, 1.0))
	var right_anchors = (is_equal_approx(right_rect.anchor_left, 0.80) and is_equal_approx(right_rect.anchor_right, 1.0) and is_equal_approx(right_rect.anchor_top, 0.0) and is_equal_approx(right_rect.anchor_bottom, 1.0))

	# Verify mouse_filter ignore on all controls
	var ignore_clicks = (indicator.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and top_rect.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and bottom_rect.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and left_rect.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and right_rect.mouse_filter == Control.MOUSE_FILTER_IGNORE)

	if sides_exist and top_anchors and bottom_anchors and left_anchors and right_anchors and ignore_clicks:
		print("TEST 2 PASSED: All 4 full-edge continuous strips (TOP, BOTTOM, LEFT, RIGHT) verified with full span, 20% inward reach, and click-through.")
		passed += 1
	else:
		push_error("TEST 2 FAILED: Edge overlay geometry or mouse filter mismatch.")

	# -------------------------------------------------------------
	# TEST GROUP 3: World-Space to Camera-View Directional Mapping
	# -------------------------------------------------------------
	print("\n--- TEST GROUP 3: World-Space to Camera-View Directional Mapping ---")
	total += 1

	# Verify camera looking default (-Z)
	var cam: Camera3D = player.get_node("%Camera3D")
	cam.global_position = Vector3(0, 1.7, 0)
	cam.rotation_degrees = Vector3.ZERO
	player.rotation_degrees = Vector3.ZERO

	# Attack from North/Front (0, 0, -10) -> Should light up TOP side with highest intensity (1.0)
	indicator.show_damage_direction(Vector3(0, 0, -10), player)
	var top_primary = top_rect.modulate.a == 1.0 and bottom_rect.modulate.a == 0.0

	# Reset sides
	top_rect.modulate.a = 0.0
	left_rect.modulate.a = 0.0
	right_rect.modulate.a = 0.0

	# Attack from East/Right (10, 0, 0) -> Should light up RIGHT side with highest intensity (1.0)
	indicator.show_damage_direction(Vector3(10, 0, 0), player)
	var right_primary = right_rect.modulate.a == 1.0 and left_rect.modulate.a == 0.0

	# Reset sides
	right_rect.modulate.a = 0.0
	top_rect.modulate.a = 0.0
	bottom_rect.modulate.a = 0.0

	# Diagonal Attack from Top-Left (-10, 0, -10) -> Should light up both TOP and LEFT full edges intensely (0.95)
	indicator.show_damage_direction(Vector3(-10, 0, -10), player)
	var diag_tl_ok = top_rect.modulate.a >= 0.9 and left_rect.modulate.a >= 0.9 and bottom_rect.modulate.a == 0.0 and right_rect.modulate.a == 0.0

	# Reset sides
	top_rect.modulate.a = 0.0
	left_rect.modulate.a = 0.0

	# Fallback/General hit -> Lights up all 4 sides
	indicator._flash_all_sides()
	var omni_ok = top_rect.modulate.a == 1.0 and bottom_rect.modulate.a == 1.0 and left_rect.modulate.a == 1.0 and right_rect.modulate.a == 1.0

	if top_primary and right_primary and diag_tl_ok and omni_ok:
		print("TEST 3 PASSED: Directional hits accurately flare appropriate continuous edge strips (Front, Right, Diagonal, Omni).")
		passed += 1
	else:
		push_error("TEST 3 FAILED: Directional damage edge mapping failed.")

	# -------------------------------------------------------------
	# TEST GROUP 4: Damage Gating (Actual Damage vs Shield / Proximity)
	# -------------------------------------------------------------
	print("\n--- TEST GROUP 4: Damage Gating & Shield Absorption ---")
	total += 1
	var recorded = {"emitted": false, "damage": 0, "pos": Vector3.ZERO}
	player.player_damaged.connect(func(amount: int, hit_pos: Vector3):
		recorded["emitted"] = true
		recorded["damage"] = amount
		recorded["pos"] = hit_pos
	)

	# 1. Active Shield absorbing damage: no signal, health unchanged
	player.activate_shield(10.0)
	var health_before = player.current_health
	player.take_damage(20, Vector3(5, 0, -5))
	var shield_absorbed = (not recorded["emitted"]) and (player.current_health == health_before)

	# 2. Shield deactivated: actual damage registers and emits signal with position
	player.deactivate_shield()
	recorded["emitted"] = false
	player.take_damage(15, Vector3(8, 0, 0))
	var damage_registered = recorded["emitted"] and recorded["damage"] == 15 and recorded["pos"] == Vector3(8, 0, 0)

	if shield_absorbed and damage_registered:
		print("TEST 4 PASSED: Damage indicator strictly gates on registered damage; shield absorbed hits do not trigger overlays.")
		passed += 1
	else:
		push_error("TEST 4 FAILED: Damage gating failed.")

	# -------------------------------------------------------------
	# TEST GROUP 5: Jump Physics & Height Tuning
	# -------------------------------------------------------------
	print("\n--- TEST GROUP 5: Player Jump Height & Physics Tuning ---")
	total += 1
	var jump_vel = player.JUMP_VELOCITY
	var grav = player.GRAVITY
	var min_jump_vel = player.MIN_JUMP_VELOCITY

	# Full jump theoretical height = v^2 / (2g)
	var full_jump_height = (jump_vel * jump_vel) / (2.0 * grav)
	# Tap jump theoretical minimum height
	var min_jump_height = (min_jump_vel * min_jump_vel) / (2.0 * grav)

	var jump_tuned = jump_vel >= 12.5 and full_jump_height >= 3.6 and full_jump_height <= 4.5 and min_jump_height >= 1.2
	if jump_tuned:
		print("TEST 5 PASSED: Jump velocity (%.1f m/s) provides satisfying jump height (%.2fm peak, %.2fm tap min) with gravity %.1f." % [
			jump_vel, full_jump_height, min_jump_height, grav
		])
		passed += 1
	else:
		push_error("TEST 5 FAILED: Jump velocity not within tuned parameters (vel=%.1f, max_h=%.2f, min_h=%.2f)." % [
			jump_vel, full_jump_height, min_jump_height
		])

	# -------------------------------------------------------------
	# TEST GROUP 6: Moving Platform Architecture (AnimatableBody3D)
	# -------------------------------------------------------------
	print("\n--- TEST GROUP 6: Moving Platform Architecture Verification ---")
	total += 1
	var level_scene = load("res://level/temporary_level.tscn")
	var level = level_scene.instantiate()
	root.add_child(level)

	var moving_platform = level.get_node_or_null("World/MovingPlatforms/MovingPlatform1")
	var island_mgr = level.get_node_or_null("Core/IslandManager")

	var platform_valid = moving_platform != null and (moving_platform is AnimatableBody3D)
	var island_mgr_valid = island_mgr != null and island_mgr.moving_platform == moving_platform

	if platform_valid and island_mgr_valid:
		print("TEST 6 PASSED: MovingPlatform1 is an AnimatableBody3D and wired to IslandManager.")
		passed += 1
	else:
		push_error("TEST 6 FAILED: MovingPlatform1 is not properly configured as an AnimatableBody3D.")

	# -------------------------------------------------------------
	# TEST GROUP 7: Moving Platform Carries Player (Physics Simulation)
	# -------------------------------------------------------------
	print("\n--- TEST GROUP 7: Player Platform-Following Physics Simulation ---")
	total += 1

	var test_player = level.get_node_or_null("Gameplay/Player")
	if test_player == null:
		test_player = level.find_child("Player", true, false) as CharacterBody3D

	# Settle player on center of platform
	test_player.global_position = moving_platform.global_position + Vector3(0, 0.4, 0)
	test_player.velocity = Vector3.ZERO

	# Allow a few frames to establish solid floor contact
	for i in range(4):
		island_mgr._physics_process(1.0 / 60.0)
		await physics_frame
		test_player._physics_process(1.0 / 60.0)

	var initial_platform_x = moving_platform.global_position.x
	var initial_player_x = test_player.global_position.x

	# Now simulate 15 frames of platform carrying player
	for i in range(15):
		island_mgr._physics_process(1.0 / 60.0)
		await physics_frame
		test_player._physics_process(1.0 / 60.0)

	var moved_platform_x = moving_platform.global_position.x
	var moved_player_x = test_player.global_position.x
	var platform_delta_x = abs(moved_platform_x - initial_platform_x)
	var player_delta_x = abs(moved_player_x - initial_player_x)
	var relative_drift = abs(player_delta_x - platform_delta_x)

	var platform_carried_player = platform_delta_x > 0.3 and relative_drift < 0.2 and test_player.is_on_floor()

	if platform_carried_player:
		print("TEST 7 PASSED: Player successfully stayed attached to and moved with MovingPlatform1 (platform dx=%.2f, player dx=%.2f, drift=%.3f)." % [
			platform_delta_x, player_delta_x, relative_drift
		])
		passed += 1
	else:
		push_error("TEST 7 FAILED: Player did not move with platform: platform_dx=%.2f, player_dx=%.2f, drift=%.2f, on_floor=%s" % [
			platform_delta_x, player_delta_x, relative_drift, str(test_player.is_on_floor())
		])

	# -------------------------------------------------------------
	# TEST GROUP 8: HUD Damage Indicator Integration
	# -------------------------------------------------------------
	print("\n--- TEST GROUP 8: HUD Damage Indicator Integration ---")
	total += 1
	var hud = level.get_node_or_null("UI/HUD")
	if hud == null:
		hud = level.find_child("HUD", true, false)
	var hud_dmg_indicator = hud.get_node_or_null("DamageIndicator") if hud != null else null

	var hud_ok = hud_dmg_indicator != null and hud_dmg_indicator.mouse_filter == Control.MOUSE_FILTER_IGNORE
	if hud_ok:
		print("TEST 8 PASSED: DamageIndicator is present in HUD CanvasLayer with mouse_filter=IGNORE.")
		passed += 1
	else:
		push_error("TEST 8 FAILED: HUD DamageIndicator missing or misconfigured.")

	# -------------------------------------------------------------
	# TEST GROUP 9: PC Controls Exact Preservation
	# -------------------------------------------------------------
	print("\n--- TEST GROUP 9: PC Controls Exact Preservation ---")
	total += 1
	var pc_player = player_scene.instantiate() as CharacterBody3D
	root.add_child(pc_player)
	pc_player.global_position = Vector3(0, 0, 0)
	pc_player.set_physics_process(true)

	# 1. PC Left-click shoots bullet
	Input.action_press("shoot")
	pc_player._physics_process(1.0 / 60.0)
	Input.action_release("shoot")
	var pc_shoot_ok = not pc_player.get_node("%Timer").is_stopped()

	# 2. PC Mouse Camera Rotation
	var initial_rot_y = pc_player.rotation_degrees.y
	pc_player._rotate_camera(Vector2(15.0, 0.0))
	var rot_ok = pc_player.rotation_degrees.y != initial_rot_y

	# 3. PC Keyboard Movement
	Input.action_press("move_forward")
	pc_player._physics_process(1.0 / 60.0)
	Input.action_release("move_forward")
	var move_ok = pc_player.velocity.length() > 0.0 or pc_player.velocity.z != 0.0

	# 4. PC Keyboard Jump Binding
	var jump_ok = InputMap.has_action("jump") and InputMap.action_get_events("jump").size() > 0

	root.remove_child(pc_player)
	pc_player.queue_free()

	if pc_shoot_ok and rot_ok and move_ok and jump_ok:
		print("TEST 9 PASSED: PC Controls fully preserved (mouse left-click shoots, mouse rotates camera, WASD movement, Spacebar jump).")
		passed += 1
	else:
		push_error("TEST 9 FAILED: PC Controls test failed: shoot=%s, rot=%s, move=%s, jump=%s" % [
			str(pc_shoot_ok), str(rot_ok), str(move_ok), str(jump_ok)
		])

	print("\n==================================================")
	print("TEST RESULTS: %d / %d PASSED" % [passed, total])
	print("==================================================")

	# Cleanup
	root.remove_child(player)
	player.queue_free()
	root.remove_child(indicator)
	indicator.queue_free()
	root.remove_child(level)
	level.queue_free()

	if passed == total:
		print("ALL GAMEPLAY IMPROVEMENTS & BUG FIXES VERIFIED SUCCESSFULLY!\n")
		quit(0)
	else:
		push_error("SOME TESTS FAILED!\n")
		quit(1)
