extends Control

const SNAPSHOT_INTERVAL_SECONDS := 1.0
const AUTO_SCRIBE_INTERVAL_SECONDS := 5.0

@onready var debug_label: Label = %DebugLabel

var bridge: AIBridge
var memory := AriMemory.new()
var chronicle := Chronicle.new()
var lesson_book := LessonBook.new()
var life_archive := LifeArchive.new()
var insight_book := PermanentInsightBook.new()
var scribe_system := ScribeSystem.new()
var reflection_system := ReflectionSystem.new()
var sleep_system := SleepConsolidation.new()
var wisdom_synthesizer := WisdomSynthesizer.new()

var request_status := "Ready. Press 1-5 to test the AI memory pipeline."
var result_status := "Latest result: none"
var elapsed_time := 0.0
var snapshot_accumulator := 0.0
var scribe_accumulator := 0.0
var current_day := 1
var current_phase := "debug"
var current_sign := ""
var ari_hp := 100.0
var ari_fear := 0.0
var ari_hunger := 0.0
var ari_stamina := 100.0
var ari_current_action := "debug_idle"
var world_enemy_count := 0
var world_stone := 0
var world_wall_count := 0
var world_aura_orb_count := 0
var latest_scribe_note := "none"
var latest_lesson_title := "none"
var latest_lesson_thought := "none"
var latest_sleep_wake_thought := "none"
var latest_life_summary_status := "none"
var latest_wisdom_status := "none"


func _ready() -> void:
	bridge = AIBridge.new()
	add_child(bridge)
	scribe_system.ai_bridge = bridge
	reflection_system.ai_bridge = bridge
	sleep_system.ai_bridge = bridge
	wisdom_synthesizer.ai_bridge = bridge

	memory.record_event("phase_changed", {"day": current_day, "phase": current_phase})
	_record_runtime_snapshot()
	_update_debug_label()


func _process(delta: float) -> void:
	advance_runtime_memory(delta)


func advance_runtime_memory(delta: float) -> void:
	elapsed_time += maxf(delta, 0.0)
	snapshot_accumulator += maxf(delta, 0.0)
	scribe_accumulator += maxf(delta, 0.0)

	while snapshot_accumulator >= SNAPSHOT_INTERVAL_SECONDS:
		snapshot_accumulator -= SNAPSHOT_INTERVAL_SECONDS
		_record_runtime_snapshot()

	while scribe_accumulator >= AUTO_SCRIBE_INTERVAL_SECONDS:
		scribe_accumulator -= AUTO_SCRIBE_INTERVAL_SECONDS
		_create_scribe_note(false, "auto")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_debug_create_scribe_note()
			KEY_2:
				_debug_library_reflection()
			KEY_3:
				_debug_sleep_plan()
			KEY_4:
				_debug_life_summary()
			KEY_5:
				_debug_wisdom_synthesis()


func _debug_create_scribe_note(callback: Callable = Callable(), show_request_status: bool = true) -> void:
	_create_scribe_note(show_request_status, "manual", callback)


func _create_scribe_note(show_request_status: bool, source: String, callback: Callable = Callable()) -> void:
	if show_request_status:
		request_status = "1: Scribe note requested"
		_update_debug_label()
	if source != "auto":
		memory.record_event("scribe_requested", {"day": current_day, "phase": current_phase, "source": source})
	_record_runtime_snapshot()
	scribe_system.create_scribe_note_from_recent_memory(memory, chronicle, _runtime_context(), func(note: Dictionary) -> void:
		latest_scribe_note = str(note.get("note", ""))
		result_status = "Latest scribe: " + latest_scribe_note
		_update_debug_label()
		if callback.is_valid():
			callback.call()
	)


func _debug_library_reflection() -> void:
	request_status = "2: Library reflection requested"
	_update_debug_label()
	if chronicle.get_today_scribe_notes().is_empty():
		var after_scribe := func() -> void:
			_request_debug_reflection()
		_debug_create_scribe_note(after_scribe, false)
		return
	_request_debug_reflection()


func _request_debug_reflection() -> void:
	reflection_system.request_library_reflection(_runtime_context(), chronicle, lesson_book, func(note: Dictionary) -> void:
		latest_lesson_title = str(note.get("title", ""))
		latest_lesson_thought = str(note.get("thought", ""))
		result_status = "Latest reflection: " + latest_lesson_title
		_update_debug_label()
	)


func _debug_sleep_plan() -> void:
	request_status = "3: Sleep plan requested"
	_update_debug_label()
	sleep_system.request_sleep_plan(_runtime_context(), lesson_book, func(plan: Dictionary) -> void:
		latest_sleep_wake_thought = str(plan.get("wake_thought", ""))
		result_status = "Latest sleep: " + latest_sleep_wake_thought
		_update_debug_label()
	)


