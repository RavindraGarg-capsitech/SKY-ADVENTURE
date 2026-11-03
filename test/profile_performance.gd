extends SceneTree

## Comprehensive Performance Profiler for Mobile Optimization (Startup & Enemy Death)

func _init() -> void:
	call_deferred("_run_profile")


func _run_profile() -> void:
	print("\n========================================================")
	print("=== RUNNING SKY ADVENTURE PERFORMANCE PROFILING SUITE ===")
	print("========================================================")

	# 1. Profile Audio Synthesis & Autoload Operations
	print("\n--- 1. PROFILING AUDIO MANAGER SYNTHESIS ---")
	var t0 = Time.get_ticks_usec()
	var am_script = load("res://autoload/audio_manager.gd")
	var am = am_script.new()
	root.add_child(am)
	var t1 = Time.get_ticks_usec()
	var am_time_ms = (t1 - t0) / 1000.0
	print("AudioManager synthesis + initialization time: %.2f ms" % am_time_ms)
	root.remove_child(am)
	am.queue_free()

	# 2. Profile PoolManager Operations
	print("\n--- 2. PROFILING POOL MANAGER INITIALIZATION ---")
	t0 = Time.get_ticks_usec()
	var pm_script = load("res://autoload/pool_manager.gd")
	var pm = pm_script.new()
	root.add_child(pm)
	t1 = Time.get_ticks_usec()
	var pm_time_ms = (t1 - t0) / 1000.0
	print("PoolManager pool allocation time (30 bullets, 8 poofs): %.2f ms" % pm_time_ms)

	# 3. Profile Main Level Loading & Instantiation
	print("\n--- 3. PROFILING LEVEL SCENE LOADING & HIERARCHY ---")
	t0 = Time.get_ticks_usec()
	var level_scene = load("res://level/temporary_level.tscn")
	t1 = Time.get_ticks_usec()
	var load_time_ms = (t1 - t0) / 1000.0

	var t_inst0 = Time.get_ticks_usec()
	var level = level_scene.instantiate()
	root.add_child(level)
	var t_inst1 = Time.get_ticks_usec()
	var inst_time_ms = (t_inst1 - t_inst0) / 1000.0

	var total_nodes = 0
	var mesh_nodes = 0
	var light_nodes = 0
	var collision_nodes = 0
	var stack = [level]
	while not stack.is_empty():
		var n = stack.pop_back()
		total_nodes += 1
		if n is MeshInstance3D:
			mesh_nodes += 1
		elif n is Light3D:
			light_nodes += 1
		elif n is CollisionShape3D or n is CollisionPolygon3D:
			collision_nodes += 1
		for c in n.get_children():
			stack.push_back(c)

	print("Level scene resource load time: %.2f ms" % load_time_ms)
	print("Level scene instantiate & tree add time: %.2f ms" % inst_time_ms)
	print("Total nodes in scene tree: %d (Meshes: %d, Lights: %d, Collisions: %d)" % [
		total_nodes, mesh_nodes, light_nodes, collision_nodes
	])

	# 4. Profile SaveManager Disk I/O
	print("\n--- 4. PROFILING SAVEMANAGER DISK I/O SPIKE ---")
	var sm = root.get_node_or_null("SaveManager")
	if sm != null:
		t0 = Time.get_ticks_usec()
		sm.save_game()
		t1 = Time.get_ticks_usec()
		print("SaveManager.save_game() synchronous disk write time: %.2f ms" % ((t1 - t0) / 1000.0))

	# 5. Profile Enemy Death Pipeline & Pickup Spawning
	print("\n--- 5. PROFILING ENEMY DEATH PIPELINE ---")
	var mob_scene = load("res://mob/mob.tscn")
	var mob = mob_scene.instantiate()
	level.add_child(mob)
	mob.global_position = Vector3(0, 2, 0)
	await process_frame

	# Simulate death
	var t_death0 = Time.get_ticks_usec()
	mob.play_hurt(99)
	var t_death1 = Time.get_ticks_usec()
	print("mob.play_hurt(99) lethal hit call duration: %.2f ms" % ((t_death1 - t_death0) / 1000.0))

	# Profile Poof Spawn
	t0 = Time.get_ticks_usec()
	var poof = pm.spawn_poof(Vector3(0, 2, 0), 1.0)
	t1 = Time.get_ticks_usec()
	print("pm.spawn_poof() duration: %.2f ms" % ((t1 - t0) / 1000.0))

	# Profile Coin Pickup Instantiation
	var coin_scene = load("res://reward/coin_pickup.tscn")
	t0 = Time.get_ticks_usec()
	var coin = coin_scene.instantiate()
	level.add_child(coin)
	coin.global_position = Vector3(0, 1.5, 0)
	t1 = Time.get_ticks_usec()
	print("coin_pickup instantiate & add_child duration: %.2f ms" % ((t1 - t0) / 1000.0))

	# Profile Coin Collection (Pickup + SaveGame)
	t0 = Time.get_ticks_usec()
	coin.collect()
	t1 = Time.get_ticks_usec()
	print("coin.collect() duration (including audio, tween, save_game): %.2f ms" % ((t1 - t0) / 1000.0))

	print("\n========================================================")
	print("=== PROFILING COMPLETE ===")
	print("========================================================")

	root.remove_child(pm)
	pm.queue_free()
	root.remove_child(level)
	level.queue_free()
	quit(0)
