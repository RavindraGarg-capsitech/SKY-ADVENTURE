extends SceneTree

func _init() -> void:
	print("--- BEGIN SKY ADVENTURE DEATH & GAME OVER TEST SUITE ---")
	call_deferred("_run_tests")


func _run_tests() -> void:
	var passed_count = 0
	var total_tests = 10

	# 1. Start the game / Load Level
	print("\n[TEST 1] Loading temporary_level scene...")
	var level_scene = load("res://level/temporary_level.tscn")
	if level_scene == null:
		printerr("FAIL: Could not load temporary_level.tscn")
		quit(1)
		return
	var level = level_scene.instantiate()
	root.add_child(level)
	current_scene = level

	# Let tree settle
	await process_frame
	await process_frame

	var player = level.get_node_or_null("Gameplay/Player")
	if player == null:
		player = level.get_node_or_null("Player")
	var game_over_modal = level.get_node_or_null("UI/GameOverModal")
	if game_over_modal == null:
		game_over_modal = level.get_node_or_null("GameOverModal")
	if game_over_modal == null:
		game_over_modal = root.get_node_or_null("GameOverModal")
	if game_over_modal == null:
		game_over_modal = root.find_child("GameOverModal", true, false)

	var upgrade_modal = level.get_node_or_null("UI/UpgradeModal")
	if upgrade_modal == null:
		upgrade_modal = level.get_node_or_null("UpgradeModal")
	var wave_manager = level.get_node_or_null("Core/WaveManager")
	if wave_manager == null:
		wave_manager = level.get_node_or_null("WaveManager")

	assert(player != null, "Player must exist")
	assert(game_over_modal != null, "GameOverModal must exist in scene tree")
	assert(upgrade_modal != null, "UpgradeModal must exist in scene tree")

	print("PASS: Level loaded. Player, GameOverModal, UpgradeModal present.")
	passed_count += 1

	# Track death emissions
	var death_signal_box = [0]
	player.player_died.connect(func(): death_signal_box[0] += 1)

	# 2. Allow enemies to damage the player
	print("\n[TEST 2] Testing partial damage...")
	player.take_damage(30)
	assert(player.current_health == 70, "Player HP should be 70")
	assert(player.is_dead == false, "Player should still be alive")
	assert(death_signal_box[0] == 0, "Death signal should not have fired")
	print("PASS: Player took damage correctly (HP: 70/100, is_dead: false)")
	passed_count += 1

	# 3. Reduce player health to zero
	print("\n[TEST 3] Reducing health to 0...")
	player.take_damage(70)
	assert(player.current_health == 0, "Player HP should be 0")
	assert(player.is_dead == true, "Player is_dead should be true")
	print("PASS: Player health reached 0 and is_dead set to true")
	passed_count += 1

	# 4. Confirm death signal emits exactly once
	print("\n[TEST 4] Testing death signal count & redundancy protection...")
	# Attempt additional damage while dead
	player.take_damage(50)
	player.take_damage(100)
	assert(death_signal_box[0] == 1, "Death signal must fire EXACTLY ONCE, but fired: %d" % death_signal_box[0])
	print("PASS: Death signal emitted exactly 1 time despite multiple post-death damage attempts")
	passed_count += 1

	# 5. Confirm GameManager enters GAME_OVER and cannot be overwritten
	print("\n[TEST 5] Testing GameManager state lock on GAME_OVER...")
	var gm = root.get_node_or_null("GameManager")
	assert(gm != null, "GameManager autoload must exist")
	assert(gm.current_state == gm.GameState.GAME_OVER, "GameManager state should be GAME_OVER")
	# Attempt illegal state overwrite (e.g. from a rogue wave manager or pause)
	gm.change_state(gm.GameState.WAVE_TRANSITION)
	assert(gm.current_state == gm.GameState.GAME_OVER, "GAME_OVER must NOT be overwritten by WAVE_TRANSITION")
	gm.change_state(gm.GameState.PAUSED)
	assert(gm.current_state == gm.GameState.GAME_OVER, "GAME_OVER must NOT be overwritten by PAUSED")
	print("PASS: GameManager is in GAME_OVER and locked against overwrite")
	passed_count += 1

	# 6. Confirm Game Over panel appears immediately with correct stats
	print("\n[TEST 6] Testing Game Over UI visibility & stat labels...")
	var modal_panel = game_over_modal.get_node("ModalPanel")
	assert(modal_panel.visible == true, "Game Over modal panel must be visible")
	var stats = game_over_modal.get_node("ModalPanel/Center/Card/Margin/VBox/Stats")
	var wave_lbl = stats.get_node("WaveReachedLabel")
	var score_lbl = stats.get_node("EnemiesKilledLabel")
	assert(wave_lbl.text.begins_with("Wave Reached:"), "Wave label text format valid")
	assert(score_lbl.text.begins_with("Final Score:"), "Score label text format valid")
	print("PASS: Game Over panel is visible with stats (Wave: '%s', Score: '%s')" % [wave_lbl.text, score_lbl.text])
	passed_count += 1

	# 7. Confirm gameplay stops
	print("\n[TEST 7] Testing gameplay freeze...")
	assert(player.is_physics_processing() == false, "Player physics processing must be stopped")
	assert(player.velocity == Vector3.ZERO, "Player velocity must be zeroed")
	assert(paused == true, "SceneTree must be paused")
	print("PASS: Gameplay stopped (Physics disabled, velocity zero, tree paused)")
	passed_count += 1

	# 8. Confirm upgrade cards do not appear after death
	print("\n[TEST 8] Testing upgrade modal suppression after death...")
	upgrade_modal.present_upgrades()
	var upg_panel = upgrade_modal.get_node("ModalPanel")
	assert(upg_panel.visible == false, "Upgrade modal must remain HIDDEN after death")
	print("PASS: Upgrade modal suppressed; cards never appear after death")
	passed_count += 1

	# 9. Test Retry
	print("\n[TEST 9] Testing Retry functionality...")
	# Verify retry button unpauses and requests PLAYING state
	game_over_modal._on_retry_pressed()
	assert(modal_panel.visible == false, "Modal panel hidden on retry")
	assert(paused == false, "Tree unpaused on retry")
	assert(gm.current_state == gm.GameState.PLAYING, "GameManager switched to PLAYING on retry")
	print("PASS: Retry button correctly unpauses and transitions to PLAYING")
	passed_count += 1

	# 10. Test Main Menu
	print("\n[TEST 10] Testing Main Menu functionality...")
	# Switch to GAME_OVER again then press Main Menu
	gm.change_state(gm.GameState.GAME_OVER)
	game_over_modal._on_menu_pressed()
	assert(modal_panel.visible == false, "Modal panel hidden on menu press")
	assert(paused == false, "Tree unpaused on menu press")
	assert(gm.current_state == gm.GameState.HOME, "GameManager switched to HOME on menu press")
	print("PASS: Main Menu button correctly unpauses and transitions to HOME")
	passed_count += 1

	print("\n==========================================")
	print("ALL %d / %d TESTS PASSED SUCCESSFULLY!" % [passed_count, total_tests])
	print("==========================================")

	quit(0)
