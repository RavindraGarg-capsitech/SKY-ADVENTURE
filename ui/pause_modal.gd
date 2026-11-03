extends CanvasLayer

## PauseModal: Polished Pause & Settings Menu for SKY ADVENTURE.
## Controls game pause state, audio sliders, camera sensitivity, and level restarts.

signal game_resumed
signal game_restarted

@onready var modal_panel: Control = $ModalPanel
@onready var main_container: VBoxContainer = $ModalPanel/Center/Card/Margin/VBox/MainContainer
@onready var settings_container: VBoxContainer = $ModalPanel/Center/Card/Margin/VBox/SettingsContainer

# Main view buttons
@onready var resume_button: Button = $ModalPanel/Center/Card/Margin/VBox/MainContainer/ResumeButton
@onready var restart_button: Button = $ModalPanel/Center/Card/Margin/VBox/MainContainer/RestartButton
@onready var settings_button: Button = $ModalPanel/Center/Card/Margin/VBox/MainContainer/SettingsButton
@onready var menu_button: Button = $ModalPanel/Center/Card/Margin/VBox/MainContainer/MainMenuButton

# Settings view controls
@onready var music_slider: HSlider = $ModalPanel/Center/Card/Margin/VBox/SettingsContainer/MusicRow/MusicSlider
@onready var music_val_label: Label = $ModalPanel/Center/Card/Margin/VBox/SettingsContainer/MusicRow/ValLabel
@onready var sfx_slider: HSlider = $ModalPanel/Center/Card/Margin/VBox/SettingsContainer/SFXRow/SFXSlider
@onready var sfx_val_label: Label = $ModalPanel/Center/Card/Margin/VBox/SettingsContainer/SFXRow/ValLabel
@onready var mouse_slider: HSlider = $ModalPanel/Center/Card/Margin/VBox/SettingsContainer/MouseRow/MouseSlider
@onready var mouse_val_label: Label = $ModalPanel/Center/Card/Margin/VBox/SettingsContainer/MouseRow/ValLabel
@onready var mobile_slider: HSlider = $ModalPanel/Center/Card/Margin/VBox/SettingsContainer/MobileRow/MobileSlider
@onready var mobile_val_label: Label = $ModalPanel/Center/Card/Margin/VBox/SettingsContainer/MobileRow/ValLabel
@onready var low_quality_btn: Button = get_node_or_null("ModalPanel/Center/Card/Margin/VBox/SettingsContainer/QualityRow/QualityButtons/LowButton")
@onready var med_quality_btn: Button = get_node_or_null("ModalPanel/Center/Card/Margin/VBox/SettingsContainer/QualityRow/QualityButtons/MedButton")
@onready var high_quality_btn: Button = get_node_or_null("ModalPanel/Center/Card/Margin/VBox/SettingsContainer/QualityRow/QualityButtons/HighButton")
@onready var settings_back_button: Button = $ModalPanel/Center/Card/Margin/VBox/SettingsContainer/BackButton


func _ready() -> void:
	if not is_in_group("pause_modal"):
		add_to_group("pause_modal")
	process_mode = Node.PROCESS_MODE_ALWAYS
	modal_panel.visible = false
	_show_main_view()

	# Connect main buttons
	if resume_button != null:
		resume_button.pressed.connect(_on_resume_pressed)
	if restart_button != null:
		restart_button.pressed.connect(_on_restart_pressed)
	if settings_button != null:
		settings_button.pressed.connect(_on_settings_pressed)
	if menu_button != null:
		menu_button.pressed.connect(_on_menu_pressed)

	# Connect settings controls
	if music_slider != null:
		music_slider.value_changed.connect(_on_music_slider_changed)
	if sfx_slider != null:
		sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	if mouse_slider != null:
		mouse_slider.value_changed.connect(_on_mouse_slider_changed)
	if mobile_slider != null:
		mobile_slider.value_changed.connect(_on_mobile_slider_changed)
	if settings_back_button != null:
		settings_back_button.pressed.connect(_on_settings_back_pressed)

	if low_quality_btn != null:
		low_quality_btn.pressed.connect(func(): _set_graphics_quality("low"))
	if med_quality_btn != null:
		med_quality_btn.pressed.connect(func(): _set_graphics_quality("medium"))
	if high_quality_btn != null:
		high_quality_btn.pressed.connect(func(): _set_graphics_quality("high"))

	var gm = get_node_or_null("/root/GraphicsManager")
	if gm != null:
		gm.quality_changed.connect(_on_quality_changed)
		_update_quality_buttons(gm.current_quality)

	_sync_settings_from_save()

	# Connect to GameManager state
	if get_node_or_null("/root/GameManager") != null:
		GameManager.game_state_changed.connect(_on_game_state_changed)


