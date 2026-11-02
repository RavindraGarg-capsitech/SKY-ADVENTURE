extends Node

## Centralized Game Manager for SKY ADVENTURE
## Manages global game states, state transitions, mouse capture, and run lifecycle.

enum GameState {
	HOME,
	PLAYING,
	WAVE_TRANSITION,
	UPGRADE_SELECT,
	BOSS_FIGHT,
	PAUSED,
	GAME_OVER
}

signal game_state_changed(new_state: GameState, previous_state: GameState)

var current_state: GameState = GameState.HOME
var previous_state: GameState = GameState.HOME


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_state_effects(current_state)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if current_state == GameState.PLAYING or current_state == GameState.BOSS_FIGHT:
			change_state(GameState.PAUSED)
			get_viewport().set_input_as_handled()
		elif current_state == GameState.PAUSED:
			var target_state: GameState = previous_state if previous_state != GameState.PAUSED else GameState.PLAYING
			change_state(target_state)
			get_viewport().set_input_as_handled()


func change_state(new_state: GameState) -> void:
	if new_state == current_state and is_inside_tree():
		_apply_state_effects(new_state)
		return

	var old_state: GameState = current_state
	previous_state = old_state
	current_state = new_state

	_apply_state_effects(new_state)
	game_state_changed.emit(new_state, old_state)


func _apply_state_effects(state: GameState) -> void:
	match state:
		GameState.HOME:
			get_tree().paused = true
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

		GameState.PLAYING:
			get_tree().paused = false
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

		GameState.WAVE_TRANSITION:
			get_tree().paused = false
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

		GameState.UPGRADE_SELECT:
			get_tree().paused = true
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

		GameState.BOSS_FIGHT:
			get_tree().paused = false
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

		GameState.PAUSED:
			get_tree().paused = true
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

		GameState.GAME_OVER:
			get_tree().paused = true
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func is_playing() -> bool:
	return current_state == GameState.PLAYING \
		or current_state == GameState.BOSS_FIGHT \
		or current_state == GameState.WAVE_TRANSITION


func start_game() -> void:
	change_state(GameState.PLAYING)


func pause_game() -> void:
	if is_playing():
		change_state(GameState.PAUSED)


func resume_game() -> void:
	if current_state == GameState.PAUSED:
		var target_state: GameState = previous_state if previous_state != GameState.PAUSED else GameState.PLAYING
		change_state(target_state)


func restart_game() -> void:
	change_state(GameState.PLAYING)
	get_tree().reload_current_scene.call_deferred()
