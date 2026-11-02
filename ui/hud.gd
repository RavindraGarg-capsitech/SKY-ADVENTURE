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


func _ready() -> void:
	if not is_in_group("hud"):
		add_to_group("hud")
	process_mode = Node.PROCESS_MODE_ALWAYS
	wave_cleared_container.visible = false
	countdown_container.visible = false
	boss_container.visible = false

	_connect_to_player()
	_connect_to_wave_manager()
	_connect_to_reward_manager()


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

	if "current_health" in player and "max_health" in player:
		update_health(player.current_health, player.max_health)


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
