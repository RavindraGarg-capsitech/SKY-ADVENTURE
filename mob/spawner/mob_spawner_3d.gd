
extends Node3D

signal mob_spawned(mob)

@export var mob_to_spawn: PackedScene = null
@export var min_spawn_time: float = 2.0
@export var max_spawn_time: float = 6.0

@onready var marker_3d: Marker3D = %Marker3D
@onready var timer: Timer = %Timer


func _ready() -> void:
	timer.one_shot = true
	_schedule_next_spawn()


func _schedule_next_spawn() -> void:
	timer.wait_time = randf_range(min_spawn_time, max_spawn_time)
	timer.start()


func _on_timer_timeout() -> void:
	if mob_to_spawn == null:
		push_warning("Mob scene is not assigned!")
		_schedule_next_spawn()
		return

	var new_mob = mob_to_spawn.instantiate()
	add_child(new_mob)
	new_mob.global_position = marker_3d.global_position

	mob_spawned.emit(new_mob)

	_schedule_next_spawn()
