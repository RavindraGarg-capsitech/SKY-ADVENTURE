
extends Node3D

signal mob_spawned(mob)

@export var auto_spawn: bool = false
@export var mob_to_spawn: PackedScene = null
@export var min_spawn_time: float = 2.0
@export var max_spawn_time: float = 6.0

@onready var marker_3d: Marker3D = %Marker3D
@onready var timer: Timer = %Timer


func _ready() -> void:
	if not is_in_group("spawners"):
		add_to_group("spawners")

	timer.one_shot = true
	if auto_spawn:
		_schedule_next_spawn()
	else:
		timer.stop()


func _schedule_next_spawn() -> void:
	if not auto_spawn:
		return
	timer.wait_time = randf_range(min_spawn_time, max_spawn_time)
	timer.start()


func spawn_mob(custom_scene: PackedScene = null, parent_node: Node = null, spawn_pos: Vector3 = Vector3.ZERO) -> Node3D:
	var scene: PackedScene = custom_scene if custom_scene != null else mob_to_spawn
	if scene == null:
		push_warning("No mob scene provided to spawn!")
		return null

	var new_mob: Node3D = scene.instantiate() as Node3D
	var target_parent: Node = parent_node if parent_node != null else get_tree().current_scene
	target_parent.add_child(new_mob)
	if spawn_pos != Vector3.ZERO:
		new_mob.global_position = spawn_pos
	else:
		new_mob.global_position = marker_3d.global_position

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
