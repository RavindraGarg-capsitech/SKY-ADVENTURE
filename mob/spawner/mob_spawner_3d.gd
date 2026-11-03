
extends Node3D

signal mob_spawned(mob)

@export var auto_spawn: bool = false
@export var mob_to_spawn: PackedScene = null
@export var min_spawn_time: float = 2.0
@export var max_spawn_time: float = 6.0

@onready var marker_3d: Marker3D = get_node_or_null("%Marker3D")
@onready var timer: Timer = get_node_or_null("%Timer")


func _ready() -> void:
	if not is_in_group("spawners"):
		add_to_group("spawners")

	if timer != null:
		timer.one_shot = true
		timer.autostart = false
		timer.stop()
		if auto_spawn:
			_schedule_next_spawn()


func _schedule_next_spawn() -> void:
	if not auto_spawn or timer == null:
		return
	timer.wait_time = randf_range(min_spawn_time, max_spawn_time)
	timer.start()


func get_safe_spawn_point() -> Vector3:
	var base_pos: Vector3 = marker_3d.global_position if marker_3d != null else global_position
	var current_scene = get_tree().current_scene
	if current_scene is Node3D and current_scene.get_world_3d() != null:
		var space_state = current_scene.get_world_3d().direct_space_state
		var ray = PhysicsRayQueryParameters3D.create(
			Vector3(base_pos.x, base_pos.y + 4.0, base_pos.z),
			Vector3(base_pos.x, -16.0, base_pos.z),
			1 # Layer 1 = Environment
		)
		var hit = space_state.intersect_ray(ray)
		if not hit.is_empty():
			return hit.position + Vector3.UP * 1.5
	return base_pos + Vector3.UP * 1.5


func spawn_mob(custom_scene: PackedScene = null, parent_node: Node = null, spawn_pos: Vector3 = Vector3.ZERO) -> Node3D:
	var scene: PackedScene = custom_scene if custom_scene != null else mob_to_spawn
	if scene == null:
		push_warning("No mob scene provided to spawn!")
		return null

	var new_mob: Node3D = scene.instantiate() as Node3D
	var target_parent: Node = parent_node if parent_node != null else get_tree().current_scene
	if target_parent == null:
		target_parent = get_tree().root
	target_parent.add_child(new_mob)
	if spawn_pos != Vector3.ZERO:
		new_mob.global_position = spawn_pos
	else:
		new_mob.global_position = get_safe_spawn_point()

	mob_spawned.emit(new_mob)
	return new_mob


func _on_timer_timeout() -> void:
	if not auto_spawn:
		return

	if mob_to_spawn == null:
		push_warning("Mob scene is not assigned!")
		_schedule_next_spawn()
		return

	spawn_mob(mob_to_spawn)
	_schedule_next_spawn()
