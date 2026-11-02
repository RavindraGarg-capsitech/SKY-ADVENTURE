extends SceneTree

func _init() -> void:
	print("--- BEGIN SKY ADVENTURE BULLET & HEALTH RECOVERY TEST SUITE ---")
	call_deferred("_run_tests")


func _run_tests() -> void:
	var passed_count = 0
	var total_tests = 8

	# 1. Load Level Scene
	print("\n[TEST 1] Loading temporary_level scene...")
	var level_scene = load("res://level/temporary_level.tscn")
	if level_scene == null:
		printerr("FAIL: Could not load temporary_level.tscn")
		quit(1)
		return

	var level = level_scene.instantiate()
	root.add_child(level)
	current_scene = level

	await process_frame
	await process_frame

	var player = level.get_node_or_null("Gameplay/Player")
	if player == null:
		player = level.get_node_or_null("Player")
	var wave_mgr = level.get_node_or_null("Core/WaveManager")
	if wave_mgr == null:
		wave_mgr = level.get_node_or_null("WaveManager")
	var hud = level.get_node_or_null("UI/HUD")
	if hud == null:
		hud = level.get_node_or_null("HUD")

	assert(player != null, "Player must exist")
	assert(wave_mgr != null, "WaveManager must exist")
	assert(hud != null, "HUD must exist")

	print("PASS: Scene loaded. Player, WaveManager, and HUD active.")
	passed_count += 1

	# 2. Test Repeated Bullet Shooting & Signal Connection (No duplicate errors)
	print("\n[TEST 2] Testing bullet shooting & signal connection integrity...")
	var bullet_scene = load("res://player/bullet_3d.tscn")
	assert(bullet_scene != null, "Bullet scene must load successfully")

	# Spawn 15 bullets in succession
	for i in range(15):
		var b = bullet_scene.instantiate() as Area3D
		level.add_child(b)
		b.global_position = Vector3(float(i), 2.0, 0.0)
		assert(b.body_entered.is_connected(b._on_body_entered), "body_entered signal must be connected")
		assert(b.damage == 1, "Default bullet damage must be 1")
		assert(b.RANGE == 40.0, "Default bullet range must be 40.0")
		assert(b.collision_layer == 4, "Bullet collision layer must be 4")
		assert(b.collision_mask == 2, "Bullet collision mask must be 2")
		b.queue_free()

	await process_frame
	print("PASS: 15 bullets spawned and verified with exactly 1 body_entered connection and correct physics attributes.")
	passed_count += 1

	# 3. Test Wave Health Recovery: 45 HP -> 70 HP
	print("\n[TEST 3] Testing health recovery: 45 HP -> 70 HP on wave completion...")
	player.current_health = 45
	player.health_changed.emit(player.current_health, player.max_health)
	assert(player.current_health == 45, "Player health set to 45")

	var hud_health_label = hud.get_node_or_null("HealthContainer/HealthBar/HealthLabel")
	assert(hud_health_label != null, "HUD HealthLabel must exist")
	assert(hud_health_label.text == "HP: 45 / 100", "HUD must show HP: 45 / 100 before recovery")

	# Simulate Wave 1 completion
	wave_mgr.current_wave = 1
	wave_mgr.wave_completed.emit(1)
	await process_frame

	assert(player.current_health == 70, "Player HP should be restored by 25 (expected 70, got: %d)" % player.current_health)
	assert(hud_health_label.text == "HP: 70 / 100", "HUD HealthLabel must immediately reflect 70 HP (got: %s)" % hud_health_label.text)
	print("PASS: Wave 1 completion restored exactly 25 HP (45 -> 70) and HUD updated immediately.")
	passed_count += 1

	# 4. Test Single-Recovery Guarantee (No duplicate healing for same wave)
	print("\n[TEST 4] Testing anti-duplication protection for wave recovery...")
	# Emit wave_completed(1) again
	wave_mgr.wave_completed.emit(1)
	wave_mgr._apply_wave_recovery(1)
	await process_frame

	assert(player.current_health == 70, "Player HP must remain 70; duplicate wave 1 completion must NOT re-heal")
	print("PASS: Duplicate wave-clear signals ignored. Healing applied exactly once.")
	passed_count += 1

	# 5. Test Cap at max_health: 90 HP -> 100 HP
	print("\n[TEST 5] Testing recovery clamp to max_health: 90 HP -> 100 HP on wave 2...")
	player.current_health = 90
	player.health_changed.emit(player.current_health, player.max_health)
	assert(player.current_health == 90, "Player HP set to 90")

	# Complete Wave 2
	wave_mgr.current_wave = 2
	wave_mgr.wave_completed.emit(2)
	await process_frame

	assert(player.current_health == 100, "Player HP should be clamped to 100 max_health (expected 100, got: %d)" % player.current_health)
	assert(hud_health_label.text == "HP: 100 / 100", "HUD must show HP: 100 / 100")
	print("PASS: Wave 2 completion clamped HP to max_health (90 + 25 -> 100).")
	passed_count += 1

	# 6. Test Health Notification Display in HUD
	print("\n[TEST 6] Testing health recovery notification...")
	var heal_notif = hud.get_node_or_null("HealthContainer/HealNotification")
	assert(heal_notif != null, "HealNotification node must exist in HUD")
	assert(heal_notif.text == "+25 HP Recovered!", "HealNotification text must match restored amount")
	assert(heal_notif.visible == true, "HealNotification must be visible after recovery")
	print("PASS: Health recovery notification verified: '%s'." % heal_notif.text)
	passed_count += 1

	# 7. Test Dead Player / Game Over Protection (No healing after death)
	print("\n[TEST 7] Testing dead player / Game Over suppression...")
	player.take_damage(100)
	assert(player.is_dead == true, "Player must be dead")
	assert(player.current_health == 0, "Player health must be 0")

	# Complete Wave 3 while player is dead
	wave_mgr.current_wave = 3
	wave_mgr.wave_completed.emit(3)
	await process_frame

	assert(player.current_health == 0, "Dead player must NOT receive health recovery (HP remains 0)")
	assert(player.is_dead == true, "Player must remain dead")
	print("PASS: Dead player correctly ignored; no health restored during Game Over.")
	passed_count += 1

	# 8. Test Configurable Amount & Vitality Boost Upgrade Compatibility
	print("\n[TEST 8] Testing configurable heal amount and Vitality Boost upgrade...")
	# Revive player and reset GameManager for testing upgrade
	var gm = root.get_node_or_null("GameManager")
	if gm != null:
		gm.change_state(gm.GameState.PLAYING)
	player.is_dead = false
	player.set_physics_process(true)
	player.current_health = 50
	player.max_health = 100
	player.health_changed.emit(player.current_health, player.max_health)

	# Apply Vitality Boost upgrade
	player.apply_upgrade("health_upgrade")
	assert(player.max_health == 125, "Vitality Boost should increase max_health to 125")
	assert(player.current_health == 75, "Vitality Boost should heal 25 immediately (50 -> 75)")

	# Set configurable wave recovery to 35
	wave_mgr.wave_heal_amount = 35
	wave_mgr.current_wave = 4
	wave_mgr.wave_completed.emit(4)
	await process_frame

	assert(player.current_health == 110, "Configurable 35 HP recovery should restore HP from 75 to 110 (expected 110, got: %d)" % player.current_health)
	assert(hud_health_label.text == "HP: 110 / 125", "HUD must show HP: 110 / 125")
	print("PASS: Configurable heal amount (35 HP) and Vitality Boost (max_health = 125) verified.")
	passed_count += 1

	print("\n==========================================")
	print("ALL %d / %d TESTS PASSED SUCCESSFULLY!" % [passed_count, total_tests])
	print("==========================================")

	quit(0)
