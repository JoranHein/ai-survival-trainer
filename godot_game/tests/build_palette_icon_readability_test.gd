extends SceneTree

const HUDScene := preload("res://scenes/ui/HUD.tscn")
const MIN_ICON_SIZE := Vector2(28.0, 20.0)
const MAX_BADGE_WIDTH := 58.0
const MIN_BADGE_HEIGHT := 31.0
const MAX_PALETTE_HEIGHT := 52.0
const BUILD_ENTRY_COUNT := 10

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var hud := HUDScene.instantiate()
	root.add_child(hud)
	await process_frame

	hud.call("update_state", _build_mode_state())
	await process_frame

	_test_palette_icons_are_large_enough(hud)
	_test_palette_stays_compact(hud)

	root.remove_child(hud)
	hud.free()

	if failures.is_empty():
		print("Build palette icon readability tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_palette_icons_are_large_enough(hud: Node) -> void:
	var build_palette: GridContainer = hud.get_node("%BuildPalette")
	_assert(build_palette.get_child_count() == BUILD_ENTRY_COUNT, "palette should show each buildable entry")
	for badge in build_palette.get_children():
		var icon := _find_build_palette_icon(badge)
		_assert(icon != null, "each build badge should include a drawn symbol")
		if icon == null:
			continue
		_assert(icon.custom_minimum_size.x >= MIN_ICON_SIZE.x, "build symbol should be wide enough for readable silhouettes")
		_assert(icon.custom_minimum_size.y >= MIN_ICON_SIZE.y, "build symbol should be tall enough for readable silhouettes")


func _test_palette_stays_compact(hud: Node) -> void:
	var palette_panel: Control = hud.get_node("%PalettePanel")
	var build_palette: GridContainer = hud.get_node("%BuildPalette")
	_assert(palette_panel.offset_bottom - palette_panel.offset_top <= MAX_PALETTE_HEIGHT, "larger build symbols should still fit the dock height")
	for badge in build_palette.get_children():
		if badge is Control:
			var control := badge as Control
			_assert(control.custom_minimum_size.x <= MAX_BADGE_WIDTH, "build badge should remain narrow enough for the ten-item row")
			_assert(control.custom_minimum_size.y >= MIN_BADGE_HEIGHT, "build badge should reserve enough height for stronger symbols")


func _find_build_palette_icon(node: Node) -> Control:
	if node is BuildPaletteIcon:
		return node as Control
	for child in node.get_children():
		var found := _find_build_palette_icon(child)
		if found != null:
			return found
	return null


func _build_mode_state() -> Dictionary:
	return {
		"day": 1,
		"phase": "midday",
		"time_left": 19.0,
		"ari_hp": 100.0,
		"ari_max_hp": 100.0,
		"enemy_count": 0,
		"stone": 30,
		"food": 3,
		"selected_build_type": "spike_trap",
		"selected_build_name": "Spike Trap",
		"build_mode": true,
		"wall_cost": 5,
		"orb_cost": 5,
		"trap_cost": 4,
		"tower_cost": 8,
		"tar_pit_cost": 4,
		"fear_lantern_cost": 5,
		"decoy_idol_cost": 6,
		"thorn_totem_cost": 6,
		"repair_bench_cost": 6,
		"storm_rod_cost": 7,
		"needs": {"hunger": 45.0, "fear": 57.0, "stamina": 37.0},
		"personality_summary": "Ari: brave",
		"run_build": {"preset_name": "Fast Coward", "tags": ["move 7"]},
		"ari_action": "resting",
		"ari_job_reason": "Need calm before night",
	}


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
