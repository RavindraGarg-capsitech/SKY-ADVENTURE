extends Control

signal jump_requested

var input_vector: Vector2 = Vector2.ZERO
var touch_index: int = -1
var knob_offset: Vector2 = Vector2.ZERO
var touch_start_position: Vector2 = Vector2.ZERO

const KNOB_RADIUS: float = 30.0
const BASE_RADIUS: float = 85.0
const MAX_DISTANCE: float = 48.0
const CENTER_TAP_RADIUS: float = 35.0
const TAP_MAX_MOVEMENT: float = 15.0


func _ready() -> void:
	custom_minimum_size = Vector2(180, 180)
	queue_redraw()


func _draw() -> void:
	var center := size / 2.0

	draw_circle(center, BASE_RADIUS, Color(0.1, 0.1, 0.1, 0.45))
	draw_arc(center, BASE_RADIUS, 0.0, TAU, 64,
		Color(1, 1, 1, 0.8), 3.0)

	draw_circle(center + knob_offset, KNOB_RADIUS,
		Color(0.85, 0.9, 1.0, 0.95))
	draw_arc(center + knob_offset, KNOB_RADIUS, 0.0, TAU, 48,
		Color(0.15, 0.2, 0.3, 1.0), 3.0)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if touch_index == -1 and get_global_rect().has_point(event.position):
				touch_index = event.index
				touch_start_position = event.position
				_update_stick(event.position)

		elif event.index == touch_index:
			var movement: float = event.position.distance_to(touch_start_position)
			var local_start: Vector2 = \
				get_global_transform_with_canvas().affine_inverse() * touch_start_position
			var distance_from_center := local_start.distance_to(size / 2.0)

			if (
				movement <= TAP_MAX_MOVEMENT
				and distance_from_center <= CENTER_TAP_RADIUS
			):
				jump_requested.emit()

			_reset_stick()

	elif event is InputEventScreenDrag:
		if event.index == touch_index:
			_update_stick(event.position)


func _update_stick(screen_pos: Vector2) -> void:
	var local_pos: Vector2 = \
		get_global_transform_with_canvas().affine_inverse() * screen_pos

	var offset: Vector2 = local_pos - size / 2.0

	if offset.length() > MAX_DISTANCE:
		offset = offset.normalized() * MAX_DISTANCE

	knob_offset = offset
	input_vector = offset / MAX_DISTANCE
	queue_redraw()


func _reset_stick() -> void:
	touch_index = -1
	knob_offset = Vector2.ZERO
	input_vector = Vector2.ZERO
	queue_redraw()
