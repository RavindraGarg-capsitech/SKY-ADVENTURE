extends Area3D

@export var speed: float = 16.0
@export var damage: int = 15
@export var max_range: float = 45.0

var travelled_distance: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	var movement: Vector3 = -global_basis.z * speed * delta
	global_position += movement
	travelled_distance += movement.length()

	if travelled_distance >= max_range:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("mobs"):
		return

	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)

	queue_free()
