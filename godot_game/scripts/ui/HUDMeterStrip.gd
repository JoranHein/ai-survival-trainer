class_name HUDMeterStrip
extends Control

var _meters: Array[Dictionary] = []


func _ready() -> void:
	custom_minimum_size = Vector2(610.0, 32.0)
	if _meters.is_empty():
		set_meters([
			{"id": "hp", "label": "HP", "value": 100.0, "maximum": 100.0, "color": Color(0.88, 0.24, 0.28, 1.0)},
			{"id": "hunger", "label": "Hu", "value": 100.0, "maximum": 100.0, "color": Color(0.78, 0.58, 0.24, 1.0)},
			{"id": "fear", "label": "Fr", "value": 0.0, "maximum": 100.0, "color": Color(0.62, 0.42, 0.96, 1.0)},
			{"id": "stamina", "label": "St", "value": 100.0, "maximum": 100.0, "color": Color(0.28, 0.72, 0.52, 1.0)},
		])


func set_meters(raw_meters: Array) -> void:
	_meters.clear()
	for raw_meter in raw_meters:
		if typeof(raw_meter) != TYPE_DICTIONARY:
			continue
		var meter: Dictionary = raw_meter
		var maximum := maxf(float(meter.get("maximum", 100.0)), 1.0)
		var value := clampf(float(meter.get("value", 0.0)), 0.0, maximum)
		var color := Color(0.75, 0.85, 0.78, 1.0)
		var raw_color = meter.get("color", color)
		if typeof(raw_color) == TYPE_COLOR:
			color = raw_color
		_meters.append({
			"id": str(meter.get("id", "")),
			"label": str(meter.get("label", "")),
			"value": value,
			"maximum": maximum,
			"ratio": clampf(value / maximum, 0.0, 1.0),
			"color": color,
		})
	queue_redraw()


func set_meter_values(hp: float, max_hp: float, hunger: float, fear: float, stamina: float) -> void:
	set_meters([
		{"id": "hp", "label": "HP", "value": hp, "maximum": max_hp, "color": Color(0.90, 0.24, 0.28, 1.0)},
		{"id": "hunger", "label": "Hu", "value": hunger, "maximum": 100.0, "color": Color(0.84, 0.62, 0.24, 1.0)},
		{"id": "fear", "label": "Fr", "value": fear, "maximum": 100.0, "color": Color(0.62, 0.42, 0.96, 1.0)},
		{"id": "stamina", "label": "St", "value": stamina, "maximum": 100.0, "color": Color(0.28, 0.76, 0.50, 1.0)},
	])


func get_meter_state() -> Array:
	return _meters.duplicate(true)


func _draw() -> void:
	if _meters.is_empty():
		return
	var count := _meters.size()
	var gap := 8.0
	var slot_width := maxf(44.0, (size.x - gap * float(count - 1)) / float(count))
	var font := get_theme_default_font()
	var font_size := 10
	var x := 0.0
	for meter in _meters:
		_draw_meter_slot(Rect2(Vector2(x, 0.0), Vector2(slot_width, size.y)), meter, font, font_size)
		x += slot_width + gap


func _draw_meter_slot(rect: Rect2, meter: Dictionary, font: Font, font_size: int) -> void:
	var color: Color = meter.get("color", Color(0.75, 0.85, 0.78, 1.0))
	var label := str(meter.get("label", "?"))
	var value := float(meter.get("value", 0.0))
	var maximum := float(meter.get("maximum", 100.0))
	var ratio := clampf(float(meter.get("ratio", 0.0)), 0.0, 1.0)
	var text := "%s %.0f" % [label, value]
	if label == "HP":
		text = "%s %.0f/%.0f" % [label, value, maximum]

	draw_string(font, rect.position + Vector2(0.0, 10.0), text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, font_size, Color(0.90, 0.96, 0.92, 1.0))
	var bar_rect := Rect2(rect.position + Vector2(0.0, 15.0), Vector2(rect.size.x, 10.0))
	draw_rect(bar_rect, Color(0.04, 0.05, 0.045, 0.92), true)
	draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * ratio, bar_rect.size.y)), color, true)
	draw_rect(bar_rect, color.lightened(0.18), false, 1.0)
