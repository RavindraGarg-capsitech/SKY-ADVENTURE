
extends CanvasLayer

@onready var home_panel: Control = $HomePanel
@onready var play_button: Button = $HomePanel/PlayButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	home_panel.show()

	play_button.pressed.connect(_on_play_pressed)


func _on_play_pressed() -> void:
	home_panel.hide()
	get_tree().paused = false

	# Ab gameplay ke liye mouse lock hoga.
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
