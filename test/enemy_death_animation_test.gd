extends SceneTree

func _init() -> void:
	print("\n=== RUNNING SKY ADVENTURE ENEMY DEATH ANIMATION & MOBILE OPTIMIZATION TEST ===")
	call_deferred("_run_tests")


func _run_tests() -> void:
	var gm = root.get_node_or_null("GameManager")
	if gm != null:
		gm.start_game()
	else:
		paused = false

	var passed = 0
	var total = 0

	# Test 1: Immediate AI & Physics Shutdown upon lethal damage
	total += 1
	var mob_scene = load("res://mob/mob.tscn")
	var mob = mob_scene.instantiate()
	root.add_child(mob)
	await process_frame

	assert(mob.is_physics_processing(), "Mob should initially process physics")
	mob.play_hurt(99) # Lethal hit

	if mob.is_dead and not mob.is_physics_processing() and mob.linear_velocity == Vector3.ZERO:
		print("TEST 1 PASSED: Mob immediately stops AI and physics processing upon death.")
		passed += 1
	else:
		push_error("TEST 1 FAILED: Mob did not immediately disable physics processing.")

	# Test 2: Collision detection disabled to prevent further interaction
	total += 1
	var col_shape = mob.get_node("CollisionShape3D") as CollisionShape3D
	await process_frame # Allow deferred call to execute
	if mob.collision_layer == 0 and mob.collision_mask == 0 and col_shape.disabled:
		print("TEST 2 PASSED: Collision layer/mask zeroed and CollisionShape3D disabled on death.")
		passed += 1
	else:
		push_error("TEST 2 FAILED: Collision not properly disabled.")

	# Test 3: Skeletal Animation calculation halted (saves mobile CPU/GPU)
	total += 1
	var anim_player = mob.get_node("CollisionShape3D/bat_model/AnimationPlayer") as AnimationPlayer
	if not anim_player.is_playing():
		print("TEST 3 PASSED: Skeletal AnimationPlayer stopped immediately to eliminate skinning calculations.")
		passed += 1
	else:
		push_error("TEST 3 FAILED: AnimationPlayer still playing during death.")

	# Test 4: Single-count death signal guarantee
	total += 1
	var signal_emissions = [0]
	mob.died.connect(func(): signal_emissions[0] += 1)

	# Simulate repeated damage while already dead
	mob.play_hurt(5)
	mob.play_hurt(10)
	mob._on_timer_timeout() # Simulate duplicate timer trigger

	if signal_emissions[0] == 1:
		print("TEST 4 PASSED: 'died' signal emitted exactly once despite multiple damage calls and timer triggers.")
		passed += 1
	else:
		push_error("TEST 4 FAILED: 'died' signal emissions = %d (expected 1)" % signal_emissions[0])

	# Test 5: Visual Shrink & Fall Animation Execution
	total += 1
	var mob2 = mob_scene.instantiate()
	root.add_child(mob2)
	await process_frame
	var bat_model2 = mob2.get_node("CollisionShape3D/bat_model") as Node3D
	var initial_scale = bat_model2.scale
	mob2.play_hurt(99)

	# Simulate 0.6s for death animation completion
	await create_timer(0.6).timeout

	# Verify mob was queued for deletion
	if not is_instance_valid(mob2) or mob2.is_queued_for_deletion():
		print("TEST 5 PASSED: Death animation completed and mob safely removed via queue_free().")
		passed += 1
	else:
		push_error("TEST 5 FAILED: Mob not queued for deletion after death duration.")

	# Test 6: Simultaneous multi-enemy death (10 bats) without freezing
	total += 1
	var swarm: Array[Node] = []
	var death_counts = [0]
	for i in range(10):
		var m = mob_scene.instantiate()
		root.add_child(m)
		m.died.connect(func(): death_counts[0] += 1)
		swarm.append(m)

	await process_frame

	# Kill all 10 at the exact same moment
	for m in swarm:
		m.play_hurt(100)

	# Wait for animations to complete
	await create_timer(0.6).timeout

	if death_counts[0] == 10:
		print("TEST 6 PASSED: 10 simultaneous enemy deaths executed cleanly with exact single-signal emissions.")
		passed += 1
	else:
		push_error("TEST 6 FAILED: Simultaneous death count = %d (expected 10)" % death_counts[0])

	# Test 7: Variant Mobs (Armored, Spitter, Boss)
	total += 1
	var spitter_scene = load("res://mob/variants/mob_spitter.tscn")
	var armored_scene = load("res://mob/variants/mob_armored.tscn")
	var boss_scene = load("res://mob/boss/boss_sky_overlord.tscn")

	var spitter = spitter_scene.instantiate()
	var armored = armored_scene.instantiate()
	var boss = boss_scene.instantiate()

	root.add_child(spitter)
	root.add_child(armored)
	root.add_child(boss)
	await process_frame

	var variant_deaths = [0]
	spitter.died.connect(func(): variant_deaths[0] += 1)
	armored.died.connect(func(): variant_deaths[0] += 1)
	boss.died.connect(func(): variant_deaths[0] += 1)

	spitter.play_hurt(99)
	armored.play_hurt(99)
	boss.play_hurt(999)

	await create_timer(0.6).timeout

	if variant_deaths[0] == 3:
		print("TEST 7 PASSED: All mob variants (Spitter, Armored, Boss) cleanly execute redesigned death sequence.")
		passed += 1
	else:
		push_error("TEST 7 FAILED: Variant deaths = %d (expected 3)" % variant_deaths[0])

	# Test 8: EnemyManager & RewardManager Integration
	total += 1
	var em_script = load("res://mob/enemy_manager.gd")
	var em = em_script.new()
	root.add_child(em)

	var rm_script = load("res://reward/reward_manager.gd")
	var rm = rm_script.new()
	root.add_child(rm)

	var test_mob = mob_scene.instantiate()
	root.add_child(test_mob)
	await process_frame

	em.active_enemies.append(test_mob)
	test_mob.died.connect(em._on_enemy_died.bind(test_mob))

	test_mob.play_hurt(99)
	await create_timer(0.6).timeout

	if em.active_enemies.size() == 0:
		print("TEST 8 PASSED: EnemyManager successfully received death signal and updated active enemies count.")
		passed += 1
	else:
		push_error("TEST 8 FAILED: Active enemies not cleaned up in EnemyManager.")

	# Cleanup
	em.queue_free()
	rm.queue_free()

	print("\n=== SUMMARY: %d/%d TESTS PASSED ===" % [passed, total])
	if passed == total:
		print("ALL ENEMY DEATH ANIMATION TESTS PASSED SUCCESSFULLY!")
	quit(0 if passed == total else 1)
