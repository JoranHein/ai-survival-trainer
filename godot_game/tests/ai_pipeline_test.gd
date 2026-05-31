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
const AriControllerScript = preload("res://scripts/ari/AriController.gd")
const AriMindScript = preload("res://scripts/ari/AriMind.gd")
const SignMindScript = preload("res://scripts/ari/SignMind.gd")
const EnemyControllerScript = preload("res://scripts/enemies/EnemyController.gd")
const WaveDirectorScript = preload("res://scripts/world/WaveDirector.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var bridge: AIBridge = AIBridgeScript.new()
	root.add_child(bridge)
	bridge.force_provider_mode("local_stub")

	await _test_bridge_health_and_raw_validation(bridge)
	_test_deep_interpretation_contract(bridge)
	_test_local_combat_signs()
	_test_local_tower_range_signs()
	_test_farming_hunger_rest_behavior()
	_test_library_reflection_v1_contract()
	_test_enemy_variety_stats()
	_test_wave_director_escalates_without_flying()
	_test_ai_tactical_priority_jobs()
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
			"lure_to_aura": 0.8,
			"repair": 0.4,
			"kite": 1.5,
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
	_assert(hints.get("lure_to_aura", 0.0) == 0.8, "deep lure_to_aura hint should be preserved")
	_assert(hints.get("repair", 0.0) == 0.4, "deep repair hint should be preserved")
	_assert(hints.get("kite", 0.0) == 1.0, "deep kite hint should be clamped")
	_assert(not hints.has("unknown_key"), "deep priority hints should remove unknown keys")
	_assert(response.get("sign_strength", 1.0) == 0.0, "deep sign strength should clamp low values")
	_assert(response.get("resonance", 0.0) == 1.0, "deep resonance should clamp high values")

	var fallback := bridge._deep_fallback(payload, "disabled")
	var fallback_hints: Dictionary = fallback.get("priority_hints", {})
	_assert(not fallback.get("ok", true), "deep fallback should report unsuccessful remote use")
	_assert(fallback.get("source", "") == "disabled", "deep fallback should preserve source")
	_assert(fallback_hints.get("build_wall", 0.0) == 0.4, "deep fallback should translate local wall hint")
	_assert(fallback_hints.get("wait_or_idle", 0.0) == 0.2, "deep fallback should translate local defensive wait hint")


func _test_ai_tactical_priority_jobs() -> void:
	var ari_mind: AriMind = AriMindScript.new()

	var cover_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 1,
		"aura_orb_count": 0,
		"priority_hints": {
			"use_existing_wall": 0.9,
			"wait_behind_wall": 0.8,
			"use_cover": 0.9,
			"build_wall": 0.1,
		},
	}))
	_assert(cover_decision.get("job", "") == "use_cover", "cover hints should make Ari use an existing wall instead of building more")
	_assert(str(cover_decision.get("reason", "")).to_lower().contains("wall"), "cover job should explain the wall tactic")

	var aura_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 1,
		"aura_orb_count": 1,
		"priority_hints": {
			"lure_to_aura": 0.95,
			"place_aura_orb": 0.2,
		},
	}))
	_assert(aura_decision.get("job", "") == "lure_to_aura", "lure_to_aura should make Ari use an existing Aura Orb instead of building")
	_assert(str(aura_decision.get("reason", "")).to_lower().contains("light"), "aura lure job should explain the light tactic")

	var repair_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 1,
		"damaged_structure_count": 0,
		"priority_hints": {
			"repair": 0.9,
		},
	}))
	_assert(repair_decision.get("job", "") == "wait_or_idle", "repair hint without damaged structures should not invent a new repair system")
	_assert(str(repair_decision.get("reason", "")).to_lower().contains("repair"), "unavailable repair should still be reported as Ari's reason")

	for training_case in [
		{"key": "train_combat", "label": "train_combat"},
		{"key": "fight", "label": "fight"},
		{"key": "prepare_weapon", "label": "prepare_weapon"},
	]:
		var training_decision := ari_mind.choose_daytime_job(_base_mind_context({
			"wall_count": 2,
			"aura_orb_count": 1,
			"priority_hints": {
				str(training_case.get("key", "")): 0.9,
			},
		}))
		_assert(training_decision.get("job", "") == "train_combat", "%s hint should make Ari train after basic defenses exist" % str(training_case.get("label", "")))
		_assert(str(training_decision.get("reason", "")).to_lower().contains("prepare") or str(training_decision.get("reason", "")).to_lower().contains("combat"), "%s training reason should explain combat preparation" % str(training_case.get("label", "")))

	for ranged_case in [
		{"key": "use_tower", "label": "use_tower"},
		{"key": "train_bow", "label": "train_bow"},
		{"key": "ranged_attack", "label": "ranged_attack"},
	]:
		var tower_decision := ari_mind.choose_daytime_job(_base_mind_context({
			"wall_count": 2,
			"bow_tower_count": 1,
			"priority_hints": {
				str(ranged_case.get("key", "")): 0.9,
			},
		}))
		_assert(tower_decision.get("job", "") == "use_tower", "%s hint should make Ari use an existing tower" % str(ranged_case.get("label", "")))
		_assert(str(tower_decision.get("reason", "")).to_lower().contains("tower") or str(tower_decision.get("reason", "")).to_lower().contains("range"), "%s tower reason should explain the ranged tactic" % str(ranged_case.get("label", "")))

	var build_tower_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 2,
		"bow_tower_count": 0,
		"priority_hints": {
			"build_tower": 0.9,
		},
	}))
	_assert(build_tower_decision.get("job", "") == "build_bow_tower", "build_tower hint should make Ari build a tower when defenses exist")

	var runner_pressure_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 2,
		"aura_orb_count": 1,
		"bow_tower_count": 1,
		"enemy_type_counts": {
			"runner": 2,
		},
	}))
	_assert(["use_tower", "lure_to_aura", "use_cover"].has(str(runner_pressure_decision.get("job", ""))), "runner pressure should push Ari toward active defensive positioning")

	var brute_pressure_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 2,
		"aura_orb_count": 1,
		"bow_tower_count": 1,
		"enemy_type_counts": {
			"brute": 1,
		},
	}))
	_assert(brute_pressure_decision.get("job", "") == "use_tower" or brute_pressure_decision.get("job", "") == "lure_to_aura", "brute pressure should prefer damage over adding weak walls")

	_assert(ari_mind.has_method("choose_night_tactic"), "AriMind should choose tactical night behavior")
	if not ari_mind.has_method("choose_night_tactic"):
		ari_mind.free()
		return

	var night_cover_decision: Dictionary = ari_mind.call("choose_night_tactic", _base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 2,
		"nearest_enemy_distance": 118.0,
		"ari_hp_ratio": 0.82,
		"wall_count": 1,
		"has_valid_cover": true,
		"priority_hints": {
			"use_existing_wall": 0.8,
			"wait_behind_wall": 0.9,
			"use_cover": 0.9,
		},
	}))
	_assert(night_cover_decision.get("job", "") == "use_cover", "night cover hints should keep Ari using wall cover")

	var night_aura_decision: Dictionary = ari_mind.call("choose_night_tactic", _base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 2,
		"nearest_enemy_distance": 112.0,
		"ari_hp_ratio": 0.9,
		"wall_count": 1,
		"aura_orb_count": 1,
		"has_valid_aura": true,
		"priority_hints": {
			"lure_to_aura": 0.95,
		},
	}))
	_assert(night_aura_decision.get("job", "") == "lure_to_aura", "night aura hint should keep Ari luring through an existing orb")

	var night_tower_decision: Dictionary = ari_mind.call("choose_night_tactic", _base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 2,
		"nearest_enemy_distance": 112.0,
		"ari_hp_ratio": 0.9,
		"wall_count": 1,
		"bow_tower_count": 1,
		"has_valid_tower": true,
		"priority_hints": {
			"use_tower": 0.9,
			"ranged_attack": 0.9,
		},
	}))
	_assert(night_tower_decision.get("job", "") == "use_tower", "night tower hints should keep Ari using a tower perch")

	var close_enemy_decision: Dictionary = ari_mind.call("choose_night_tactic", _base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 1,
		"nearest_enemy_distance": 28.0,
		"ari_hp_ratio": 0.7,
		"wall_count": 1,
		"has_valid_cover": true,
		"priority_hints": {
			"use_cover": 0.9,
		},
	}))
	_assert(close_enemy_decision.get("job", "") == "flee", "Ari should flee when enemies are too close for the tactic")
	_assert(str(close_enemy_decision.get("reason", "")).to_lower().contains("close"), "flee reason should explain close danger")

	var broken_cover_decision: Dictionary = ari_mind.call("choose_night_tactic", _base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 1,
		"nearest_enemy_distance": 90.0,
		"ari_hp_ratio": 0.8,
		"wall_count": 0,
		"has_valid_cover": false,
		"priority_hints": {
			"use_cover": 0.9,
		},
	}))
	_assert(broken_cover_decision.get("job", "") == "flee", "Ari should reposition when sign cover fails at night")
	_assert(str(broken_cover_decision.get("reason", "")).to_lower().contains("wall"), "failed cover reason should mention the wall")
	ari_mind.free()


