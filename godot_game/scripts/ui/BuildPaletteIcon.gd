class_name BuildPaletteIcon
extends Control

const ICON_SIZE := Vector2(28.0, 20.0)

var build_type := "wall"
var accent_color := Color(0.70, 0.74, 0.70, 1.0)
var can_afford := true


func setup(next_build_type: String, next_color: Color, affordable: bool) -> void:
	build_type = next_build_type
	accent_color = next_color
	can_afford = affordable
	custom_minimum_size = ICON_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _ready() -> void:
	custom_minimum_size = ICON_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var color := accent_color if can_afford else accent_color.darkened(0.50)
	var line_color := color.lightened(0.28)
	var center := size * 0.5
	match build_type:
		"wall":
			_draw_wall(center, color, line_color)
		"aura_orb":
			_draw_orb(center, color, line_color)
		"spike_trap":
			_draw_spikes(center, color, line_color)
		"bow_tower":
			_draw_tower(center, color, line_color)
		"tar_pit":
			_draw_mud(center, color, line_color)
		"fear_lantern":
			_draw_lantern(center, color, line_color)
		"decoy_idol":
			_draw_decoy(center, color, line_color)
		"thorn_totem":
			_draw_thorns(center, color, line_color)
		"repair_bench":
			_draw_repair(center, color, line_color)
		"storm_rod":
			_draw_storm(center, color, line_color)
		_:
			draw_circle(center, 6.0, color)


func _draw_wall(center: Vector2, color: Color, line_color: Color) -> void:
	var rect := Rect2(center - Vector2(10.0, 7.0), Vector2(20.0, 14.0))
	draw_rect(rect, color.darkened(0.15), true)
	draw_rect(rect, line_color, false, 2.0)
	draw_line(rect.position + Vector2(0.0, 7.0), rect.position + Vector2(20.0, 7.0), line_color.darkened(0.18), 1.3)
	draw_line(rect.position + Vector2(5.0, 0.0), rect.position + Vector2(5.0, 7.0), line_color.darkened(0.22), 1.3)
	draw_line(rect.position + Vector2(14.0, 7.0), rect.position + Vector2(14.0, 14.0), line_color.darkened(0.22), 1.3)


func _draw_orb(center: Vector2, color: Color, line_color: Color) -> void:
	draw_arc(center, 9.2, 0.0, TAU, 32, Color(line_color.r, line_color.g, line_color.b, 0.82), 2.0)
	draw_arc(center, 6.4, -0.3, TAU * 0.72, 22, line_color.lightened(0.18), 1.7)
	draw_circle(center, 5.8, color)
	draw_circle(center, 2.8, Color(0.92, 0.98, 1.0, 0.95))


func _draw_spikes(center: Vector2, color: Color, line_color: Color) -> void:
	for x in [-8.0, 0.0, 8.0]:
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(x, -9.0),
			center + Vector2(x - 5.0, 6.0),
			center + Vector2(x + 5.0, 6.0),
		]), color.lightened(0.12))
	draw_line(center + Vector2(-12.0, 7.5), center + Vector2(12.0, 7.5), line_color, 2.0)


func _draw_tower(center: Vector2, color: Color, line_color: Color) -> void:
	draw_rect(Rect2(center + Vector2(-3.5, -1.0), Vector2(7.0, 10.0)), color.darkened(0.25), true)
	draw_rect(Rect2(center + Vector2(-10.0, -9.0), Vector2(20.0, 8.0)), color, true)
	draw_arc(center + Vector2(-2.0, -5.0), 6.8, -0.9, 0.9, 14, line_color, 2.0)
	draw_line(center + Vector2(-6.0, -5.0), center + Vector2(9.0, -5.0), line_color, 2.0)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(10.5, -5.0),
		center + Vector2(5.0, -8.0),
		center + Vector2(6.0, -2.0),
	]), Color(0.98, 0.90, 0.62, 1.0))


