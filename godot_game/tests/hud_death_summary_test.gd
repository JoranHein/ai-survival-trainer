extends SceneTree

const HUDScene := preload("res://scenes/ui/HUD.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var hud := HUDScene.instantiate()
	root.add_child(hud)
	await process_frame
	await _test_dead_state_uses_compact_summary(hud)
	root.remove_child(hud)
	hud.free()

	if failures.is_empty():
		print("HUD death summary tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_dead_state_uses_compact_summary(hud: CanvasLayer) -> void:
	var long_recap := "Death recap: Day 1 night. Enemies got close enough to hurt him. Visual review pauses permanent rewards. A first wall layer may buy him time."
	hud.call("update_state", {
		"day": 1,
		"phase": "night",
		"time_left": 22.0,
		"ari_hp": 0.0,
		"ari_max_hp": 100.0,
		"enemy_count": 1,
		"stone": 10,
		"food": 1,
		"ari_alive": false,
		"ari_action": "idle",
		"ari_job_reason": "Night has started",
		"personality_summary": "Ari: fearful, practical",
		"run_build": {"preset_name": "Balanced", "tags": ["building 2"]},
		"run_build_name": "Balanced",
		"needs": {"hunger": 72.0, "fear": 26.0, "stamina": 92.0},
		"death_recap": long_recap,
		"permanent_progression": {
			"time_points": 8,
			"permanent_summary": "Attack 2, Defense 1, Mining 1",
		},
	})
	await process_frame

	var status_label: Label = hud.get_node("%StatusLabel")
	var mind_label: Label = hud.get_node("%MindLabel")
	var build_label: Label = hud.get_node("%BuildLabel")
	_assert(status_label.text.contains("Ari died. Press R to restart."), "dead HUD should keep restart instruction")
	_assert(mind_label.text.contains("Death:"), "dead HUD should show a compact death cause")
	_assert(mind_label.text.contains("Tip:"), "dead HUD should show a compact next-run tip")
	_assert(not mind_label.text.contains("Visual review pauses permanent rewards"), "dead HUD should not show verbose reward text")
	_assert(not build_label.text.contains("Combat"), "dead HUD should hide live combat/build rows")
	_assert(mind_label.text.length() <= 110, "dead HUD mind text should stay compact")
	_assert(status_label.text.split("\n").size() <= 2, "dead HUD status section should stay short")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