func _test_local_combat_signs() -> void:
	var sign_mind: SignMind = SignMindScript.new()
	for sign_text in [
		"train before night",
		"make your hands hurt them",
		"teeth are coming",
		"fight the dead",
		"be ready to hit",
	]:
		var interpretation := sign_mind.interpret_sign(sign_text)
		var hints: Dictionary = interpretation.get("priority_hints", {})
		_assert(float(hints.get("combat_training", 0.0)) > 0.0, "local SignMind should read '%s' as combat training" % sign_text)
	sign_mind.free()


func _test_local_tower_range_signs() -> void:
	var sign_mind: SignMind = SignMindScript.new()
	for sign_text in [
		"arrows keep teeth far away",
		"build a mountain where arrows rain",
		"shoot from above",
		"height keeps teeth below",
	]:
		var interpretation := sign_mind.interpret_sign(sign_text)
		var hints: Dictionary = interpretation.get("priority_hints", {})
		_assert(float(hints.get("range", 0.0)) > 0.0 or float(hints.get("build_tower", 0.0)) > 0.0, "local SignMind should read '%s' as range or tower intent" % sign_text)
	sign_mind.free()


func _test_farming_hunger_rest_behavior() -> void:
	var ari: AriController = AriControllerScript.new()
	ari.reset_run()
	var starting_hunger := float(ari.get("hunger"))
	ari.advance_survival_needs(10.0, "morning")
	_assert(float(ari.get("hunger")) > starting_hunger, "Ari hunger should rise over time")

	ari.set("hunger", 82.0)
	ari.restore_from_food(30.0)
	_assert(float(ari.get("hunger")) < 82.0, "eating should reduce hunger pressure")

	ari.set("hp", 52.0)
	ari.set("fear", 74.0)
	ari.set("stamina", 26.0)
	ari.set("hunger", 66.0)
	ari.restore_from_rest(2.0)
	_assert(float(ari.get("hp")) > 52.0, "rest should recover HP")
	_assert(float(ari.get("fear")) < 74.0, "rest should lower fear")
	_assert(float(ari.get("stamina")) > 26.0, "rest should recover stamina")
	_assert(float(ari.get("hunger")) <= 66.0, "rest should not increase hunger pressure")
	ari.free()

	var sign_mind: SignMind = SignMindScript.new()
	var food_sign := sign_mind.interpret_sign("full stomach, quiet heart, long life")
	var food_hints: Dictionary = food_sign.get("priority_hints", {})
	_assert(float(food_hints.get("farm_food", 0.0)) > 0.0, "SignMind should read full stomach as food intent")
	_assert(float(food_hints.get("rest", 0.0)) > 0.0, "SignMind should read quiet heart as rest intent")

	var rest_sign := sign_mind.interpret_sign("I really need some time for myself to breathe")
	var rest_hints: Dictionary = rest_sign.get("priority_hints", {})
	_assert(float(rest_hints.get("rest", 0.0)) > 0.0, "SignMind should read time for myself and breathe as rest intent")
	sign_mind.free()

	var ari_mind: AriMind = AriMindScript.new()
	var eat_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"food": 1,
		"needs": {"hunger": 82.0, "stamina": 92.0, "fear": 18.0},
	}))
	_assert(eat_decision.get("job", "") == "eat_food", "high hunger with food should make Ari eat")

	var farm_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"food": 0,
		"needs": {"hunger": 76.0, "stamina": 92.0, "fear": 18.0},
	}))
	_assert(farm_decision.get("job", "") == "farm_food", "high hunger without food should make Ari farm")

	var rest_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 2,
		"ari_hp_ratio": 0.34,
		"needs": {"hunger": 22.0, "stamina": 88.0, "fear": 20.0},
	}))
	_assert(rest_decision.get("job", "") == "rest", "low HP with defenses should make Ari rest")

	var rest_sign_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 2,
		"priority_hints": {"rest": 0.9},
		"needs": {"hunger": 22.0, "stamina": 88.0, "fear": 20.0},
	}))
	_assert(rest_sign_decision.get("job", "") == "rest", "rest sign should make Ari rest when defenses exist")

	var raw_eat_hint_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"food": 0,
		"priority_hints": {"eat": 0.9},
		"needs": {"hunger": 30.0, "stamina": 90.0, "fear": 18.0},
	}))
	_assert(raw_eat_hint_decision.get("job", "") == "farm_food", "raw eat AI hint should make Ari prepare food")
	ari_mind.free()


