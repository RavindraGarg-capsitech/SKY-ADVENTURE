
extends Control

## DamageIndicator: Directional red damage overlay
## Full-width and full-height strips covering all four screen edges.
## Softer red intensity with smooth gradient fading.

enum Side {
	TOP = 0,
	BOTTOM = 1,
	LEFT = 2,
	RIGHT = 3
}

enum Corner {
	TOP_LEFT = 0,
	TOP_RIGHT = 1,
	BOTTOM_LEFT = 2,
	BOTTOM_RIGHT = 3
}

enum Direction {
	TOP = 0,
	TOP_RIGHT = 1,
	RIGHT = 2,
	BOTTOM_RIGHT = 3,
	BOTTOM = 4,
	BOTTOM_LEFT = 5,
	LEFT = 6,
	TOP_LEFT = 7
}

const EDGE_INSET_RATIO: float = 0.20
const FADE_OUT_TIME: float = 0.55
const MAX_OPACITY: float = 0.65

var sides: Dictionary = {}
var corners: Dictionary = {}
var tweens: Dictionary = {}


func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_edge_indicators()


func _setup_edge_indicators() -> void:
	# Softer transparent red gradient
	var red_origin = Color(1.0, 0.02, 0.02, MAX_OPACITY)
	var red_mid = Color(0.95, 0.02, 0.02, 0.30)
	var red_transparent = Color(0.85, 0.0, 0.0, 0.0)

	# TOP EDGE
	var top_tex = _create_linear_gradient(
		red_origin,
		red_mid,
		red_transparent,
		Vector2(0.5, 0.0),
		Vector2(0.5, 1.0)
	)

	var top_rect = _create_edge_rect("TopEdge", top_tex)
	top_rect.anchor_left = 0.0
	top_rect.anchor_right = 1.0
	top_rect.anchor_top = 0.0
	top_rect.anchor_bottom = EDGE_INSET_RATIO
	_set_rect_offsets(top_rect)
	sides[Side.TOP] = top_rect

	# BOTTOM EDGE
	var bottom_tex = _create_linear_gradient(
		red_origin,
		red_mid,
		red_transparent,
		Vector2(0.5, 1.0),
		Vector2(0.5, 0.0)
	)

	var bottom_rect = _create_edge_rect("BottomEdge", bottom_tex)
	bottom_rect.anchor_left = 0.0
	bottom_rect.anchor_right = 1.0
	bottom_rect.anchor_top = 1.0 - EDGE_INSET_RATIO
	bottom_rect.anchor_bottom = 1.0
	_set_rect_offsets(bottom_rect)
	sides[Side.BOTTOM] = bottom_rect

	# LEFT EDGE
	var left_tex = _create_linear_gradient(
		red_origin,
		red_mid,
		red_transparent,
		Vector2(0.0, 0.5),
		Vector2(1.0, 0.5)
	)

	var left_rect = _create_edge_rect("LeftEdge", left_tex)
	left_rect.anchor_left = 0.0
	left_rect.anchor_right = EDGE_INSET_RATIO
	left_rect.anchor_top = 0.0
	left_rect.anchor_bottom = 1.0
	_set_rect_offsets(left_rect)
	sides[Side.LEFT] = left_rect

	# RIGHT EDGE
	var right_tex = _create_linear_gradient(
		red_origin,
		red_mid,
		red_transparent,
		Vector2(1.0, 0.5),
		Vector2(0.0, 0.5)
	)

	var right_rect = _create_edge_rect("RightEdge", right_tex)
	right_rect.anchor_left = 1.0 - EDGE_INSET_RATIO
	right_rect.anchor_right = 1.0
	right_rect.anchor_top = 0.0
	right_rect.anchor_bottom = 1.0
	_set_rect_offsets(right_rect)
	sides[Side.RIGHT] = right_rect

	# Backwards compatibility
	corners[Corner.TOP_LEFT] = top_rect
	corners[Corner.TOP_RIGHT] = top_rect
	corners[Corner.BOTTOM_LEFT] = bottom_rect
	corners[Corner.BOTTOM_RIGHT] = bottom_rect


func _set_rect_offsets(rect: Control) -> void:
	rect.offset_left = 0.0
	rect.offset_top = 0.0
	rect.offset_right = 0.0
	rect.offset_bottom = 0.0


func _create_linear_gradient(
	color_start: Color,
	color_mid: Color,
	color_end: Color,
	from: Vector2,
	to: Vector2
) -> GradientTexture2D:

	var grad = Gradient.new()
	grad.colors = PackedColorArray([
		color_start,
		color_mid,
		color_end
	])
	grad.offsets = PackedFloat32Array([
		0.0,
		0.45,
		1.0
	])

	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = from
	tex.fill_to = to
	tex.width = 64
	tex.height = 64

	return tex