func _draw_mud(center: Vector2, color: Color, line_color: Color) -> void:
	draw_circle(center, 9.0, color.darkened(0.28))
	draw_arc(center, 7.0, 0.2, TAU * 0.90, 24, line_color, 2.0)
	draw_arc(center + Vector2(0.5, 0.0), 4.2, 0.4, TAU * 0.72, 18, line_color.lightened(0.12), 1.5)
	draw_circle(center + Vector2(-5.0, 2.0), 2.3, color.lightened(0.18))
	draw_circle(center + Vector2(5.5, -2.0), 2.0, color.lightened(0.10))


func _draw_lantern(center: Vector2, color: Color, line_color: Color) -> void:
	draw_circle(center, 8.5, Color(color.r, color.g, color.b, 0.30))
	draw_rect(Rect2(center + Vector2(-5.0, -6.5), Vector2(10.0, 13.0)), color.darkened(0.18), true)
	draw_rect(Rect2(center + Vector2(-7.0, -9.0), Vector2(14.0, 4.0)), line_color, true)
	draw_line(center + Vector2(-5.0, -1.0), center + Vector2(5.0, -1.0), line_color.darkened(0.18), 1.2)
	draw_circle(center + Vector2(0.0, 1.5), 4.0, Color(1.0, 0.86, 0.34, 1.0))


func _draw_decoy(center: Vector2, color: Color, line_color: Color) -> void:
	draw_rect(Rect2(center + Vector2(-5.5, -8.5), Vector2(11.0, 17.0)), color.darkened(0.10), true)
	draw_circle(center, 5.4, color.lightened(0.18))
	draw_circle(center, 2.2, Color(0.08, 0.02, 0.04, 1.0))
	draw_arc(center, 6.8, 3.7, 5.7, 14, line_color, 1.5)
	draw_line(center + Vector2(-8.5, 1.0), center + Vector2(-12.5, -5.5), line_color, 2.0)
	draw_line(center + Vector2(8.5, 1.0), center + Vector2(12.5, -5.5), line_color, 2.0)


func _draw_thorns(center: Vector2, color: Color, line_color: Color) -> void:
	draw_rect(Rect2(center + Vector2(-4.0, -8.5), Vector2(8.0, 17.0)), color.darkened(0.22), true)
	for angle in [0.0, TAU / 4.0, TAU / 2.0, TAU * 3.0 / 4.0]:
		var start := center + Vector2(cos(angle), sin(angle)) * 3.0
		var finish := center + Vector2(cos(angle), sin(angle)) * 11.0
		draw_line(start, finish, line_color, 2.0)
	draw_circle(center, 3.6, color.lightened(0.22))


func _draw_repair(center: Vector2, color: Color, line_color: Color) -> void:
	draw_rect(Rect2(center + Vector2(-10.5, -3.5), Vector2(21.0, 7.5)), color.darkened(0.10), true)
	draw_line(center + Vector2(-8.0, -8.0), center + Vector2(7.5, 7.0), line_color, 2.4)
	draw_line(center + Vector2(7.5, -8.0), center + Vector2(-8.0, 7.0), line_color, 2.4)
	draw_line(center + Vector2(0.0, -7.5), center + Vector2(0.0, 7.0), Color(0.92, 1.0, 1.0, 1.0), 1.5)
	draw_line(center + Vector2(-7.0, -0.5), center + Vector2(7.0, -0.5), Color(0.92, 1.0, 1.0, 1.0), 1.5)


func _draw_storm(center: Vector2, color: Color, line_color: Color) -> void:
	draw_line(center + Vector2(0.0, 8.5), center + Vector2(0.0, -7.5), color, 3.0)
	draw_circle(center + Vector2(0.0, -8.0), 3.4, line_color)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(2.5, -8.5),
		center + Vector2(-5.0, 1.5),
		center + Vector2(1.0, 1.5),
		center + Vector2(-2.5, 9.0),
		center + Vector2(8.0, -2.5),
		center + Vector2(2.0, -2.5),
	]), Color(0.85, 1.0, 1.0, 1.0))
