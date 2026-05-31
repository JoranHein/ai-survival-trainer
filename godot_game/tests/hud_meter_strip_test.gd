extends SceneTree

const HUDScene := preload("res://scenes/ui/HUD.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var hud := HUDScene.instantiate()
	root.add_child(hud)
	await process_frame
	_test_hud_exposes_meter_strip(hud)
	_test_meter_strip_clamps_state(hud)
	root.remove_child(hud)
	hud.free()

	if failures.is_empty():
		print("HUD meter strip tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_hud_exposes_meter_strip(hud: Node) -> void:
	var meter_strip := hud.find_child("MeterStrip", true, false)
	_assert(meter_strip != null, "HUD scene should include a MeterStrip control")
	if meter_strip == null:
		return
	_assert(meter_strip.has_method("set_meters"), "MeterStrip should accept meter data")
	_assert(meter_strip.has_method("get_meter_state"), "MeterStrip should expose clamped meter state")


func _test_meter_strip_clamps_state(hud: Node) -> void:
	var meter_strip := hud.find_child("MeterStrip", true, false)
	if meter_strip == null or not meter_strip.has_method("set_meters") or not meter_strip.has_method("get_meter_state"):
		return
	meter_strip.call("set_meters", [
		{"id": "hp", "label": "HP", "value": 120.0, "maximum": 100.0},
		{"id": "hunger", "label": "Hu", "value": -10.0, "maximum": 100.0},
		{"id": "fear", "label": "Fr", "value": 57.0, "maximum": 100.0},
		{"id": "stamina", "label": "St", "value": 37.0, "maximum": 100.0},
	])
	var state = meter_strip.call("get_meter_state")
	_assert(typeof(state) == TYPE_ARRAY and state.size() == 4, "MeterStrip should keep four meters")
	if typeof(state) != TYPE_ARRAY or state.size() < 4:
		return
	_assert(float(state[0].get("ratio", -1.0)) == 1.0, "HP ratio should clamp to 1.0")
	_assert(float(state[1].get("ratio", -1.0)) == 0.0, "hunger ratio should clamp to 0.0")
	_assert(float(state[2].get("ratio", -1.0)) > 0.56 and float(state[2].get("ratio", -1.0)) < 0.58, "fear ratio should preserve normalized value")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
