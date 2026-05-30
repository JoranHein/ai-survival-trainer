extends Control

const SNAPSHOT_INTERVAL_SECONDS := 1.0
const AUTO_SCRIBE_INTERVAL_SECONDS := 5.0
const DAY_LENGTH_SECONDS := 24.0
const PHASE_LENGTH_SECONDS := 6.0
const NIGHT_START_SECONDS := 18.0
const ARI_RADIUS := 14.0
const ZOMBIE_RADIUS := 12.0
const ARI_SPEED := 180.0
const ZOMBIE_SPEED := 72.0
const ZOMBIE_SPAWN_INTERVAL_SECONDS := 2.5
const ZOMBIE_ATTACK_RANGE := 26.0
const ZOMBIE_ATTACK_COOLDOWN_SECONDS := 1.0
const ZOMBIE_DAMAGE := 12.0

@onready var debug_label: Label = %DebugLabel
@onready var survival_label: Label = %SurvivalLabel

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
var day_clock := 0.0
var phase_time_left := PHASE_LENGTH_SECONDS
var snapshot_accumulator := 0.0
var scribe_accumulator := 0.0
var current_day := 1
var current_phase := "morning"
var current_sign := ""
var ari_max_hp := 100.0
var ari_hp := 100.0
var ari_fear := 0.0
var ari_hunger := 0.0
var ari_stamina := 100.0
var ari_current_action := "idle"
var ari_alive := true
var ari_position := Vector2.ZERO
var zombies: Array = []
var zombie_spawn_accumulator := 0.0
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

	restart_run(false)
	memory.record_event("phase_changed", {"day": current_day, "phase": current_phase, "time": elapsed_time})
	_record_runtime_snapshot()
	_update_ui()


func _process(delta: float) -> void:
	advance_runtime_memory(delta)