func _sync_settings_from_save() -> void:
	if get_node_or_null("/root/SaveManager") != null:
		if music_slider != null:
			music_slider.value = SaveManager.music_volume * 100.0
			music_val_label.text = "%d%%" % int(music_slider.value)
		if sfx_slider != null:
			sfx_slider.value = SaveManager.sfx_volume * 100.0
			sfx_val_label.text = "%d%%" % int(sfx_slider.value)
		if mouse_slider != null:
			mouse_slider.value = SaveManager.mouse_sensitivity
			mouse_val_label.text = "%.1fx" % mouse_slider.value
		if mobile_slider != null:
			mobile_slider.value = SaveManager.mobile_sensitivity
			mobile_val_label.text = "%.1fx" % mobile_slider.value


func _on_game_state_changed(new_state: int, _previous_state: int) -> void:
	if new_state == GameManager.GameState.PAUSED:
		show_modal()
	elif new_state != GameManager.GameState.PAUSED and modal_panel.visible:
		hide_modal()


func _unhandled_input(event: InputEvent) -> void:
	if not modal_panel.visible:
		return

	if event.is_action_pressed("ui_cancel"):
		if settings_container != null and settings_container.visible:
			_show_main_view()
			get_viewport().set_input_as_handled()
		else:
			_on_resume_pressed()
			get_viewport().set_input_as_handled()


func show_modal() -> void:
	# Avoid opening if Game Over is active
	if get_node_or_null("/root/GameManager") != null and GameManager.current_state == GameManager.GameState.GAME_OVER:
		return

	_sync_settings_from_save()
	_show_main_view()
	modal_panel.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func hide_modal() -> void:
	modal_panel.visible = false
	_show_main_view()


func is_modal_visible() -> bool:
	return modal_panel != null and modal_panel.visible


func _show_main_view() -> void:
	if main_container != null:
		main_container.visible = true
	if settings_container != null:
		settings_container.visible = false


func _show_settings_view() -> void:
	if main_container != null:
		main_container.visible = false
	if settings_container != null:
		settings_container.visible = true


func _on_resume_pressed() -> void:
	hide_modal()
	game_resumed.emit()
	if get_node_or_null("/root/GameManager") != null:
		GameManager.resume_game()
	else:
		get_tree().paused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_restart_pressed() -> void:
	hide_modal()
	game_restarted.emit()
	if get_node_or_null("/root/GameManager") != null:
		GameManager.restart_game()
	else:
		get_tree().paused = false
		get_tree().reload_current_scene.call_deferred()


func _on_settings_pressed() -> void:
	_show_settings_view()


func _on_settings_back_pressed() -> void:
	_show_main_view()


func _on_menu_pressed() -> void:
	hide_modal()
	if get_node_or_null("/root/GameManager") != null:
		get_tree().paused = false
		GameManager.change_state(GameManager.GameState.HOME)
		get_tree().reload_current_scene.call_deferred()
	else:
		get_tree().paused = false
		get_tree().reload_current_scene.call_deferred()


func _on_music_slider_changed(val: float) -> void:
	var fraction = val / 100.0
	music_val_label.text = "%d%%" % int(val)
	if get_node_or_null("/root/AudioManager") != null:
		AudioManager.set_music_volume(fraction)
	if get_node_or_null("/root/SaveManager") != null:
		SaveManager.music_volume = fraction
		SaveManager.save_game()


func _on_sfx_slider_changed(val: float) -> void:
	var fraction = val / 100.0
	sfx_val_label.text = "%d%%" % int(val)
	if get_node_or_null("/root/AudioManager") != null:
		AudioManager.set_sfx_volume(fraction)
	if get_node_or_null("/root/SaveManager") != null:
		SaveManager.sfx_volume = fraction
		SaveManager.save_game()


func _on_mouse_slider_changed(val: float) -> void:
	mouse_val_label.text = "%.1fx" % val
	if get_node_or_null("/root/SaveManager") != null:
		SaveManager.mouse_sensitivity = val
		SaveManager.save_game()
	var player = get_tree().get_first_node_in_group("player")
	if player != null and "mouse_sensitivity_factor" in player:
		player.mouse_sensitivity_factor = val


func _on_mobile_slider_changed(val: float) -> void:
	mobile_val_label.text = "%.1fx" % val
	if get_node_or_null("/root/SaveManager") != null:
		SaveManager.mobile_sensitivity = val
		SaveManager.save_game()


func _set_graphics_quality(quality: String) -> void:
	var gm = get_node_or_null("/root/GraphicsManager")
	if gm != null and gm.has_method("set_quality"):
		gm.set_quality(quality)
	_update_quality_buttons(quality)


func _on_quality_changed(new_qual: String) -> void:
	_update_quality_buttons(new_qual)


func _update_quality_buttons(current_qual: String) -> void:
	var active_color = Color(0.3, 0.8, 1.0, 1.0)
	var normal_color = Color(0.7, 0.7, 0.7, 1.0)
	if low_quality_btn != null:
		low_quality_btn.modulate = active_color if current_qual == "low" else normal_color
	if med_quality_btn != null:
		med_quality_btn.modulate = active_color if current_qual == "medium" else normal_color
	if high_quality_btn != null:
		high_quality_btn.modulate = active_color if current_qual == "high" else normal_color
