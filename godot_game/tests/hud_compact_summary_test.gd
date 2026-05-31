extends SceneTree

const HUDScript := preload("res://scripts/ui/HUD.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var hud := HUDScript.new()
	_test_needs_line_is_meter_based(hud)
	_test_build_counts_hide_zero_spam(hud)
	_test_support_counts_hide_zero_spam(hud)
	hud.free()

	if failures.is_empty():
		print("HUD compact summary tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_needs_line_is_meter_based(hud: CanvasLayer) -> void:
	_assert(hud.has_method("_needs_meter_line"), "HUD should expose a compact needs meter helper")
	if not hud.has_method("_needs_meter_line"):
		return
	var line := str(hud.call("_needs_meter_line", {
		"hunger": 45.0,
		"fear": 57.0,
		"stamina": 37.0,
	}))
	_assert(line.contains("Hu ["), "needs line should show hunger as a meter token")
	_assert(line.contains("Fr ["), "needs line should show fear as a meter token")
	_assert(line.contains("St ["), "needs line should show stamina as a meter token")
	_assert(not line.contains("Hunger"), "needs line should avoid long labels")
	_assert(line.length() <= 58, "needs line should stay compact")


func _test_build_counts_hide_zero_spam(hud: CanvasLayer) -> void:
	_assert(hud.has_method("_build_counts_line"), "HUD should expose a compact build counts helper")
	if not hud.has_method("_build_counts_line"):
		return
	var empty_line := str(hud.call("_build_counts_line", {}))
	_assert(empty_line == "Built: none", "zero build counts should collapse to a short empty state")

	var line := str(hud.call("_build_counts_line", {
		"wall_count": 4,
		"aura_orb_count": 1,
		"spike_trap_count": 0,
		"bow_tower_count": 1,
		"tar_pit_count": 0,
	}))
	_assert(line.contains("Wall 4"), "build line should include nonzero wall count")
	_assert(line.contains("Orb 1"), "build line should include nonzero orb count")
	_assert(line.contains("Tower 1"), "build line should include nonzero tower count")
	_assert(not line.contains("Trap 0"), "build line should hide zero trap count")
	_assert(line.length() <= 52, "build count line should stay compact")


func _test_support_counts_hide_zero_spam(hud: CanvasLayer) -> void:
	_assert(hud.has_method("_support_counts_line"), "HUD should expose a compact support counts helper")
	if not hud.has_method("_support_counts_line"):
		return
	var empty_line := str(hud.call("_support_counts_line", {}))
	_assert(empty_line == "Support: none", "zero support counts should collapse to a short empty state")

	var line := str(hud.call("_support_counts_line", {
		"fear_lantern_count": 1,
		"decoy_idol_count": 0,
		"thorn_totem_count": 1,
		"repair_bench_count": 0,
		"storm_rod_count": 1,
		"damaged_structure_count": 1,
	}))
	_assert(line.contains("Lamp 1"), "support line should include nonzero lamp count")
	_assert(line.contains("Thorn 1"), "support line should include nonzero thorn count")
	_assert(line.contains("Storm 1"), "support line should include nonzero storm count")
	_assert(line.contains("Dmg 1"), "support line should include damaged structure count")
	_assert(not line.contains("Decoy 0"), "support line should hide zero decoy count")
	_assert(line.length() <= 62, "support count line should stay compact")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
