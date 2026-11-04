extends CanvasLayer

## MobileControls: Two-side mobile touch control system for SKY ADVENTURE.
## Left half: Fullscreen touch-to-drag Virtual Joystick for player movement.
## Right half: Hold anywhere to continuously shoot bullets and drag to aim camera.
## Dedicated mobile-friendly JumpButton on the right side.

@export var force_show: bool = false

@onready var joystick: Control = $Joystick
@onready var jump_button: Button = get_node_or_null("JumpButton")

# Joystick configuration & state (enlarged for mobile usability)
var is_dragging_joystick: bool = false
var joystick_touch_index: int = -1
var joystick_center: Vector2 = Vector2.ZERO
var default_joystick_center: Vector2 = Vector2.ZERO
var default_joystick_pos: Vector2 = Vector2.ZERO
var joystick_radius: float = 120.0
var knob_radius: float = 48.0
var current_joystick_offset: Vector2 = Vector2.ZERO

# Right-side shooting and camera look state
var is_shooting: bool = false
var shoot_touch_index: int = -1
var jump_touch_index: int = -1

var player_node: Node3D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Detect mobile touch environment - auto hide on desktop PC
	var is_mobile_os: bool = OS.has_feature("mobile") or OS.get_name() in ["Android", "iOS"]
	var is_touch: bool = is_mobile_os or force_show
	visible = is_touch

	if joystick != null:
		default_joystick_pos = joystick.global_position
		default_joystick_center = default_joystick_pos + joystick.size * 0.5
		joystick_center = default_joystick_center
		if not joystick.draw.is_connected(_on_joystick_draw):
			joystick.draw.connect(_on_joystick_draw)
		joystick.queue_redraw()

	_apply_safe_area()
	_setup_buttons()
	_find_player()


func _apply_safe_area() -> void:
	var safe_area = DisplayServer.get_display_safe_area()
	var win_size = DisplayServer.window_get_size()
	if win_size.x <= 0 or win_size.y <= 0 or safe_area.size.x <= 0:
		return

	# Apply safe area padding for mobile notch/cutouts
	var left_pad = float(safe_area.position.x)
	var right_pad = float(win_size.x - (safe_area.position.x + safe_area.size.x))

	if joystick != null and left_pad > 0:
		joystick.offset_left += left_pad
		joystick.offset_right += left_pad
		default_joystick_pos = joystick.global_position
		default_joystick_center = default_joystick_pos + joystick.size * 0.5
		joystick_center = default_joystick_center

	if jump_button != null and right_pad > 0:
		jump_button.offset_left -= right_pad
		jump_button.offset_right -= right_pad


func _find_player() -> void:
	player_node = get_tree().get_first_node_in_group("player") as Node3D
	if is_instance_valid(player_node) and player_node.has_method("set_mobile_mode"):
		player_node.set_mobile_mode(visible)


func _setup_buttons() -> void:
	# Beautiful translucent circular style for mobile JUMP button
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.12, 0.20, 0.32, 0.70)
	style_normal.corner_radius_top_left = 65
	style_normal.corner_radius_top_right = 65
	style_normal.corner_radius_bottom_left = 65
	style_normal.corner_radius_bottom_right = 65
	style_normal.border_width_left = 3
	style_normal.border_width_top = 3
	style_normal.border_width_right = 3
	style_normal.border_width_bottom = 3
	style_normal.border_color = Color(0.4, 0.8, 1.0, 0.85)

	var style_pressed = style_normal.duplicate() as StyleBoxFlat
	style_pressed.bg_color = Color(0.25, 0.65, 1.0, 0.90)
	style_pressed.border_color = Color(1.0, 1.0, 1.0, 1.0)

	if jump_button != null:
		jump_button.add_theme_stylebox_override("normal", style_normal)
		jump_button.add_theme_stylebox_override("pressed", style_pressed)
		jump_button.add_theme_stylebox_override("hover", style_normal)
		if not jump_button.button_down.is_connected(_on_jump_down):
			jump_button.button_down.connect(_on_jump_down)
		if not jump_button.button_up.is_connected(_on_jump_up):
			jump_button.button_up.connect(_on_jump_up)


func _on_joystick_draw() -> void:
	if joystick == null:
		return
	var center = joystick.size * 0.5
	var is_active = (joystick_touch_index != -1)

	# Colors: subtle translucent when idle, bright neon blue when touched
	var base_fill = Color(0.08, 0.14, 0.24, 0.55 if is_active else 0.25)
	var base_ring = Color(0.40, 0.80, 1.0, 0.85 if is_active else 0.40)
	var knob_fill = Color(0.25, 0.65, 1.0, 0.90 if is_active else 0.45)
	var knob_ring = Color(1.0, 1.0, 1.0, 0.95 if is_active else 0.60)

	# 1. Outer base disc and ring (Radius 120.0px, ~240px wide)
	joystick.draw_circle(center, joystick_radius, base_fill)
	joystick.draw_arc(center, joystick_radius, 0.0, TAU, 48, base_ring, 3.5)

	# Directional cardinal ticks for tactile arcade feel
	var tick_len = 10.0
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var dir = Vector2(cos(angle), sin(angle))
		joystick.draw_line(center + dir * (joystick_radius - tick_len), center + dir * (joystick_radius + 4.0), base_ring, 2.5)

	# 2. Draggable thumb knob (Radius 48.0px, ~96px wide)
	var knob_pos = center + current_joystick_offset
	joystick.draw_circle(knob_pos, knob_radius, knob_fill)
	joystick.draw_arc(knob_pos, knob_radius, 0.0, TAU, 36, knob_ring, 3.0)
	# Center dot
	joystick.draw_circle(knob_pos, 8.0, Color(1.0, 1.0, 1.0, 0.85 if is_active else 0.5))


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)


