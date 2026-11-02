extends Node

## RewardManager: Controls coin/XP banking, persistent saving, and physical pickup drops.

signal coins_changed(total_coins: int)
signal xp_changed(total_xp: int)

var coins: int = 0
var xp: int = 0

const COIN_PICKUP_SCENE = preload("res://reward/coin_pickup.tscn")
const HEALTH_PICKUP_SCENE = preload("res://reward/health_pickup.tscn")
const SHIELD_PICKUP_SCENE = preload("res://reward/shield_pickup.tscn")


func _ready() -> void:
	if not is_in_group("reward_manager"):
		add_to_group("reward_manager")

	var enemy_mgr = get_node_or_null("../EnemyManager")
	if enemy_mgr == null:
		enemy_mgr = get_tree().get_first_node_in_group("enemy_manager")

	if enemy_mgr != null:
		_connect_enemy_manager(enemy_mgr)
	else:
		get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node.is_in_group("enemy_manager") or node.name == "EnemyManager":
		_connect_enemy_manager(node)


func _connect_enemy_manager(enemy_mgr: Node) -> void:
	if enemy_mgr.has_signal("enemy_died"):
		if not enemy_mgr.enemy_died.is_connected(_on_enemy_died):
			enemy_mgr.enemy_died.connect(_on_enemy_died)


func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)

	# Direct persistence via SaveManager
	if get_node_or_null("/root/SaveManager") != null:
		SaveManager.total_coins += amount
		SaveManager.save_game()


func add_xp(amount: int) -> void:
	xp += amount
	xp_changed.emit(xp)


func _on_enemy_died(mob: Node3D, death_position: Vector3) -> void:
	var raw_pos: Vector3 = death_position
	if is_instance_valid(mob) and "death_position_recorded" in mob and mob.death_position_recorded != Vector3.ZERO:
		raw_pos = mob.death_position_recorded
	elif raw_pos == Vector3.ZERO and is_instance_valid(mob):
		raw_pos = mob.global_position

	var is_boss: bool = false
	if mob != null and (mob.name.to_lower().contains("boss") or mob.mass > 4.0):
		is_boss = true

	if is_boss:
		add_xp(200)
		for i in range(8):
			var offset = Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-2.0, 2.0))
			var safe_pos = _find_safe_ground_position(raw_pos + offset)
			_spawn_pickup(COIN_PICKUP_SCENE, safe_pos)
		for i in range(3):
			var offset = Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))
			var safe_pos = _find_safe_ground_position(raw_pos + offset)
			_spawn_pickup(HEALTH_PICKUP_SCENE, safe_pos)
		# Guaranteed Shield Pickup from Boss
		var shield_pos = _find_safe_ground_position(raw_pos + Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)))
		_spawn_pickup(SHIELD_PICKUP_SCENE, shield_pos)
	else:
		add_xp(10)
		# Guaranteed coin drop
		var safe_pos = _find_safe_ground_position(raw_pos)
		_spawn_pickup(COIN_PICKUP_SCENE, safe_pos)

		# 25% chance for health pickup
		if randf() < 0.25:
			var hp_pos = _find_safe_ground_position(raw_pos + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5)))
			_spawn_pickup(HEALTH_PICKUP_SCENE, hp_pos)

		# Wave 5+ chance for Energy Shield pickup drop (15% chance)
		var wm = get_tree().get_first_node_in_group("wave_manager")
		var wave_num = wm.current_wave if wm != null and "current_wave" in wm else 1
		if wave_num >= 5 and randf() < 0.15:
			var shld_pos = _find_safe_ground_position(raw_pos + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8)))
			_spawn_pickup(SHIELD_PICKUP_SCENE, shld_pos)


## Finds a valid, walkable island surface directly below target_pos, or clamps safely near the player.
func _find_safe_ground_position(target_pos: Vector3) -> Vector3:
	var player = get_tree().get_first_node_in_group("player") as Node3D

	# If the target position is already below platform level or in the void, relocate near player
	if target_pos.y < -2.0 and is_instance_valid(player):
		return player.global_position + Vector3(randf_range(-1.5, 1.5), 0.6, randf_range(-1.5, 1.5))

	var current_scene = get_tree().current_scene
	if current_scene is Node3D and current_scene.get_world_3d() != null:
		var space_state = current_scene.get_world_3d().direct_space_state
		# Raycast downwards from above target_pos to detect island floor
		var ray_start: Vector3 = Vector3(target_pos.x, maxf(target_pos.y + 1.5, 2.0), target_pos.z)
		var ray_end: Vector3 = Vector3(target_pos.x, -12.0, target_pos.z)
		var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end, 1) # Layer 1 = environment
		var hit = space_state.intersect_ray(query)

		if not hit.is_empty() and hit.has("position"):
			return hit.position + Vector3.UP * 0.6

	# Fallback: if over open void, spawn on nearest island ground or near player
	if is_instance_valid(player):
		return player.global_position + Vector3(randf_range(-1.2, 1.2), 0.6, randf_range(-1.2, 1.2))

	return Vector3(target_pos.x, maxf(target_pos.y, 0.6), target_pos.z)


func _spawn_pickup(scene: PackedScene, pos: Vector3) -> void:
	if scene == null:
		return
	var pickup = scene.instantiate() as Node3D
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = pos
