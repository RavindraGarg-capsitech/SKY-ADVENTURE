extends CanvasLayer

## MobileControls: Provides on-screen virtual joystick, camera touch-drag, and shoot/jump buttons.

@export var force_show: bool = false

@onready var joystick: Control = $Joystick
@onready var shoot_button: Button = $ShootButton
@onready var jump_button: Button = get_node_or_null("JumpButton")

var is_dragging_joystick: bool = false
var joystick_touch_index: int = -1
var joystick_center: Vector2 = Vector2.ZERO
var joystick_radius: float = 80.0
var current_joystick_offset: Vector2 = Vector2.ZERO

var is_dragging_look: bool = false
var look_touch_index: int = -1

var player_node: Node3D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Detect mobile touch environment - auto hide on desktop PC
	var is_touch: bool = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or OS.get_name() in ["Android", "iOS"] or force_show
	visible = is_touch

	if joystick != null:
		joystick_center = joystick.global_position + joystick.size * 0.5
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

	# Apply safe area padding for notch/cutouts on mobile
	var left_pad = float(safe_area.position.x)
	var right_pad = float(win_size.x - (safe_area.position.x + safe_area.size.x))
	var bottom_pad = float(win_size.y - (safe_area.position.y + safe_area.size.y))

	if joystick != null and left_pad > 0:
		joystick.offset_left += left_pad
		joystick.offset_right += left_pad
		joystick_center = joystick.global_position + joystick.size * 0.5

	if shoot_button != null and right_pad > 0:
		shoot_button.offset_left -= right_pad
		shoot_button.offset_right -= right_pad

	if jump_button != null and right_pad > 0:
		jump_button.offset_left -= right_pad
		jump_button.offset_right -= right_pad


func _find_player() -> void:
	player_node = get_tree().get_first_node_in_group("player") as Node3D


func _setup_buttons() -> void:
	# Beautiful translucent circular/rounded style for mobile action buttons
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.12, 0.18, 0.28, 0.65)
	style_normal.corner_radius_top_left = 30
	style_normal.corner_radius_top_right = 30
	style_normal.corner_radius_bottom_left = 30
	style_normal.corner_radius_bottom_right = 30
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = Color(0.4, 0.7, 1.0, 0.7)

	var style_pressed = style_normal.duplicate() as StyleBoxFlat
	style_pressed.bg_color = Color(0.2, 0.5, 0.9, 0.85)
	style_pressed.border_color = Color(1.0, 1.0, 1.0, 0.95)

	if shoot_button != null:
		shoot_button.add_theme_stylebox_override("normal", style_normal)
		shoot_button.add_theme_stylebox_override("pressed", style_pressed)
		shoot_button.add_theme_stylebox_override("hover", style_normal)
		shoot_button.button_down.connect(_on_shoot_down)
		shoot_button.button_up.connect(_on_shoot_up)

	if jump_button != null:
		jump_button.add_theme_stylebox_override("normal", style_normal)
		jump_button.add_theme_stylebox_override("pressed", style_pressed)
		jump_button.add_theme_stylebox_override("hover", style_normal)
		jump_button.button_down.connect(_on_jump_down)
		jump_button.button_up.connect(_on_jump_up)


func _on_joystick_draw() -> void:
	if joystick == null:
		return
	var center = joystick.size * 0.5
	# Outer base ring
	joystick.draw_circle(center, joystick_radius, Color(0.10, 0.15, 0.25, 0.45))
	joystick.draw_arc(center, joystick_radius, 0.0, TAU, 36, Color(0.4, 0.75, 1.0, 0.7), 3.0)

	# Draggable inner thumb knob
	var knob_center = center + current_joystick_offset
	joystick.draw_circle(knob_center, 34.0, Color(0.25, 0.55, 0.95, 0.8))
	joystick.draw_arc(knob_center, 34.0, 0.0, TAU, 28, Color(1.0, 1.0, 1.0, 0.9), 2.5)


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)


func _is_point_on_ui_button(pos: Vector2) -> bool:
	if shoot_button != null and shoot_button.is_visible_in_tree() and shoot_button.get_global_rect().has_point(pos):
		return true
	if jump_button != null and jump_button.is_visible_in_tree() and jump_button.get_global_rect().has_point(pos):
		return true
	var pause_btn = get_tree().get_first_node_in_group("pause_button")
	if pause_btn is Control and pause_btn.is_visible_in_tree() and pause_btn.get_global_rect().has_point(pos):
		return true
	return false


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	var viewport_width = get_viewport().get_visible_rect().size.x

	if event.pressed:
		# Don't capture touches on UI buttons (shoot, jump, pause)
		if _is_point_on_ui_button(event.position):
			return

		# Touch on left half of screen -> Joystick
		if event.position.x < viewport_width * 0.45:
			if joystick_touch_index == -1:
				joystick_touch_index = event.index
				is_dragging_joystick = true
				if joystick != null:
					joystick.global_position = event.position - joystick.size * 0.5
					joystick_center = event.position
					current_joystick_offset = Vector2.ZERO
					joystick.queue_redraw()
		# Touch on right half of screen -> Camera Look
		elif event.position.x >= viewport_width * 0.45:
			if look_touch_index == -1:
				look_touch_index = event.index
				is_dragging_look = true
	else:
		if event.index == joystick_touch_index:
			_reset_joystick()
		elif event.index == look_touch_index:
			is_dragging_look = false
			look_touch_index = -1


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index == joystick_touch_index and is_dragging_joystick:
		var offset: Vector2 = event.position - joystick_center
		var clamped_offset = offset.limit_length(joystick_radius)
		current_joystick_offset = clamped_offset
		if joystick != null:
			joystick.queue_redraw()

		var norm_input = clamped_offset / joystick_radius
		_apply_movement_input(norm_input)

	elif event.index == look_touch_index and is_dragging_look:
		if not is_instance_valid(player_node):
			_find_player()

		if is_instance_valid(player_node) and player_node.has_method("_rotate_camera"):
			var mob_sens: float = 1.0
			var sm = get_node_or_null("/root/SaveManager")
			if sm != null and "mobile_sensitivity" in sm:
				mob_sens = sm.mobile_sensitivity
			player_node._rotate_camera(event.relative * 0.4 * mob_sens)


func _apply_movement_input(vec: Vector2) -> void:
	# Feed into Godot Input map
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
		joystick.queue_redraw()
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_forward")
	Input.action_release("move_back")


func _on_shoot_down() -> void:
	Input.action_press("shoot")


func _on_shoot_up() -> void:
	Input.action_release("shoot")


func _on_jump_down() -> void:
	Input.action_press("jump")


func _on_jump_up() -> void:
	Input.action_release("jump")
