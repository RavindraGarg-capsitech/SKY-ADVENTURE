extends "res://mob/Mob.gd"

## Energy Spitter Bat: Ranged enemy that maintains distance and fires energy bolts.

@export var shoot_interval: float = 2.5
@export var projectile_scene: PackedScene = preload("res://mob/projectile/mob_projectile_3d.tscn")

var shoot_timer: float = 1.0


func _ready() -> void:
	stop_distance = 8.5
	health = 4
	max_health = 4
	speed = 2.4
	attack_damage = 8
	super._ready()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		_find_player()
		if not is_instance_valid(player):
			return

	if is_dead:
		return

	# Handle shooting cooldown
	var distance: float = (player.global_position - global_position).length()
	if distance <= 18.0:
		shoot_timer -= delta
		if shoot_timer <= 0.0:
			shoot_timer = shoot_interval
			_shoot_projectile()

	super._physics_process(delta)


func _shoot_projectile() -> void:
	if projectile_scene == null or not is_instance_valid(player):
		return

	var proj = projectile_scene.instantiate() as Node3D
	get_tree().current_scene.add_child(proj)
	proj.global_position = global_position + Vector3.UP * 0.2

	# Aim at player center
	var aim_target: Vector3 = player.global_position + Vector3.UP * 1.0
	proj.look_at(aim_target, Vector3.UP)
