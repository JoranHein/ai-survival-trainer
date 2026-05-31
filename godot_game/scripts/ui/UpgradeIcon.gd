extends Control

var upgrade_id := "max_hp"
var accent_color := Color(0.80, 0.68, 0.36, 1.0)
var can_buy := false
var is_maxed := false


func setup(next_upgrade_id: String, next_color: Color, next_can_buy: bool, next_is_maxed: bool) -> void:
	upgrade_id = next_upgrade_id
	accent_color = next_color
	can_buy = next_can_buy
	is_maxed = next_is_maxed
	custom_minimum_size = Vector2(28.0, 28.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(28.0, 28.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var color := accent_color
	if not can_buy and not is_maxed:
		color = accent_color.darkened(0.12)
	if is_maxed:
		color = Color(0.46, 0.95, 0.56, 1.0)
	var line_color := color.lightened(0.28)
	var center := size * 0.5
	match upgrade_id:
		"max_hp":
			_draw_heart(center, color, line_color)
		"attack":
			_draw_sword(center, color, line_color)
		"defense":
			_draw_shield(center, color, line_color)
		"mining_efficiency":
			_draw_pick(center, color, line_color)
		"building_efficiency":
			_draw_hammer(center, color, line_color)
		"farming_yield":
			_draw_sprout(center, color, line_color)
		"warding_power":
			_draw_ward(center, color, line_color)
		"trapcraft":
			_draw_trap(center, color, line_color)
		"regeneration":
			_draw_regen(center, color, line_color)
		"sign_understanding":
			_draw_sign(center, color, line_color)
		_:
			draw_circle(center, 7.0, color)


func _draw_heart(center: Vector2, color: Color, line_color: Color) -> void:
	draw_circle(center + Vector2(-4.2, -3.0), 4.3, color)
	draw_circle(center + Vector2(4.2, -3.0), 4.3, color)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-8.2, -1.2),
		center + Vector2(8.2, -1.2),
		center + Vector2(0.0, 9.5),
	]), color)
	draw_line(center + Vector2(-5.5, 1.0), center + Vector2(0.0, 8.0), line_color, 1.1)
	draw_line(center + Vector2(5.5, 1.0), center + Vector2(0.0, 8.0), line_color, 1.1)


func _draw_sword(center: Vector2, color: Color, line_color: Color) -> void:
	draw_line(center + Vector2(-6.5, 7.0), center + Vector2(7.0, -8.0), line_color, 3.0)
	draw_line(center + Vector2(-8.2, 1.8), center + Vector2(-1.2, 8.0), color.darkened(0.20), 2.2)
	draw_line(center + Vector2(3.0, -5.5), center + Vector2(8.8, -9.8), Color(1.0, 0.92, 0.62, 1.0), 1.2)
	draw_circle(center + Vector2(-8.5, 8.8), 2.3, color)


func _draw_shield(center: Vector2, color: Color, line_color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0.0, -10.0),
		center + Vector2(8.0, -6.0),
		center + Vector2(6.0, 4.0),
		center + Vector2(0.0, 10.0),
		center + Vector2(-6.0, 4.0),
		center + Vector2(-8.0, -6.0),
	])
	draw_colored_polygon(points, color.darkened(0.08))
	draw_polyline(points + PackedVector2Array([points[0]]), line_color, 1.4)
	draw_line(center + Vector2(0.0, -7.2), center + Vector2(0.0, 7.2), line_color.darkened(0.20), 1.1)


func _draw_pick(center: Vector2, color: Color, line_color: Color) -> void:
	draw_arc(center + Vector2(-1.0, -3.5), 8.0, 3.55, 6.05, 14, line_color, 2.0)
	draw_line(center + Vector2(0.0, -1.0), center + Vector2(-7.5, 9.0), color, 3.0)
	draw_line(center + Vector2(5.5, -7.0), center + Vector2(9.5, -4.0), line_color, 1.7)
	draw_circle(center + Vector2(-7.5, 9.0), 1.8, color.darkened(0.20))


func _draw_hammer(center: Vector2, color: Color, line_color: Color) -> void:
	draw_line(center + Vector2(-6.8, 8.0), center + Vector2(3.2, -2.0), color, 3.2)
	draw_rect(Rect2(center + Vector2(-1.5, -9.0), Vector2(12.0, 6.0)), color.darkened(0.08), true)
	draw_rect(Rect2(center + Vector2(-1.5, -9.0), Vector2(12.0, 6.0)), line_color, false, 1.2)
	draw_line(center + Vector2(-4.5, 5.7), center + Vector2(0.3, 10.2), line_color, 1.2)


func _draw_sprout(center: Vector2, color: Color, line_color: Color) -> void:
	draw_line(center + Vector2(0.0, 9.5), center + Vector2(0.0, -5.0), line_color, 2.0)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-1.0, -2.0),
		center + Vector2(-10.0, -6.8),
		center + Vector2(-5.5, 2.0),
	]), color)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(1.0, -4.0),
		center + Vector2(10.0, -8.0),
		center + Vector2(5.8, 1.0),
	]), color.lightened(0.10))
	draw_line(center + Vector2(-8.0, 9.0), center + Vector2(8.0, 9.0), color.darkened(0.25), 1.5)


func _draw_ward(center: Vector2, color: Color, line_color: Color) -> void:
	draw_arc(center, 9.5, 0.0, TAU, 30, line_color, 1.5)
	draw_circle(center, 6.0, Color(color.r, color.g, color.b, 0.58))
	draw_circle(center, 2.8, Color(0.92, 1.0, 1.0, 0.95))
	for angle in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
		draw_line(center, center + Vector2(cos(angle), sin(angle)) * 8.0, line_color.darkened(0.16), 1.0)


func _draw_trap(center: Vector2, color: Color, line_color: Color) -> void:
	for x in [-6.5, 0.0, 6.5]:
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(x, -9.0),
			center + Vector2(x - 4.0, 6.0),
			center + Vector2(x + 4.0, 6.0),
		]), color)
	draw_line(center + Vector2(-10.0, 8.0), center + Vector2(10.0, 8.0), line_color, 1.8)


func _draw_regen(center: Vector2, color: Color, line_color: Color) -> void:
	draw_arc(center, 8.5, -1.1, TAU * 0.70, 24, line_color, 2.0)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-7.3, -1.3),
		center + Vector2(-11.0, -6.2),
		center + Vector2(-4.6, -6.8),
	]), line_color)
	draw_line(center + Vector2(-5.5, 0.0), center + Vector2(5.5, 0.0), color, 2.2)
	draw_line(center + Vector2(0.0, -5.5), center + Vector2(0.0, 5.5), color, 2.2)


func _draw_sign(center: Vector2, color: Color, line_color: Color) -> void:
	var board := Rect2(center + Vector2(-9.0, -8.0), Vector2(18.0, 11.0))
	draw_rect(board, color.darkened(0.12), true)
	draw_rect(board, line_color, false, 1.2)
	draw_line(center + Vector2(0.0, 3.0), center + Vector2(0.0, 10.0), color, 2.0)
	draw_line(center + Vector2(-5.5, -4.5), center + Vector2(5.5, -4.5), line_color.darkened(0.16), 1.0)
	draw_line(center + Vector2(-5.5, -1.0), center + Vector2(3.0, -1.0), line_color.darkened(0.16), 1.0)