func advance_runtime_memory(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	elapsed_time += safe_delta
	advance_survival(safe_delta)
	snapshot_accumulator += safe_delta
	scribe_accumulator += safe_delta

	while snapshot_accumulator >= SNAPSHOT_INTERVAL_SECONDS:
		snapshot_accumulator -= SNAPSHOT_INTERVAL_SECONDS
		_record_runtime_snapshot()

	while scribe_accumulator >= AUTO_SCRIBE_INTERVAL_SECONDS:
		scribe_accumulator -= AUTO_SCRIBE_INTERVAL_SECONDS
		_create_scribe_note(false, "auto")

	_update_ui()
	queue_redraw()


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
			KEY_R:
				restart_run()


func advance_survival(delta: float) -> void:
	_update_day_night(delta)
	_update_ari(delta)
	_update_zombie_spawning(delta)
	_update_zombies(delta)
	_update_survival_placeholders(delta)
	_sync_world_counts()


func restart_run(record_event: bool = true) -> void:
	current_day = 1
	day_clock = 0.0
	current_phase = "morning"
	phase_time_left = PHASE_LENGTH_SECONDS
	ari_hp = ari_max_hp
	ari_fear = 0.0
	ari_hunger = 0.0
	ari_stamina = 100.0
	ari_current_action = "idle"
	ari_alive = true
	ari_position = _arena_rect().get_center()
	zombies.clear()
	zombie_spawn_accumulator = 0.0
	_sync_world_counts()
	if record_event:
		memory.record_event("run_restarted", _event_payload())
	_record_runtime_snapshot()
	_update_ui()
	queue_redraw()


func set_time_of_day_for_test(seconds: float) -> void:
	var previous_phase := current_phase
	day_clock = clampf(seconds, 0.0, DAY_LENGTH_SECONDS - 0.001)
	current_phase = _phase_for_time(day_clock)
	phase_time_left = _phase_time_left(day_clock)
	if current_phase != previous_phase:
		_record_phase_events(previous_phase)
	_update_ui()
	queue_redraw()


func spawn_zombie(spawn_position = null) -> Dictionary:
	var position := _random_edge_position()
	if spawn_position is Vector2:
		position = spawn_position
	var zombie := {
		"position": _clamp_to_arena(position),
		"attack_cooldown": 0.0,
	}
	zombies.append(zombie)
	_sync_world_counts()
	memory.record_event("enemy_spawned", _event_payload({"position": [position.x, position.y]}))
	_update_ui()
	queue_redraw()
	return zombie


func damage_ari(amount: float, source: String = "unknown") -> void:
	if not ari_alive:
		return
	var previous_hp := ari_hp
	ari_hp = maxf(0.0, ari_hp - maxf(amount, 0.0))
	ari_fear = clampf(ari_fear + 12.0, 0.0, 100.0)
	memory.record_event("ari_damaged", _event_payload({
		"source": source,
		"amount": previous_hp - ari_hp,
		"hp": ari_hp,
	}))
	if ari_hp <= 0.0:
		ari_alive = false
		ari_current_action = "dead"
		memory.record_event("ari_died", _event_payload({"source": source, "hp": ari_hp}))
	_update_ui()
	queue_redraw()


func _update_day_night(delta: float) -> void:
	if delta <= 0.0:
		phase_time_left = _phase_time_left(day_clock)
		return
	var previous_phase := current_phase
	var survived_night := false
	day_clock += delta
	while day_clock >= DAY_LENGTH_SECONDS:
		day_clock -= DAY_LENGTH_SECONDS
		if ari_alive:
			survived_night = true
		current_day += 1
	current_phase = _phase_for_time(day_clock)
	phase_time_left = _phase_time_left(day_clock)
	if survived_night:
		memory.record_event("night_survived", _event_payload({"survived_day": current_day - 1}))
	if current_phase != previous_phase:
		_record_phase_events(previous_phase)


func _record_phase_events(_previous_phase: String) -> void:
	memory.record_event("phase_changed", _event_payload({"phase": current_phase}))
	if current_phase == "night":
		memory.record_event("night_started", _event_payload())


func _update_ari(delta: float) -> void:
	if not ari_alive:
		ari_current_action = "dead"
		return
	var direction := Vector2.ZERO
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		direction.x -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		direction.x += 1.0
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		direction.y -= 1.0
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		direction.y += 1.0

	if direction.length() > 0.0 and ari_stamina > 0.0:
		ari_position = _clamp_to_arena(ari_position + direction.normalized() * ARI_SPEED * delta)
		ari_stamina = clampf(ari_stamina - 7.5 * delta, 0.0, 100.0)
		ari_current_action = "moving"
	else:
		ari_stamina = clampf(ari_stamina + 5.0 * delta, 0.0, 100.0)
		ari_current_action = "surviving_night" if current_phase == "night" and world_enemy_count > 0 else "idle"


func _update_zombie_spawning(delta: float) -> void:
	if not ari_alive or current_phase != "night":
		zombie_spawn_accumulator = 0.0
		return
	zombie_spawn_accumulator += delta
	while zombie_spawn_accumulator >= ZOMBIE_SPAWN_INTERVAL_SECONDS:
		zombie_spawn_accumulator -= ZOMBIE_SPAWN_INTERVAL_SECONDS
		spawn_zombie()


func _update_zombies(delta: float) -> void:
	if zombies.is_empty():
		return
	for zombie in zombies:
		if typeof(zombie) != TYPE_DICTIONARY:
			continue
		var position: Vector2 = zombie.get("position", ari_position)
		var cooldown := maxf(float(zombie.get("attack_cooldown", 0.0)) - delta, 0.0)
		if ari_alive:
			var to_ari := ari_position - position
			if to_ari.length() > 0.01:
				position += to_ari.normalized() * ZOMBIE_SPEED * delta
			if position.distance_to(ari_position) <= ZOMBIE_ATTACK_RANGE and cooldown <= 0.0:
				damage_ari(ZOMBIE_DAMAGE, "zombie")
				cooldown = ZOMBIE_ATTACK_COOLDOWN_SECONDS
		zombie["position"] = _clamp_to_arena(position)
		zombie["attack_cooldown"] = cooldown
	_sync_world_counts()


func _update_survival_placeholders(delta: float) -> void:
	var target_fear := 4.0
	if current_phase == "dusk":
		target_fear = 20.0
	elif current_phase == "night":
		target_fear = 38.0 + world_enemy_count * 12.0
	if not ari_alive:
		target_fear = 100.0
	ari_fear = _move_toward_float(ari_fear, clampf(target_fear, 0.0, 100.0), delta * 10.0)
	ari_hunger = clampf(ari_hunger + delta * 0.08, 0.0, 100.0)


func _sync_world_counts() -> void:
	world_enemy_count = zombies.size()


func _phase_for_time(time_of_day: float) -> String:
	if time_of_day < PHASE_LENGTH_SECONDS:
		return "morning"
	if time_of_day < PHASE_LENGTH_SECONDS * 2.0:
		return "midday"
	if time_of_day < NIGHT_START_SECONDS:
		return "dusk"
	return "night"


func _phase_time_left(time_of_day: float) -> float:
	var phase_index := int(floor(time_of_day / PHASE_LENGTH_SECONDS))
	var phase_end := minf(float(phase_index + 1) * PHASE_LENGTH_SECONDS, DAY_LENGTH_SECONDS)
	return maxf(0.0, phase_end - time_of_day)


func _event_payload(extra: Dictionary = {}) -> Dictionary:
	var payload := {
		"time": elapsed_time,
		"day": current_day,
		"phase": current_phase,
		"hp": ari_hp,
		"enemy_count": world_enemy_count,
	}
	for key in extra.keys():
		payload[key] = extra[key]
	return payload


func _arena_rect() -> Rect2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1152.0, 648.0)
	var right_panel_width := 430.0
	var left := 24.0
	var top := 104.0
	var width := maxf(360.0, viewport_size.x - right_panel_width - 56.0)
	var height := maxf(300.0, viewport_size.y - top - 28.0)
	return Rect2(Vector2(left, top), Vector2(width, height))


