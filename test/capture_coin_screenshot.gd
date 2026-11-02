extends SceneTree

var cam: Camera3D
var level: Node3D

func _init() -> void:
	print("--- CAPTURING COIN VISUAL SCREENSHOT ---")
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

	# Hide HomeUI so gameplay and coins are front-and-center
	var home_ui = level.get_node_or_null("HomeUI")
	if home_ui != null:
		home_ui.visible = false

	# Position camera to look directly at the glowing bridge coin
	cam = Camera3D.new()
	cam.fov = 65.0
	root.add_child(cam)
	cam.current = true

	# PathCoin1 is at (0, 0.8, 18.5)
	cam.global_position = Vector3(1.5, 1.4, 21.0)
	cam.look_at(Vector3(0.0, 0.8, 18.5), Vector3.UP)

	# Let frames render so meshes, materials, and lights compile
	for i in range(12):
		await process_frame

	call_deferred("_capture_and_save")


func _capture_and_save() -> void:
	var viewport = root.get_viewport()
	var img = viewport.get_texture().get_image()
	if img != null:
		var dir = DirAccess.open("res://")
		if not dir.dir_exists("screenshots"):
			dir.make_dir("screenshots")
		var save_path = "screenshots/coin_pickup_in_game.png"
		var err = img.save_png(save_path)
		if err == OK:
			print("Saved screenshot to: %s" % save_path)
		else:
			printerr("Failed to save screenshot: %d" % err)

	quit(0)
