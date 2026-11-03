extends Node

## PoolManager: Zero-allocation pooling system for bullets, particle effects, and coin pickups.
## Fully deferred physics property management to prevent PhysicsServer3D query flush errors.
## Combat shader precompilation / warmup to eliminate in-game shader compilation freezes.

const BULLET_SCENE = preload("uid://db2jr0d33yyi6")
const SMOKE_PUFF_SCENE = preload("uid://cjk3frr43yesb")
const COIN_SCENE = preload("res://reward/coin_pickup.tscn")

const BULLET_POOL_SIZE: int = 30
const POOF_POOL_SIZE: int = 8
const COIN_POOL_SIZE: int = 16

var bullet_pool: Array[Node3D] = []
var poof_pool: Array[Node3D] = []
var coin_pool: Array[Node3D] = []

var bullet_container: Node3D = null
var poof_container: Node3D = null
var coin_container: Node3D = null

var _shaders_warmed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_pools()
	warmup_combat_shaders()


func _init_pools() -> void:
	if bullet_container != null:
		return

	bullet_container = Node3D.new()
	bullet_container.name = "BulletPool"
	add_child(bullet_container)

	poof_container = Node3D.new()
	poof_container.name = "PoofPool"
	add_child(poof_container)

	coin_container = Node3D.new()
	coin_container.name = "CoinPool"
	add_child(coin_container)

	for i in range(BULLET_POOL_SIZE):
		var b = BULLET_SCENE.instantiate() as Area3D
		bullet_container.add_child(b)
		b.visible = false
		b.set_physics_process(false)
		b.set_deferred("monitoring", false)
		b.set_deferred("monitorable", false)
		if "is_active" in b:
			b.is_active = false
		if "is_ready_for_pool" in b:
			b.is_ready_for_pool = true
		var col = b.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col != null:
			col.set_deferred("disabled", true)
		if b.is_in_group("bullets"):
			b.remove_from_group("bullets")
		b.global_position = Vector3(0, -200, 0)
		bullet_pool.append(b)

	for i in range(POOF_POOL_SIZE):
		var p = SMOKE_PUFF_SCENE.instantiate() as Node3D
		poof_container.add_child(p)
		p.visible = false
		poof_pool.append(p)

	for i in range(COIN_POOL_SIZE):
		var c = COIN_SCENE.instantiate() as Area3D
		coin_container.add_child(c)
		c.visible = false
		c.set_physics_process(false)
		c.set_deferred("monitoring", false)
		c.set_deferred("monitorable", false)
		var col = c.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col != null:
			col.set_deferred("disabled", true)
		if c.is_in_group("coins"):
			c.remove_from_group("coins")
		c.global_position = Vector3(0, -200, 0)
		coin_pool.append(c)


## Precompiles combat shaders (inner/outer smoke) in a 1-frame offscreen SubViewport
## to prevent mid-combat GPU compilation hitches on mobile.
func warmup_combat_shaders() -> void:
	if _shaders_warmed:
		return
	_shaders_warmed = true

	var vp = SubViewport.new()
	vp.name = "ShaderWarmupViewport"
	vp.size = Vector2i(16, 16)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)

	var cam = Camera3D.new()
	cam.position = Vector3(0, 0, 4)
	vp.add_child(cam)

	var holder = Node3D.new()
	vp.add_child(holder)

	var p = SMOKE_PUFF_SCENE.instantiate() as Node3D
	holder.add_child(p)
	p.position = Vector3(0, 0, 0)
	p.visible = true

	# After 2 frames of GPU presentation, safely remove the pre-warmer
	get_tree().process_frame.connect(func():
		get_tree().process_frame.connect(func():
			if is_instance_valid(vp):
				vp.queue_free()
		, CONNECT_ONE_SHOT)
	, CONNECT_ONE_SHOT)


func spawn_bullet(pos: Vector3, bullet_basis: Basis, dmg: int, rng: float, spd: float, p_scale: float, col: Color, impact_type: String) -> Node3D:
	var bullet: Node3D = null
	for b in bullet_pool:
		if is_instance_valid(b) and not b.visible and (not ("is_active" in b) or not b.is_active):
			bullet = b
			break

	if bullet == null:
		bullet = BULLET_SCENE.instantiate() as Node3D
		if bullet_container != null:
			bullet_container.add_child(bullet)
		else:
			add_child(bullet)
		bullet_pool.append(bullet)

	bullet.global_transform = Transform3D(bullet_basis, pos)
	if bullet.has_method("configure_projectile"):
		bullet.call("configure_projectile", dmg, rng, spd, p_scale, col, impact_type)
	if "is_active" in bullet:
		bullet.is_active = true

	bullet.visible = true
	bullet.set_physics_process(true)

	if "monitoring" in bullet:
		bullet.set_deferred("monitoring", true)
	if "monitorable" in bullet:
		bullet.set_deferred("monitorable", true)

	var col_shape = bullet.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col_shape != null:
		col_shape.set_deferred("disabled", false)

	if not bullet.is_in_group("bullets"):
		bullet.add_to_group("bullets")

	return bullet


