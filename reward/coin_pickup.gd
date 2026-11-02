extends Area3D

## Collectible Coin Pickup: Visually bright gold coin with bobbing, rotation, light, and magnetic attraction.

@export var coin_value: int = 1

var player: Node3D = null
var is_collected: bool = false
var move_speed: float = 0.0
var base_y: float = 0.0
var bob_time: float = 0.0

@onready var coin_visual: Node3D = $CoinVisual
@onready var sparkle: MeshInstance3D = $Sparkle


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	base_y = position.y
	bob_time = randf() * TAU
	_find_player()


func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Node3D


func _physics_process(delta: float) -> void:
	if is_collected:
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
	set_deferred("monitoring", false)

	if get_node_or_null("/root/AudioManager") != null:
		AudioManager.play_coin_sound()

	var rm = get_tree().get_first_node_in_group("reward_manager")
	if rm != null and rm.has_method("add_coins"):
		rm.add_coins(coin_value)

	# Visual collection pop & burst
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", scale * 1.5, 0.16)
	tween.tween_property(self, "position:y", position.y + 0.5, 0.16)
	tween.chain().tween_callback(queue_free)
