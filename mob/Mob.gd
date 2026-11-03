
extends RigidBody3D

signal died

@export var speed: float = 3.0
@export var stop_distance: float = 2.4
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
var _death_emitted: bool = false
var attack_timer: float = 0.0

@onready var animation_player: AnimationPlayer = \
	$CollisionShape3D/bat_model/AnimationPlayer

@onready var bat_model: Node3D = \
	$CollisionShape3D/bat_model

@onready var collision_shape: CollisionShape3D = \
	get_node_or_null("CollisionShape3D")

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

	var player_base_pos: Vector3 = player.global_position
	var gun_pos: Vector3 = player_base_pos + Vector3.UP * 1.5
	if player.has_node("Camera3D"):
		gun_pos = player.get_node("Camera3D").global_position

	var direction: Vector3 = player_base_pos - global_position
	direction.y = 0.0

	var distance: float = direction.length()
	var dist_to_gun: float = (global_position - gun_pos).length()

	# Safe approach boundary: never enter the gun or camera volume (stay >= 2.2m from gun and >= stop_distance from player body)
	if distance <= stop_distance or dist_to_gun <= 2.2:
		linear_velocity.x = 0.0
		linear_velocity.z = 0.0
		_try_attack()
	else:
		direction = direction.normalized()

		# Obstacle avoidance: cast raycast forward to steer around trees, rocks, and buildings
		var current_scene = get_tree().current_scene
		if current_scene is Node3D and current_scene.get_world_3d() != null:
			var space_state = current_scene.get_world_3d().direct_space_state
			var ray_query = PhysicsRayQueryParameters3D.create(
				global_position,
				global_position + direction * 1.8,
				1 # Layer 1 = Environment
			)
			var obstacle = space_state.intersect_ray(ray_query)
			if not obstacle.is_empty():
				var normal: Vector3 = obstacle.normal
				normal.y = 0.0
				if normal.length_squared() > 0.01:
					direction = (direction + normal.normalized() * 1.5).normalized()

		linear_velocity.x = direction.x * speed
		linear_velocity.z = direction.z * speed

	# Smooth vertical hovering above ground (maintains natural 1.5m flying height across bridges & platforms)
	var current_scene_ref = get_tree().current_scene
	if current_scene_ref is Node3D and current_scene_ref.get_world_3d() != null:
		var space_state = current_scene_ref.get_world_3d().direct_space_state
		var ground_ray = PhysicsRayQueryParameters3D.create(
			Vector3(global_position.x, global_position.y + 0.5, global_position.z),
			Vector3(global_position.x, global_position.y - 4.0, global_position.z),
			1 # Layer 1 = Environment
		)
		var ground_hit = space_state.intersect_ray(ground_ray)
		if not ground_hit.is_empty():
			var target_hover_y: float = ground_hit.position.y + 1.5
			global_position.y = move_toward(global_position.y, target_hover_y, 2.5 * delta)

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

	if health <= 0:
		_start_death_sequence()
		return

	# Living enemy: play hurt sound and brief hurt animation
	if hurt_sound != null and not hurt_sound.playing:
		hurt_sound.play()

	if animation_player != null:
		if animation_player.has_animation("Custom/hurt"):
			animation_player.play("Custom/hurt")
		elif animation_player.has_animation("hurt"):
			animation_player.play("hurt")
		else:
			push_warning("Hurt animation not found!")


func _start_death_sequence() -> void:
	is_dead = true
	death_position_recorded = global_position

	# 1. Immediate AI, attack & physics processing shutdown
	set_physics_process(false)
	set_process(false)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	attack_timer = 999.0

	# 2. Disable collision to prevent further interaction or bullet impacts
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	collision_layer = 0
	collision_mask = 0
	freeze_mode = FREEZE_MODE_STATIC
	freeze = true
	gravity_scale = 0.0

	# 3. Halt expensive skeletal animation calculation (saves mobile CPU/GPU cycles)
	if animation_player != null:
		animation_player.stop()

	# 4. Play KO sound
	if ko_sound != null:
		ko_sound.play()

	# 5. Lightweight, smooth procedural death animation (0.45s)
	# Combines quick Y-spin, subtle vertical drop, and smooth shrink to zero.
	if bat_model != null:
		bat_model.rotation.x = 0.0
		bat_model.rotation.z = 0.0
		var start_pos_y: float = bat_model.position.y
		var start_rot_y: float = bat_model.rotation.y

		var death_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD)
		# Fast smooth spin strictly around Y-axis
		death_tween.tween_property(bat_model, "rotation:y", start_rot_y + TAU, 0.45).set_ease(Tween.EASE_OUT)
		# Subtle downward fall
		death_tween.tween_property(bat_model, "position:y", start_pos_y - 0.4, 0.45).set_ease(Tween.EASE_IN)
		# Smooth shrink to tiny scale
		death_tween.tween_property(bat_model, "scale", Vector3(0.01, 0.01, 0.01), 0.45).set_ease(Tween.EASE_IN)

		death_tween.chain().tween_callback(self._on_death_completed)
	else:
		_on_death_completed()


func _on_death_completed() -> void:
	if _death_emitted:
		return
	_death_emitted = true
	died.emit()
	queue_free()


func _on_animation_player_animation_finished(
	anim_name: StringName
) -> void:
	if (
		anim_name == &"Custom/hurt"
		or anim_name == &"hurt"
	):
		if health > 0 and not is_dead and animation_player != null:
			animation_player.play("Idle")


func _on_timer_timeout() -> void:
	if is_dead and not _death_emitted:
		_on_death_completed()
