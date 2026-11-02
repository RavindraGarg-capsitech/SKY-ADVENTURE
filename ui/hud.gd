extends CanvasLayer

@onready var health_bar: ProgressBar = $HealthContainer/HealthBar
@onready var health_label: Label = $HealthContainer/HealthBar/HealthLabel

@onready var wave_label: Label = $WaveContainer/WaveLabel
@onready var enemies_label: Label = $WaveContainer/EnemiesLabel

@onready var transition_container: Control = $TransitionContainer
@onready var transition_title: Label = $TransitionContainer/Title
@onready var transition_subtitle: Label = $TransitionContainer/SubTitle

@onready var boss_container: Control = $BossContainer
@onready var boss_name_label: Label = $BossContainer/BossNameLabel
@onready var boss_health_bar: ProgressBar = $BossContainer/BossHealthBar
@onready var boss_health_label: Label = $BossContainer/BossHealthBar/BossHealthLabel


func _ready() -> void:
	if not is_in_group("hud"):
		add_to_group("hud")
	process_mode = Node.PROCESS_MODE_ALWAYS
	transition_container.visible = false
	boss_container.visible = false

	_connect_to_player()
	_connect_to_wave_manager()


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


func _on_node_added(node: Node) -> void:
	if node.is_in_group("player"):
		_bind_player(node)
	if node.is_in_group("wave_manager"):
		_bind_wave_manager(node)


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

	if wave_mgr.has_signal("wave_transition_started"):
		if not wave_mgr.wave_transition_started.is_connected(_on_wave_transition_started):
			wave_mgr.wave_transition_started.connect(_on_wave_transition_started)

	if wave_mgr.has_signal("wave_transition_updated"):
		if not wave_mgr.wave_transition_updated.is_connected(_on_wave_transition_updated):
			wave_mgr.wave_transition_updated.connect(_on_wave_transition_updated)

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
	if transition_container != null:
		transition_container.visible = false


func _on_remaining_enemies_changed(count: int) -> void:
	update_remaining_enemies(count)


func _on_wave_transition_started(_duration: float) -> void:
	if transition_container != null:
		transition_container.visible = true
	var wm = get_tree().get_first_node_in_group("wave_manager")
	var completed_wave: int = wm.current_wave if wm != null and "current_wave" in wm else 1
	if transition_title != null:
		transition_title.text = "WAVE %d CLEARED!" % completed_wave


func _on_wave_transition_updated(seconds_left: float) -> void:
	if transition_subtitle != null:
		transition_subtitle.text = "Next wave in %.1fs" % seconds_left


func update_wave_number(wave_num: int) -> void:
	if wave_label != null:
		wave_label.text = "Wave: %d" % wave_num


func update_remaining_enemies(count: int) -> void:
	if enemies_label != null:
		enemies_label.text = "Enemies Remaining: %d" % count


# --- Boss HUD Interface (Phase 4) ---

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
