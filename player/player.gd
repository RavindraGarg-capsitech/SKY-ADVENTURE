
extends CharacterBody3D

signal health_changed(current_health: int, max_health: int)
signal player_died
signal weapon_changed(weapon_id: String, weapon_name: String, weapon_info: String, icon: String)
signal shield_activated(duration: float)
signal shield_updated(time_left: float, max_duration: float)
signal shield_expired

@export var max_health: int = 100
@export var current_health: int = 100

@export var bullet_damage: int = 1
@export var multishot_count: int = 1
@export var bullet_range: float = 40.0
@export var shoot_cooldown: float = 0.20
@export var magnet_radius: float = 4.0

var mouse_sensitivity_factor: float = 1.0
var is_dead: bool = false

# --- Energy Shield System ---
var is_shield_active: bool = false
var shield_duration: float = 10.0
var shield_time_left: float = 0.0
@onready var shield_sphere: Node3D = get_node_or_null("ShieldSphere")

# --- Weapon System ---
const WEAPONS: Dictionary = {
	"default": {
		"id": "default",
		"name": "Standard Blaster",
		"info": "1x DMG • Semi-Auto • Keys [1-5] / [Q] to Switch",
		"icon": "🔫",
		"damage": 1,
		"cooldown": 0.20,
		"range": 40.0,
		"speed": 50.0,
		"multishot": 1,
		"spread_angles": [0.0],
		"scale": 1.0,
		"color": Color(1.0, 0.75, 0.1),
		"impact": "default"
	},
	"plasma": {
		"id": "plasma",
		"name": "Plasma Gun",
		"info": "3x DMG • High-Energy • Slower Fire",
		"icon": "⚡",
		"damage": 3,
		"cooldown": 0.38,
		"range": 50.0,
		"speed": 60.0,
		"multishot": 1,
		"spread_angles": [0.0],
		"scale": 1.35,
		"color": Color(0.15, 0.85, 1.0),
		"impact": "default"
	},
	"triple": {
		"id": "triple",
		"name": "Triple Shot",
		"info": "3x Bullets • Spread Formation",
		"icon": "🔱",
		"damage": 1,
		"cooldown": 0.26,
		"range": 40.0,
		"speed": 50.0,
		"multishot": 3,
		"spread_angles": [-0.10, 0.0, 0.10],
		"scale": 1.0,
		"color": Color(0.2, 1.0, 0.4),
		"impact": "default"
	},
	"cannon": {
		"id": "cannon",
		"name": "Heavy Cannon",
		"info": "6x DMG • Artillery Shell • High Impact",
		"icon": "💥",
		"damage": 6,
		"cooldown": 0.75,
		"range": 45.0,
		"speed": 40.0,
		"multishot": 1,
		"spread_angles": [0.0],
		"scale": 2.2,
		"color": Color(1.0, 0.25, 0.1),
		"impact": "heavy"
	},
	"rapid": {
		"id": "rapid",
		"name": "Rapid Blaster",
		"info": "Rapid Fire • 0.08s Cooldown • Fast Bullet",
		"icon": "⚡",
		"damage": 1,
		"cooldown": 0.08,
		"range": 35.0,
		"speed": 55.0,
		"multishot": 1,
		"spread_angles": [0.0],
		"scale": 0.85,
		"color": Color(0.9, 0.25, 1.0),
		"impact": "default"
	}
}

var unlocked_weapons: Array[String] = ["default"]
var current_weapon_id: String = "default"

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

	if get_node_or_null("/root/SaveManager") != null:
		mouse_sensitivity_factor = SaveManager.mouse_sensitivity

	if shield_sphere == null:
		shield_sphere = get_node_or_null("ShieldSphere")
	if shield_sphere != null:
		shield_sphere.visible = false

	var wdata = get_current_weapon_data()
	weapon_changed.emit(current_weapon_id, wdata["name"], wdata["info"], wdata["icon"])


