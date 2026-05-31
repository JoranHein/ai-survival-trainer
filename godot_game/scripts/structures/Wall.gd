extends "res://scripts/structures/Structure.gd"


func _ready() -> void:
	super._ready()
	z_index = 2


func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	var hp_ratio := get_hp_ratio()
	var damage_amount := 1.0 - hp_ratio
	var flash := get_damage_flash_amount()
	var fill_color := Color(0.42, 0.44, 0.43, 1.0).lerp(Color(0.34, 0.30, 0.28, 1.0), damage_amount)
	var edge_color := Color(0.72, 0.76, 0.74, 1.0).lerp(Color(0.96, 0.58, 0.44, 1.0), damage_amount)
	if flash > 0.0:
		fill_color = fill_color.lerp(Color(1.0, 0.78, 0.52, 1.0), flash * 0.65)
		edge_color = edge_color.lerp(Color(1.0, 0.92, 0.68, 1.0), flash)
	var shadow_rect := rect.grow(4.0)
	shadow_rect.position += Vector2(3.0, 5.0)
	draw_rect(shadow_rect, Color(0.0, 0.0, 0.0, 0.30), true)
	draw_rect(rect.grow(2.0), Color(0.08, 0.08, 0.07, 0.95), true)
	draw_rect(rect, fill_color, true)
	draw_rect(rect, edge_color, false, 3.0)
	_draw_cracks(hp_ratio)
	draw_rect(Rect2(rect.position + Vector2(3.0, 3.0), Vector2(size.x - 6.0, 4.0)), Color(0.10, 0.11, 0.10, 0.95), true)
	draw_rect(Rect2(rect.position + Vector2(3.0, 3.0), Vector2((size.x - 6.0) * hp_ratio, 4.0)), _hp_bar_color(hp_ratio), true)
	if flash > 0.0:
		draw_rect(rect.grow(2.0), Color(1.0, 0.86, 0.52, 0.45 * flash), false, 3.0)


func _draw_cracks(hp_ratio: float) -> void:
	var crack_color := Color(0.12, 0.10, 0.10, 0.82)
	if hp_ratio < 0.78:
		draw_polyline(PackedVector2Array([
			Vector2(-9.0, -10.0),
			Vector2(-2.0, -4.0),
			Vector2(-5.0, 5.0),
		]), crack_color, 2.0)
	if hp_ratio < 0.55:
		draw_polyline(PackedVector2Array([
			Vector2(10.0, -12.0),
			Vector2(4.0, -3.0),
			Vector2(9.0, 8.0),
		]), crack_color, 2.0)
	if hp_ratio < 0.35:
		draw_line(Vector2(-12.0, 10.0), Vector2(13.0, -8.0), crack_color, 2.0)


func _hp_bar_color(hp_ratio: float) -> Color:
	if hp_ratio < 0.35:
		return Color(1.0, 0.34, 0.24, 1.0)
	if hp_ratio < 0.65:
		return Color(1.0, 0.80, 0.32, 1.0)
	return Color(0.68, 0.92, 0.72, 1.0)
