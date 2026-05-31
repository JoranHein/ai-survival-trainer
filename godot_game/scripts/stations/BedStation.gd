class_name BedStation
extends Node2D

@export var rest_spot_offset := Vector2(-48.0, 0.0)
@export var size := Vector2(60.0, 34.0)

var _active := false
var _pulse := 0.0


func reset_run() -> void:
	set_active(false)


func set_active(active: bool) -> void:
	if _active == active:
		return
	_active = active
	queue_redraw()


func get_rest_spot() -> Vector2:
	return global_position + rest_spot_offset


func get_activity_state() -> Dictionary:
	return {
		"kind": "rest",
		"active": _active,
		"progress": 1.0 if _active else 0.0,
	}


func rest(delta: float, ari: Node) -> void:
	set_active(true)
	if ari != null and ari.has_method("restore_from_rest"):
		ari.call("restore_from_rest", delta)
	queue_redraw()


func _ready() -> void:
	z_index = 1


func _process(delta: float) -> void:
	if _active:
		_pulse += delta * 2.0
		queue_redraw()


func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	var glow_alpha := 0.14 + sin(_pulse) * 0.05 if _active else 0.04
	draw_circle(Vector2.ZERO, 48.0, Color(0.95, 0.80, 0.42, glow_alpha))
	draw_rect(rect, Color(0.32, 0.23, 0.20, 1.0), true)
	draw_rect(Rect2(rect.position + Vector2(7.0, 5.0), Vector2(size.x - 14.0, size.y - 10.0)), Color(0.76, 0.65, 0.50, 1.0), true)
	draw_rect(Rect2(rect.position + Vector2(6.0, 4.0), Vector2(18.0, size.y - 8.0)), Color(0.94, 0.86, 0.66, 1.0), true)
	draw_rect(rect, Color(0.98, 0.82, 0.46, 1.0), false, 2.0)
	if _active:
		_draw_rest_cues()


func _draw_rest_cues() -> void:
	for i in range(3):
		var offset := Vector2(18.0 + float(i) * 9.0, -22.0 - float(i) * 4.0)
		var lift := sin(_pulse + float(i) * 0.7) * 2.0
		var start := offset + Vector2(0.0, lift)
		draw_line(start, start + Vector2(7.0, -4.0), Color(1.0, 0.88, 0.48, 0.68), 1.7)
		draw_line(start + Vector2(7.0, -4.0), start + Vector2(1.0, -8.0), Color(1.0, 0.88, 0.48, 0.68), 1.7)