func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return

	# Keyboard weapon switching
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			equip_weapon("default")
		elif event.keycode == KEY_2:
			equip_weapon("plasma")
		elif event.keycode == KEY_3:
			equip_weapon("triple")
		elif event.keycode == KEY_4:
			equip_weapon("cannon")
		elif event.keycode == KEY_5:
			equip_weapon("rapid")
		elif event.keycode == KEY_Q:
			cycle_weapon()

	# PC mouse camera rotation
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			_rotate_camera(event.relative)

	# Capture mouse on left click
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _rotate_camera(relative: Vector2) -> void:
	var sens: float = MOUSE_SENSITIVITY * mouse_sensitivity_factor
	rotation_degrees.y -= relative.x * sens

	%Camera3D.rotation_degrees.x -= (
		relative.y * LOOK_SENSITIVITY * mouse_sensitivity_factor
	)

	%Camera3D.rotation_degrees.x = clampf(
		%Camera3D.rotation_degrees.x,
		-60.0,
		60.0
	)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Update shield countdown if active
	if is_shield_active:
		shield_time_left -= delta
		shield_updated.emit(shield_time_left, shield_duration)
		if shield_time_left <= 0.0:
			deactivate_shield()

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


func get_current_weapon_data() -> Dictionary:
	return WEAPONS.get(current_weapon_id, WEAPONS["default"])


func unlock_weapon(weapon_id: String) -> void:
	if not weapon_id in unlocked_weapons:
		unlocked_weapons.append(weapon_id)
	equip_weapon(weapon_id)


func equip_weapon(weapon_id: String) -> bool:
	if not weapon_id in unlocked_weapons:
		return false
	if not WEAPONS.has(weapon_id):
		return false

	current_weapon_id = weapon_id
	var wdata = get_current_weapon_data()
	weapon_changed.emit(current_weapon_id, wdata["name"], wdata["info"], wdata["icon"])
	return true


func cycle_weapon() -> void:
	if unlocked_weapons.is_empty():
		return
	var idx = unlocked_weapons.find(current_weapon_id)
	var next_idx = (idx + 1) % unlocked_weapons.size()
	equip_weapon(unlocked_weapons[next_idx])


func activate_shield(duration: float = 10.0) -> bool:
	if is_shield_active:
		# Prevent repeated activation while shield is already active
		return false

	is_shield_active = true
	shield_duration = duration
	shield_time_left = duration
	if shield_sphere == null:
		shield_sphere = get_node_or_null("ShieldSphere")
	if shield_sphere != null:
		shield_sphere.visible = true

	shield_activated.emit(duration)
	return true


func deactivate_shield() -> void:
	is_shield_active = false
	shield_time_left = 0.0
	if shield_sphere != null:
		shield_sphere.visible = false
	shield_expired.emit()


func shoot_bullet() -> void:
	if is_dead:
		return
	const BULLET_3D = preload("uid://db2jr0d33yyi6")

	var wdata: Dictionary = get_current_weapon_data()
	var weapon_multishot: int = int(wdata.get("multishot", 1))
	var effective_multishot: int = weapon_multishot
	if multishot_count > 1 and weapon_multishot == 1:
		effective_multishot = multishot_count

	var angles: Array = []
	if wdata.has("spread_angles") and wdata["spread_angles"].size() > 1:
		angles = wdata["spread_angles"].duplicate()
	else:
		match effective_multishot:
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

	var bonus_dmg = max(0, bullet_damage - 1)
	var final_damage = int(wdata.get("damage", 1)) + bonus_dmg
	var final_range = float(wdata.get("range", 40.0)) + max(0.0, bullet_range - 40.0)
	var final_speed = float(wdata.get("speed", 50.0))
	var p_scale = float(wdata.get("scale", 1.0))
	var p_color = wdata.get("color", Color.ORANGE)
	var impact_type = String(wdata.get("impact", "default"))

	for angle in angles:
		var new_bullet: Node3D = BULLET_3D.instantiate() as Node3D
		get_tree().current_scene.add_child(new_bullet)
		new_bullet.global_position = muzzle_pos

		var rotated_basis: Basis = muzzle_basis.rotated(muzzle_basis.y, angle)
		new_bullet.global_basis = rotated_basis

		if new_bullet.has_method("configure_projectile"):
			new_bullet.configure_projectile(final_damage, final_range, final_speed, p_scale, p_color, impact_type)
		else:
			if "damage" in new_bullet:
				new_bullet.damage = final_damage
			if "RANGE" in new_bullet:
				new_bullet.RANGE = final_range

	var cooldown_factor = shoot_cooldown / 0.20
	var final_cooldown = maxf(0.04, float(wdata.get("cooldown", 0.20)) * cooldown_factor)
	%Timer.wait_time = final_cooldown
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

	if is_shield_active:
		# Energy Shield completely absorbs all incoming damage!
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
