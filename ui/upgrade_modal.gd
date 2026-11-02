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
		"desc": "+25% Fire Rate\nShoot bullets faster",
		"min_wave": 1
	},
	{
		"id": "multishot",
		"title": "🔱 Multishot",
		"desc": "+1 Bullet Spread\nFires extra projectile per volley",
		"min_wave": 1
	},
	{
		"id": "heavy_shot",
		"title": "💥 Heavy Shot",
		"desc": "+1 Bullet Damage\nInflicts heavier damage on impact",
		"min_wave": 1
	},
	{
		"id": "increased_range",
		"title": "🎯 Extended Range",
		"desc": "+15m Bullet Distance\nBullets travel much further",
		"min_wave": 1
	},
	{
		"id": "magnetism",
		"title": "🧲 Sky Magnet",
		"desc": "+3.5m Pickup Radius\nAttracts coins and crystals effortlessly",
		"min_wave": 1
	},
	{
		"id": "health_upgrade",
		"title": "❤️ Vitality Boost",
		"desc": "+25 Max Health\nImmediately restores 25 HP",
		"min_wave": 1
	},
	{
		"id": "weapon_plasma",
		"title": "⚡ Plasma Gun",
		"desc": "Unlock Plasma Gun\n3x Heavy Energy Damage • Slower Fire",
		"min_wave": 5
	},
	{
		"id": "powerup_shield",
		"title": "🛡️ Energy Shield",
		"desc": "Impenetrable Forcefield\nAbsorbs 100% of damage for 10 seconds",
		"min_wave": 5
	},
	{
		"id": "weapon_triple",
		"title": "🔱 Triple Shot Gun",
		"desc": "Unlock Triple Spread Gun\nFires 3 bullets per blast",
		"min_wave": 6
	},
	{
		"id": "weapon_cannon",
		"title": "💥 Heavy Cannon",
		"desc": "Unlock Heavy Cannon\nMassive Artillery Shells • 6x Damage",
		"min_wave": 6
	},
	{
		"id": "weapon_rapid",
		"title": "⚡ Rapid Blaster",
		"desc": "Unlock Rapid Blaster\nSuper-fast 0.08s firing rate barrage",
		"min_wave": 6
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


func present_upgrades(wave_override: int = -1) -> void:
	# If player is dead or in GAME_OVER, never show upgrade modal!
	var player = get_tree().get_first_node_in_group("player")
	if player != null and "is_dead" in player and player.is_dead:
		return
	if get_node_or_null("/root/GameManager") != null and GameManager.current_state == GameManager.GameState.GAME_OVER:
		return

	# Determine wave number for unlocked progression
	var wave_num: int = 1
	if wave_override > 0:
		wave_num = wave_override
	else:
		var wave_mgr = get_tree().get_first_node_in_group("wave_manager")
		if wave_mgr != null and "current_wave" in wave_mgr and wave_mgr.current_wave > 0:
			wave_num = wave_mgr.current_wave

	# Filter available upgrades based on wave and weapon ownership
	var pool: Array[Dictionary] = []
	for item in ALL_UPGRADES:
		var min_w = item.get("min_wave", 1)
		if wave_num >= min_w:
			var uid = item["id"]
			# If it's a weapon unlock, do not offer if already unlocked by player
			if uid.begins_with("weapon_") and player != null and "unlocked_weapons" in player:
				var wid = uid.substr(7)
				if wid in player.unlocked_weapons:
					continue
			pool.append(item)

	if pool.size() < 3:
		pool = ALL_UPGRADES.slice(0, 6)

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
	if player != null:
		var uid = chosen["id"]
		if uid.begins_with("weapon_"):
			var wid = uid.substr(7)
			if player.has_method("unlock_weapon"):
				player.unlock_weapon(wid)
		elif uid == "powerup_shield":
			if player.has_method("activate_shield"):
				player.activate_shield(10.0)
		elif player.has_method("apply_upgrade"):
			player.apply_upgrade(uid)

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
