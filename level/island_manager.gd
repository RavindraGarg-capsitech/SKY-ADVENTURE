extends Node3D

## IslandManager: Controls moving platforms and reveals new island sectors upon wave milestones.

signal sector_unlocked(sector_name: String)

@export var bridge_sector_2: Node3D = null
@export var moving_platform: Node3D = null

var is_sector_2_unlocked: bool = false
var elapsed_time: float = 0.0
var initial_platform_pos: Vector3 = Vector3.ZERO


func _ready() -> void:
	if not is_in_group("island_manager"):
		add_to_group("island_manager")

	if moving_platform != null:
		initial_platform_pos = moving_platform.position

	# Keep Sector 2 bridge sunken until Boss is defeated
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


func _process(delta: float) -> void:
	elapsed_time += delta

	# Smooth horizontal oscillation for the moving stepping platform
	if moving_platform != null:
		var offset_x: float = sin(elapsed_time * 1.5) * 5.0
		moving_platform.position.x = initial_platform_pos.x + offset_x


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
