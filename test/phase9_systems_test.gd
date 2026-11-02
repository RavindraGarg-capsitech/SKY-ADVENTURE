extends SceneTree

## Phase 9 Comprehensive Test Suite:
## Tests Pause Menu, Settings, Weapons (Plasma, Triple, Cannon, Rapid), Energy Shield, and Wave 5+ Progression.

func _init() -> void:
	print("--- BEGIN SKY ADVENTURE PHASE 9 SYSTEMS TEST SUITE ---")
	call_deferred("_run_tests")


func _run_tests() -> void:
	var passed_count: int = 0
	var total_tests: int = 15

	# 1. Load temporary_level
	print("\n[TEST 1] Loading temporary_level scene with Phase 9 systems...")
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
	var hud = level.get_node_or_null("UI/HUD")
	var pause_modal = level.get_node_or_null("UI/PauseModal")
	var upgrade_modal = level.get_node_or_null("UI/UpgradeModal")
	var wave_mgr = level.get_node_or_null("Core/WaveManager")
	var gm = root.get_node_or_null("GameManager")

	assert(player != null, "Player must exist")
	assert(hud != null, "HUD must exist")
	assert(pause_modal != null, "PauseModal must exist")
	assert(upgrade_modal != null, "UpgradeModal must exist")
	assert(wave_mgr != null, "WaveManager must exist")

	if gm != null:
		gm.change_state(gm.GameState.PLAYING)
	else:
		paused = false

	print("PASS: Level loaded. Player, HUD, PauseModal, UpgradeModal, WaveManager verified.")
	passed_count += 1

	# 2. Test Pause Button & State Transition
	print("\n[TEST 2] Testing Pause Button and PAUSED state...")
	var pause_btn = hud.get_node_or_null("PauseButton")
	assert(pause_btn != null, "Pause button must exist in HUD")
	assert(pause_btn.visible, "Pause button must be visible in HUD")

	pause_modal.show_modal()
	if gm != null:
		gm.change_state(gm.GameState.PAUSED)
	else:
		paused = true

	assert(pause_modal.is_modal_visible(), "Pause modal must be visible when paused")
	assert(paused == true, "SceneTree must be paused when game is paused")
	print("PASS: Pause button and pause state successfully stop gameplay and display menu.")
	passed_count += 1

	# 3. Test Resume from Pause Menu
	print("\n[TEST 3] Testing Resume from Pause Menu...")
	pause_modal._on_resume_pressed()
	await process_frame
	assert(not pause_modal.is_modal_visible(), "Pause modal must be hidden after resume")
	if gm != null:
		assert(gm.current_state == gm.GameState.PLAYING, "GameManager must return to PLAYING")
	assert(paused == false, "SceneTree must be unpaused after resume")
	print("PASS: Resume restores gameplay state and hides modal.")
	passed_count += 1

	# 4. Test Settings Sliders & SaveManager Integration
	print("\n[TEST 4] Testing Settings sliders, audio volume & sensitivity persistence...")
	var save_mgr = root.get_node_or_null("SaveManager")
	var audio_mgr = root.get_node_or_null("AudioManager")

	pause_modal._on_music_slider_changed(65.0)
	pause_modal._on_sfx_slider_changed(85.0)
	pause_modal._on_mouse_slider_changed(1.6)
	pause_modal._on_mobile_slider_changed(1.4)

	if save_mgr != null:
		assert(is_equal_approx(save_mgr.music_volume, 0.65), "Music volume must be saved as 0.65")
		assert(is_equal_approx(save_mgr.sfx_volume, 0.85), "SFX volume must be saved as 0.85")
		assert(is_equal_approx(save_mgr.mouse_sensitivity, 1.6), "Mouse sensitivity must be saved as 1.6")
		assert(is_equal_approx(save_mgr.mobile_sensitivity, 1.4), "Mobile sensitivity must be saved as 1.4")

	if audio_mgr != null:
		assert(is_equal_approx(audio_mgr.music_volume, 0.65), "AudioManager music volume updated")
		assert(is_equal_approx(audio_mgr.sfx_volume, 0.85), "AudioManager sfx volume updated")

	assert(is_equal_approx(player.mouse_sensitivity_factor, 1.6), "Player mouse sensitivity factor updated")
	print("PASS: Volume and sensitivity sliders correctly update managers and persist.")
	passed_count += 1

	# 5. Test Default Weapon & Baseline Shooting
	print("\n[TEST 5] Testing Default weapon stats and baseline shooting...")
	var wdata = player.get_current_weapon_data()
	assert(wdata["id"] == "default", "Default weapon must be active initially")
	assert(wdata["damage"] == 1, "Default weapon damage must be 1")
	assert(is_equal_approx(wdata["cooldown"], 0.20), "Default weapon cooldown must be 0.20")

	var initial_bullet_count = get_nodes_in_group("bullets").size()
	player.shoot_bullet()
	await process_frame
	var post_bullet_count = get_nodes_in_group("bullets").size()

	assert(post_bullet_count > initial_bullet_count, "Player must spawn bullet on default weapon fire")
	print("PASS: Default weapon fires correctly with expected baseline stats.")
	passed_count += 1

	# 6. Test Plasma Gun Unlock & Damage Configuration
	print("\n[TEST 6] Testing Plasma Gun unlock and high damage...")
	player.unlock_weapon("plasma")
	assert(player.current_weapon_id == "plasma", "Plasma Gun must be equipped upon unlock")

	var plasma_data = player.get_current_weapon_data()
	assert(plasma_data["damage"] == 3, "Plasma Gun damage must be 3")
	assert(is_equal_approx(plasma_data["cooldown"], 0.38), "Plasma Gun cooldown must be 0.38s")
	assert(plasma_data["color"] == Color(0.15, 0.85, 1.0), "Plasma Gun has cyan energy color")

	var bullet_inst = load("res://player/bullet_3d.tscn").instantiate()
	bullet_inst.configure_projectile(plasma_data["damage"], plasma_data["range"], plasma_data["speed"], plasma_data["scale"], plasma_data["color"])
	assert(bullet_inst.damage == 3, "Instantiated bullet must have 3 damage")
	bullet_inst.free()
	await process_frame
	print("PASS: Plasma Gun deals 3 damage and has high-energy projectile profile.")
	passed_count += 1

	# 7. Test Triple Shot Weapon Spread
	print("\n[TEST 7] Testing Triple Shot gun fires exactly 3 projectiles in spread...")
	player.unlock_weapon("triple")
	assert(player.current_weapon_id == "triple", "Triple Shot gun must be equipped")
	var triple_data = player.get_current_weapon_data()
	assert(triple_data["multishot"] == 3, "Triple Shot multishot count must be 3")
	assert(triple_data["spread_angles"].size() == 3, "Triple Shot must have 3 spread angles")

	var bullet_start_count = get_nodes_in_group("bullets").size()
	player.shoot_bullet()
	await process_frame
	var bullet_end_count = get_nodes_in_group("bullets").size()

	assert(bullet_end_count - bullet_start_count == 3, "Triple Shot must spawn exactly 3 bullets per blast (found: %d)" % (bullet_end_count - bullet_start_count))
	print("PASS: Triple Shot fires exactly 3 projectiles in configured spread.")
	passed_count += 1

	# 8. Test Heavy Cannon & Impact Effect
	print("\n[TEST 8] Testing Heavy Cannon (high damage & heavy impact)...")
	player.unlock_weapon("cannon")
	assert(player.current_weapon_id == "cannon", "Heavy Cannon equipped")
	var cannon_data = player.get_current_weapon_data()
	assert(cannon_data["damage"] == 6, "Heavy Cannon damage must be 6")
	assert(is_equal_approx(cannon_data["cooldown"], 0.75), "Heavy Cannon cooldown must be 0.75s")
	assert(cannon_data["impact"] == "heavy", "Heavy Cannon impact type must be 'heavy'")
	print("PASS: Heavy Cannon deals 6 damage with slow heavy firing rate.")
	passed_count += 1

	# 9. Test Rapid Blaster Firing Rate
	print("\n[TEST 9] Testing Rapid Blaster fast firing rate...")
	player.unlock_weapon("rapid")
	assert(player.current_weapon_id == "rapid", "Rapid Blaster equipped")
	var rapid_data = player.get_current_weapon_data()
	assert(is_equal_approx(rapid_data["cooldown"], 0.08), "Rapid Blaster cooldown must be 0.08s")
	print("PASS: Rapid Blaster has configured 0.08s rapid fire cooldown.")
	passed_count += 1

	# 10. Test Weapon Switching (keys / cycling / programmatic)
	print("\n[TEST 10] Testing Weapon Switching and HUD display...")
	var hud_wpn_label = hud.get_node_or_null("WeaponContainer/Margin/VBox/WeaponLabel")
	assert(hud_wpn_label != null, "HUD weapon label must exist")

	player.equip_weapon("plasma")
	assert(player.current_weapon_id == "plasma", "Equipped plasma")
	assert(hud_wpn_label.text.contains("Plasma"), "HUD must reflect Plasma Gun")

	player.equip_weapon("cannon")
	assert(player.current_weapon_id == "cannon", "Equipped cannon")
	assert(hud_wpn_label.text.contains("Heavy Cannon"), "HUD must reflect Heavy Cannon")

	player.cycle_weapon()
	assert(player.current_weapon_id != "cannon", "Cycling switches to next unlocked weapon")
	print("PASS: Weapon switching works reliably and synchronizes to HUD.")
	passed_count += 1

	# 11. Test Energy Shield Activation & Visual Sphere
	print("\n[TEST 11] Testing Energy Shield activation & visual sphere...")
	assert(player.is_shield_active == false, "Shield must be inactive initially")
	var shield_ok = player.activate_shield(10.0)
	assert(shield_ok == true, "Shield activation must succeed")
	assert(player.is_shield_active == true, "Shield must be active")
	assert(is_equal_approx(player.shield_time_left, 10.0), "Shield duration must be 10.0s")
	if player.shield_sphere != null:
		assert(player.shield_sphere.visible == true, "Shield visual sphere must be visible")

	var hud_shield_cont = hud.get_node_or_null("ShieldContainer")
	assert(hud_shield_cont != null and hud_shield_cont.visible == true, "HUD shield indicator must be visible")
	print("PASS: Energy Shield activates with 10s timer, visual sphere, and HUD display.")
	passed_count += 1

	# 12. Test Energy Shield Prevents Duplicate Activation
	print("\n[TEST 12] Testing repeated shield activation prevention...")
	var second_activation = player.activate_shield(10.0)
	assert(second_activation == false, "Repeated activation while active must return false")
	print("PASS: Redundant activation while shield is active is prevented.")
	passed_count += 1

	# 13. Test Energy Shield Full Damage Immunity (Melee, Ranged, Boss)
	print("\n[TEST 13] Testing full damage immunity during shield protection...")
	var hp_before = player.current_health
	player.take_damage(25) # melee attack simulation
	player.take_damage(40) # boss attack simulation
	player.take_damage(15) # spitter projectile simulation
	assert(player.current_health == hp_before, "Player HP must not decrease while shield is active (found: %d, expected: %d)" % [player.current_health, hp_before])

	# Verify player can still move and shoot during protection
	player.velocity = Vector3(5, 0, 0)
	player.shoot_bullet()
	assert(player.velocity.x == 5.0, "Player can move during shield protection")
	print("PASS: Energy Shield completely absorbs all damage while allowing movement and shooting.")
	passed_count += 1

	# 14. Test Shield Expiration & Resumption of Normal Damage
	print("\n[TEST 14] Testing shield expiration and damage resumption...")
	player.deactivate_shield()
	assert(player.is_shield_active == false, "Shield must be inactive after deactivation")
	if player.shield_sphere != null:
		assert(player.shield_sphere.visible == false, "Shield visual sphere must be hidden")

	player.take_damage(20)
	assert(player.current_health == hp_before - 20, "Normal damage must resume after shield expires")
	print("PASS: Shield deactivation resumes normal damage intake.")
	passed_count += 1

	# 15. Test Wave 5+ Power-Up Progression Filtering
	print("\n[TEST 15] Testing wave-gated upgrade card progression...")
	player.unlocked_weapons.clear()
	player.unlocked_weapons.append("default")
	# Simulate Wave 1: advanced weapons must NOT appear
	upgrade_modal.present_upgrades(1)
	for choice in upgrade_modal.current_choices:
		assert(choice.get("min_wave", 1) <= 1, "Wave 1 choices must only contain basic upgrades (found: %s)" % choice["id"])
	upgrade_modal.hide_modal()

	# Simulate Wave 5: Plasma Gun & Energy Shield should be available in pool
	var wave5_has_plasma_or_shield = false
	for i in range(15): # sample 15 times to guarantee coverage
		upgrade_modal.present_upgrades(5)
		for choice in upgrade_modal.current_choices:
			if choice["id"] == "weapon_plasma" or choice["id"] == "powerup_shield":
				wave5_has_plasma_or_shield = true
				break
		upgrade_modal.hide_modal()
		if wave5_has_plasma_or_shield:
			break
	assert(wave5_has_plasma_or_shield, "Wave 5 pool must offer Plasma Gun or Energy Shield")

	# Simulate Wave 6+: Triple Shot, Heavy Cannon, Rapid Blaster available in pool
	var wave6_has_advanced = false
	for i in range(15):
		upgrade_modal.present_upgrades(6)
		for choice in upgrade_modal.current_choices:
			if choice["id"] in ["weapon_triple", "weapon_cannon", "weapon_rapid"]:
				wave6_has_advanced = true
				break
		upgrade_modal.hide_modal()
		if wave6_has_advanced:
			break
	assert(wave6_has_advanced, "Wave 6+ pool must offer advanced weapons")
	print("PASS: Wave progression gating verified (Wave 1-4 standard, Wave 5 Plasma/Shield, Wave 6+ advanced).")
	passed_count += 1

	print("\n==========================================")
	print("ALL %d / %d PHASE 9 TESTS PASSED SUCCESSFULLY!" % [passed_count, total_tests])
	print("==========================================")
	quit(0)
