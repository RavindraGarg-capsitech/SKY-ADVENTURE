extends Area3D

## Collectible Energy Shield Pickup.
## Grants 10 seconds of invulnerability when collected.

@export var shield_duration: float = 10.0
var player: Node3D = null
var is_collected: bool = false
var move_speed: float = 0.0


func _ready() -> void:
	if not is_in_group("shield_pickups"):
		add_to_group("shield_pickups")
	body_entered.connect(_on_body_entered)
	_find_player()


func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Node3D


func _physics_process(delta: float) -> void:
	if is_collected:
		return

	# Gentle spin & hover bob
	rotate_y(3.0 * delta)

	if not is_instance_valid(player):
		_find_player()
		return

	var to_player: Vector3 = player.global_position + Vector3.UP * 0.8 - global_position
	var dist: float = to_player.length()

	var magnet_range: float = 4.0
	if "magnet_radius" in player:
		magnet_range = player.magnet_radius

	if dist <= magnet_range:
		move_speed = move_toward(move_speed, 18.0, 32.0 * delta)
		global_position += to_player.normalized() * move_speed * delta


func _on_body_entered(body: Node3D) -> void:
	if is_collected:
		return

	if body.is_in_group("player"):
		is_collected = true
		if body.has_method("activate_shield"):
			body.activate_shield(shield_duration)
		queue_free()
