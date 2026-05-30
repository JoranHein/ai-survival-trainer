extends Control

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
var fake_day := 1
var fake_phase := "night"
var fake_sign := "prepare before night"


func _ready() -> void:
	bridge = AIBridge.new()
	add_child(bridge)
	scribe_system.ai_bridge = bridge
	reflection_system.ai_bridge = bridge
	sleep_system.ai_bridge = bridge
	wisdom_synthesizer.ai_bridge = bridge

	memory.record_event("phase_changed", {"day": fake_day, "phase": fake_phase})
	memory.record_snapshot(_debug_context())
	_update_debug_label()


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
	if show_request_status:
		request_status = "1: Scribe note requested"
		_update_debug_label()
	memory.record_event("ari_started_job", {"day": fake_day, "phase": fake_phase, "job": "prepare"})
	memory.record_snapshot(_debug_context())
	scribe_system.create_scribe_note_from_recent_memory(memory, chronicle, _debug_context(), func(note: Dictionary) -> void:
		result_status = "Latest scribe: " + str(note.get("note", ""))
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
	reflection_system.request_library_reflection(_debug_context(), chronicle, lesson_book, func(note: Dictionary) -> void:
		result_status = "Latest reflection: " + str(note.get("title", ""))
		_update_debug_label()
	)


func _debug_sleep_plan() -> void:
	request_status = "3: Sleep plan requested"
	_update_debug_label()
	sleep_system.request_sleep_plan(_debug_context(), lesson_book, func(plan: Dictionary) -> void:
		result_status = "Latest sleep: " + str(plan.get("wake_thought", ""))
		_update_debug_label()
	)


func _debug_life_summary() -> void:
	request_status = "4: Life summary requested"
	_update_debug_label()
	var payload := {
		"life_id": "debug-life-%d" % int(Time.get_unix_time_from_system()),
		"result": "debug",
		"survived_days": fake_day,
		"events": memory.get_recent_events(50),
		"scribe_notes": chronicle.get_lifetime_scribe_notes(),
		"lesson_notes": lesson_book.get_all_notes(),
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
		result_status = "Latest life summary: " + str(summary.get("next_life_hint", ""))
		print("Life summary created: ", summary.get("next_life_hint", ""))
		_update_debug_label()
	)


func _debug_wisdom_synthesis() -> void:
	request_status = "5: Wisdom synthesis requested"
	_update_debug_label()
	wisdom_synthesizer.request_background_synthesis(life_archive, insight_book, func(_result: Dictionary) -> void:
		result_status = "Latest wisdom: %d permanent insight(s)" % insight_book.get_all_insights().size()
		_update_debug_label()
	)


func _debug_context() -> Dictionary:
	return {
		"day": fake_day,
		"phase": fake_phase,
		"current_sign": fake_sign,
		"ari": {
			"fear": 82,
			"hp": 45,
			"current_action": "preparing",
			"phase": fake_phase,
		},
		"available_actions": ["prepare", "rest", "stay_safe"],
	}


func _update_debug_label() -> void:
	if debug_label == null:
		return
	debug_label.text = "\n".join([
		"AI Survival Trainer - AI Pipeline Debug",
		"Provider mode: %s" % bridge.get_provider_mode(),
		"No server is required in local_stub mode.",
		"",
		"1 = create fake scribe note",
		"2 = request library reflection",
		"3 = request sleep plan",
		"4 = request life summary",
		"5 = request wisdom synthesis",
		"",
		"Memory events: %d" % memory.get_recent_events(500).size(),
		"Scribe notes: %d" % chronicle.get_lifetime_scribe_notes().size(),
		"Lesson notes: %d" % lesson_book.get_all_notes().size(),
		"Life summaries: %d" % life_archive.get_all_life_summaries().size(),
		"Permanent insights: %d" % insight_book.get_all_insights().size(),
		"",
		request_status,
		result_status,
	])
