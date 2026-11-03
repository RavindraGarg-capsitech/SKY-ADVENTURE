extends Area3D

## Collectible Coin Pickup: Visually bright gold coin with bobbing, rotation, light, and magnetic attraction.
## Supports zero-allocation object pooling via PoolManager and mobile lighting optimization.

@export var coin_value: int = 1
@export var skip_ground_raycast: bool = false

var player: Node3D = null
var is_collected: bool = false
var move_speed: float = 0.0
var base_y: float = 0.0
var bob_time: float = 0.0
var collect_tween: Tween = null
var is_pooled: bool = false

@onready var coin_visual: Node3D = $CoinVisual
@onready var sparkle: MeshInstance3D = $Sparkle
@onready var omni_light: OmniLight3D = get_node_or_null("OmniLight3D")
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	base_y = position.y
	bob_time = randf() * TAU
	_apply_mobile_light_optimization()
	if not skip_ground_raycast:
		_ensure_above_ground()
	_find_player()


func _apply_mobile_light_optimization() -> void:
	if omni_light == null:
		return
	var gm = get_node_or_null("/root/GraphicsManager")
	var is_mobile = OS.has_feature("mobile") or OS.get_name() in ["Android", "iOS"]
	# On mobile or Low/Medium quality, disable omni lights on pickups to save GPU fill rate & light clustering
	if is_mobile or (gm != null and gm.current_quality != "high"):
		omni_light.visible = false
	else:
		omni_light.visible = true


func reset_for_pool(new_pos: Vector3) -> void:
	is_pooled = true
	is_collected = false
	move_speed = 0.0
	global_position = new_pos
	base_y = new_pos.y
	bob_time = randf() * TAU
	scale = Vector3.ONE
	visible = true

	if coin_visual != null:
		coin_visual.rotation = Vector3.ZERO
		coin_visual.scale = Vector3.ONE

	if sparkle != null:
		sparkle.rotation = Vector3.ZERO
		sparkle.scale = Vector3.ONE

	_apply_mobile_light_optimization()

	if collision_shape != null:
		collision_shape.disabled = false
	monitoring = true
	monitorable = true


func _ensure_above_ground() -> void:
	var current_scene = get_tree().current_scene
	if current_scene is Node3D and current_scene.get_world_3d() != null:
		var space_state = current_scene.get_world_3d().direct_space_state
		var ray_start = Vector3(global_position.x, global_position.y + 2.0, global_position.z)
		var ray_end = Vector3(global_position.x, global_position.y - 4.0, global_position.z)
		var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end, 1)
		var hit = space_state.intersect_ray(query)
		if not hit.is_empty() and hit.has("position"):
			var min_allowed_y = hit.position.y + 0.85
			if global_position.y < min_allowed_y:
				global_position.y = min_allowed_y
				base_y = position.y


func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Node3D


func _physics_process(delta: float) -> void:
	if is_collected or not visible:
		return

	# Smooth rotation and bobbing
	if coin_visual != null:
		coin_visual.rotate_y(3.5 * delta)

	if sparkle != null:
		sparkle.rotate_y(-5.0 * delta)
		sparkle.rotate_z(2.5 * delta)

	bob_time += delta * 3.2
	position.y = base_y + sin(bob_time) * 0.16

	if not is_instance_valid(player):
		_find_player()
		return

	# Check magnet radius from player
	var target_pos: Vector3 = player.global_position + Vector3.UP * 0.8
	var to_player: Vector3 = target_pos - global_position
	var dist: float = to_player.length()

	var magnet_range: float = 4.5
	if "magnet_radius" in player:
		magnet_range = player.magnet_radius

	if dist <= magnet_range:
		move_speed = move_toward(move_speed, 20.0, 35.0 * delta)
		global_position += to_player.normalized() * move_speed * delta
		base_y = position.y


func _on_body_entered(body: Node3D) -> void:
	if is_collected:
		return

	if body.is_in_group("player"):
		collect()


func collect() -> void:
	if is_collected:
		return

	is_collected = true
	# Immediately disable collision & detection to prevent duplicate triggers
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)

	var am = get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("play_coin_sound"):
		am.play_coin_sound()

	var rm = get_tree().get_first_node_in_group("reward_manager")
	if rm != null and rm.has_method("add_coins"):
		rm.add_coins(coin_value)

	# Polish Collection Animation:
	# 1. Rise quickly upward by ~1.2m
	# 2. Spin rapidly around Y-axis (2 full rotations = TAU * 2)
	# 3. Smoothly scale down to 0
	# 4. Quick total duration (~0.4s)
	var target_pos: Vector3 = global_position + Vector3.UP * 1.25
	collect_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	collect_tween.tween_property(self, "global_position", target_pos, 0.4)
	if coin_visual != null:
		collect_tween.tween_property(coin_visual, "rotation:y", coin_visual.rotation.y + TAU * 2.0, 0.4)
	collect_tween.tween_property(self, "scale", Vector3.ZERO, 0.4)

	if omni_light != null and omni_light.visible:
		omni_light.light_energy = 3.5
		collect_tween.tween_property(omni_light, "light_energy", 0.0, 0.4)

	if sparkle != null:
		collect_tween.tween_property(sparkle, "scale", sparkle.scale * 2.0, 0.2)
		collect_tween.tween_property(sparkle, "scale", Vector3.ZERO, 0.2).set_delay(0.2)

	collect_tween.chain().tween_callback(self._on_collect_finished)


func _on_collect_finished() -> void:
	var pm = get_node_or_null("/root/PoolManager")
	if is_pooled and pm != null and pm.has_method("recycle_coin"):
		pm.recycle_coin(self)
	else:
		queue_free()
