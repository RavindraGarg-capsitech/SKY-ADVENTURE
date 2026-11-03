extends Node

## PoolManager: Zero-allocation pooling system for bullets and particle effects.

const BULLET_SCENE = preload("uid://db2jr0d33yyi6")
const SMOKE_PUFF_SCENE = preload("uid://cjk3frr43yesb")

const BULLET_POOL_SIZE: int = 30
const POOF_POOL_SIZE: int = 8

var bullet_pool: Array[Node3D] = []
var poof_pool: Array[Node3D] = []

var bullet_container: Node3D = null
var poof_container: Node3D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_pools()


func _init_pools() -> void:
	if bullet_container != null:
		return

	bullet_container = Node3D.new()
	bullet_container.name = "BulletPool"
	add_child(bullet_container)

	poof_container = Node3D.new()
	poof_container.name = "PoofPool"
	add_child(poof_container)

	for i in range(BULLET_POOL_SIZE):
		var b = BULLET_SCENE.instantiate() as Area3D
		bullet_container.add_child(b)
		b.visible = false
		b.set_physics_process(false)
		b.monitoring = false
		b.monitorable = false
		if b.is_in_group("bullets"):
			b.remove_from_group("bullets")
		bullet_pool.append(b)

	for i in range(POOF_POOL_SIZE):
		var p = SMOKE_PUFF_SCENE.instantiate() as Node3D
		poof_container.add_child(p)
		p.visible = false
		poof_pool.append(p)


func spawn_bullet(pos: Vector3, bullet_basis: Basis, dmg: int, rng: float, spd: float, p_scale: float, col: Color, impact_type: String) -> Node3D:
	var bullet: Node3D = null
	for b in bullet_pool:
		if is_instance_valid(b) and not b.visible:
			bullet = b
			break

	if bullet == null:
		# Fallback if pool is exhausted: allocate new instance
		bullet = BULLET_SCENE.instantiate() as Node3D
		if bullet_container != null:
			bullet_container.add_child(bullet)
		else:
			add_child(bullet)
		bullet_pool.append(bullet)

	bullet.global_transform = Transform3D(bullet_basis, pos)
	if bullet.has_method("configure_projectile"):
		bullet.call("configure_projectile", dmg, rng, spd, p_scale, col, impact_type)
	bullet.visible = true
	bullet.set_physics_process(true)
	if "monitoring" in bullet:
		bullet.monitoring = true
	if "monitorable" in bullet:
		bullet.monitorable = true
	if not bullet.is_in_group("bullets"):
		bullet.add_to_group("bullets")
	return bullet


func recycle_bullet(bullet: Node3D) -> void:
	if not is_instance_valid(bullet):
		return
	bullet.visible = false
	bullet.set_physics_process(false)
	if "monitoring" in bullet:
		bullet.monitoring = false
	if "monitorable" in bullet:
		bullet.monitorable = false
	if bullet.is_in_group("bullets"):
		bullet.remove_from_group("bullets")
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

	# Auto-hide and return to pool after duration
	get_tree().create_timer(0.6).timeout.connect(func():
		if is_instance_valid(poof):
			poof.visible = false
	)
	return poof