func _clamp_to_arena(position: Vector2) -> Vector2:
	var arena := _arena_rect()
	return Vector2(
		clampf(position.x, arena.position.x + ARI_RADIUS, arena.end.x - ARI_RADIUS),
		clampf(position.y, arena.position.y + ARI_RADIUS, arena.end.y - ARI_RADIUS)
	)


func _random_edge_position() -> Vector2:
	var arena := _arena_rect()
	var edge := randi() % 4
	match edge:
		0:
			return Vector2(lerpf(arena.position.x, arena.end.x, randf()), arena.position.y + ZOMBIE_RADIUS)
		1:
			return Vector2(lerpf(arena.position.x, arena.end.x, randf()), arena.end.y - ZOMBIE_RADIUS)
		2:
			return Vector2(arena.position.x + ZOMBIE_RADIUS, lerpf(arena.position.y, arena.end.y, randf()))
	return Vector2(arena.end.x - ZOMBIE_RADIUS, lerpf(arena.position.y, arena.end.y, randf()))


func _move_toward_float(value: float, target: float, amount: float) -> float:
	if value < target:
		return minf(value + amount, target)
	return maxf(value - amount, target)


func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1152.0, 648.0)
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.035, 0.045, 0.055, 1.0), true)

	var arena := _arena_rect()
	draw_rect(arena, Color(0.12, 0.16, 0.13, 1.0), true)
	draw_rect(arena, Color(0.36, 0.42, 0.36, 1.0), false, 3.0)
	for x in range(int(arena.position.x) + 64, int(arena.end.x), 64):
		draw_line(Vector2(x, arena.position.y), Vector2(x, arena.end.y), Color(1, 1, 1, 0.035), 1.0)
	for y in range(int(arena.position.y) + 64, int(arena.end.y), 64):
		draw_line(Vector2(arena.position.x, y), Vector2(arena.end.x, y), Color(1, 1, 1, 0.035), 1.0)

	for zombie in zombies:
		if typeof(zombie) == TYPE_DICTIONARY:
			draw_circle(zombie.get("position", Vector2.ZERO), ZOMBIE_RADIUS, Color(0.82, 0.13, 0.12, 1.0))
			draw_circle(zombie.get("position", Vector2.ZERO), ZOMBIE_RADIUS * 0.45, Color(0.25, 0.02, 0.02, 1.0))

	var ari_color := Color(0.12, 0.45, 1.0, 1.0) if ari_alive else Color(0.20, 0.22, 0.26, 1.0)
	draw_circle(ari_position, ARI_RADIUS, ari_color)
	draw_circle(ari_position + Vector2(4.0, -4.0), 3.0, Color(0.85, 0.94, 1.0, 1.0))

	var darkness := _darkness_alpha()
	if darkness > 0.0:
		draw_rect(arena, Color(0.0, 0.0, 0.07, darkness), true)


func _darkness_alpha() -> float:
	var progress := 1.0 - phase_time_left / PHASE_LENGTH_SECONDS
	match current_phase:
		"morning":
			return lerpf(0.18, 0.03, progress)
		"midday":
			return 0.0
		"dusk":
			return lerpf(0.08, 0.34, progress)
		"night":
			return 0.58
	return 0.0


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


func _update_ui() -> void:
	_update_survival_label()
	_update_debug_label()


func _update_survival_label() -> void:
	if survival_label == null:
		return
	survival_label.text = "\n".join([
		"Day: %d | Phase: %s | Time left: %.1fs" % [current_day, current_phase, phase_time_left],
		"Ari HP: %.0f/%.0f | Fear: %.0f | Hunger: %.0f | Stamina: %.0f" % [
			ari_hp,
			ari_max_hp,
			ari_fear,
			ari_hunger,
			ari_stamina,
		],
		"Enemies: %d | Action: %s" % [world_enemy_count, ari_current_action],
		"Move: WASD/arrows | R = restart run",
	])


func _update_debug_label() -> void:
	if debug_label == null:
		return
	debug_label.text = "\n".join([
		"AI Survival Trainer - AI Debug",
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
