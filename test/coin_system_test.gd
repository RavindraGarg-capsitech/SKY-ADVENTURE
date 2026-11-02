extends SceneTree

func _init() -> void:
	print("--- BEGIN SKY ADVENTURE COIN & PICKUP SYSTEM TEST SUITE ---")
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
	var enemy_mgr = level.get_node_or_null("Core/EnemyManager")
	if enemy_mgr == null:
		enemy_mgr = level.get_node_or_null("EnemyManager")
	var reward_mgr = level.get_node_or_null("Core/RewardManager")
	if reward_mgr == null:
		reward_mgr = level.get_node_or_null("RewardManager")
	var hud = level.get_node_or_null("UI/HUD")
	if hud == null:
		hud = level.get_node_or_null("HUD")

	assert(player != null, "Player must exist")
	assert(enemy_mgr != null, "EnemyManager must exist")
	assert(reward_mgr != null, "RewardManager must exist")
	assert(hud != null, "HUD must exist")

	print("PASS: Level loaded. Player, EnemyManager, RewardManager, HUD present.")
	passed_count += 1

	# 2. Check pre-placed path coins
	print("\n[TEST 2] Verifying pre-placed path coins on bridges & islands...")
	var path_coins = []
	for child in level.get_children():
		if child.is_in_group("coins"):
			path_coins.append(child)

	assert(path_coins.size() >= 4, "Expected at least 4 pre-placed path coins, found: %d" % path_coins.size())
	for c in path_coins:
		assert(c.visible == true, "Path coin must be visible")
		assert(c.global_position.y >= 0.4, "Path coin Y should be above ground (found: %f)" % c.global_position.y)
		assert(c.collision_layer == 16, "Coin collision layer must be 16")
		assert(c.collision_mask == 1, "Coin collision mask must be 1 (detects player)")
	print("PASS: Found %d pre-placed path coins, all visible and safely elevated above ground." % path_coins.size())
	passed_count += 1

	# 3. Simulate Enemy Death & Coin Spawning
	print("\n[TEST 3] Testing enemy death -> coin spawn...")
	var initial_coin_count = 0
	for child in level.get_children():
		if child.is_in_group("coins"):
			initial_coin_count += 1

	# Instantiate a real mob from mob.tscn
	var mob_scene = load("res://mob/mob.tscn")
	var enemy_mob = mob_scene.instantiate()
	enemy_mob.name = "TestEnemyBat"
	level.add_child(enemy_mob)
	enemy_mob.global_position = Vector3(-28.0, 1.5, 25.5)
	enemy_mob.death_position_recorded = Vector3(-28.0, 1.5, 25.5)

	# Trigger enemy_died signal through EnemyManager
	enemy_mgr.enemy_died.emit(enemy_mob, enemy_mob.death_position_recorded)
	await process_frame

	var new_coin_count = 0
	var spawned_coin = null
	for child in level.get_children():
		if child.is_in_group("coins"):
			new_coin_count += 1
			if child not in path_coins:
				spawned_coin = child

	assert(new_coin_count == initial_coin_count + 1, "Exactly one coin should spawn on standard enemy death (expected %d, got %d)" % [initial_coin_count + 1, new_coin_count])
	assert(spawned_coin != null, "Spawned coin must be valid")
	print("PASS: Enemy death triggered exactly 1 coin drop.")
	passed_count += 1

	# 4. Verify Coin Ground Clamping & Safe Position
	print("\n[TEST 4] Testing coin ground clamping and safe elevation...")
	assert(spawned_coin.global_position.y >= 0.5, "Spawned coin must be on/above platform surface (found Y: %f)" % spawned_coin.global_position.y)
	assert(spawned_coin.global_position.y < 5.0, "Spawned coin must not float into sky (found Y: %f)" % spawned_coin.global_position.y)
	print("PASS: Spawned coin safely positioned at Y = %.2f (on island surface, not in void)." % spawned_coin.global_position.y)
	passed_count += 1

	# 5. Verify Coin Visual Polish (Mesh, Light, Sparkle)
	print("\n[TEST 5] Testing coin visual components...")
	var coin_visual = spawned_coin.get_node_or_null("CoinVisual")
	var omni_light = spawned_coin.get_node_or_null("OmniLight3D")
	var sparkle = spawned_coin.get_node_or_null("Sparkle")

	assert(coin_visual != null, "CoinVisual container must exist")
	assert(omni_light != null, "OmniLight3D must exist for gold glow")
	assert(sparkle != null, "Sparkle mesh must exist for twinkle effect")
	assert(omni_light.light_energy > 0.5, "OmniLight3D energy must be bright")
	assert(coin_visual.get_node_or_null("OuterRim") != null, "Outer rim mesh must exist")
	assert(coin_visual.get_node_or_null("InnerCore") != null, "Inner core mesh must exist")
	print("PASS: Coin visual components verified: 3D embossed gold mesh, OmniLight3D glow, and Sparkle twinkle.")
	passed_count += 1

	# 6. Test Coin Collection Flow & HUD Update
	print("\n[TEST 6] Testing coin collection and HUD counter update...")
	var initial_coins = reward_mgr.coins
	var coins_label = hud.get_node_or_null("WaveContainer/CoinsLabel")
	assert(coins_label != null, "HUD CoinsLabel must exist")

	# Move player to coin and collect
	player.global_position = spawned_coin.global_position
	spawned_coin._on_body_entered(player)
	await process_frame

	assert(reward_mgr.coins == initial_coins + 1, "RewardManager coins must increase by 1")
	assert(coins_label.text == "Coins: %d" % reward_mgr.coins, "HUD CoinsLabel must immediately display updated count (got: '%s', expected: 'Coins: %d')" % [coins_label.text, reward_mgr.coins])
	print("PASS: Coin collected. RewardManager coins: %d, HUD label: '%s'." % [reward_mgr.coins, coins_label.text])
	passed_count += 1

	# 7. Test Coin Removal & Single-Collection Guarantee
	print("\n[TEST 7] Testing single-collection guarantee and deletion...")
	assert(spawned_coin.is_collected == true, "Coin is_collected flag must be true")
	# Attempt second collection
	spawned_coin._on_body_entered(player)
	spawned_coin.collect()
	assert(reward_mgr.coins == initial_coins + 1, "Coins must NOT double-increment on multiple triggers")
	print("PASS: Duplicate collection prevented. Single-collection guarantee verified.")
	passed_count += 1

	# 8. Test SaveManager Coin Persistence
	print("\n[TEST 8] Testing SaveManager persistence...")
	var save_mgr = root.get_node_or_null("SaveManager")
	assert(save_mgr != null, "SaveManager autoload must exist")
	var saved_coins_before = save_mgr.total_coins

	# Collect one of the path coins
	var test_path_coin = path_coins[0]
	test_path_coin._on_body_entered(player)
	await process_frame

	assert(save_mgr.total_coins == saved_coins_before + 1, "SaveManager total_coins must increase by 1")
	# Reload save game
	save_mgr.load_game()
	assert(save_mgr.total_coins >= saved_coins_before + 1, "SaveManager loaded total_coins must persist across loads")
	print("PASS: SaveManager coin persistence verified (total_coins: %d)." % save_mgr.total_coins)
	passed_count += 1

	# 9. Test Sector 2 Pickups
	print("\n[TEST 9] Testing Sector 2 void ground clamping...")
	# Simulate mob dying at Sector 2 void location (e.g. X = 0, Y = -8, Z = -25)
	var void_death_pos = Vector3(0.0, -8.0, -25.0)
	var safe_sec2_pos = reward_mgr._find_safe_ground_position(void_death_pos)
	assert(safe_sec2_pos.y >= 0.5, "Void position must be safely clamped to ground or near player (clamped Y: %f)" % safe_sec2_pos.y)
	print("PASS: Sector 2 void position safely clamped to valid surface at Y = %.2f." % safe_sec2_pos.y)
	passed_count += 1

	# 10. Test Boss Death Multi-Reward Drops
	print("\n[TEST 10] Testing Boss multi-coin drops...")
	var boss_scene = load("res://mob/boss/boss_sky_overlord.tscn")
	var boss_node = boss_scene.instantiate()
	boss_node.name = "BossSkyOverlord"
	level.add_child(boss_node)
	boss_node.global_position = Vector3(0.0, 1.0, 0.0)
	boss_node.death_position_recorded = Vector3(0.0, 1.0, 0.0)

	var coins_before_boss = 0
	for child in level.get_children():
		if child.is_in_group("coins"):
			coins_before_boss += 1

	enemy_mgr.enemy_died.emit(boss_node, boss_node.death_position_recorded)
	await process_frame

	var coins_after_boss = 0
	for child in level.get_children():
		if child.is_in_group("coins"):
			coins_after_boss += 1

	assert(coins_after_boss == coins_before_boss + 8, "Boss must drop exactly 8 coins (got %d -> %d)" % [coins_before_boss, coins_after_boss])
	print("PASS: Boss death dropped exactly 8 coins.")
	passed_count += 1

	print("\n==========================================")
	print("ALL %d / %d COIN SYSTEM TESTS PASSED!" % [passed_count, total_tests])
	print("==========================================")

	# Clean up dummy objects
	enemy_mob.queue_free()
	boss_node.queue_free()

	quit(0)
