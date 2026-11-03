extends CanvasLayer

@onready var health_bar: ProgressBar = $HealthContainer/HealthBar
@onready var health_label: Label = $HealthContainer/HealthBar/HealthLabel
@onready var heal_notification: Label = $HealthContainer/HealNotification
var _heal_tween: Tween = null

@onready var wave_label: Label = $WaveContainer/WaveLabel
@onready var enemies_label: Label = $WaveContainer/EnemiesLabel
@onready var coins_label: Label = $WaveContainer/CoinsLabel
@onready var score_label: Label = $WaveContainer/ScoreLabel

@onready var wave_cleared_container: Control = $WaveClearedContainer
@onready var wave_cleared_title: Label = $WaveClearedContainer/Title
@onready var wave_cleared_subtitle: Label = $WaveClearedContainer/SubTitle

@onready var countdown_container: Control = $CountdownContainer
@onready var countdown_title: Label = $CountdownContainer/Title
@onready var countdown_subtitle: Label = $CountdownContainer/SubTitle

@onready var boss_container: Control = $BossContainer
@onready var boss_name_label: Label = $BossContainer/BossNameLabel
@onready var boss_health_bar: ProgressBar = $BossContainer/BossHealthBar
@onready var boss_health_label: Label = $BossContainer/BossHealthBar/BossHealthLabel

@onready var pause_button: Button = get_node_or_null("PauseButton")

@onready var weapon_container: Control = get_node_or_null("WeaponContainer")
@onready var weapon_label: Label = get_node_or_null("WeaponContainer/Margin/VBox/WeaponLabel")
@onready var weapon_sub_label: Label = get_node_or_null("WeaponContainer/Margin/VBox/WeaponSubLabel")

@onready var shield_container: Control = get_node_or_null("ShieldContainer")
@onready var shield_bar: ProgressBar = get_node_or_null("ShieldContainer/ShieldBar")
@onready var shield_label: Label = get_node_or_null("ShieldContainer/ShieldBar/ShieldLabel")

@onready var powerup_notification: Label = get_node_or_null("PowerupNotification")
var _powerup_tween: Tween = null

@onready var damage_indicator: Control = get_node_or_null("DamageIndicator")


func _ready() -> void:
	if not is_in_group("hud"):
		add_to_group("hud")
	process_mode = Node.PROCESS_MODE_ALWAYS
	wave_cleared_container.visible = false
	countdown_container.visible = false
	boss_container.visible = false
	if shield_container != null:
		shield_container.visible = false
	if powerup_notification != null:
		powerup_notification.visible = false

	if pause_button != null:
		pause_button.pressed.connect(_on_pause_button_pressed)

	_apply_safe_area()
	_connect_to_player()
	_connect_to_wave_manager()
	_connect_to_reward_manager()


func _apply_safe_area() -> void:
	var safe_area = DisplayServer.get_display_safe_area()
	var win_size = DisplayServer.window_get_size()
	if win_size.x <= 0 or win_size.y <= 0 or safe_area.size.x <= 0:
		return

	var left_pad = float(safe_area.position.x)
	var right_pad = float(win_size.x - (safe_area.position.x + safe_area.size.x))
	var top_pad = float(safe_area.position.y)

	var health_c = get_node_or_null("HealthContainer")
	if health_c != null and (left_pad > 0 or top_pad > 0):
		health_c.position.x += left_pad
		health_c.position.y += top_pad

	if weapon_container != null and (left_pad > 0 or top_pad > 0):
		weapon_container.position.x += left_pad
		weapon_container.position.y += top_pad

	if shield_container != null and (left_pad > 0 or top_pad > 0):
		shield_container.position.x += left_pad
		shield_container.position.y += top_pad

	if pause_button != null and (right_pad > 0 or top_pad > 0):
		pause_button.position.x -= right_pad
		pause_button.position.y += top_pad


func _connect_to_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		_bind_player(player)
	else:
		get_tree().node_added.connect(_on_node_added)


func _connect_to_wave_manager() -> void:
	var wave_manager = get_tree().get_first_node_in_group("wave_manager")
	if wave_manager != null:
		_bind_wave_manager(wave_manager)
	else:
		get_tree().node_added.connect(_on_node_added)


func _connect_to_reward_manager() -> void:
	var rm = get_tree().get_first_node_in_group("reward_manager")
	if rm != null:
		_bind_reward_manager(rm)
	else:
		get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node.is_in_group("player"):
		_bind_player(node)
	if node.is_in_group("wave_manager"):
		_bind_wave_manager(node)
	if node.is_in_group("reward_manager"):
		_bind_reward_manager(node)


