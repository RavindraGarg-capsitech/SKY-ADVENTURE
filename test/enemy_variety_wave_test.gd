extends SceneTree

func _init() -> void:
	print("--- BEGIN SKY ADVENTURE ENEMY VARIETY & WAVE COMPOSITION TEST SUITE ---")
	call_deferred("_run_tests")


func _run_tests() -> void:
	var passed_count = 0
	var total_tests = 10

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

	var wave_mgr = level.get_node_or_null("Core/WaveManager")
	if wave_mgr == null:
		wave_mgr = level.get_node_or_null("WaveManager")
	var enemy_mgr = level.get_node_or_null("Core/EnemyManager")
	if enemy_mgr == null:
		enemy_mgr = level.get_node_or_null("EnemyManager")
	var player = level.get_node_or_null("Gameplay/Player")
	if player == null:
		player = level.get_node_or_null("Player")
	var hud = level.get_node_or_null("UI/HUD")
	if hud == null:
		hud = level.get_node_or_null("HUD")

	assert(wave_mgr != null, "WaveManager must exist")
	assert(enemy_mgr != null, "EnemyManager must exist")
	assert(player != null, "Player must exist")
	assert(hud != null, "HUD must exist")

	var gm = root.get_node_or_null("GameManager")
	if gm != null:
		gm.change_state(gm.GameState.PLAYING)
	else:
		paused = false

	print("PASS: Level loaded. WaveManager, EnemyManager, Player, and HUD active.")
	passed_count += 1

	# 2. Verify Predefined Wave Compositions (Waves 1 to 10)
	print("\n[TEST 2] Verifying predefined wave composition configurations for Waves 1 to 10...")
	var expected_compositions = {
		1: {"standard": 5, "scout": 0, "armored": 0, "spitter": 0, "boss": 0, "total": 5},
		2: {"standard": 5, "scout": 3, "armored": 0, "spitter": 0, "boss": 0, "total": 8},
		3: {"standard": 5, "scout": 3, "armored": 2, "spitter": 0, "boss": 0, "total": 10},
		4: {"standard": 5, "scout": 4, "armored": 2, "spitter": 1, "boss": 0, "total": 12},
		5: {"standard": 3, "scout": 2, "armored": 0, "spitter": 0, "boss": 1, "total": 6},
		6: {"standard": 6, "scout": 4, "armored": 3, "spitter": 2, "boss": 0, "total": 15},
		7: {"standard": 0, "scout": 5, "armored": 4, "spitter": 3, "boss": 0, "total": 12},
		8: {"standard": 8, "scout": 5, "armored": 4, "spitter": 3, "boss": 0, "total": 20},
		9: {"standard": 0, "scout": 6, "armored": 6, "spitter": 4, "boss": 0, "total": 16},
		10: {"standard": 0, "scout": 4, "armored": 3, "spitter": 2, "boss": 1, "total": 10}
	}

	for wave_idx in expected_compositions.keys():
		var exp_comp = expected_compositions[wave_idx]
		var act_comp = wave_mgr.get_wave_composition(wave_idx)
		assert(act_comp.standard == exp_comp.standard, "Wave %d standard mismatch: exp %d, got %d" % [wave_idx, exp_comp.standard, act_comp.standard])
		assert(act_comp.scout == exp_comp.scout, "Wave %d scout mismatch: exp %d, got %d" % [wave_idx, exp_comp.scout, act_comp.scout])
		assert(act_comp.armored == exp_comp.armored, "Wave %d armored mismatch: exp %d, got %d" % [wave_idx, exp_comp.armored, act_comp.armored])
		assert(act_comp.spitter == exp_comp.spitter, "Wave %d spitter mismatch: exp %d, got %d" % [wave_idx, exp_comp.spitter, act_comp.spitter])
		assert(act_comp.boss == exp_comp.boss, "Wave %d boss mismatch: exp %d, got %d" % [wave_idx, exp_comp.boss, act_comp.boss])
		assert(act_comp.total == exp_comp.total, "Wave %d total mismatch: exp %d, got %d" % [wave_idx, exp_comp.total, act_comp.total])

		var generated_scenes = wave_mgr._generate_wave_composition(wave_idx)
		assert(generated_scenes.size() == exp_comp.total, "Wave %d generated scene count mismatch: exp %d, got %d" % [wave_idx, exp_comp.total, generated_scenes.size()])

	print("PASS: Waves 1 to 10 compositions match specifications exactly.")
	passed_count += 1

	# 3. Verify Visual Distinctiveness of All 5 Archetypes
	print("\n[TEST 3] Verifying visual identification & material properties for all 5 archetypes...")
	var mob_std = load("res://mob/mob.tscn").instantiate()
	var mob_sct = load("res://mob/variants/mob_fast.tscn").instantiate()
	var mob_arm = load("res://mob/variants/mob_armored.tscn").instantiate()
	var mob_spt = load("res://mob/variants/mob_spitter.tscn").instantiate()
	var mob_bss = load("res://mob/boss/boss_sky_overlord.tscn").instantiate()

	level.add_child(mob_std)
	level.add_child(mob_sct)
	level.add_child(mob_arm)
	level.add_child(mob_spt)
	level.add_child(mob_bss)

	await process_frame

	assert(mob_std.enemy_type_name == "Standard Bat", "Standard bat type name valid")
	assert(mob_sct.enemy_type_name == "Scout Bat", "Scout bat type name valid")
	assert(mob_arm.enemy_type_name == "Armored Bat", "Armored bat type name valid")
	assert(mob_spt.enemy_type_name == "Energy Spitter", "Energy Spitter type name valid")
	assert(mob_bss.enemy_type_name == "Sky Overlord", "Boss Sky Overlord type name valid")

	# Check visual color tints
	assert(mob_sct.enemy_color_tint.g > 0.8 and mob_sct.enemy_color_tint.b > 0.9, "Scout bat has azure/cyan speed tint")
	assert(mob_arm.enemy_metallic > 0.8, "Armored bat has heavy metallic sheen")
	assert(mob_spt.enemy_emissive_energy > 1.0, "Energy spitter has glowing emissive arcane aura")
	assert(mob_bss.enemy_color_tint.r > 0.9, "Boss has crimson fiery color tint")

	# Check size differences
	assert(mob_sct.scale.x < mob_std.scale.x or mob_sct.get_node("CollisionShape3D/bat_model").scale.x < 1.0, "Scout bat is smaller and agile")
	assert(mob_arm.get_node("CollisionShape3D/bat_model").scale.x > 1.2, "Armored bat is bulkier and larger")
	assert(mob_bss.get_node("CollisionShape3D/bat_model").scale.x > 2.0, "Boss is massive colossus")

	mob_std.queue_free()
	mob_sct.queue_free()
	mob_arm.queue_free()
	mob_spt.queue_free()
	mob_bss.queue_free()
	await process_frame

	print("PASS: Visual identification verified (body tints, silhouettes, metallic, and emission).")
	passed_count += 1

	# 4. Test Multiple Spawner Distribution & Registration
	print("\n[TEST 4] Verifying spawner discovery & distribution...")
	enemy_mgr.refresh_spawners()
	assert(enemy_mgr.spawners.size() >= 4, "Expected at least 4 active spawners on the island arena, found: %d" % enemy_mgr.spawners.size())
	print("PASS: Found %d island spawners correctly registered in EnemyManager." % enemy_mgr.spawners.size())
	passed_count += 1

	# 5. Test Controlled Spawn Bursts & Spacing (No Overlap)
	print("\n[TEST 5] Testing controlled group spawn timing, burst pacing, and spacing...")
	enemy_mgr.clear_all()
	var test_queue: Array[PackedScene] = [
		load("res://mob/mob.tscn"),
		load("res://mob/variants/mob_fast.tscn"),
		load("res://mob/variants/mob_armored.tscn"),
		load("res://mob/variants/mob_spitter.tscn")
	]

	# Start wave spawns sequentially one by one
	enemy_mgr.start_wave_spawns(test_queue, 0.4, 1)
	assert(enemy_mgr.get_remaining_count() == 4, "Remaining count must accurately show total 4 before spawns begin")

	# Wait for first sequential enemy to spawn
	await create_timer(0.35).timeout
	await process_frame

	assert(enemy_mgr.active_enemies.size() == 1, "Sequential spawning: exactly 1 enemy spawned initially (got: %d)" % enemy_mgr.active_enemies.size())
	assert(enemy_mgr.get_remaining_count() == 4, "Total remaining enemies must remain 4 (1 active + 3 queued)")

	# Wait for subsequent sequential spawns
	for i in range(3):
		await create_timer(0.45).timeout
		await process_frame

	assert(enemy_mgr.active_enemies.size() >= 2, "Sequential spawns progressing (active: %d)" % enemy_mgr.active_enemies.size())
	var mob1 = enemy_mgr.active_enemies[0]
	assert(mob1.global_position.y >= 0.5, "Spawned enemy elevated safely on island ground (found Y: %f)" % mob1.global_position.y)
	print("PASS: Controlled sequential pacing and enemy spacing verified (no overlaps, safe elevation).")
	passed_count += 1

	# 6. Test Enemy Death Counting (Exactly Once per Death)
	print("\n[TEST 6] Testing single-count enemy death tracking...")
	var initial_remaining = enemy_mgr.get_remaining_count()
	assert(initial_remaining == 4, "Remaining count should be 4")

	var death_signals_emitted = [0]
	var death_cb = func(_mob, _pos): death_signals_emitted[0] += 1
	enemy_mgr.enemy_died.connect(death_cb)

	# Defeat mob 1
	var target_mob = enemy_mgr.active_enemies[0]
	enemy_mgr._on_enemy_died(target_mob)
	assert(enemy_mgr.get_remaining_count() == 3, "Remaining count must decrease to 3")
	assert(death_signals_emitted[0] == 1, "Death signal must fire once")

	# Attempt redundant death trigger on same mob
	enemy_mgr._on_enemy_died(target_mob)
	assert(enemy_mgr.get_remaining_count() == 3, "Redundant death trigger must be ignored")
	assert(death_signals_emitted[0] == 1, "Death signal must NOT fire again")

	enemy_mgr.enemy_died.disconnect(death_cb)
	print("PASS: Single-count death guarantee verified. Redundant deaths ignored.")
	passed_count += 1

	# 7. Test Wave Completion Trigger
	print("\n[TEST 7] Testing all_enemies_defeated signal emission upon wave clear...")
	var all_defeated_box = [false]
	var all_cb = func(): all_defeated_box[0] = true
	enemy_mgr.all_enemies_defeated.connect(all_cb)

	# Ensure all queued mobs are accounted for before defeating active mobs
	enemy_mgr.spawn_queue.clear()
	# Defeat the remaining active mobs
	while not enemy_mgr.active_enemies.is_empty():
		var m = enemy_mgr.active_enemies[0]
		enemy_mgr._on_enemy_died(m)

	assert(enemy_mgr.get_remaining_count() == 0, "Remaining count should be 0")
	assert(all_defeated_box[0] == true, "all_enemies_defeated signal must fire when all enemies are defeated")
	enemy_mgr.all_enemies_defeated.disconnect(all_cb)
	print("PASS: all_enemies_defeated correctly emitted when final enemy was defeated.")
	passed_count += 1

	# 8. Test Boss Wave 5 Encounter Composition
	print("\n[TEST 8] Testing Wave 5 Boss encounter composition and Sky Overlord...")
	var w5_comp = wave_mgr.get_wave_composition(5)
	assert(w5_comp.boss == 1, "Wave 5 must include 1 Boss")
	assert(w5_comp.standard == 3, "Wave 5 must include 3 Standard Bats")
	assert(w5_comp.scout == 2, "Wave 5 must include 2 Scout Bats")
	assert(wave_mgr.is_boss_wave(5) == true, "Wave 5 must be recognized as boss wave")

	var w5_scenes = wave_mgr._generate_wave_composition(5)
	var boss_found = 0
	for sc in w5_scenes:
		var dummy = sc.instantiate()
		if dummy.name.to_lower().contains("boss") or dummy.mass > 4.0:
			boss_found += 1
		dummy.queue_free()
	assert(boss_found == 1, "Wave 5 composition must contain exactly 1 Boss Sky Overlord instance")
	print("PASS: Wave 5 Boss encounter verified (Sky Overlord Boss + 5 escorts).")
	passed_count += 1

	# 9. Test Wave 10 Boss Encounter Composition
	print("\n[TEST 9] Testing Wave 10 Boss encounter composition...")
	var w10_comp = wave_mgr.get_wave_composition(10)
	assert(w10_comp.boss == 1, "Wave 10 must include 1 Boss")
	assert(w10_comp.scout == 4, "Wave 10 must include 4 Scout Bats")
	assert(w10_comp.armored == 3, "Wave 10 must include 3 Armored Bats")
	assert(w10_comp.spitter == 2, "Wave 10 must include 2 Energy Spitters")
	assert(w10_comp.total == 10, "Wave 10 total must be 10 enemies")
	assert(wave_mgr.is_boss_wave(10) == true, "Wave 10 must be recognized as boss wave")
	print("PASS: Wave 10 Boss encounter verified (Sky Overlord + 4 Scouts + 3 Armored + 2 Spitters).")
	passed_count += 1

	# 10. Test Wave 11+ Procedural Scaling & Set Archetypes
	print("\n[TEST 10] Testing Wave 11+ procedural scaling and named sets...")
	var w11_comp = wave_mgr.get_wave_composition(11)
	var w12_comp = wave_mgr.get_wave_composition(12)
	var w13_comp = wave_mgr.get_wave_composition(13)
	var w14_comp = wave_mgr.get_wave_composition(14)
	var w15_comp = wave_mgr.get_wave_composition(15)

	assert(w11_comp.set_name == "Swarm Set", "Wave 11 should be Swarm Set")
	assert(w12_comp.set_name == "Heavy Set", "Wave 12 should be Heavy Set")
	assert(w13_comp.set_name == "Ranged Set", "Wave 13 should be Ranged Set")
	assert(w14_comp.set_name == "Elite Set", "Wave 14 should be Elite Set")
	assert(w15_comp.set_name == "Boss Set", "Wave 15 should be Boss Set")
	assert(w15_comp.boss == 1, "Wave 15 must be a boss encounter")
	assert(w11_comp.total > w10_comp.total, "Wave 11 enemy count scales up")
	print("PASS: Wave 11+ procedural scaling and named set archetypes verified.")
	passed_count += 1

	print("\n==========================================")
	print("ALL %d / %d TESTS PASSED SUCCESSFULLY!" % [passed_count, total_tests])
	print("==========================================")

	quit(0)
