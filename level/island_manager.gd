extends Node3D

## IslandManager: Controls moving platforms and reveals new island sectors upon wave milestones.

signal sector_unlocked(sector_name: String)

@export var bridge_sector_2: Node3D = null
@export var moving_platform: Node3D = null
@export var platform_amplitude: Vector3 = Vector3(5.0, 0.0, 0.0)
@export var platform_speed: float = 1.5

var is_sector_2_unlocked: bool = false
var elapsed_time: float = 0.0
var initial_platform_pos: Vector3 = Vector3.ZERO


func _ready() -> void:
	if not is_in_group("island_manager"):
		add_to_group("island_manager")

	_find_moving_platform()

	# Keep Sector 2 bridge sunken until Boss is defeated
	if bridge_sector_2 == null:
		bridge_sector_2 = get_node_or_null("../../World/Bridges/BridgeSector2")
		if bridge_sector_2 == null:
			bridge_sector_2 = get_node_or_null("../BridgeSector2")
		if bridge_sector_2 == null and get_tree().current_scene != null:
			bridge_sector_2 = get_tree().current_scene.find_child("BridgeSector2", true, false) as Node3D

	if bridge_sector_2 != null:
		bridge_sector_2.position.y = -18.0
		bridge_sector_2.visible = false

	var wave_mgr = get_tree().get_first_node_in_group("wave_manager")
	if wave_mgr != null:
		_connect_wave_manager(wave_mgr)
	else:
		get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node.is_in_group("wave_manager"):
		_connect_wave_manager(node)


func _connect_wave_manager(wave_mgr: Node) -> void:
	if wave_mgr.has_signal("wave_completed"):
		if not wave_mgr.wave_completed.is_connected(_on_wave_completed):
			wave_mgr.wave_completed.connect(_on_wave_completed)


func _find_moving_platform() -> void:
	if moving_platform == null:
		moving_platform = get_node_or_null("../../World/MovingPlatforms/MovingPlatform1")
		if moving_platform == null:
			moving_platform = get_node_or_null("../MovingPlatform1")
		if moving_platform == null:
			var root_node = get_tree().current_scene
			if root_node == null and get_tree().root.get_child_count() > 0:
				root_node = get_tree().root.get_child(get_tree().root.get_child_count() - 1)
			if root_node != null:
				moving_platform = root_node.find_child("MovingPlatform1", true, false) as Node3D

	if moving_platform != null and initial_platform_pos == Vector3.ZERO:
		initial_platform_pos = moving_platform.position


func _physics_process(delta: float) -> void:
	if moving_platform == null or initial_platform_pos == Vector3.ZERO:
		_find_moving_platform()

	elapsed_time += delta

	# Smooth oscillation for the moving stepping platform (AnimatableBody3D physics)
	if moving_platform != null:
		var offset_x: float = sin(elapsed_time * platform_speed) * platform_amplitude.x
		var offset_y: float = sin(elapsed_time * platform_speed) * platform_amplitude.y
		var offset_z: float = cos(elapsed_time * platform_speed) * platform_amplitude.z
		var target_pos = initial_platform_pos + Vector3(offset_x, offset_y, offset_z)
		var platform_vel = (target_pos - moving_platform.position) / delta
		moving_platform.position = target_pos
		if "constant_linear_velocity" in moving_platform:
			moving_platform.constant_linear_velocity = platform_vel


func _on_wave_completed(wave_num: int) -> void:
	if wave_num >= 5 and not is_sector_2_unlocked:
		unlock_sector_2()


func unlock_sector_2() -> void:
	if is_sector_2_unlocked:
		return

	is_sector_2_unlocked = true

	if bridge_sector_2 != null:
		bridge_sector_2.visible = true
		var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(bridge_sector_2, "position:y", 0.0, 3.0)

	sector_unlocked.emit("Sector 2: The Stepping Pillars")