func _bind_reward_manager(rm: Node) -> void:
	if rm.has_signal("coins_changed"):
		if not rm.coins_changed.is_connected(_on_coins_changed):
			rm.coins_changed.connect(_on_coins_changed)
	if "coins" in rm:
		update_coins(rm.coins)


func _on_coins_changed(total: int) -> void:
	update_coins(total)


func update_coins(amount: int) -> void:
	if coins_label != null:
		coins_label.text = "Coins: %d" % amount


func update_score(score: int) -> void:
	if score_label != null:
		score_label.text = "Score: %d" % score


func _bind_player(player: Node) -> void:
	if player.has_signal("health_changed"):
		if not player.health_changed.is_connected(_on_player_health_changed):
			player.health_changed.connect(_on_player_health_changed)

	if player.has_signal("player_damaged"):
		if not player.player_damaged.is_connected(_on_player_damaged):
			player.player_damaged.connect(_on_player_damaged)

	if player.has_signal("weapon_changed"):
		if not player.weapon_changed.is_connected(_on_player_weapon_changed):
			player.weapon_changed.connect(_on_player_weapon_changed)

	if player.has_signal("shield_activated"):
		if not player.shield_activated.is_connected(_on_player_shield_activated):
			player.shield_activated.connect(_on_player_shield_activated)

	if player.has_signal("shield_updated"):
		if not player.shield_updated.is_connected(_on_player_shield_updated):
			player.shield_updated.connect(_on_player_shield_updated)

	if player.has_signal("shield_expired"):
		if not player.shield_expired.is_connected(_on_player_shield_expired):
			player.shield_expired.connect(_on_player_shield_expired)

	if "current_health" in player and "max_health" in player:
		update_health(player.current_health, player.max_health)

	if player.has_method("get_current_weapon_data"):
		var wdata = player.get_current_weapon_data()
		update_weapon(wdata["name"], wdata["info"], wdata["icon"])

	if "is_shield_active" in player and player.is_shield_active:
		var duration = player.shield_duration if "shield_duration" in player else 10.0
		var remaining = player.shield_time_left if "shield_time_left" in player else duration
		update_shield(remaining, duration)
	else:
		hide_shield()


func _on_pause_button_pressed() -> void:
	if get_node_or_null("/root/GameManager") != null:
		GameManager.pause_game()
	else:
		get_tree().paused = true


func _on_player_weapon_changed(_weapon_id: String, weapon_name: String, weapon_info: String, icon: String) -> void:
	update_weapon(weapon_name, weapon_info, icon)
	show_powerup_notification("%s %s EQUIPPED!" % [icon, weapon_name.to_upper()])


func update_weapon(weapon_name: String, weapon_info: String, icon: String = "🔫") -> void:
	if weapon_label != null:
		weapon_label.text = "%s %s" % [icon, weapon_name]
	if weapon_sub_label != null:
		weapon_sub_label.text = weapon_info


func _on_player_shield_activated(duration: float) -> void:
	update_shield(duration, duration)
	show_powerup_notification("🛡️ ENERGY SHIELD ACTIVATED!")


func _on_player_shield_updated(time_left: float, max_duration: float) -> void:
	update_shield(time_left, max_duration)


func _on_player_shield_expired() -> void:
	hide_shield()
	show_powerup_notification("⚠️ SHIELD EXPIRED")


func update_shield(time_left: float, max_duration: float = 10.0) -> void:
	if shield_container != null:
		shield_container.visible = true
	if shield_bar != null:
		shield_bar.max_value = max_duration
		shield_bar.value = time_left
	if shield_label != null:
		shield_label.text = "🛡️ SHIELD: %.1fs" % maxf(0.0, time_left)


func hide_shield() -> void:
	if shield_container != null:
		shield_container.visible = false


func show_powerup_notification(text: String) -> void:
	if powerup_notification == null:
		powerup_notification = get_node_or_null("PowerupNotification")
	if powerup_notification != null:
		if _powerup_tween != null and _powerup_tween.is_valid():
			_powerup_tween.kill()

		powerup_notification.text = text
		powerup_notification.visible = true
		powerup_notification.modulate = Color(1, 1, 1, 1)

		_powerup_tween = create_tween()
		_powerup_tween.tween_interval(1.8)
		_powerup_tween.tween_property(powerup_notification, "modulate:a", 0.0, 0.5)
		_powerup_tween.tween_callback(func():
			if is_instance_valid(powerup_notification):
				powerup_notification.visible = false
		)


