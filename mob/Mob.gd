
extends RigidBody3D

signal died

@export var speed: float = 3.0
@export var stop_distance: float = 1.5

var health: int = 3
var is_dead: bool = false

@onready var animation_player: AnimationPlayer = \
	$CollisionShape3D/bat_model/AnimationPlayer

@onready var bat_model: Node3D = \
	$CollisionShape3D/bat_model

@onready var player: Node3D = \
	get_tree().current_scene.get_node_or_null("Player")

@onready var timer: Timer = %Timer
@onready var ko_sound: AudioStreamPlayer3D = %KOSound
@onready var hurt_sound: AudioStreamPlayer3D = %HurtSound


func _ready() -> void:
	lock_rotation = true
	can_sleep = false

	# Stop physical impulses from moving the bat vertically.


	if player == null:
		push_error("Player not found! Check the Player node path.")
		return

	if not animation_player.animation_finished.is_connected(
		_on_animation_player_animation_finished
	):
		animation_player.animation_finished.connect(
			_on_animation_player_animation_finished
		)

	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)

	animation_player.play("Idle")


func _physics_process(_delta: float) -> void:
	if player == null or is_dead:
		return

	var direction: Vector3 = player.global_position - global_position
	direction.y = 0.0

	var distance: float = direction.length()

	if distance <= stop_distance:
		linear_velocity.x = 0.0
		linear_velocity.z = 0.0
	else:
		direction = direction.normalized()
		linear_velocity.x = direction.x * speed
		linear_velocity.z = direction.z * speed
	# Prevent upward movement while allowing horizontal collision.
	if linear_velocity.y > 0.0:
		linear_velocity.y = 0.0
	angular_velocity = Vector3.ZERO

	if distance > 0.01:
		var target_position := Vector3(
			player.global_position.x,
			bat_model.global_position.y,
			player.global_position.z
		)

		bat_model.look_at(target_position, Vector3.UP)
		bat_model.rotate_y(PI)


func play_hurt() -> void:
	if is_dead or health <= 0:
		return

	health -= 1
	hurt_sound.play()

	if health <= 0:
		is_dead = true
		set_physics_process(false)

		# Allow rotation and gravity for the death effect.
		axis_lock_linear_y = false
		lock_rotation = false
		gravity_scale = 1.0
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO

		if player != null:
			var knockback_direction: Vector3 = \
				global_position - player.global_position

			knockback_direction.y = 0.0

			if knockback_direction.length_squared() > 0.001:
				knockback_direction = knockback_direction.normalized()
			else:
				knockback_direction = Vector3.BACK

			apply_central_impulse(
				knockback_direction * 5.0 + Vector3.UP * 2.0
			)

		# Rotate around Y, not Z.
		apply_torque_impulse(Vector3(0.0, 10.0, 0.0))

		ko_sound.play()
		timer.start()
		return

	if animation_player.has_animation("Custom/hurt"):
		animation_player.play("Custom/hurt")
	elif animation_player.has_animation("hurt"):
		animation_player.play("hurt")
	else:
		push_warning("Hurt animation not found!")


func _on_animation_player_animation_finished(
	anim_name: StringName
) -> void:
	if (
		anim_name == &"Custom/hurt"
		or anim_name == &"hurt"
	):
		if health > 0 and not is_dead:
			animation_player.play("Idle")


func _on_timer_timeout() -> void:
	if is_dead:
		died.emit()
		queue_free()
