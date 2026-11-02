
extends CharacterBody3D

signal health_changed(current_health: int, max_health: int)
signal player_died

@export var max_health: int = 100
@export var current_health: int = 100

@export var bullet_damage: int = 1
@export var multishot_count: int = 1
@export var bullet_range: float = 40.0
@export var shoot_cooldown: float = 0.20
@export var magnet_radius: float = 4.0

var is_dead: bool = false

const SPEED: float = 5.5
const GRAVITY: float = 20.0
const JUMP_VELOCITY: float = 10.0
const MOUSE_SENSITIVITY: float = 0.5
const LOOK_SENSITIVITY: float = 0.2

func _ready() -> void:
	if not is_in_group("player"):
		add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	current_health = max_health
	health_changed.emit(current_health, max_health)


func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return

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
	if is_dead:
		return

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
	if is_dead:
		return
	const BULLET_3D = preload("uid://db2jr0d33yyi6")

	var angles: Array[float] = []
	match multishot_count:
		1:
			angles = [0.0]
		2:
			angles = [-0.06, 0.06]
		3:
			angles = [-0.10, 0.0, 0.10]
		4:
			angles = [-0.14, -0.05, 0.05, 0.14]
		_:
			angles = [-0.18, -0.09, 0.0, 0.09, 0.18]

	var muzzle_basis: Basis = %Marker3D.global_basis.orthonormalized()
	var muzzle_pos: Vector3 = %Marker3D.global_position

	for angle in angles:
		var new_bullet: Node3D = BULLET_3D.instantiate() as Node3D
		get_tree().current_scene.add_child(new_bullet)
		new_bullet.global_position = muzzle_pos

		var rotated_basis: Basis = muzzle_basis.rotated(muzzle_basis.y, angle)
		new_bullet.global_basis = rotated_basis

		if "damage" in new_bullet:
			new_bullet.damage = bullet_damage
		if "RANGE" in new_bullet:
			new_bullet.RANGE = bullet_range

	%Timer.wait_time = shoot_cooldown
	%Timer.start()
	%AudioStreamPlayer.play()


func apply_upgrade(upgrade_id: String) -> void:
	match upgrade_id:
		"rapid_fire":
			shoot_cooldown = maxf(0.08, shoot_cooldown * 0.8)
		"multishot":
			multishot_count = mini(5, multishot_count + 1)
		"heavy_shot":
			bullet_damage += 1
		"increased_range":
			bullet_range += 15.0
		"magnetism":
			magnet_radius += 3.5
		"health_upgrade":
			max_health += 25
			heal(25)


func take_damage(amount: int) -> void:
	if is_dead or amount <= 0:
		return

	current_health = clampi(current_health - amount, 0, max_health)
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		die()


func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return

	current_health = clampi(current_health + amount, 0, max_health)
	health_changed.emit(current_health, max_health)


func die() -> void:
	if is_dead:
		return

	is_dead = true
	velocity = Vector3.ZERO
	set_physics_process(false)
	set_process_unhandled_input(false)
	if has_node("%Timer"):
		%Timer.stop()

	player_died.emit()

	var rm = get_tree().get_first_node_in_group("reward_manager")
	var wm = get_tree().get_first_node_in_group("wave_manager")
	var coins = rm.coins if rm != null and "coins" in rm else 0
	var wave = wm.current_wave if wm != null and "current_wave" in wm else 1
	if get_node_or_null("/root/SaveManager") != null:
		SaveManager.bank_run_results(wave, coins, coins * 10)

	if wm != null and wm.has_method("abort_wave_transition"):
		wm.abort_wave_transition()

	var modal = get_tree().get_first_node_in_group("upgrade_modal")
	if modal != null and modal.has_method("hide_modal"):
		modal.hide_modal()

	var hud = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("hide_all_banners"):
		hud.hide_all_banners()

	if get_node_or_null("/root/GameManager") != null:
		GameManager.change_state(GameManager.GameState.GAME_OVER)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var go_modal = get_tree().get_first_node_in_group("game_over_modal")
	if go_modal != null and go_modal.has_method("show_game_over"):
		go_modal.show_game_over()
