extends Node3D

## WaveManager: Controls wave progression, wave compositions, and wave transitions.

signal wave_started(wave_number: int, total_enemies: int)
signal wave_completed(wave_number: int)
signal wave_transition_started(duration: float)
signal wave_transition_updated(seconds_left: float)
signal remaining_enemies_changed(remaining: int)

@export var enemy_manager: Node3D = null
@export var transition_duration: float = 3.0

var current_wave: int = 0
var is_wave_in_progress: bool = false
var is_transitioning: bool = false
var transition_timer: float = 0.0

# Base mob scene (Standard Bat)
const STANDARD_BAT_SCENE = preload("uid://cfrh7v3obpgsh")
const FAST_BAT_SCENE = preload("res://mob/variants/mob_fast.tscn")
const ARMORED_BAT_SCENE = preload("res://mob/variants/mob_armored.tscn")
const SPITTER_BAT_SCENE = preload("res://mob/variants/mob_spitter.tscn")
const BOSS_SCENE = preload("res://mob/boss/boss_sky_overlord.tscn")

# Enemy variants for Phase 4
var fast_bat_scene: PackedScene = FAST_BAT_SCENE
var armored_bat_scene: PackedScene = ARMORED_BAT_SCENE
var spitter_bat_scene: PackedScene = SPITTER_BAT_SCENE
var boss_scene: PackedScene = BOSS_SCENE


func _ready() -> void:
	if not is_in_group("wave_manager"):
		add_to_group("wave_manager")

	if enemy_manager == null:
		enemy_manager = get_node_or_null("../EnemyManager") as Node3D
		if enemy_manager == null:
			enemy_manager = get_tree().get_first_node_in_group("enemy_manager") as Node3D

	if enemy_manager != null:
		_connect_enemy_manager()

	if get_node_or_null("/root/GameManager") != null:
		GameManager.game_state_changed.connect(_on_game_state_changed)
		if GameManager.current_state == GameManager.GameState.PLAYING:
			start_next_wave()
	else:
		# Fallback if GameManager is not active
		call_deferred("start_next_wave")


func _connect_enemy_manager() -> void:
	if not enemy_manager.all_enemies_defeated.is_connected(_on_all_enemies_defeated):
		enemy_manager.all_enemies_defeated.connect(_on_all_enemies_defeated)
	if not enemy_manager.remaining_enemies_changed.is_connected(_on_remaining_enemies_changed):
		enemy_manager.remaining_enemies_changed.connect(_on_remaining_enemies_changed)


func _on_game_state_changed(new_state: int, _previous_state: int) -> void:
	if new_state == GameManager.GameState.PLAYING:
		if current_wave == 0:
			start_next_wave()


func _process(delta: float) -> void:
	if is_transitioning:
		transition_timer -= delta
		wave_transition_updated.emit(maxf(0.0, transition_timer))

		if transition_timer <= 0.0:
			is_transitioning = false
			start_next_wave()


func start_next_wave() -> void:
	if enemy_manager == null:
		enemy_manager = get_node_or_null("../EnemyManager") as Node3D
		if enemy_manager != null:
			_connect_enemy_manager()

	if enemy_manager == null:
		push_error("WaveManager: Cannot start wave, EnemyManager not found!")
		return

	current_wave += 1
	is_wave_in_progress = true
	is_transitioning = false

	var wave_mobs: Array[PackedScene] = _generate_wave_composition(current_wave)
	var spawn_delay: float = _calculate_spawn_interval(current_wave)

	if get_node_or_null("/root/GameManager") != null:
		if is_boss_wave(current_wave):
			GameManager.change_state(GameManager.GameState.BOSS_FIGHT)
		else:
			GameManager.change_state(GameManager.GameState.PLAYING)

	enemy_manager.start_wave_spawns(wave_mobs, spawn_delay)
	wave_started.emit(current_wave, wave_mobs.size())
	remaining_enemies_changed.emit(wave_mobs.size())


func _generate_wave_composition(wave_num: int) -> Array[PackedScene]:
	var list: Array[PackedScene] = []

	match wave_num:
		1:
			# Wave 1: 5 Standard Bats
			for i in range(5):
				list.append(STANDARD_BAT_SCENE)
		2:
			# Wave 2: 8 Standard Bats (or fast bats if loaded in Phase 4)
			var fast_scene = fast_bat_scene if fast_bat_scene != null else STANDARD_BAT_SCENE
			for i in range(6):
				list.append(STANDARD_BAT_SCENE)
			for i in range(2):
				list.append(fast_scene)
		3:
			# Wave 3: 12 Bats (standard + fast + armored)
			var fast_scene = fast_bat_scene if fast_bat_scene != null else STANDARD_BAT_SCENE
			var armored_scene = armored_bat_scene if armored_bat_scene != null else STANDARD_BAT_SCENE
			for i in range(7):
				list.append(STANDARD_BAT_SCENE)
			for i in range(3):
				list.append(fast_scene)
			for i in range(2):
				list.append(armored_scene)
		4:
			# Wave 4: 15 Bats (standard + fast + armored + spitters)
			var fast_scene = fast_bat_scene if fast_bat_scene != null else STANDARD_BAT_SCENE
			var armored_scene = armored_bat_scene if armored_bat_scene != null else STANDARD_BAT_SCENE
			var spitter_scene = spitter_bat_scene if spitter_bat_scene != null else STANDARD_BAT_SCENE
			for i in range(7):
				list.append(STANDARD_BAT_SCENE)
			for i in range(4):
				list.append(fast_scene)
			for i in range(2):
				list.append(armored_scene)
			for i in range(2):
				list.append(spitter_scene)
		5:
			# Wave 5: Boss Wave
			if boss_scene != null:
				list.append(boss_scene)
				for i in range(4):
					list.append(STANDARD_BAT_SCENE)
			else:
				# Fallback if Phase 4 boss not loaded yet
				for i in range(18):
					list.append(STANDARD_BAT_SCENE)
		_:
			# Wave 6+: Progressively scaling formula
			var total = 15 + (wave_num - 4) * 3
			var fast_scene = fast_bat_scene if fast_bat_scene != null else STANDARD_BAT_SCENE
			var armored_scene = armored_bat_scene if armored_bat_scene != null else STANDARD_BAT_SCENE
			var spitter_scene = spitter_bat_scene if spitter_bat_scene != null else STANDARD_BAT_SCENE
			for i in range(total):
				var r = randf()
				if r < 0.4:
					list.append(STANDARD_BAT_SCENE)
				elif r < 0.65:
					list.append(fast_scene)
				elif r < 0.85:
					list.append(armored_scene)
				else:
					list.append(spitter_scene)

	return list


func _calculate_spawn_interval(wave_num: int) -> float:
	match wave_num:
		1:
			return 1.4
		2:
			return 1.2
		3:
			return 1.0
		4:
			return 0.9
		_:
			return 0.8


func is_boss_wave(wave_num: int) -> bool:
	return wave_num == 5 or wave_num % 5 == 0


func _on_all_enemies_defeated() -> void:
	if not is_wave_in_progress:
		return

	is_wave_in_progress = false
	wave_completed.emit(current_wave)

	is_transitioning = true
	transition_timer = transition_duration
	wave_transition_started.emit(transition_duration)

	if get_node_or_null("/root/GameManager") != null:
		GameManager.change_state(GameManager.GameState.WAVE_TRANSITION)


func _on_remaining_enemies_changed(count: int) -> void:
	remaining_enemies_changed.emit(count)
