
extends Node3D

var player_score: int = 0

@onready var label: Label = get_node_or_null("Gameplay/SpawnPoints/MobSpawner3D/Label")


func _ready() -> void:
	if label == null:
		label = find_child("Label", true, false) as Label
	if label != null:
		label.visible = false
	update_score()
	_ensure_game_over_modal()

	var enemy_mgr: Node = get_node_or_null("Core/EnemyManager")
	if enemy_mgr == null:
		enemy_mgr = get_tree().get_first_node_in_group("enemy_manager")
	if enemy_mgr != null and enemy_mgr.has_signal("enemy_died"):
		if not enemy_mgr.enemy_died.is_connected(_on_enemy_manager_enemy_died):
			enemy_mgr.enemy_died.connect(_on_enemy_manager_enemy_died)

	var spawner2: Node = get_node_or_null("Gameplay/SpawnPoints/MobSpawner3D2")
	if spawner2 == null:
		spawner2 = find_child("MobSpawner3D2", true, false)
	if spawner2 != null and spawner2.has_signal("mob_spawned"):
		if not spawner2.mob_spawned.is_connected(_on_mob_spawner_3d_mob_spawned):
			spawner2.mob_spawned.connect(_on_mob_spawner_3d_mob_spawned)


func _on_enemy_manager_enemy_died(_mob: Node3D, death_position: Vector3) -> void:
	increase_score()
	do_poof(death_position)


func increase_score() -> void:
	player_score += 1
	update_score()


func do_poof(mob_global_position: Vector3) -> void:
	var pm = get_node_or_null("/root/PoolManager")
	if pm != null and pm.has_method("spawn_poof"):
		pm.spawn_poof(mob_global_position, 1.0)
	else:
		const SMOKE_PUFF = preload("uid://cjk3frr43yesb")
		var poof = SMOKE_PUFF.instantiate()
		add_child(poof)
		poof.global_position = mob_global_position


func update_score() -> void:
	if label != null:
		label.text = "Score: " + str(player_score)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("update_score"):
		hud.update_score(player_score)


func _on_mob_spawner_3d_mob_spawned(mob: Variant) -> void:
	if mob == null or get_node_or_null("Core/EnemyManager") != null or get_node_or_null("EnemyManager") != null:
		return

	if mob.has_signal("died"):
		if not mob.died.is_connected(_on_mob_died.bind(mob)):
			mob.died.connect(_on_mob_died.bind(mob))


func _on_mob_died(mob: Node3D) -> void:
	if not is_instance_valid(mob):
		return

	var death_position: Vector3 = mob.global_position

	increase_score()
	do_poof(death_position)


func _on_kill_plane_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	get_tree().reload_current_scene.call_deferred()


func _ensure_game_over_modal() -> void:
	var gom = get_tree().get_first_node_in_group("game_over_modal")
	if gom == null:
		var go_scene = load("res://ui/game_over_modal.tscn")
		if go_scene != null:
			var go_inst = go_scene.instantiate()
			add_child(go_inst)
