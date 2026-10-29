
extends CharacterBody3D

const SPEED: float = 5.5
const GRAVITY: float = 20.0
const JUMP_VELOCITY: float = 10.0
const MOUSE_SENSITIVITY: float = 0.5
const LOOK_SENSITIVITY: float = 0.2

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return

	# PC mouse camera rotation
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			_rotate_camera(event.relative)

	# Capture mouse on left click
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _rotate_camera(relative: Vector2) -> void:
	rotation_degrees.y -= relative.x * MOUSE_SENSITIVITY

	%Camera3D.rotation_degrees.x -= (
		relative.y * LOOK_SENSITIVITY
	)

	%Camera3D.rotation_degrees.x = clampf(
		%Camera3D.rotation_degrees.x,
		-60.0,
		60.0
	)


func _physics_process(delta: float) -> void:
	# Keyboard movement
	var input_direction: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)

	var direction: Vector3 = transform.basis * Vector3(
		input_direction.x,
		0.0,
		input_direction.y
	)

	direction.y = 0.0
	direction = direction.normalized()

	if direction.length_squared() > 0.0:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Keyboard jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	elif (
		Input.is_action_just_released("jump")
		and velocity.y > 0.0
	):
		velocity.y = 0.0

	move_and_slide()

	if is_on_floor() and velocity.y > 0.0:
		velocity.y = 0.0

	# PC shooting
	if Input.is_action_pressed("shoot") and %Timer.is_stopped():
		shoot_bullet()


func shoot_bullet() -> void:
	const BULLET_3D = preload("uid://db2jr0d33yyi6")

	var new_bullet: Node3D = BULLET_3D.instantiate()
	get_tree().current_scene.add_child(new_bullet)

	new_bullet.global_position = %Marker3D.global_position
	new_bullet.global_basis = %Marker3D.global_basis.orthonormalized()

	%Timer.start()
	%AudioStreamPlayer.play()