func recycle_bullet(bullet: Node3D) -> void:
	if not is_instance_valid(bullet):
		return

	# 1. Immediate visual and logical deactivation (stops further damage or collisions)
	bullet.visible = false
	bullet.set_physics_process(false)
	if "is_active" in bullet:
		bullet.is_active = false
	if bullet.is_in_group("bullets"):
		bullet.remove_from_group("bullets")

	# 2. Defer all physics state changes to avoid "Function blocked during in/out signal"
	if "monitoring" in bullet:
		bullet.set_deferred("monitoring", false)
	if "monitorable" in bullet:
		bullet.set_deferred("monitorable", false)

	var col = bullet.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col != null:
		col.set_deferred("disabled", true)

	bullet.global_position = Vector3(0, -200, 0)


func spawn_poof(pos: Vector3, p_scale: float = 1.0) -> Node3D:
	var poof: Node3D = null
	for p in poof_pool:
		if is_instance_valid(p) and not p.visible:
			poof = p
			break

	if poof == null:
		poof = SMOKE_PUFF_SCENE.instantiate() as Node3D
		if poof_container != null:
			poof_container.add_child(poof)
		else:
			add_child(poof)
		poof_pool.append(poof)

	poof.global_position = pos
	poof.scale = Vector3.ONE * 0.1 * p_scale
	poof.visible = true

	var anim = poof.get_node_or_null("%AnimationPlayer") as AnimationPlayer
	if anim != null and anim.has_animation("poof"):
		anim.stop()
		anim.play("poof")
	var snd = poof.get_node_or_null("%Sound") as AudioStreamPlayer3D
	if snd != null:
		snd.play()

	get_tree().create_timer(0.6).timeout.connect(func():
		if is_instance_valid(poof):
			poof.visible = false
	)
	return poof


func spawn_coin(pos: Vector3, val: int = 1, parent: Node = null) -> Node3D:
	var coin: Node3D = null
	for c in coin_pool:
		if is_instance_valid(c) and not c.visible:
			coin = c
			break

	if coin == null:
		coin = COIN_SCENE.instantiate() as Node3D
		coin_pool.append(coin)

	var target_parent: Node = parent
	if target_parent == null:
		target_parent = get_tree().current_scene if get_tree().current_scene != null else coin_container
	if target_parent == null:
		target_parent = self

	if coin.get_parent() != target_parent:
		if coin.get_parent() != null:
			coin.get_parent().remove_child(coin)
		target_parent.add_child(coin)

	coin.global_position = pos
	if "coin_value" in coin:
		coin.coin_value = val
	if "skip_ground_raycast" in coin:
		coin.skip_ground_raycast = true
	if coin.has_method("reset_for_pool"):
		coin.call("reset_for_pool", pos)

	coin.visible = true
	coin.set_physics_process(true)
	if "monitoring" in coin:
		coin.set_deferred("monitoring", true)
	if "monitorable" in coin:
		coin.set_deferred("monitorable", true)
	var col_shape = coin.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col_shape != null:
		col_shape.set_deferred("disabled", false)
	if not coin.is_in_group("coins"):
		coin.add_to_group("coins")
	return coin


func recycle_coin(coin: Node3D) -> void:
	if not is_instance_valid(coin):
		return
	coin.visible = false
	coin.set_physics_process(false)
	if "monitoring" in coin:
		coin.set_deferred("monitoring", false)
	if "monitorable" in coin:
		coin.set_deferred("monitorable", false)
	var col_shape = coin.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col_shape != null:
		col_shape.set_deferred("disabled", true)
	if coin.is_in_group("coins"):
		coin.remove_from_group("coins")

	call_deferred("_finalize_coin_recycle", coin)


func _finalize_coin_recycle(coin: Node3D) -> void:
	if not is_instance_valid(coin):
		return
	if coin_container != null and coin.get_parent() != coin_container:
		if coin.get_parent() != null:
			coin.get_parent().remove_child(coin)
		coin_container.add_child(coin)
	coin.global_position = Vector3(0, -200, 0)