func _create_edge_rect(
	edge_name: String,
	texture: Texture2D
) -> TextureRect:

	var rect = TextureRect.new()
	rect.name = edge_name
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.modulate.a = 0.0

	add_child(rect)

	return rect


## Detect attacker direction relative to player camera.
func show_damage_direction(
	attacker_pos: Vector3,
	player: Node3D
) -> void:

	if attacker_pos == Vector3.INF or not is_instance_valid(player):
		_flash_all_sides()
		return

	var cam: Camera3D = player.get_node_or_null("%Camera3D") as Camera3D

	if cam == null:
		cam = player.find_child(
			"Camera3D",
			true,
			false
		) as Camera3D

	var local_pos: Vector3

	if cam != null:
		local_pos = cam.global_transform.affine_inverse() * attacker_pos
	else:
		local_pos = player.global_transform.affine_inverse() * attacker_pos

	var angle: float = atan2(local_pos.x, -local_pos.z)

	var dir_idx: int = angle_to_direction_index(angle)

	flash_direction(dir_idx)


## Convert angle into 8-way direction.
static func angle_to_direction_index(angle: float) -> int:

	var octant = roundi(angle / (PI / 4.0))

	match octant:
		0:
			return Direction.TOP
		1:
			return Direction.TOP_RIGHT
		2:
			return Direction.RIGHT
		3:
			return Direction.BOTTOM_RIGHT
		4, -4:
			return Direction.BOTTOM
		-3:
			return Direction.BOTTOM_LEFT
		-2:
			return Direction.LEFT
		-1:
			return Direction.TOP_LEFT
		_:
			return Direction.TOP


## Display directional damage on full screen edges.
func flash_direction(dir_idx: int) -> void:

	match dir_idx:

		Direction.TOP:
			flash_side(Side.TOP, 0.75)
			flash_side(Side.LEFT, 0.35)
			flash_side(Side.RIGHT, 0.35)

		Direction.TOP_RIGHT:
			flash_side(Side.TOP, 0.70)
			flash_side(Side.RIGHT, 0.70)

		Direction.RIGHT:
			flash_side(Side.RIGHT, 0.75)
			flash_side(Side.TOP, 0.35)
			flash_side(Side.BOTTOM, 0.35)

		Direction.BOTTOM_RIGHT:
			flash_side(Side.BOTTOM, 0.70)
			flash_side(Side.RIGHT, 0.70)

		Direction.BOTTOM:
			flash_side(Side.BOTTOM, 0.75)
			flash_side(Side.LEFT, 0.35)
			flash_side(Side.RIGHT, 0.35)

		Direction.BOTTOM_LEFT:
			flash_side(Side.BOTTOM, 0.70)
			flash_side(Side.LEFT, 0.70)

		Direction.LEFT:
			flash_side(Side.LEFT, 0.75)
			flash_side(Side.TOP, 0.35)
			flash_side(Side.BOTTOM, 0.35)

		Direction.TOP_LEFT:
			flash_side(Side.TOP, 0.70)
			flash_side(Side.LEFT, 0.70)

		_:
			_flash_all_sides()


## Flash a specific edge and smoothly fade it.
func flash_side(
	side_idx: int,
	intensity: float = 0.75
) -> void:

	if not sides.has(side_idx):
		return

	var rect: TextureRect = sides[side_idx]

	if rect == null:
		return

	# Stop previous tween for this edge.
	if tweens.has(side_idx):
		var old_tween = tweens[side_idx] as Tween

		if old_tween != null and old_tween.is_valid():
			old_tween.kill()

	# Apply intensity.
	rect.modulate.a = clampf(intensity, 0.0, 1.0)

	# Smooth fade out.
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)

	tweens[side_idx] = tween

	tween.tween_property(
		rect,
		"modulate:a",
		0.0,
		FADE_OUT_TIME
	)


## Backwards compatibility for corner-based calls.
func flash_corner(
	corner_idx: int,
	intensity: float = 0.75
) -> void:

	match corner_idx:

		Corner.TOP_LEFT:
			flash_side(Side.TOP, intensity)
			flash_side(Side.LEFT, intensity)

		Corner.TOP_RIGHT:
			flash_side(Side.TOP, intensity)
			flash_side(Side.RIGHT, intensity)

		Corner.BOTTOM_LEFT:
			flash_side(Side.BOTTOM, intensity)
			flash_side(Side.LEFT, intensity)

		Corner.BOTTOM_RIGHT:
			flash_side(Side.BOTTOM, intensity)
			flash_side(Side.RIGHT, intensity)


## Fallback when attacker position is unknown.
func _flash_all_sides() -> void:

	flash_side(Side.TOP, 0.75)
	flash_side(Side.BOTTOM, 0.75)
	flash_side(Side.LEFT, 0.75)
	flash_side(Side.RIGHT, 0.75)


func _flash_all_corners() -> void:
	_flash_all_sides()
