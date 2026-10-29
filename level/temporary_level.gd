
extends Node3D

var player_score: int = 0

@onready var label: Label = $MobSpawner3D/Label


func _ready() -> void:
	update_score()


func increase_score() -> void:
	player_score += 1
	update_score()


func do_poof(mob_global_position: Vector3) -> void:
	const SMOKE_PUFF = preload("uid://cjk3frr43yesb")

	var poof = SMOKE_PUFF.instantiate()
	add_child(poof)
	poof.global_position = mob_global_position


func update_score() -> void:
	label.text = "Score: " + str(player_score)


func _on_mob_spawner_3d_mob_spawned(mob: Variant) -> void:
	if mob == null:
		return

	if mob.has_signal("died"):
		if not mob.died.is_connected(increase_score):
			mob.died.connect(increase_score)

		if not mob.died.is_connected(_on_mob_died.bind(mob)):
			mob.died.connect(_on_mob_died.bind(mob))


func _on_mob_died(mob: Node3D) -> void:
	if not is_instance_valid(mob):
		return

	var death_position: Vector3 = mob.global_position

	increase_score()
	do_poof(death_position)


func _on_kill_plane_body_entered(body: Node3D) -> void:
	get_tree().reload_current_scene.call_deferred()
