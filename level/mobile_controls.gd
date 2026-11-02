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

var is_dragging_look: bool = false
var look_touch_index: int = -1

var player_node: Node3D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Detect mobile touch environment
	var is_touch: bool = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or force_show
	visible = is_touch

	if joystick != null:
		joystick_center = joystick.global_position + joystick.size * 0.5

	_setup_buttons()
	_find_player()


func _find_player() -> void:
	player_node = get_tree().get_first_node_in_group("player") as Node3D


func _setup_buttons() -> void:
	if shoot_button != null:
		shoot_button.button_down.connect(_on_shoot_down)
		shoot_button.button_up.connect(_on_shoot_up)

	if jump_button != null:
		jump_button.button_down.connect(_on_jump_down)
		jump_button.button_up.connect(_on_jump_up)


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	var viewport_width = get_viewport().get_visible_rect().size.x

	if event.pressed:
		# Touch on left half of screen -> Joystick
		if event.position.x < viewport_width * 0.45:
			if joystick_touch_index == -1:
				joystick_touch_index = event.index
				is_dragging_joystick = true
				if joystick != null:
					joystick.global_position = event.position - joystick.size * 0.5
					joystick_center = event.position
		# Touch on right half of screen (not on buttons) -> Camera Look
		elif event.position.x >= viewport_width * 0.45:
			if look_touch_index == -1:
				# Avoid hijacking button presses
				if shoot_button != null and shoot_button.get_global_rect().has_point(event.position):
					return
				if jump_button != null and jump_button.get_global_rect().has_point(event.position):
					return

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
		var norm_input = clamped_offset / joystick_radius

		_apply_movement_input(norm_input)

	elif event.index == look_touch_index and is_dragging_look:
		if not is_instance_valid(player_node):
			_find_player()

		if is_instance_valid(player_node) and player_node.has_method("_rotate_camera"):
			var mob_sens: float = 1.0
			if get_node_or_null("/root/SaveManager") != null:
				mob_sens = SaveManager.mobile_sensitivity
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
