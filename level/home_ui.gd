
extends CanvasLayer

@onready var home_panel: Control = $HomePanel
@onready var play_button: Button = $HomePanel/PlayButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	play_button.pressed.connect(_on_play_pressed)

	if get_node_or_null("/root/GameManager") != null:
		GameManager.game_state_changed.connect(_on_game_state_changed)
		if GameManager.current_state == GameManager.GameState.PLAYING:
			home_panel.hide()
		else:
			home_panel.show()
			GameManager.change_state(GameManager.GameState.HOME)
	else:
		home_panel.show()
		get_tree().paused = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_play_pressed() -> void:
	if get_node_or_null("/root/AudioManager") != null:
		AudioManager.play_click_sound()
	home_panel.hide()

	if get_node_or_null("/root/GameManager") != null:
		GameManager.change_state(GameManager.GameState.PLAYING)
	else:
		get_tree().paused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_game_state_changed(new_state: int, _previous_state: int) -> void:
	if new_state == GameManager.GameState.HOME:
		home_panel.show()
	else:
		home_panel.hide()
