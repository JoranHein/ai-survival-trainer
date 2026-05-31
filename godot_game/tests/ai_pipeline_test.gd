extends SceneTree

const AIBridgeScript = preload("res://scripts/autoload/AIBridge.gd")
const AriMemoryScript = preload("res://scripts/ari/AriMemory.gd")
const ChronicleScript = preload("res://scripts/ari/Chronicle.gd")
const ScribeSystemScript = preload("res://scripts/ari/ScribeSystem.gd")
const ReflectionSystemScript = preload("res://scripts/ari/ReflectionSystem.gd")
const LessonBookScript = preload("res://scripts/ari/LessonBook.gd")
const SleepConsolidationScript = preload("res://scripts/ari/SleepConsolidation.gd")
const LifeArchiveScript = preload("res://scripts/ari/LifeArchive.gd")
const PermanentInsightBookScript = preload("res://scripts/ari/PermanentInsightBook.gd")
const WisdomSynthesizerScript = preload("res://scripts/ari/WisdomSynthesizer.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var bridge: AIBridge = AIBridgeScript.new()
	root.add_child(bridge)
	bridge.force_provider_mode("local_stub")

	await _test_bridge_health_and_raw_validation(bridge)
	_test_deep_interpretation_contract(bridge)
	_test_memory_records_events()
	_test_chronicle_validates_scribe_notes()
	await _test_scribe_pipeline(bridge)
	await _test_reflection_and_sleep_pipeline(bridge)
	await _test_life_and_wisdom_pipeline(bridge)

	if failures.is_empty():
		print("AI pipeline tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _test_bridge_health_and_raw_validation(bridge: AIBridge) -> void:
	var health_state := {"done": false}
	bridge.request_health(func(result: Dictionary) -> void:
		_assert(result.get("ok", false), "local_stub health should be available without a server")
		_assert(result.get("provider_mode", "") == "local_stub", "local_stub health should report local_stub")
		health_state["done"] = true
	)

	var valid_body := JSON.stringify({"raw": JSON.stringify({"note": "Remote note", "tags": ["remote"], "salience": 2.0})}).to_utf8_buffer()
	var parsed := bridge._parse_remote_response("scribe", {}, HTTPRequest.RESULT_SUCCESS, 200, valid_body)
	_assert(parsed.get("note", "") == "Remote note", "remote raw JSON should parse through the raw field")
	_assert(parsed.get("salience", 0.0) == 1.0, "remote scribe salience should be clamped")

	var invalid_body := JSON.stringify({"raw": "not json"}).to_utf8_buffer()
	var fallback := bridge._parse_remote_response("scribe", {"recent_events": [{"type": "enemy_spawned"}], "ari": {"fear": 90}}, HTTPRequest.RESULT_SUCCESS, 200, invalid_body)
	_assert(fallback.get("note", "").contains("enemy_spawned"), "invalid remote raw JSON should fall back to local_stub")
	_assert(fallback.get("tags", []).has("fear_high"), "fallback after invalid raw should still validate local_stub tags")

	await process_frame
	_assert(health_state["done"], "health callback should run in local_stub mode")


func _test_deep_interpretation_contract(bridge: AIBridge) -> void:
	var long_interpretation := ""
	var long_thought := ""
	for _i in range(300):
		long_interpretation += "x"
	for _j in range(220):
		long_thought += "y"

	var payload := {
		"local_fallback": {
			"interpretation": "Fallback wall reading",
			"priority_hints": {
				"wall": 0.4,
				"defensive_wait": 0.2,
			},
			"sign_strength": 0.3,
			"resonance": 0.2,
		},
	}
	var response := bridge._validate_deep_interpretation({
		"interpretation": long_interpretation,
		"thought": long_thought,
		"survival_theory": "cover",
		"priority_hints": {
			"build_wall": 2.0,
			"wait_behind_wall": "0.7",
			"unknown_key": 1.0,
		},
		"sign_strength": -5.0,
		"resonance": 2.0,
	}, payload, true, "remote_server")

	_assert(response.get("ok", false), "deep interpretation should report successful remote validation")
	_assert(str(response.get("interpretation", "")).length() == 240, "deep interpretation text should be capped")
	_assert(str(response.get("thought", "")).length() == 160, "deep thought text should be capped")
	var hints: Dictionary = response.get("priority_hints", {})
	_assert(hints.get("build_wall", 0.0) == 1.0, "deep build_wall hint should be clamped")
	_assert(hints.get("wait_behind_wall", 0.0) == 0.7, "deep wait_behind_wall hint should accept numeric strings")
	_assert(not hints.has("unknown_key"), "deep priority hints should remove unknown keys")
	_assert(response.get("sign_strength", 1.0) == 0.0, "deep sign strength should clamp low values")
	_assert(response.get("resonance", 0.0) == 1.0, "deep resonance should clamp high values")

	var fallback := bridge._deep_fallback(payload, "disabled")
	var fallback_hints: Dictionary = fallback.get("priority_hints", {})
	_assert(not fallback.get("ok", true), "deep fallback should report unsuccessful remote use")
	_assert(fallback.get("source", "") == "disabled", "deep fallback should preserve source")
	_assert(fallback_hints.get("build_wall", 0.0) == 0.4, "deep fallback should translate local wall hint")
	_assert(fallback_hints.get("wait_or_idle", 0.0) == 0.2, "deep fallback should translate local defensive wait hint")


func _test_memory_records_events() -> void:
	var memory = AriMemoryScript.new()
	memory.record_event("ari_damaged", {"day": 2, "phase": "night", "hp": 40})
	memory.record_snapshot({"ari": {"fear": 72}, "phase": "night"})

	var events = memory.get_recent_events()
	var snapshots = memory.get_recent_snapshots()
	_assert(events.size() == 1, "memory should store one event")
	_assert(events[0].get("type", "") == "ari_damaged", "event should keep its type")
	_assert(events[0].get("phase", "") == "night", "event should preserve provided phase")
	_assert(snapshots.size() == 1, "memory should store one snapshot")


func _test_chronicle_validates_scribe_notes() -> void:
	var chronicle = ChronicleScript.new()
	chronicle.add_scribe_note({
		"t_start": 1,
		"t_end": 2,
		"note": "Ari noticed the wall cracking.",
		"tags": ["wall", "danger", "extra", "extra2", "extra3", "extra4", "extra5", "extra6", "extra7"],
		"salience": 2.0,
	})

	var note = chronicle.get_today_scribe_notes()[0]
	_assert(note["tags"].size() == 8, "chronicle should cap scribe note tags")
	_assert(note["salience"] == 1.0, "chronicle should clamp salience")


func _test_scribe_pipeline(bridge: AIBridge) -> void:
	var memory = AriMemoryScript.new()
	var chronicle = ChronicleScript.new()
	var scribe = ScribeSystemScript.new()
	scribe.ai_bridge = bridge

	memory.record_event("wall_destroyed", {"phase": "night"})
	memory.record_snapshot({"ari": {"fear": 83, "current_action": "hiding"}, "phase": "night"})

	var state := {"done": false}
	scribe.create_scribe_note_from_recent_memory(memory, chronicle, {"phase": "night", "ari": {"fear": 83, "current_action": "hiding"}}, func(note: Dictionary) -> void:
		_assert(note.get("note", "").contains("wall_destroyed"), "local scribe should mention the last event")
		_assert(note.get("tags", []).has("fear_high"), "local scribe should tag high fear")
		_assert(chronicle.get_today_scribe_notes().size() == 1, "scribe should add note to chronicle")
		state["done"] = true
	)
	await process_frame
	_assert(state["done"], "scribe callback should run in local_stub mode")


func _test_reflection_and_sleep_pipeline(bridge: AIBridge) -> void:
	var chronicle = ChronicleScript.new()
	var lesson_book = LessonBookScript.new()
	var reflection = ReflectionSystemScript.new()
	var sleep = SleepConsolidationScript.new()
	reflection.ai_bridge = bridge
	sleep.ai_bridge = bridge

	chronicle.add_scribe_note({"note": "Ari survived by preparing early.", "tags": ["prepare"], "salience": 0.8})

	var reflection_state := {"done": false}
	reflection.request_library_reflection({"day": 1, "current_sign": "prepare before night"}, chronicle, lesson_book, func(note: Dictionary) -> void:
		_assert(note.get("title", "") != "", "reflection should create a titled note")
		_assert(lesson_book.get_all_notes().size() == 1, "reflection should add note to lesson book")
		reflection_state["done"] = true
	)
	await process_frame
	_assert(reflection_state["done"], "reflection callback should run in local_stub mode")

	var sleep_state := {"done": false}
	sleep.request_sleep_plan({"day": 1}, lesson_book, func(plan: Dictionary) -> void:
		_assert(plan.get("tomorrow_focus", []).has("prepare"), "sleep plan should include prepare focus")
		_assert(plan.get("wake_thought", "") != "", "sleep plan should provide wake thought")
		sleep_state["done"] = true
	)
	await process_frame
	_assert(sleep_state["done"], "sleep callback should run in local_stub mode")


func _test_life_and_wisdom_pipeline(bridge: AIBridge) -> void:
	var archive = LifeArchiveScript.new()
	var insights = PermanentInsightBookScript.new()
	var wisdom = WisdomSynthesizerScript.new()
	wisdom.ai_bridge = bridge

	var summary_state := {"summary": {}, "done": false}
	bridge.request_life_summary({"life_id": "test-life", "result": "died", "survived_days": 1}, func(result: Dictionary) -> void:
		summary_state["summary"] = result
		summary_state["done"] = true
	)
	await process_frame
	_assert(summary_state["done"], "life summary callback should run in local_stub mode")
	var life_summary: Dictionary = summary_state["summary"]
	var long_summary := ""
	for i in range(800):
		long_summary += "x"
	archive.add_life_summary({
		"life_id": "test-life",
		"result": "died",
		"survived_days": 1,
		"life_summary_markdown": life_summary.get("life_summary_markdown", ""),
		"candidate_insights": [{
			"title": "Prepare Before Night",
			"summary": long_summary,
			"conditions": ["dusk", "night", "extra", "extra2", "extra3", "extra4", "extra5", "extra6", "extra7", "extra8", "extra9", "extra10", "extra11"],
			"suggested_actions": ["prepare"],
			"confidence": 2.0,
		}],
		"next_life_hint": life_summary.get("next_life_hint", ""),
	})
	insights.add_or_merge_insight(life_summary.get("candidate_insights", [])[0])
	insights.add_or_merge_insight(life_summary.get("candidate_insights", [])[0])
	_assert(not insights.update_matching_insight({"title": "Unknown New Advice", "summary": "Should not be added."}), "updated insights should not create unmatched permanent insights")

	_assert(archive.get_all_life_summaries().size() == 1, "life archive should store summary")
	_assert(archive.get_all_life_summaries()[0].get("candidate_insights", [])[0].get("summary", "").length() == 500, "life archive should cap candidate insight summary length")
	_assert(archive.get_all_life_summaries()[0].get("candidate_insights", [])[0].get("confidence", 0.0) == 1.0, "life archive should clamp candidate insight confidence")
	_assert(insights.get_all_insights().size() == 1, "insight book should merge duplicate titles")
	_assert(insights.get_all_insights()[0].get("times_confirmed", 0) == 2, "insight merge should increase confirmation count")

	var wisdom_state := {"done": false}
	wisdom.request_background_synthesis(archive, insights, func(result: Dictionary) -> void:
		_assert(result.has("new_insights"), "wisdom synthesis should return a validated result")
		wisdom_state["done"] = true
	)
	await process_frame
	_assert(wisdom_state["done"], "wisdom callback should run in local_stub mode")
