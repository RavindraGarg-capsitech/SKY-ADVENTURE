extends CanvasLayer

var shoot_held: bool = false

@onready var joystick: Control = $Joystick
@onready var shoot_button: Button = $ShootButton


func _ready() -> void:
	_layout_controls()
	get_viewport().size_changed.connect(_layout_controls)

	shoot_button.text = "SHOOT"
	shoot_button.button_down.connect(_on_shoot_down)
	shoot_button.button_up.connect(_on_shoot_up)

	# Keep touch input restricted to the actual button
	shoot_button.mouse_filter = Control.MOUSE_FILTER_STOP


func _layout_controls() -> void:
	var screen_size: Vector2 = get_viewport().get_visible_rect().size

	joystick.size = Vector2(180, 180)
	joystick.position = Vector2(
		35.0,
		screen_size.y - 215.0
	)

	shoot_button.position = Vector2(
		screen_size.x - 165.0,
		screen_size.y - 125.0
	)
	shoot_button.size = Vector2(150.0, 100.0)


func _on_shoot_down() -> void:
	shoot_held = true


func _on_shoot_up() -> void:
	shoot_held = false


func _exit_tree() -> void:
	shoot_held = false