func _debug_life_summary() -> void:
	request_status = "4: Life summary requested"
	_update_debug_label()
	var payload := {
		"life_id": "debug-life-%d" % int(Time.get_unix_time_from_system()),
		"result": "debug",
		"survived_days": current_day,
		"events": memory.get_recent_events(50),
		"snapshots": memory.get_recent_snapshots(20),
		"scribe_notes": chronicle.get_lifetime_scribe_notes(),
		"lesson_notes": lesson_book.get_all_notes(),
		"ari_context": _runtime_context(),
	}
	bridge.request_life_summary(payload, func(summary: Dictionary) -> void:
		var archived := {
			"life_id": payload["life_id"],
			"result": payload["result"],
			"survived_days": payload["survived_days"],
			"life_summary_markdown": summary.get("life_summary_markdown", ""),
			"candidate_insights": summary.get("candidate_insights", []),
			"next_life_hint": summary.get("next_life_hint", ""),
		}
		life_archive.add_life_summary(archived)
		for insight in summary.get("candidate_insights", []):
			if typeof(insight) == TYPE_DICTIONARY:
				insight_book.add_or_merge_insight(insight)
		latest_life_summary_status = "Count: %d, Hint: %s" % [
			life_archive.get_all_life_summaries().size(),
			str(summary.get("next_life_hint", "")),
		]
		result_status = "Latest life summary: " + latest_life_summary_status
		print("Life summary created: ", summary.get("next_life_hint", ""))
		_update_debug_label()
	)


func _debug_wisdom_synthesis() -> void:
	request_status = "5: Wisdom synthesis requested"
	_update_debug_label()
	wisdom_synthesizer.request_background_synthesis(life_archive, insight_book, func(_result: Dictionary) -> void:
		latest_wisdom_status = "%d permanent insight(s)" % insight_book.get_all_insights().size()
		result_status = "Latest wisdom: " + latest_wisdom_status
		_update_debug_label()
	)


func _record_runtime_snapshot() -> void:
	memory.record_snapshot(_runtime_snapshot())


func _runtime_snapshot() -> Dictionary:
	return {
		"time": elapsed_time,
		"day": current_day,
		"phase": current_phase,
		"ari": {
			"hp": ari_hp,
			"fear": ari_fear,
			"hunger": ari_hunger,
			"stamina": ari_stamina,
			"current_action": ari_current_action,
		},
		"world": {
			"enemy_count": world_enemy_count,
			"stone": world_stone,
			"wall_count": world_wall_count,
			"aura_orb_count": world_aura_orb_count,
		},
	}


func _runtime_context() -> Dictionary:
	var snapshot := _runtime_snapshot()
	snapshot["current_sign"] = current_sign
	snapshot["recent_events"] = memory.get_recent_events(50)
	snapshot["recent_snapshots"] = memory.get_recent_snapshots(10)
	snapshot["scribe_notes"] = chronicle.get_lifetime_scribe_notes()
	snapshot["lesson_notes"] = lesson_book.get_all_notes()
	snapshot["permanent_insights"] = insight_book.get_all_insights()
	snapshot["available_actions"] = ["prepare", "rest", "stay_safe"]
	return snapshot


func _snapshot_count() -> int:
	return memory.get_recent_snapshots(500).size()


func _event_count() -> int:
	return memory.get_recent_events(500).size()


func _latest_life_summary_line() -> String:
	if latest_life_summary_status == "none":
		return "Latest life summary: none"
	return "Latest life summary: " + latest_life_summary_status


func _latest_wisdom_line() -> String:
	if latest_wisdom_status == "none":
		return "Latest wisdom: none"
	return "Latest wisdom: " + latest_wisdom_status


func _latest_sleep_line() -> String:
	if latest_sleep_wake_thought == "none":
		return "Latest sleep: none"
	return "Latest sleep: " + latest_sleep_wake_thought


func _latest_scribe_line() -> String:
	if latest_scribe_note == "none":
		return "Latest scribe: none"
	return "Latest scribe: " + latest_scribe_note


func _latest_lesson_title_line() -> String:
	if latest_lesson_title == "none":
		return "Latest lesson title: none"
	return "Latest lesson title: " + latest_lesson_title


func _latest_lesson_thought_line() -> String:
	if latest_lesson_thought == "none":
		return "Latest lesson thought: none"
	return "Latest lesson thought: " + latest_lesson_thought


func _update_debug_label() -> void:
	if debug_label == null:
		return
	debug_label.text = "\n".join([
		"AI Survival Trainer - AI Pipeline Debug",
		"Provider mode: %s" % bridge.get_provider_mode(),
		"No server is required in local_stub mode.",
		"",
		"1 = create scribe note",
		"2 = request library reflection",
		"3 = request sleep plan",
		"4 = request life summary",
		"5 = request wisdom synthesis",
		"",
		"Snapshots: %d" % _snapshot_count(),
		"Memory events: %d" % _event_count(),
		"Scribe notes: %d" % chronicle.get_lifetime_scribe_notes().size(),
		"Lesson notes: %d" % lesson_book.get_all_notes().size(),
		"Life summaries: %d" % life_archive.get_all_life_summaries().size(),
		"Permanent insights: %d" % insight_book.get_all_insights().size(),
		"",
		_latest_scribe_line(),
		_latest_lesson_title_line(),
		_latest_lesson_thought_line(),
		_latest_sleep_line(),
		_latest_life_summary_line(),
		_latest_wisdom_line(),
		"",
		request_status,
		result_status,
	])
