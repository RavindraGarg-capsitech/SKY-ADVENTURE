
extends Area3D

@export var damage: int = 1

const SPEED: float = 50.0
const RANGE: float = 40.0

var travelled_distance: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	var movement: Vector3 = -global_basis.z * SPEED * delta
	global_position += movement
	travelled_distance += movement.length()

	if travelled_distance >= RANGE:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("mobs") and body.has_method("play_hurt"):
		body.play_hurt(damage)

	queue_free()
