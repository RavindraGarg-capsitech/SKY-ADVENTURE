extends Node3D

## WaveManager: Controls wave progression, wave compositions, and the 5-step wave transition sequence.

signal wave_started(wave_number: int, total_enemies: int)
signal wave_completed(wave_number: int)
signal wave_transition_started(duration: float)
signal wave_transition_updated(seconds_left: float)
signal remaining_enemies_changed(remaining: int)

enum TransitionStage {
	NONE,
	WAVE_CLEARED_BANNER,
	UPGRADE_SELECTION,
	COUNTDOWN_TRANSITION
}

@export var enemy_manager: Node3D = null
@export var transition_duration: float = 3.0
@export var wave_clear_banner_duration: float = 2.0
@export var wave_heal_amount: int = 25

var current_wave: int = 0
var is_wave_in_progress: bool = false
var transition_stage: TransitionStage = TransitionStage.NONE
var stage_timer: float = 0.0
var _recovered_waves: Dictionary = {}

# Base mob scenes
const STANDARD_BAT_SCENE = preload("uid://cfrh7v3obpgsh")
const FAST_BAT_SCENE = preload("res://mob/variants/mob_fast.tscn")
const ARMORED_BAT_SCENE = preload("res://mob/variants/mob_armored.tscn")
const SPITTER_BAT_SCENE = preload("res://mob/variants/mob_spitter.tscn")
const BOSS_SCENE = preload("res://mob/boss/boss_sky_overlord.tscn")

var fast_bat_scene: PackedScene = FAST_BAT_SCENE
var armored_bat_scene: PackedScene = ARMORED_BAT_SCENE
var spitter_bat_scene: PackedScene = SPITTER_BAT_SCENE
var boss_scene: PackedScene = BOSS_SCENE


func _ready() -> void:
	if not is_in_group("wave_manager"):
		add_to_group("wave_manager")

	_recovered_waves.clear()
	if not wave_completed.is_connected(_apply_wave_recovery):
		wave_completed.connect(_apply_wave_recovery)

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
	elif new_state == GameManager.GameState.GAME_OVER:
		abort_wave_transition()


func _process(delta: float) -> void:
	match transition_stage:
		TransitionStage.WAVE_CLEARED_BANNER:
			stage_timer -= delta
			if stage_timer <= 0.0:
				_transition_to_upgrade_selection()

		TransitionStage.COUNTDOWN_TRANSITION:
			stage_timer -= delta
			var time_left: float = maxf(0.0, stage_timer)
			wave_transition_updated.emit(time_left)

			var hud = get_tree().get_first_node_in_group("hud")
			if hud != null and hud.has_method("update_countdown"):
				hud.update_countdown(time_left)

			if stage_timer <= 0.0:
				transition_stage = TransitionStage.NONE
				if hud != null and hud.has_method("hide_countdown"):
					hud.hide_countdown()
				start_next_wave()


func _on_all_enemies_defeated() -> void:
	if not is_wave_in_progress or transition_stage != TransitionStage.NONE:
		return

	is_wave_in_progress = false
	wave_completed.emit(current_wave)

	if get_node_or_null("/root/AudioManager") != null:
		AudioManager.play_wave_clear_sound()

	# Step 2: Show Wave Cleared banner for 2 seconds
	transition_stage = TransitionStage.WAVE_CLEARED_BANNER
	stage_timer = wave_clear_banner_duration

	var hud = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_wave_cleared"):
		hud.show_wave_cleared(current_wave, wave_heal_amount)


func _apply_wave_recovery(wave_num: int) -> void:
	if wave_num <= 0:
		return

	# Ensure recovery applies exactly once per completed wave
	if _recovered_waves.has(wave_num):
		return
	_recovered_waves[wave_num] = true

	# Do not restore health if player is dead or GAME_OVER is active
	if get_node_or_null("/root/GameManager") != null:
		if GameManager.current_state == GameManager.GameState.GAME_OVER:
			return

	var player = get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		return

	if "is_dead" in player and player.is_dead:
		return

	# Restore health up to max_health
	if player.has_method("heal") and wave_heal_amount > 0:
		player.heal(wave_heal_amount)

	# Display short health recovery notification
	var hud = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_health_recovery"):
		hud.show_health_recovery(wave_heal_amount)