func _is_point_on_jump_button(pos: Vector2) -> bool:
	if jump_button != null and jump_button.is_visible_in_tree():
		return jump_button.get_global_rect().has_point(pos)
	return false


func _is_point_on_ui(pos: Vector2) -> bool:
	# Pause button on HUD
	var pause_btn = get_tree().get_first_node_in_group("pause_button")
	if pause_btn is Control and pause_btn.is_visible_in_tree() and pause_btn.get_global_rect().has_point(pos):
		return true

	# Check if any modal panel is currently visible and open
	var pause_modal = get_tree().get_first_node_in_group("pause_modal")
	if pause_modal != null and pause_modal.has_method("is_modal_visible") and pause_modal.is_modal_visible():
		return true

	var upg_modal = get_tree().get_first_node_in_group("upgrade_modal")
	if upg_modal != null:
		var panel = upg_modal.get_node_or_null("ModalPanel")
		if panel != null and panel.visible:
			return true

	var game_over_modal = get_tree().get_first_node_in_group("game_over_modal")
	if game_over_modal != null:
		var panel = game_over_modal.get_node_or_null("ModalPanel")
		if panel != null and panel.visible:
			return true

	return false


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	var viewport_width = get_viewport().get_visible_rect().size.x
	var half_width = viewport_width * 0.5

	if event.pressed:
		# Check if touching Jump button
		if _is_point_on_jump_button(event.position):
			jump_touch_index = event.index
			_on_jump_down()
			return

		# Check if touching other UI elements (Pause button, open modals)
		if _is_point_on_ui(event.position):
			return

		# LEFT SIDE: Movement ONLY (never triggers shooting)
		if event.position.x < half_width:
			if joystick_touch_index == -1:
				joystick_touch_index = event.index
				is_dragging_joystick = true
				if joystick != null:
					# Center the virtual joystick at the initial touch point
					joystick.global_position = event.position - joystick.size * 0.5
					joystick_center = event.position
					current_joystick_offset = Vector2.ZERO
					joystick.queue_redraw()

		# RIGHT SIDE: Continuous Shooting + Camera Aiming (never triggers movement)
		else:
			if shoot_touch_index == -1:
				shoot_touch_index = event.index
				is_shooting = true
				if not is_instance_valid(player_node):
					_find_player()
				if is_instance_valid(player_node) and player_node.has_method("set_mobile_shooting"):
					player_node.set_mobile_shooting(true)
				Input.action_press("shoot")
	else:
		# Touch release handling per tracked index
		if event.index == joystick_touch_index:
			_reset_joystick()

		elif event.index == shoot_touch_index:
			is_shooting = false
			shoot_touch_index = -1
			if not is_instance_valid(player_node):
				_find_player()
			if is_instance_valid(player_node) and player_node.has_method("set_mobile_shooting"):
				player_node.set_mobile_shooting(false)
			Input.action_release("shoot")

		elif event.index == jump_touch_index:
			jump_touch_index = -1
			_on_jump_up()


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	# Left finger drag: update movement vector
	if event.index == joystick_touch_index and is_dragging_joystick:
		var offset: Vector2 = event.position - joystick_center
		var clamped_offset = offset.limit_length(joystick_radius)
		current_joystick_offset = clamped_offset
		if joystick != null:
			joystick.queue_redraw()

		var norm_input = clamped_offset / joystick_radius
		_apply_movement_input(norm_input)

	# Right finger drag: rotate camera while continuous shooting is active
	elif event.index == shoot_touch_index and is_shooting:
		if not is_instance_valid(player_node):
			_find_player()

		if is_instance_valid(player_node) and player_node.has_method("_rotate_camera"):
			var mob_sens: float = 1.0
			var sm = get_node_or_null("/root/SaveManager")
			if sm != null and "mobile_sensitivity" in sm:
				mob_sens = sm.mobile_sensitivity
			player_node._rotate_camera(event.relative * 0.4 * mob_sens)


func _apply_movement_input(vec: Vector2) -> void:
	# Feed into Godot Input map with smooth analog thresholds
	if vec.x < -0.2:
		Input.action_press("move_left", -vec.x)
	else:
		Input.action_release("move_left")

	if vec.x > 0.2:
		Input.action_press("move_right", vec.x)
	else:
		Input.action_release("move_right")

	if vec.y < -0.2:
		Input.action_press("move_forward", -vec.y)
	else:
		Input.action_release("move_forward")

	if vec.y > 0.2:
		Input.action_press("move_back", vec.y)
	else:
		Input.action_release("move_back")


func _reset_joystick() -> void:
	is_dragging_joystick = false
	joystick_touch_index = -1
	current_joystick_offset = Vector2.ZERO
	if joystick != null:
		# Return to default resting position
		joystick.global_position = default_joystick_pos
		joystick_center = default_joystick_center
		joystick.queue_redraw()
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_forward")
	Input.action_release("move_back")


func _release_all_inputs() -> void:
	_reset_joystick()
	if is_shooting or shoot_touch_index != -1:
		is_shooting = false
		shoot_touch_index = -1
		if is_instance_valid(player_node) and player_node.has_method("set_mobile_shooting"):
			player_node.set_mobile_shooting(false)
		Input.action_release("shoot")
	if jump_touch_index != -1:
		jump_touch_index = -1
		Input.action_release("jump")


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_PAUSED:
		_release_all_inputs()


func _on_jump_down() -> void:
	Input.action_press("jump")


func _on_jump_up() -> void:
	Input.action_release("jump")
