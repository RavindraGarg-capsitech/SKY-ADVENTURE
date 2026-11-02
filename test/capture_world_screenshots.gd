extends SceneTree

var cam: Camera3D
var step: int = 0
var level: Node3D

func _init() -> void:
	print("--- STARTING AUTOMATED SCREENSHOT CAPTURE ---")
	call_deferred("_setup_scene")


func _setup_scene() -> void:
	var level_scene = load("res://level/temporary_level.tscn")
	if level_scene == null:
		printerr("Failed to load temporary_level.tscn")
		quit(1)
		return

	level = level_scene.instantiate()
	root.add_child(level)
	current_scene = level

	# Hide HomeUI so the environment is clearly visible
	var home_ui = level.get_node_or_null("HomeUI")
	if home_ui != null:
		home_ui.visible = false

	var hud = level.get_node_or_null("HUD")
	if hud != null:
		hud.visible = false

	# Create screenshot camera
	cam = Camera3D.new()
	cam.fov = 70.0
	root.add_child(cam)
	cam.current = true

	# Unlock Sector 2 bridge & platform visually for the shot
	var bridge_sec2 = level.get_node_or_null("BridgeSector2")
	if bridge_sec2 != null:
		bridge_sec2.position.y = 0.0
		bridge_sec2.visible = true

	# Allow 10 frames for shaders and textures to compile and settle
	for i in range(10):
		await process_frame

	call_deferred("_capture_shots")


func _capture_shots() -> void:
	# 1. Sector 1 Starting Island
	print("Capturing 1/5: Sector 1 Starting Island...")
	cam.global_position = Vector3(7.5, 4.0, 33.5)
	cam.look_at(Vector3(0.0, 1.0, 26.0), Vector3.UP)
	await _wait_and_save("screenshots/sector1_starting_island.png")

	# 2. Main Combat Arena
	print("Capturing 2/5: Main Combat Arena...")
	cam.global_position = Vector3(-17.0, 5.5, 33.0)
	cam.look_at(Vector3(-28.0, 1.0, 25.5), Vector3.UP)
	await _wait_and_save("screenshots/main_combat_arena.png")

	# 3. Connected Floating Islands & Bridges
	print("Capturing 3/5: Connected Floating Islands and Bridges...")
	cam.global_position = Vector3(14.0, 12.0, 42.0)
	cam.look_at(Vector3(-8.0, 1.0, 16.0), Vector3.UP)
	await _wait_and_save("screenshots/connected_floating_islands.png")

	# 4. Wave 5 Boss Arena
	print("Capturing 4/5: Wave 5 Boss Arena...")
	cam.global_position = Vector3(0.0, 4.5, 14.0)
	cam.look_at(Vector3(0.0, 1.5, 0.0), Vector3.UP)
	await _wait_and_save("screenshots/wave5_boss_arena.png")

	# 5. Sector 2 Environment
	print("Capturing 5/5: Sector 2 Ethereal Void Environment...")
	cam.global_position = Vector3(0.0, 5.0, -15.0)
	cam.look_at(Vector3(0.0, 1.0, -28.0), Vector3.UP)
	await _wait_and_save("screenshots/sector2_void_environment.png")

	print("\nALL 5 SCREENSHOTS CAPTURED SUCCESSFULLY!")
	quit(0)


func _wait_and_save(file_path: String) -> void:
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw

	var img: Image = root.get_viewport().get_texture().get_image()
	if img != null:
		var err = img.save_png(file_path)
		if err == OK:
			print("Saved: %s (%dx%d)" % [file_path, img.get_width(), img.get_height()])
		else:
			printerr("Error saving image: %d" % err)
	else:
		printerr("Viewport image was null!")