func _test_library_reflection_v1_contract() -> void:
	_assert(ResourceLoader.exists("res://scenes/stations/Library.tscn"), "Library v1 should expose a Library.tscn station resource")

	var sign_mind: SignMind = SignMindScript.new()
	var why_sign := sign_mind.interpret_sign("why did the wall fail")
	var why_hints: Dictionary = why_sign.get("priority_hints", {})
	_assert(float(why_hints.get("reflect_library", 0.0)) > 0.0, "SignMind should read why/mistake language as library reflection")
	sign_mind.free()

	var memory = AriMemoryScript.new()
	_assert(memory.has_method("create_lifetime_note_from_recent_events"), "AriMemory should create lifetime notes from recent events")
	_assert(memory.has_method("get_lifetime_notes"), "AriMemory should expose lifetime notes")
	_assert(memory.has_method("get_note_priority_bias"), "AriMemory should expose newest-note priority bias")
	if not memory.has_method("create_lifetime_note_from_recent_events"):
		return

	memory.record_event("structure_destroyed", {"structure_type": "wall", "day": 2, "phase": "night"})
	var note: Dictionary = memory.call("create_lifetime_note_from_recent_events", 2)
	_assert(str(note.get("title", "")).to_lower().contains("wall"), "library note should title the wall failure")
	_assert(str(note.get("markdown_text", "")).begins_with("#"), "library note should have markdown-like text")
	_assert(note.get("tags", []).has("structure_destroyed"), "library note should tag the source event")
	var note_hints: Dictionary = note.get("priority_hints", {})
	_assert(float(note_hints.get("build_wall", 0.0)) > 0.0 or float(note_hints.get("place_aura_orb", 0.0)) > 0.0, "library note should carry soft priority hints")
	_assert(int(note.get("created_day", 0)) == 2, "library note should store created day")
	_assert(memory.call("get_lifetime_notes").size() == 1, "memory should store the created lifetime note")

	var duplicate_note: Dictionary = memory.call("create_lifetime_note_from_recent_events", 2)
	_assert(duplicate_note.is_empty(), "reflection should not spam duplicate notes for the same event")

	memory.record_event("enemy_killed", {"enemy_type": "runner", "day": 2, "phase": "night"})
	var second_note: Dictionary = memory.call("create_lifetime_note_from_recent_events", 2)
	_assert(not second_note.is_empty(), "a new meaningful event should allow a new lifetime note")
	var bias: Dictionary = memory.call("get_note_priority_bias")
	_assert(float(bias.get("place_aura_orb", 0.0)) > 0.0 or float(bias.get("train_combat", 0.0)) > 0.0, "newest note should softly bias future priorities")

	var reflection = ReflectionSystemScript.new()
	var safe_note: Dictionary = reflection._validate_reflection({
		"title": "Day 2 - The tower saved me",
		"markdown_text": "# Day 2\n\nThe tower helped.",
		"tags": ["tower_ranged_success"],
		"priority_hints": {"build_tower": 0.4},
		"created_day": 2,
	})
	_assert(safe_note.has("markdown_text"), "ReflectionSystem should preserve markdown_text")
	_assert(safe_note.has("tags"), "ReflectionSystem should preserve note tags")
	_assert(safe_note.has("priority_hints"), "ReflectionSystem should preserve priority_hints")

	var ari_mind: AriMind = AriMindScript.new()
	var curious_reflect_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 2,
		"meaningful_event_count": 1,
		"personality": {"fearfulness": 0.25, "aggression": 0.2, "curiosity": 0.92},
		"needs": {"hunger": 24.0, "stamina": 90.0, "fear": 18.0},
	}))
	_assert(curious_reflect_decision.get("job", "") == "reflect_library", "curious Ari should reflect after a meaningful event when needs are stable")
	ari_mind.free()