func _transition_to_upgrade_selection() -> void:
	# Check if player died during banner
	var player = get_tree().get_first_node_in_group("player")
	if player != null and "is_dead" in player and player.is_dead:
		abort_wave_transition()
		return

	transition_stage = TransitionStage.UPGRADE_SELECTION

	var hud = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("hide_wave_cleared"):
		hud.hide_wave_cleared()

	# Step 3: Present upgrade cards modal
	var modal = get_tree().get_first_node_in_group("upgrade_modal")
	if modal != null and modal.has_method("present_upgrades"):
		modal.present_upgrades()
	else:
		# Fallback if upgrade modal not present: go directly to countdown
		on_upgrade_chosen()


## Step 4/5: Called when player chooses an upgrade from UpgradeModal
func on_upgrade_chosen() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null and "is_dead" in player and player.is_dead:
		abort_wave_transition()
		return

	# Step 5: 3-second safe transition countdown
	transition_stage = TransitionStage.COUNTDOWN_TRANSITION
	stage_timer = transition_duration
	wave_transition_started.emit(transition_duration)

	if get_node_or_null("/root/GameManager") != null:
		GameManager.change_state(GameManager.GameState.WAVE_TRANSITION)
	else:
		get_tree().paused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	var hud = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_countdown"):
		hud.show_countdown(current_wave + 1, transition_duration)


## Step 6: Start next wave after countdown completes
func start_next_wave() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null and "is_dead" in player and player.is_dead:
		return
	if get_node_or_null("/root/GameManager") != null and GameManager.current_state == GameManager.GameState.GAME_OVER:
		return

	if enemy_manager == null:
		enemy_manager = get_node_or_null("../EnemyManager") as Node3D
		if enemy_manager != null:
			_connect_enemy_manager()

	if enemy_manager == null:
		push_error("WaveManager: Cannot start wave, EnemyManager not found!")
		return

	current_wave += 1
	is_wave_in_progress = true
	transition_stage = TransitionStage.NONE
	stage_timer = 0.0

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


func abort_wave_transition() -> void:
	transition_stage = TransitionStage.NONE
	stage_timer = 0.0
	is_wave_in_progress = false

	if enemy_manager != null and enemy_manager.has_method("stop_spawning"):
		enemy_manager.stop_spawning()

	var hud = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("hide_all_banners"):
		hud.hide_all_banners()

	var modal = get_tree().get_first_node_in_group("upgrade_modal")
	if modal != null and modal.has_method("hide_modal"):
		modal.hide_modal()


func _generate_wave_composition(wave_num: int) -> Array[PackedScene]:
	var list: Array[PackedScene] = []

	match wave_num:
		1:
			for i in range(5):
				list.append(STANDARD_BAT_SCENE)
		2:
			var fast_scene = fast_bat_scene if fast_bat_scene != null else STANDARD_BAT_SCENE
			for i in range(6):
				list.append(STANDARD_BAT_SCENE)
			for i in range(2):
				list.append(fast_scene)
		3:
			var fast_scene = fast_bat_scene if fast_bat_scene != null else STANDARD_BAT_SCENE
			var armored_scene = armored_bat_scene if armored_bat_scene != null else STANDARD_BAT_SCENE
			for i in range(7):
				list.append(STANDARD_BAT_SCENE)
			for i in range(3):
				list.append(fast_scene)
			for i in range(2):
				list.append(armored_scene)
		4:
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
			if boss_scene != null:
				list.append(boss_scene)
				for i in range(4):
					list.append(STANDARD_BAT_SCENE)
			else:
				for i in range(18):
					list.append(STANDARD_BAT_SCENE)
		_:
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


func _on_remaining_enemies_changed(count: int) -> void:
	remaining_enemies_changed.emit(count)
