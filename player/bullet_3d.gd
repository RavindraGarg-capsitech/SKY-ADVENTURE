
extends Area3D

@export var damage: int = 1
@export var RANGE: float = 40.0
@export var speed: float = 50.0
@export var impact_effect_type: String = "default"

const DEFAULT_SPEED: float = 50.0

var travelled_distance: float = 0.0


func _ready() -> void:
	if not is_in_group("bullets"):
		add_to_group("bullets")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func configure_projectile(dmg: int, rng: float, spd: float = 50.0, p_scale: float = 1.0, col: Color = Color.ORANGE, impact_type: String = "default") -> void:
	damage = dmg
	RANGE = rng
	speed = spd
	scale = Vector3.ONE * p_scale
	impact_effect_type = impact_type
	travelled_distance = 0.0

	# Add glowing projectile light matching weapon color (disabled on Low mobile quality)
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
	var move_spd = speed if speed > 0.0 else DEFAULT_SPEED
	var movement: Vector3 = -global_basis.z * move_spd * delta
	global_position += movement
	travelled_distance += movement.length()

	if travelled_distance >= RANGE:
		deactivate()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("mobs") and body.has_method("play_hurt"):
		body.play_hurt(damage)

	if impact_effect_type == "heavy":
		_create_heavy_impact()

	deactivate()


func deactivate() -> void:
	travelled_distance = 0.0
	var pm = get_node_or_null("/root/PoolManager")
	if pm != null and pm.has_method("recycle_bullet"):
		pm.recycle_bullet(self)
	else:
		queue_free()


func _create_heavy_impact() -> void:
	# Heavy impact burst using PoolManager
	var pm = get_node_or_null("/root/PoolManager")
	if pm != null and pm.has_method("spawn_poof"):
		pm.spawn_poof(global_position, 1.8)
	else:
		const SMOKE_PUFF = preload("uid://cjk3frr43yesb")
		var poof = SMOKE_PUFF.instantiate()
		get_tree().current_scene.add_child(poof)
		poof.global_position = global_position
		poof.scale = Vector3.ONE * 1.8