func _test_enemy_variety_stats() -> void:
	var zombie: EnemyController = EnemyControllerScript.new()
	zombie.configure_type("zombie")
	var runner: EnemyController = EnemyControllerScript.new()
	runner.configure_type("runner")
	var brute: EnemyController = EnemyControllerScript.new()
	brute.configure_type("brute")

	_assert(float(runner.get("speed")) > float(zombie.get("speed")), "runner should be faster than zombie")
	_assert(float(runner.get("max_hp")) < float(zombie.get("max_hp")), "runner should have lower HP than zombie")
	_assert(float(runner.get("structure_attack_damage")) < float(zombie.get("structure_attack_damage")), "runner should have lower wall damage than zombie")
	_assert(float(brute.get("speed")) < float(zombie.get("speed")), "brute should be slower than zombie")
	_assert(float(brute.get("max_hp")) > float(zombie.get("max_hp")), "brute should have higher HP than zombie")
	_assert(float(brute.get("structure_attack_damage")) > float(zombie.get("structure_attack_damage")), "brute should have higher wall damage than zombie")

	zombie.free()
	runner.free()
	brute.free()


func _test_wave_director_escalates_without_flying() -> void:
	var director: WaveDirector = WaveDirectorScript.new()
	_assert(director.has_method("choose_enemy_type_for_day"), "WaveDirector should expose deterministic enemy type choice")
	if not director.has_method("choose_enemy_type_for_day"):
		director.free()
		return
	_assert(director.call("choose_enemy_type_for_day", 1, 0.01) == "zombie", "day 1 should only spawn baseline zombies")
	_assert(director.call("choose_enemy_type_for_day", 2, 0.10) == "runner", "day 2 should begin adding runners")
	_assert(director.call("choose_enemy_type_for_day", 3, 0.05) == "brute", "day 3 should begin adding brutes")
	for roll in [0.0, 0.08, 0.24, 0.55, 0.99]:
		_assert(director.call("choose_enemy_type_for_day", 5, roll) != "flying", "Enemy Variety v1 should not spawn flying enemies")
	director.free()


