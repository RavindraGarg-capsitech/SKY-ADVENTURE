extends Node

## GraphicsManager: Controls mobile & desktop rendering presets, scaling, shadows, and battery performance.

signal quality_changed(new_quality: String)

enum Quality { LOW, MEDIUM, HIGH }

var current_quality: String = "medium"
var is_mobile_device: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_mobile_device = OS.has_feature("mobile") or OS.get_name() in ["Android", "iOS"]

	var initial_quality = get_auto_quality()
	var sm = get_node_or_null("/root/SaveManager")
	if sm != null and "graphics_quality" in sm and sm.graphics_quality != "":
		initial_quality = sm.graphics_quality

	set_quality(initial_quality)


func get_auto_quality() -> String:
	if is_mobile_device:
		var processor_count = OS.get_processor_count()
		# Lower-end devices (4 cores or less) default to low for maximum smoothness
		if processor_count <= 4:
			return "low"
		return "medium"
	return "high"


func set_quality(preset: String) -> void:
	current_quality = preset.to_lower()
	apply_current_settings()
	quality_changed.emit(current_quality)

	var sm = get_node_or_null("/root/SaveManager")
	if sm != null and "graphics_quality" in sm:
		sm.graphics_quality = current_quality
		if sm.has_method("save_game"):
			sm.save_game()


func apply_current_settings() -> void:
	var vp = get_viewport()

	# Mobile Frame Rate Cap: stable 60 FPS prevents thermal throttling and saves battery
	Engine.max_fps = 60

	if vp != null:
		match current_quality:
			"low":
				# 70% resolution scaling with fast bilinear upscaling (huge mobile performance boost)
				vp.scaling_3d_scale = 0.70
				vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
				vp.msaa_3d = Viewport.MSAA_DISABLED
				RenderingServer.directional_shadow_atlas_set_size(512, true)
				_set_scene_shadows(false)
				_apply_environment_settings()

			"medium":
				# 85% resolution scaling (balanced sharpness and speed for modern phones)
				vp.scaling_3d_scale = 0.85
				vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
				vp.msaa_3d = Viewport.MSAA_DISABLED
				RenderingServer.directional_shadow_atlas_set_size(1024, true)
				_set_scene_shadows(true)
				_apply_environment_settings()

			"high":
				# 100% native resolution
				vp.scaling_3d_scale = 1.0
				vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
				vp.msaa_3d = Viewport.MSAA_2X
				RenderingServer.directional_shadow_atlas_set_size(2048, true)
				_set_scene_shadows(true)
				_apply_environment_settings()


func _apply_environment_settings() -> void:
	var scene = get_tree().current_scene
	if scene == null:
		return
	var env_nodes = scene.find_children("*", "WorldEnvironment", true, false)
	for env_node in env_nodes:
		if env_node is WorldEnvironment and env_node.environment != null:
			var env = env_node.environment
			match current_quality:
				"low":
					env.ssao_enabled = false
					env.glow_enabled = false
				"medium":
					env.ssao_enabled = false
					env.glow_enabled = true
				"high":
					env.ssao_enabled = (not is_mobile_device)
					env.glow_enabled = true


func _set_scene_shadows(enable: bool) -> void:
	var scene = get_tree().current_scene
	if scene == null:
		return
	var lights = scene.find_children("*", "DirectionalLight3D", true, false)
	for light in lights:
		if light is DirectionalLight3D:
			light.shadow_enabled = enable
