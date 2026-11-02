extends CanvasLayer

## UpgradeModal: Displays a 3-card procedural upgrade draft between waves.

signal upgrade_selected(upgrade_id: String)

@onready var modal_panel: Control = $ModalPanel
@onready var card_buttons: Array[Button] = [
	$ModalPanel/Center/VBox/CardsContainer/Card1,
	$ModalPanel/Center/VBox/CardsContainer/Card2,
	$ModalPanel/Center/VBox/CardsContainer/Card3
]

const ALL_UPGRADES: Array[Dictionary] = [
	{
		"id": "rapid_fire",
		"title": "⚡ Rapid Fire",
		"desc": "+25% Fire Rate\nShoot bullets faster"
	},
	{
		"id": "multishot",
		"title": "🔱 Multishot",
		"desc": "+1 Bullet Spread\nFires extra projectile per volley"
	},
	{
		"id": "heavy_shot",
		"title": "💥 Heavy Shot",
		"desc": "+1 Bullet Damage\nInflicts heavier damage on impact"
	},
	{
		"id": "increased_range",
		"title": "🎯 Extended Range",
		"desc": "+15m Bullet Distance\nBullets travel much further"
	},
	{
		"id": "magnetism",
		"title": "🧲 Sky Magnet",
		"desc": "+3.5m Pickup Radius\nAttracts coins and crystals effortlessly"
	},
	{
		"id": "health_upgrade",
		"title": "❤️ Vitality Boost",
		"desc": "+25 Max Health\nImmediately restores 25 HP"
	}
]

var current_choices: Array[Dictionary] = []


func _ready() -> void:
	if not is_in_group("upgrade_modal"):
		add_to_group("upgrade_modal")
	process_mode = Node.PROCESS_MODE_ALWAYS
	modal_panel.visible = false

	for i in range(card_buttons.size()):
		var idx = i
		card_buttons[i].pressed.connect(_on_card_pressed.bind(idx))


func present_upgrades() -> void:
	# If player is dead or in GAME_OVER, never show upgrade modal!
	var player = get_tree().get_first_node_in_group("player")
	if player != null and "is_dead" in player and player.is_dead:
		return
	if get_node_or_null("/root/GameManager") != null and GameManager.current_state == GameManager.GameState.GAME_OVER:
		return

	# Shuffle and pick 3 distinct upgrades
	var pool = ALL_UPGRADES.duplicate()
	pool.shuffle()
	current_choices = pool.slice(0, 3)

	for i in range(3):
		var choice = current_choices[i]
		var btn = card_buttons[i]
		btn.text = "%s\n\n%s" % [choice["title"], choice["desc"]]

	modal_panel.visible = true

	if get_node_or_null("/root/GameManager") != null:
		GameManager.change_state(GameManager.GameState.UPGRADE_SELECT)
	else:
		get_tree().paused = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func hide_modal() -> void:
	modal_panel.visible = false


func _on_card_pressed(card_index: int) -> void:
	if card_index < 0 or card_index >= current_choices.size():
		return

	if get_node_or_null("/root/AudioManager") != null:
		AudioManager.play_upgrade_sound()

	var chosen = current_choices[card_index]
	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("apply_upgrade"):
		player.apply_upgrade(chosen["id"])

	hide_modal()
	upgrade_selected.emit(chosen["id"])

	# Hand off to WaveManager to trigger the 3-second countdown transition
	var wave_mgr = get_tree().get_first_node_in_group("wave_manager")
	if wave_mgr != null and wave_mgr.has_method("on_upgrade_chosen"):
		wave_mgr.on_upgrade_chosen()
	elif wave_mgr != null and wave_mgr.has_method("start_next_wave"):
		wave_mgr.start_next_wave()
	elif get_node_or_null("/root/GameManager") != null:
		GameManager.change_state(GameManager.GameState.PLAYING)
	else:
		get_tree().paused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