func _base_mind_context(overrides: Dictionary) -> Dictionary:
	var context := {
		"is_night": false,
		"phase": "midday",
		"time_left": 25.0,
		"night_close": false,
		"stone": 20,
		"wall_cost": 4,
		"aura_orb_cost": 5,
		"spike_trap_cost": 5,
		"bow_tower_cost": 6,
		"tar_pit_cost": 4,
		"fear_lantern_cost": 5,
		"decoy_idol_cost": 4,
		"thorn_totem_cost": 5,
		"repair_bench_cost": 6,
		"storm_rod_cost": 7,
		"wall_count": 0,
		"aura_orb_count": 0,
		"spike_trap_count": 0,
		"bow_tower_count": 0,
		"tar_pit_count": 0,
		"fear_lantern_count": 0,
		"decoy_idol_count": 0,
		"thorn_totem_count": 0,
		"repair_bench_count": 0,
		"storm_rod_count": 0,
		"damaged_structure_count": 0,
		"lowest_structure_hp_ratio": 1.0,
		"combat_stats": {"combat_level": 0.0},
		"needs": {"hunger": 28.0, "stamina": 92.0, "fear": 18.0},
		"food": 2,
		"lesson_count": 0,
		"lesson_priority_bias": {},
		"priority_hints": {},
		"personality": {"fearfulness": 0.45, "aggression": 0.25, "curiosity": 0.5},
		"run_build": {"points": {}},
		"current_job": "wait_or_idle",
	}
	for key in overrides.keys():
		context[key] = overrides[key]
	return context


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
