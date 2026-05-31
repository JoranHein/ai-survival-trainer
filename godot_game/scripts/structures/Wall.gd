extends "res://scripts/structures/Structure.gd"


func _ready() -> void:
	super._ready()
	z_index = 2


func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	var hp_ratio := hp / max_hp if max_hp > 0.0 else 0.0
	draw_rect(rect, Color(0.42, 0.44, 0.43, 1.0), true)
	draw_rect(rect, Color(0.72, 0.76, 0.74, 1.0), false, 2.0)
	draw_rect(Rect2(rect.position + Vector2(3.0, 3.0), Vector2((size.x - 6.0) * hp_ratio, 4.0)), Color(0.68, 0.92, 0.72, 1.0), true)
