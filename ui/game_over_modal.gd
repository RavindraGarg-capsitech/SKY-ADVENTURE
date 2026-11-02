extends CanvasLayer

## GameOverModal: Displays run summary, scores, and restart buttons upon player death.

@onready var modal_panel: Control = $ModalPanel
@onready var wave_reached_label: Label = $ModalPanel/Center/Card/Margin/VBox/Stats/WaveReachedLabel
@onready var enemies_killed_label: Label = $ModalPanel/Center/Card/Margin/VBox/Stats/EnemiesKilledLabel
@onready var coins_collected_label: Label = $ModalPanel/Center/Card/Margin/VBox/Stats/CoinsCollectedLabel
@onready var high_wave_label: Label = $ModalPanel/Center/Card/Margin/VBox/Stats/HighWaveLabel

@onready var retry_button: Button = $ModalPanel/Center/Card/Margin/VBox/Buttons/RetryButton
@onready var menu_button: Button = $ModalPanel/Center/Card/Margin/VBox/Buttons/MenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	modal_panel.visible = false

	if not is_in_group("game_over_modal"):
		add_to_group("game_over_modal")

	retry_button.pressed.connect(_on_retry_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

	if get_node_or_null("/root/GameManager") != null:
		GameManager.game_state_changed.connect(_on_game_state_changed)
		if GameManager.current_state == GameManager.GameState.GAME_OVER:
			show_game_over()

	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		_bind_player(player)
	else:
		get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node.is_in_group("player"):
		_bind_player(node)


func _bind_player(player: Node) -> void:
	if player.has_signal("player_died"):
		if not player.player_died.is_connected(show_game_over):
			player.player_died.connect(show_game_over)


func _on_game_state_changed(new_state: int, _previous_state: int) -> void:
	if new_state == GameManager.GameState.GAME_OVER:
		show_game_over()
	else:
		modal_panel.visible = false


func show_game_over() -> void:
	var wave_mgr = get_tree().get_first_node_in_group("wave_manager")
	var reward_mgr = get_tree().get_first_node_in_group("reward_manager")
	var level = get_tree().current_scene

	var wave_reached: int = wave_mgr.current_wave if wave_mgr != null and "current_wave" in wave_mgr else 1
	var coins: int = reward_mgr.coins if reward_mgr != null and "coins" in reward_mgr else 0
	var score: int = level.player_score if level != null and "player_score" in level else 0

	var high_wave: int = wave_reached
	if get_node_or_null("/root/SaveManager") != null:
		high_wave = SaveManager.high_wave

	wave_reached_label.text = "Wave Reached: %d" % wave_reached
	enemies_killed_label.text = "Final Score: %d" % score
	coins_collected_label.text = "Coins Collected: %d" % coins
	high_wave_label.text = "High Wave Record: %d" % high_wave

	modal_panel.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_retry_pressed() -> void:
	if get_node_or_null("/root/AudioManager") != null:
		AudioManager.play_click_sound()
	modal_panel.visible = false
	get_tree().paused = false
	if get_node_or_null("/root/GameManager") != null:
		GameManager.change_state(GameManager.GameState.PLAYING)
	get_tree().reload_current_scene.call_deferred()


func _on_menu_pressed() -> void:
	if get_node_or_null("/root/AudioManager") != null:
		AudioManager.play_click_sound()
	modal_panel.visible = false
	get_tree().paused = false
	if get_node_or_null("/root/GameManager") != null:
		GameManager.change_state(GameManager.GameState.HOME)
	get_tree().reload_current_scene.call_deferred()
