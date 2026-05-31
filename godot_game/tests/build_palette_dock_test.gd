extends SceneTree

const HUDScene := preload("res://scenes/ui/HUD.tscn")
const DOCK_GAP := 6.0
const MAX_DOCK_HEIGHT := 52.0
const BUILD_ENTRY_COUNT := 10

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var hud := HUDScene.instantiate()
	root.add_child(hud)
	await process_frame

	_test_palette_docks_to_status_panel(hud)
	await _test_palette_uses_single_row_for_all_buildables(hud)

	root.remove_child(hud)
	hud.free()

	if failures.is_empty():
		print("Build palette dock tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_palette_docks_to_status_panel(hud: Node) -> void:
	var status_panel: Control = hud.get_node("StatusPanel")
	var palette_panel: Control = hud.get_node("%PalettePanel")
	_assert(is_equal_approx(palette_panel.offset_left, status_panel.offset_left), "palette should share the HUD left edge")
	_assert(is_equal_approx(palette_panel.offset_right, status_panel.offset_right), "palette should share the HUD right edge")
	_assert(is_equal_approx(palette_panel.offset_top - status_panel.offset_bottom, DOCK_GAP), "palette should dock directly below the HUD with one small gap")
	_assert(palette_panel.offset_bottom - palette_panel.offset_top <= MAX_DOCK_HEIGHT, "palette dock should stay short enough to avoid arena overlap")


func _test_palette_uses_single_row_for_all_buildables(hud: Node) -> void:
	var palette_panel: Control = hud.get_node("%PalettePanel")
	var build_palette: GridContainer = hud.get_node("%BuildPalette")
	hud.call("update_state", _build_mode_state())
	await process_frame
	_assert(palette_panel.visible, "palette should be visible in build mode")
	_assert(build_palette.columns == BUILD_ENTRY_COUNT, "palette should use one row for the current buildable set")
	_assert(build_palette.get_child_count() == BUILD_ENTRY_COUNT, "palette should show each buildable entry")


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
