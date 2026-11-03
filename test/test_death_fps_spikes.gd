extends SceneTree

## Detailed Frame-by-Frame Spike Profiler for Enemy Death Pipeline

func _init() -> void:
	call_deferred("_run_spike_test")


func _run_spike_test() -> void:
	print("\n=== RUNNING ENEMY DEATH FRAME SPIKE PROFILER ===")

	var level_scene = load("res://level/temporary_level.tscn")
	var level = level_scene.instantiate()
	root.add_child(level)

	# Ensure game is in PLAYING state so tree is unpaused
	var gm = root.get_node_or_null("GameManager")
	if gm != null:
		gm.change_state(gm.GameState.PLAYING)
	else:
		paused = false

	# Let the level settle for 10 frames
	for i in range(10):
		await process_frame

	var enemy_mgr = level.get_node_or_null("Core/EnemyManager")
	var mob_scene = load("res://mob/mob.tscn")
	var mob = mob_scene.instantiate()
	level.add_child(mob)
	mob.global_position = Vector3(0, 2, -5)
	if enemy_mgr != null:
		enemy_mgr.active_enemies.append(mob)
		mob.died.connect(enemy_mgr._on_enemy_died.bind(mob))

	# Settle for 5 frames
	for i in range(5):
		await process_frame

	print("\n--- Triggering lethal hit on enemy ---")
	var t0 = Time.get_ticks_usec()
	mob.play_hurt(99)
	var t1 = Time.get_ticks_usec()
	print("Lethal hit frame CPU execution: %.3f ms" % ((t1 - t0) / 1000.0))

	# Measure frame deltas during the 0.45s death animation
	var max_frame_delta: float = 0.0
	var frames_measured = 0
	while is_instance_valid(mob) and not mob.is_queued_for_deletion():
		var frame_t0 = Time.get_ticks_usec()
		await process_frame
		var frame_t1 = Time.get_ticks_usec()
		var frame_ms = (frame_t1 - frame_t0) / 1000.0
		if frame_ms > max_frame_delta:
			max_frame_delta = frame_ms
		frames_measured += 1

	print("Enemy death animation completed over %d frames. Max inter-frame time: %.3f ms" % [frames_measured, max_frame_delta])

	# Let poof and pickups process for 15 frames
	var post_death_max: float = 0.0
	for i in range(15):
		var frame_t0 = Time.get_ticks_usec()
		await process_frame
		var frame_t1 = Time.get_ticks_usec()
		var frame_ms = (frame_t1 - frame_t0) / 1000.0
		if frame_ms > post_death_max:
			post_death_max = frame_ms

	print("Post-death (poof + reward drop) max inter-frame time: %.3f ms" % post_death_max)

	root.remove_child(level)
	level.queue_free()
	print("\n=== SPIKE PROFILER COMPLETED ===")
	quit(0)
