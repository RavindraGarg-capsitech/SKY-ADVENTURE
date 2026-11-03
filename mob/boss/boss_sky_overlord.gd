extends "res://mob/Mob.gd"

## Sky Overlord Boss: Wave 5 Apex Boss with heavy melee and multi-projectile energy barrages.

@export var barrage_interval: float = 3.2
@export var projectile_scene: PackedScene = preload("res://mob/projectile/mob_projectile_3d.tscn")

var barrage_timer: float = 2.0
var hud_node: Node = null


func _ready() -> void:
	speed = 3.2
	stop_distance = 2.2
	attack_damage = 25
	attack_cooldown = 1.2
	health = 75
	max_health = 75

	super._ready()
	_init_boss_hud()


func _init_boss_hud() -> void:
	hud_node = get_tree().get_first_node_in_group("hud")
	if hud_node == null:
		var root = get_tree().current_scene
		if root != null:
			hud_node = root.get_node_or_null("HUD")

	if hud_node != null and hud_node.has_method("show_boss_bar"):
		hud_node.show_boss_bar("SKY OVERLORD", max_health)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		_find_player()
		if not is_instance_valid(player):
			return

	if is_dead:
		return

	# Handle energy barrage timer
	barrage_timer -= delta
	if barrage_timer <= 0.0:
		barrage_timer = barrage_interval
		_fire_energy_barrage()

	super._physics_process(delta)


func _fire_energy_barrage() -> void:
	if projectile_scene == null or not is_instance_valid(player):
		return
	if "is_dead" in player and player.is_dead:
		return

	var origin: Vector3 = global_position + Vector3.UP * 0.5
	var target: Vector3 = player.global_position + Vector3.UP * 1.0
	var base_direction: Vector3 = (target - origin).normalized()

	# Fire 3 spread bolts (-15 deg, 0 deg, +15 deg)
	var angles = [-0.25, 0.0, 0.25]
	for angle in angles:
		var proj = projectile_scene.instantiate() as Node3D
		get_tree().current_scene.add_child(proj)
		proj.global_position = origin

		var rotated_dir = base_direction.rotated(Vector3.UP, angle)
		proj.look_at(origin + rotated_dir, Vector3.UP)


func play_hurt(amount: int = 1) -> void:
	super.play_hurt(amount)
	if hud_node != null and hud_node.has_method("update_boss_health"):
		hud_node.update_boss_health(maxi(0, health), max_health)


func _on_death_completed() -> void:
	if hud_node != null and hud_node.has_method("hide_boss_bar"):
		hud_node.hide_boss_bar()
	super._on_death_completed()


func _on_timer_timeout() -> void:
	if hud_node != null and hud_node.has_method("hide_boss_bar"):
		hud_node.hide_boss_bar()
	super._on_timer_timeout()
