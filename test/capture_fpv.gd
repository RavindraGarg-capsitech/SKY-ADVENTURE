extends SceneTree

func _init() -> void:
	call_deferred("_setup_and_capture")

func _setup_and_capture() -> void:
	var level_scene = load("res://level/temporary_level.tscn")
	var level = level_scene.instantiate()
	root.add_child(level)
	current_scene = level

	var home_ui = level.find_child("HomeUI", true, false)
	if home_ui != null:
		home_ui.visible = false

	var player = level.find_child("Player", true, false)
	var player_cam = player.get_node("%Camera3D")
	player_cam.current = true

	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw

	var img = root.get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("screenshots/player_first_person_view.png")
		print("Saved: screenshots/player_first_person_view.png")

	quit(0)
