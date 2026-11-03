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

	get_tree().node_added.connect(_on_node_added)
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		_bind_player(player)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		# Mobile backgrounding: pause active gameplay and flush save data
		if is_playing():
			pause_game()
		var sm = get_node_or_null("/root/SaveManager")
		if sm != null and sm.has_method("save_game"):
			sm.save_game()


func _on_node_added(node: Node) -> void:
	if node.is_in_group("player"):
		_bind_player(node)


func _bind_player(player: Node) -> void:
	if player.has_signal("player_died"):
		if not player.player_died.is_connected(_on_player_died):
			player.player_died.connect(_on_player_died)


func _on_player_died() -> void:
	change_state(GameState.GAME_OVER)


func _unhandled_input(event: InputEvent) -> void:
	if current_state == GameState.GAME_OVER:
		return

	if event.is_action_pressed("ui_cancel"):
		if current_state == GameState.PLAYING or current_state == GameState.BOSS_FIGHT:
			change_state(GameState.PAUSED)
			get_viewport().set_input_as_handled()
		elif current_state == GameState.PAUSED:
			var target_state: GameState = previous_state if previous_state != GameState.PAUSED else GameState.PLAYING
			change_state(target_state)
			get_viewport().set_input_as_handled()


func change_state(new_state: GameState) -> void:
	# GAME_OVER lock: Once in GAME_OVER, only restart/retry (PLAYING) or main menu (HOME) can leave GAME_OVER
	if current_state == GameState.GAME_OVER and new_state != GameState.PLAYING and new_state != GameState.HOME:
		return

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
			var go_modal = get_tree().get_first_node_in_group("game_over_modal")
			if go_modal != null and go_modal.has_method("show_game_over"):
				go_modal.show_game_over()


func is_playing() -> bool:
	return (current_state == GameState.PLAYING \
		or current_state == GameState.BOSS_FIGHT \
		or current_state == GameState.WAVE_TRANSITION) \
		and current_state != GameState.GAME_OVER


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
