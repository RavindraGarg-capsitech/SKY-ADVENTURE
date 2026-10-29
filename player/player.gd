extends CharacterBody3D

const SPEED: float = 5.5
const GRAVITY: float = 20.0
const JUMP_VELOCITY: float = 10.0
const MOUSE_SENSITIVITY: float = 0.5
const LOOK_SENSITIVITY: float = 0.2
const GYRO_SENSITIVITY: float = 2.0

var mobile_jump_requested: bool = false
var gyro_available: bool = false

@onready var mobile_joystick: Control = \
	get_tree().current_scene.get_node_or_null("MobileUI/Joystick")

@onready var mobile_ui: CanvasLayer = \
	get_tree().current_scene.get_node_or_null("MobileUI")


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if mobile_joystick != null:
		if mobile_joystick.has_signal("jump_requested"):
			mobile_joystick.jump_requested.connect(
				_on_mobile_jump_requested
			)


func _on_mobile_jump_requested() -> void:
	mobile_jump_requested = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return

	# PC mouse camera rotation only
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			_rotate_camera(event.relative)


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


func _update_gyroscope(delta: float) -> void:
	var gyro: Vector3 = Input.get_gyroscope()

	# Horizontal rotation
	rotation_degrees.y -= (
		rad_to_deg(gyro.y) * GYRO_SENSITIVITY * delta
	)

	# Vertical rotation
	%Camera3D.rotation_degrees.x -= (
		rad_to_deg(gyro.x) * GYRO_SENSITIVITY * delta
	)

	%Camera3D.rotation_degrees.x = clampf(
		%Camera3D.rotation_degrees.x,
		-60.0,
		60.0
	)


func _physics_process(delta: float) -> void:
	# Gyroscope: mobile only
	if OS.has_feature("mobile"):
		_update_gyroscope(delta)

	# Keyboard movement
	var input_direction: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)

	# Joystick movement
	if mobile_joystick != null:
		var stick_value: Vector2 = mobile_joystick.input_vector

		if stick_value.length() > 0.1:
			input_direction = stick_value

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

	# Jump
	if (
		Input.is_action_just_pressed("jump")
		or mobile_jump_requested
	):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY

	elif (
		Input.is_action_just_released("jump")
		and velocity.y > 0.0
	):
		velocity.y = 0.0

	mobile_jump_requested = false

	move_and_slide()

	if is_on_floor() and velocity.y > 0.0:
		velocity.y = 0.0

	# SHOOTING
	# PC: keyboard/mouse action
	# Mobile: Shoot button only
	var shoot_pressed: bool = false

	if OS.has_feature("mobile"):
		if mobile_ui != null:
			shoot_pressed = mobile_ui.shoot_held
	else:
		shoot_pressed = Input.is_action_pressed("shoot")

	if shoot_pressed and %Timer.is_stopped():
		shoot_bullet()


func shoot_bullet() -> void:
	const BULLET_3D = preload("uid://db2jr0d33yyi6")

	var new_bullet: Node3D = BULLET_3D.instantiate()
	get_tree().current_scene.add_child(new_bullet)

	new_bullet.global_position = %Marker3D.global_position
	new_bullet.global_basis = %Marker3D.global_basis.orthonormalized()

	%Timer.start()
	%AudioStreamPlayer.play()
