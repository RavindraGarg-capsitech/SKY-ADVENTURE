
extends RigidBody3D

signal died

@export var speed: float = 3.0
@export var stop_distance: float = 1.5
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.0
@export var health: int = 3
@export var max_health: int = 3

@export var enemy_type_name: String = "Standard Bat"
@export var enemy_color_tint: Color = Color.WHITE
@export var enemy_emissive_tint: Color = Color.BLACK
@export var enemy_emissive_energy: float = 0.0
@export var enemy_metallic: float = 0.0
@export var enemy_roughness: float = 0.42

var is_dead: bool = false
var attack_timer: float = 0.0

@onready var animation_player: AnimationPlayer = \
	$CollisionShape3D/bat_model/AnimationPlayer

@onready var bat_model: Node3D = \
	$CollisionShape3D/bat_model

var player: Node3D = null
var death_position_recorded: Vector3 = Vector3.ZERO

@onready var timer: Timer = %Timer
@onready var ko_sound: AudioStreamPlayer3D = %KOSound
@onready var hurt_sound: AudioStreamPlayer3D = %HurtSound


func _ready() -> void:
	lock_rotation = true
	can_sleep = false

	_find_player()

	if not animation_player.animation_finished.is_connected(
		_on_animation_player_animation_finished
	):
		animation_player.animation_finished.connect(
			_on_animation_player_animation_finished
		)

	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)

	animation_player.play("Idle")
	_setup_visual_tint()


func _setup_visual_tint() -> void:
	if bat_model == null:
		return
	var mesh_node = bat_model.get_node_or_null("Armature/Skeleton3D/bat") as MeshInstance3D
	if mesh_node == null:
		return

	if enemy_color_tint != Color.WHITE or enemy_emissive_energy > 0.0 or enemy_metallic > 0.0:
		var base_mat = mesh_node.get_surface_override_material(0)
		if base_mat == null:
			base_mat = mesh_node.get_active_material(0)

		var mat: StandardMaterial3D = null
		if base_mat is StandardMaterial3D:
			mat = base_mat.duplicate()
		else:
			mat = StandardMaterial3D.new()

		if enemy_color_tint != Color.WHITE:
			mat.albedo_color = enemy_color_tint
		if enemy_emissive_energy > 0.0:
			mat.emission_enabled = true
			mat.emission = enemy_emissive_tint
			mat.emission_energy_multiplier = enemy_emissive_energy
		if enemy_metallic > 0.0:
			mat.metallic = enemy_metallic
			mat.roughness = enemy_roughness

		mesh_node.set_surface_override_material(0, mat)


func _find_player() -> void:
	if is_instance_valid(player):
		return

	var candidate = get_tree().get_first_node_in_group("player")
	if candidate is Node3D:
		player = candidate
	elif get_tree().current_scene != null:
		player = get_tree().current_scene.get_node_or_null("Player")


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		_find_player()
		if not is_instance_valid(player):
			return

	if is_dead:
		return

	if attack_timer > 0.0:
		attack_timer -= delta

	var direction: Vector3 = player.global_position - global_position
	direction.y = 0.0

	var distance: float = direction.length()

	if distance <= stop_distance:
		linear_velocity.x = 0.0
		linear_velocity.z = 0.0
		_try_attack()
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


func _try_attack() -> void:
	if is_dead or not is_instance_valid(player):
		return

	if "is_dead" in player and player.is_dead:
		return

	if attack_timer <= 0.0:
		attack_timer = attack_cooldown
		if player.has_method("take_damage"):
			player.take_damage(attack_damage)


func play_hurt(amount: int = 1) -> void:
	if is_dead or health <= 0:
		return

	health -= amount
	hurt_sound.play()

	if health <= 0:
		is_dead = true
		death_position_recorded = global_position
		set_physics_process(false)

		# Allow rotation and gravity for the death effect.
		axis_lock_linear_y = false
		lock_rotation = false
		gravity_scale = 1.0
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO

		if not is_instance_valid(player):
			_find_player()

		if is_instance_valid(player):
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