func _bind_wave_manager(wave_mgr: Node) -> void:
	if wave_mgr.has_signal("wave_started"):
		if not wave_mgr.wave_started.is_connected(_on_wave_started):
			wave_mgr.wave_started.connect(_on_wave_started)

	if wave_mgr.has_signal("remaining_enemies_changed"):
		if not wave_mgr.remaining_enemies_changed.is_connected(_on_remaining_enemies_changed):
			wave_mgr.remaining_enemies_changed.connect(_on_remaining_enemies_changed)

	if "current_wave" in wave_mgr and wave_mgr.current_wave > 0:
		update_wave_number(wave_mgr.current_wave)


func _on_player_health_changed(current: int, maximum: int) -> void:
	update_health(current, maximum)


func _on_player_damaged(_amount: int, hit_pos: Vector3) -> void:
	if damage_indicator == null:
		damage_indicator = get_node_or_null("DamageIndicator")
	if damage_indicator != null and damage_indicator.has_method("show_damage_direction"):
		var player = get_tree().get_first_node_in_group("player")
		damage_indicator.show_damage_direction(hit_pos, player)


func update_health(current: int, maximum: int) -> void:
	if health_bar != null:
		health_bar.max_value = maximum
		health_bar.value = current

	if health_label != null:
		health_label.text = "HP: %d / %d" % [current, maximum]


func _on_wave_started(wave_num: int, total_enemies: int) -> void:
	update_wave_number(wave_num)
	update_remaining_enemies(total_enemies)
	hide_all_banners()


func _on_remaining_enemies_changed(count: int) -> void:
	update_remaining_enemies(count)


# --- Separated Banner Displays ---

func show_wave_cleared(wave_num: int, heal_amt: int = 25) -> void:
	hide_all_banners()
	if wave_cleared_title != null:
		wave_cleared_title.text = "WAVE %d CLEARED!" % wave_num
	if wave_cleared_subtitle != null:
		if heal_amt > 0:
			wave_cleared_subtitle.text = "Sector Secured • +%d HP Recovered!" % heal_amt
		else:
			wave_cleared_subtitle.text = "Sector Secured"
	if wave_cleared_container != null:
		wave_cleared_container.visible = true


func show_health_recovery(amount: int) -> void:
	if heal_notification == null:
		heal_notification = get_node_or_null("HealthContainer/HealNotification")

	if heal_notification != null:
		if _heal_tween != null and _heal_tween.is_valid():
			_heal_tween.kill()

		heal_notification.text = "+%d HP Recovered!" % amount
		heal_notification.visible = true
		heal_notification.modulate = Color(1, 1, 1, 1)

		_heal_tween = create_tween()
		_heal_tween.tween_interval(1.8)
		_heal_tween.tween_property(heal_notification, "modulate:a", 0.0, 0.6)
		_heal_tween.tween_callback(func():
			if is_instance_valid(heal_notification):
				heal_notification.visible = false
		)

	if wave_cleared_subtitle != null and wave_cleared_container != null and wave_cleared_container.visible:
		wave_cleared_subtitle.text = "Sector Secured • +%d HP Recovered!" % amount


func hide_wave_cleared() -> void:
	if wave_cleared_container != null:
		wave_cleared_container.visible = false


func show_countdown(next_wave_num: int, seconds_left: float) -> void:
	hide_wave_cleared()
	if countdown_title != null:
		countdown_title.text = "PREPARE FOR WAVE %d" % next_wave_num
	if countdown_subtitle != null:
		countdown_subtitle.text = "Incoming in %.1fs" % seconds_left
	if countdown_container != null:
		countdown_container.visible = true


func update_countdown(seconds_left: float) -> void:
	if countdown_subtitle != null:
		countdown_subtitle.text = "Incoming in %.1fs" % seconds_left


func hide_countdown() -> void:
	if countdown_container != null:
		countdown_container.visible = false


func hide_all_banners() -> void:
	hide_wave_cleared()
	hide_countdown()


func update_wave_number(wave_num: int) -> void:
	if wave_label != null:
		wave_label.text = "Wave: %d" % wave_num


func update_remaining_enemies(count: int) -> void:
	if enemies_label != null:
		enemies_label.text = "Enemies: %d" % count


# --- Boss HUD Interface ---

func show_boss_bar(boss_name: String, max_hp: int) -> void:
	if boss_container != null:
		boss_container.visible = true
	if boss_name_label != null:
		boss_name_label.text = boss_name
	update_boss_health(max_hp, max_hp)


func update_boss_health(current_hp: int, max_hp: int) -> void:
	if boss_health_bar != null:
		boss_health_bar.max_value = max_hp
		boss_health_bar.value = current_hp
	if boss_health_label != null:
		boss_health_label.text = "%d / %d" % [current_hp, max_hp]


func hide_boss_bar() -> void:
	if boss_container != null:
		boss_container.visible = false
