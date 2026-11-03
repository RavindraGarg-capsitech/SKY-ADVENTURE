extends Area3D

## Bullet3D: High-performance projectile with safe deferred physics property management,
## double-hit prevention, and zero-allocation object pooling compatibility.

@export var damage: int = 1
@export var RANGE: float = 40.0
@export var speed: float = 50.0
@export var impact_effect_type: String = "default"

const DEFAULT_SPEED: float = 50.0

var travelled_distance: float = 0.0
var is_active: bool = true
var is_ready_for_pool: bool = true
var _is_recycling: bool = false


func _ready() -> void:
	if not is_in_group("bullets"):
		add_to_group("bullets")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


func configure_projectile(dmg: int, rng: float, spd: float = 50.0, p_scale: float = 1.0, col: Color = Color.ORANGE, impact_type: String = "default") -> void:
	damage = dmg
	RANGE = rng
	speed = spd
	scale = Vector3.ONE * p_scale
	impact_effect_type = impact_type
	travelled_distance = 0.0
	is_active = true
	_is_recycling = false
	is_ready_for_pool = false

	# Projectile light configuration
	var gm = get_node_or_null("/root/GraphicsManager") if is_inside_tree() else null
	var allow_lights = true
	if gm != null and gm.current_quality == "low":
		allow_lights = false

	var omni = get_node_or_null("OmniLight3D") as OmniLight3D
	if allow_lights:
		if omni == null:
			omni = OmniLight3D.new()
			omni.name = "OmniLight3D"
			add_child(omni)
		omni.visible = true
		omni.light_color = col
		omni.light_energy = 2.0 * p_scale
		omni.omni_range = 3.5 * p_scale
	elif omni != null:
		omni.visible = false


func _physics_process(delta: float) -> void:
	if not is_active or _is_recycling:
		return

	var move_spd = speed if speed > 0.0 else DEFAULT_SPEED
	var movement: Vector3 = -global_basis.z * move_spd * delta
	global_position += movement
	travelled_distance += movement.length()

	if travelled_distance >= RANGE:
		deactivate()


func _on_body_entered(body: Node3D) -> void:
	_handle_impact(body)


func _on_area_entered(area: Area3D) -> void:
	_handle_impact(area)


func _handle_impact(collider: Node) -> void:
	# 1. Immediate logical lock to block any duplicate collisions or damage on this frame
	if not is_active or _is_recycling:
		return
	is_active = false
	_is_recycling = true

	# 2. Apply damage to target mob if applicable
	if collider != null and collider.is_in_group("mobs") and collider.has_method("play_hurt"):
		collider.play_hurt(damage)

	# 3. Create impact VFX
	if impact_effect_type == "heavy":
		_create_heavy_impact()

	# 4. Safely return to pool
	deactivate()


func deactivate() -> void:
	is_active = false
	_is_recycling = true
	visible = false
	set_physics_process(false)
	travelled_distance = 0.0

	var pm = get_node_or_null("/root/PoolManager")
	if pm != null and pm.has_method("recycle_bullet"):
		pm.recycle_bullet(self)
	else:
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		var col = get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col != null:
			col.set_deferred("disabled", true)
		queue_free()


func _create_heavy_impact() -> void:
	var pm = get_node_or_null("/root/PoolManager")
	if pm != null and pm.has_method("spawn_poof"):
		pm.spawn_poof(global_position, 1.8)
	else:
		const SMOKE_PUFF = preload("uid://cjk3frr43yesb")
		var poof = SMOKE_PUFF.instantiate()
		var target = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
		target.add_child(poof)
		poof.global_position = global_position
		poof.scale = Vector3.ONE * 1.8
