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
const RunBuildScript = preload("res://scripts/ari/RunBuild.gd")
const EnemyControllerScript = preload("res://scripts/enemies/EnemyController.gd")
const DayNightCycleScript = preload("res://scripts/world/DayNightCycle.gd")
const WaveDirectorScript = preload("res://scripts/world/WaveDirector.gd")
const ResourceSystemScript = preload("res://scripts/world/ResourceSystem.gd")
const MineNodeScript = preload("res://scripts/stations/MineNode.gd")
const WorldScript = preload("res://scripts/world/World.gd")
const SignPanelScene = preload("res://scenes/ui/SignPanel.tscn")
const HUDScene = preload("res://scenes/ui/HUD.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var bridge: AIBridge = AIBridgeScript.new()
	root.add_child(bridge)
	bridge.force_provider_mode("local_stub")

	await _test_bridge_health_and_raw_validation(bridge)
	_test_deep_interpretation_contract(bridge)
	await _test_no_random_trait_runtime_contract()
	_test_ai_latency_cache_v1_contract(bridge)
	await _test_world_ai_latency_commit_contract()
	await _test_sign_panel_ai_status_line()
	await _test_hud_enemy_counter_is_readable()
	_test_local_combat_signs()
	_test_local_tower_range_signs()
	_test_local_flying_storm_signs()
	_test_farming_hunger_rest_behavior()
	_test_library_reflection_v1_contract()
	_test_permanent_upgrades_v1_contract()
	_test_enemy_variety_stats()
	_test_wave_director_escalates_with_flying()
	_test_day_night_balance_v1_targets()
	await _test_day_night_balance_v1_multiday_simulation()
	await _test_combat_survival_balance_v1_scenarios()
	await _test_survival_strategy_expansion_v1_contract(bridge)
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
		"emotion": "focused fear",
		"grounded_plan": [
			{
				"affordance_id": "use_existing_wall",
				"priority": 2.0,
				"reason": "The wall already exists, so cover matters more than building.",
			},
			{
				"affordance_id": "build_storm_rod",
				"priority": "0.8",
				"reason": "Wings need a sky answer.",
			},
			{
				"affordance_id": "unknown_spell",
				"priority": 1.0,
				"reason": "Unknown model affordances should be ignored.",
			},
		],
		"priority_hints": {
			"build_wall": 2.0,
			"wait_behind_wall": "0.7",
			"lure_to_aura": 0.8,
			"repair": 0.4,
			"kite": 1.5,
			"prepare_weapon": 0.5,
			"ranged_attack": 2.0,
			"use_tower": 0.9,
			"train_bow": "0.6",
			"eat": 0.3,
			"eat_food": 0.4,
			"build_storm_rod": 0.45,
			"anti_flying": 1.4,
			"sky_answer": 0.8,
			"unknown_key": 1.0,
		},
		"sign_strength": -5.0,
		"resonance": 2.0,
	}, payload, true, "remote_server")

	_assert(response.get("ok", false), "deep interpretation should report successful remote validation")
	_assert(str(response.get("interpretation", "")).length() == 240, "deep interpretation text should be capped")
	_assert(str(response.get("thought", "")).length() == 160, "deep thought text should be capped")
	_assert(response.get("emotion", "") == "focused fear", "deep response should preserve Ari emotion")
	var grounded_plan: Array = response.get("grounded_plan", [])
	_assert(grounded_plan.size() == 2, "deep grounded plan should keep known affordances and ignore unknown ones")
	if grounded_plan.size() >= 2:
		_assert(grounded_plan[0].get("affordance_id", "") == "use_existing_wall", "first grounded plan item should keep affordance id")
		_assert(grounded_plan[0].get("priority", 0.0) == 1.0, "grounded plan priority should be clamped")
		_assert(grounded_plan[1].get("affordance_id", "") == "build_storm_rod", "storm plan item should be preserved")
		_assert(grounded_plan[1].get("priority", 0.0) == 0.8, "grounded plan should accept numeric strings")
	var hints: Dictionary = response.get("priority_hints", {})
	_assert(hints.get("build_wall", 0.0) == 1.0, "deep build_wall hint should be clamped")
	_assert(hints.get("wait_behind_wall", 0.0) == 0.7, "deep wait_behind_wall hint should accept numeric strings")
	_assert(hints.get("lure_to_aura", 0.0) == 0.8, "deep lure_to_aura hint should be preserved")
	_assert(hints.get("repair", 0.0) == 0.4, "deep repair hint should be preserved")
	_assert(hints.get("kite", 0.0) == 1.0, "deep kite hint should be clamped")
	_assert(hints.get("prepare_weapon", 0.0) == 0.5, "deep prepare_weapon hint should be preserved")
	_assert(hints.get("ranged_attack", 0.0) == 1.0, "deep ranged_attack hint should be clamped")
	_assert(hints.get("use_tower", 0.0) == 0.9, "deep use_tower hint should be preserved")
	_assert(hints.get("train_bow", 0.0) == 0.6, "deep train_bow hint should accept numeric strings")
	_assert(hints.get("eat", 0.0) == 0.3, "deep eat hint should be preserved")
	_assert(hints.get("eat_food", 0.0) == 0.4, "deep eat_food hint should be preserved")
	_assert(hints.get("build_storm_rod", 0.0) == 0.8, "deep build_storm_rod hint should include grounded plan priority")
	_assert(hints.get("anti_flying", 0.0) == 1.0, "deep anti_flying hint should be clamped")
	_assert(hints.get("sky_answer", 0.0) == 0.8, "deep sky_answer hint should be preserved")
	_assert(not hints.has("unknown_key"), "deep priority hints should remove unknown keys")
	_assert(response.get("sign_strength", 1.0) == 0.0, "deep sign strength should clamp low values")
	_assert(response.get("resonance", 0.0) == 1.0, "deep resonance should clamp high values")

	var fallback := bridge._deep_fallback(payload, "disabled")
	var fallback_hints: Dictionary = fallback.get("priority_hints", {})
	var fallback_plan: Array = fallback.get("grounded_plan", [])
	_assert(not fallback.get("ok", true), "deep fallback should report unsuccessful remote use")
	_assert(fallback.get("source", "") == "disabled", "deep fallback should preserve source")
	_assert(fallback_hints.get("build_wall", 0.0) == 0.4, "deep fallback should translate local wall hint")
	_assert(fallback_hints.get("wait_or_idle", 0.0) == 0.2, "deep fallback should translate local defensive wait hint")
	_assert(fallback_plan.size() > 0 and fallback_plan[0].get("affordance_id", "") == "build_wall", "deep fallback should expose a grounded plan from local hints")


func _test_no_random_trait_runtime_contract() -> void:
	var removed_state_key := "person" + "ality"
	var removed_summary_key := removed_state_key + "_summary"
	var removed_script_path := "res://scripts/ari/" + "Person" + "ality.gd"
	var removed_node_name := "Person" + "ality"
	_assert(not ResourceLoader.exists(removed_script_path), "Ari random trait script should be removed from the active game")
	var sign_mind: SignMind = SignMindScript.new()
	var neutral := sign_mind.interpret_sign("stand behind the wall")
	var sign_faith_build := sign_mind.interpret_sign("stand behind the wall", {"points": {"sign_faith": 12}})
	_assert(float(sign_faith_build.get("sign_strength", 0.0)) > float(neutral.get("sign_strength", 0.0)), "SignMind should treat its second argument as run_build")
	sign_mind.free()

	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load without the removed trait resource")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	_assert(world.get_node_or_null(removed_node_name) == null, "World scene should not instantiate the removed trait node")
	var seen_state := {"state": {}}
	world.state_changed.connect(func(state: Dictionary) -> void:
		seen_state["state"] = state
	)
	world.call("_emit_state")
	await process_frame
	var state = seen_state.get("state", {})
	if typeof(state) == TYPE_DICTIONARY:
		_assert(not state.has(removed_state_key), "World state should not expose removed random traits")
		_assert(not state.has(removed_summary_key), "World state should not expose removed random trait summary")
	var payload: Dictionary = world.call("_build_ai_deep_interpretation_payload")
	var ari_payload = payload.get("ari", {})
	if typeof(ari_payload) == TYPE_DICTIONARY:
		_assert(not ari_payload.has(removed_state_key), "AIBridge deep payload should not send removed random traits")
	world.queue_free()


func _test_ai_latency_cache_v1_contract(bridge: AIBridge) -> void:
	_assert(bridge.has_method("clear_deep_interpretation_cache"), "AIBridge should expose a way to clear the in-memory deep interpretation cache")
	_assert(bridge.has_method("_deep_cache_key"), "AIBridge should build a stable deep interpretation cache key")
	_assert(bridge.has_method("_store_deep_interpretation_cache"), "AIBridge should store valid deep interpretations")
	_assert(bridge.has_method("_cached_deep_interpretation"), "AIBridge should return cached deep interpretations")
	if not bridge.has_method("clear_deep_interpretation_cache") or not bridge.has_method("_deep_cache_key") or not bridge.has_method("_store_deep_interpretation_cache") or not bridge.has_method("_cached_deep_interpretation"):
		return
	bridge.call("clear_deep_interpretation_cache")
	var payload := {
		"sign_text": "  Stand   behind the WALL  ",
		"world": {
			"phase": "midday",
			"wall_count": 1,
			"aura_orb_count": 0,
			"bow_tower_count": 0,
			"storm_rod_count": 0,
			"enemy_type_counts": {"flying": 1},
			"structures": [{"type": "wall", "status": "intact"}],
		},
		"current_affordances": [
			{"id": "use_existing_wall", "available": true},
			{"id": "build_storm_rod", "available": true},
		],
		"local_fallback": {
			"interpretation": "Ari locally reads the wall as cover.",
			"thought": "The wall may help.",
			"survival_theory": "local_cover",
			"priority_hints": {
				"use_existing_wall": 0.7,
			},
			"grounded_plan": [{
				"affordance_id": "use_existing_wall",
				"priority": 0.7,
				"reason": "The local sign reading points to the existing wall.",
			}],
			"sign_strength": 0.6,
			"resonance": 0.55,
		},
	}
	var similar_payload := payload.duplicate(true)
	similar_payload["sign_text"] = "stand behind the wall"
	var changed_context := payload.duplicate(true)
	changed_context["world"]["wall_count"] = 0

	_assert(bridge.call("_deep_cache_key", payload) == bridge.call("_deep_cache_key", similar_payload), "deep cache should treat whitespace/case-only sign edits as the same key")
	_assert(bridge.call("_deep_cache_key", payload) != bridge.call("_deep_cache_key", changed_context), "deep cache key should include compact world context")

	var remote_result := bridge._validate_deep_interpretation({
		"interpretation": "Remote says the wall is useful cover while wings need a sky answer.",
		"thought": "The sign is deeper than it looks, but I see the wall and the sky now.",
		"survival_theory": "cover_and_sky",
		"priority_hints": {
			"use_existing_wall": 0.8,
			"build_storm_rod": 0.7,
			"unknown_key": 1.0,
		},
		"grounded_plan": [{
			"affordance_id": "build_storm_rod",
			"priority": 0.7,
			"reason": "Flying enemies bypass walls, so storm support answers the sky.",
		}],
		"sign_strength": 0.9,
		"resonance": 0.85,
	}, payload, true, "remote_server")
	bridge.call("_store_deep_interpretation_cache", payload, remote_result)
	var cached: Dictionary = bridge.call("_cached_deep_interpretation", similar_payload)
	_assert(cached.get("ok", false), "deep cache should return a valid cached interpretation")
	_assert(cached.get("source", "") == "cache", "deep cache should mark cached results")
	_assert(bool(cached.get("cached", false)), "deep cache should expose cached status")
	_assert(cached.get("interpretation", "") == remote_result.get("interpretation", ""), "deep cache should preserve the remote interpretation")
	_assert(cached.get("priority_hints", {}).get("build_storm_rod", 0.0) == 0.7, "deep cache should preserve validated priority hints")

	bridge.force_provider_mode("remote_server")
	var cached_request_state := {"done": false, "result": {}}
	bridge.request_deep_interpretation(similar_payload, func(result: Dictionary) -> void:
		cached_request_state["done"] = true
		cached_request_state["result"] = result
	)
	_assert(cached_request_state["done"], "request_deep_interpretation should return cached results immediately")
	_assert(cached_request_state["result"].get("source", "") == "cache", "request_deep_interpretation should use cache before the network")
	bridge.force_provider_mode("local_stub")

	var failed := bridge._parse_deep_interpretation_response(payload, HTTPRequest.RESULT_TIMEOUT, 0, PackedByteArray())
	_assert(not failed.get("ok", true), "failed remote deep interpretation should report fallback")
	_assert(failed.get("source", "") == "request_failed", "failed remote deep interpretation should preserve failure source")
	_assert(failed.get("interpretation", "") == "Ari locally reads the wall as cover.", "failed remote deep interpretation should keep local interpretation")

	var world: World = WorldScript.new()
	_assert(world.has_method("_begin_ai_waiting"), "World should begin visible remote-AI thinking state")
	_assert(world.has_method("_advance_ai_waiting"), "World should advance visible remote-AI thinking state")
	_assert(world.has_method("_finish_ai_waiting"), "World should finish visible remote-AI thinking state")
	if not world.has_method("_begin_ai_waiting") or not world.has_method("_advance_ai_waiting") or not world.has_method("_finish_ai_waiting"):
		world.free()
		return
	world.call("_begin_ai_waiting")
	_assert(str(world.get("ai_status")).begins_with("AI: thinking"), "world should expose an AI thinking status while remote interpretation is pending")
	_assert(str(world.get("latest_thought")) == "I understand part of it. I need to turn the rest over.", "world should show the requested initial waiting thought")
	world.call("_advance_ai_waiting", 10.1)
	_assert(str(world.get("latest_thought")) == "The sign is still unfolding.", "world should show the requested long-pending thought after ten seconds")
	world.set("latest_thought", "sentinel after long pending")
	world.call("_advance_ai_waiting", 10.0)
	_assert(str(world.get("latest_thought")) == "sentinel after long pending", "world should not repeat the long-pending thought after it fires once")
	_assert(str(world.get("ai_status")).contains("thinking"), "world should keep exposing thinking status for slow remote interpretation")
	world.call("_finish_ai_waiting")
	_assert(not bool(world.get("_ai_waiting_active")), "world should stop pending state when remote interpretation resolves")
	world.free()


func _test_world_ai_latency_commit_contract() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should be loadable for AI latency integration checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("local_stub")

	world.commit_sign("stand behind the wall")
	var local_interpretation := str(world.get("sign_interpretation"))
	var local_hints: Dictionary = world.get("sign_priority_hints")
	_assert(local_interpretation != "" and local_interpretation != "No sign yet.", "committing a sign should apply local SignMind interpretation immediately")
	_assert(float(local_hints.get("use_existing_wall", 0.0)) > 0.0 or float(local_hints.get("defensive_wait", 0.0)) > 0.0 or float(local_hints.get("wall", 0.0)) > 0.0, "local fallback should immediately provide executable cover/wall priority")
	_assert(str(world.get("ai_status")) == "AI disabled", "AI-disabled commits should keep gameplay on local fallback")

	world.call("_begin_ai_waiting")
	var request_id := int(world.get("_ai_sign_request_id"))
	world.call("_on_ai_deep_interpretation_response", request_id, {
		"ok": true,
		"source": "remote_server",
		"interpretation": "Remote reads the wall as cover and gives Ari a calmer plan.",
		"thought": "The wall is not the whole answer, but it buys me time.",
		"survival_theory": "remote_cover",
		"emotion": "careful focus",
		"grounded_plan": [{
			"affordance_id": "use_existing_wall",
			"priority": 0.9,
			"reason": "The sign says to stand behind the existing wall.",
		}],
		"priority_hints": {
			"use_existing_wall": 0.9,
			"use_cover": 0.8,
		},
		"sign_strength": 0.82,
		"resonance": 0.76,
	})
	_assert(str(world.get("sign_interpretation")).begins_with("Remote reads"), "valid remote response should replace the displayed interpretation")
	_assert(float(world.get("sign_priority_hints").get("use_existing_wall", 0.0)) >= 0.9, "valid remote response should enhance priorities")
	_assert(str(world.get("ai_status")) == "AI: active", "valid remote response should leave AI active")
	_assert(str(world.get("latest_thought")).contains("buys me time"), "valid remote response should show Ari's AI thought")

	world.call("_begin_ai_waiting")
	world.call("_on_ai_deep_interpretation_response", request_id, {
		"ok": true,
		"source": "remote_server",
		"interpretation": "Remote sees the wall again.",
		"survival_theory": "remote_cover",
		"grounded_plan": [{
			"affordance_id": "use_existing_wall",
			"priority": 0.7,
			"reason": "The sign says to stand behind the existing wall.",
		}],
		"priority_hints": {
			"use_existing_wall": 0.7,
		},
		"sign_strength": 0.7,
		"resonance": 0.7,
	})
	_assert(str(world.get("latest_thought")) == "Now I see it.", "valid remote response without a thought should show the fallback understood moment")

	world.call("_begin_ai_waiting")
	world.call("_on_ai_deep_interpretation_response", request_id, {
		"ok": true,
		"cached": true,
		"source": "cache",
		"interpretation": "Cached remote reads the wall as cover.",
		"thought": "Cached thought should not override the remembered sign line.",
		"survival_theory": "cached_cover",
		"grounded_plan": [{
			"affordance_id": "use_existing_wall",
			"priority": 0.8,
			"reason": "The cached sign still points to existing cover.",
		}],
		"priority_hints": {
			"use_existing_wall": 0.8,
		},
		"sign_strength": 0.8,
		"resonance": 0.8,
	})
	_assert(str(world.get("ai_status")) == "AI: cached", "cached remote response should expose cached status")
	_assert(str(world.get("latest_thought")) == "I remember this sign.", "cached remote response should show the requested memory thought")

	var remote_interpretation := str(world.get("sign_interpretation"))
	world.call("_begin_ai_waiting")
	world.call("_on_ai_deep_interpretation_response", request_id, {
		"ok": false,
		"source": "request_failed",
	})
	_assert(str(world.get("sign_interpretation")) == remote_interpretation, "failed remote response should not erase the current interpretation")
	_assert(str(world.get("ai_status")) == "AI: failed/fallback", "failed remote response should expose fallback status")
	_assert(str(world.get("latest_thought")) == "I cannot hear more from the sign. I will use what I understood.", "failed remote response should show the requested fallback thought")

	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_sign_panel_ai_status_line() -> void:
	var panel = SignPanelScene.instantiate()
	root.add_child(panel)
	await process_frame
	panel.call("update_state", {
		"ai_status": "AI: thinking 12s...",
		"ai_top_hint": "build_tower",
		"sign_text": "stand behind the wall",
		"sign_interpretation": "Ari reads the wall as cover.",
	})
	var status_label = panel.get_node_or_null("DisplayPanel/DisplayVBox/AiHeaderRow/AiStatusLabel")
	_assert(status_label != null, "SignPanel should expose a compact AI status line in the AI section")
	if status_label != null:
		_assert(str(status_label.get("text")) == "AI: thinking 12s...", "SignPanel should show the current AI status")
	var sign_header = panel.get_node_or_null("DisplayPanel/DisplayVBox/SignHeaderLabel")
	var ai_header = panel.get_node_or_null("DisplayPanel/DisplayVBox/AiHeaderRow/AIHeaderLabel")
	_assert(sign_header != null and str(sign_header.get("text")) == "SIGN", "SignPanel should group the current sign under a Sign header")
	_assert(ai_header != null and str(ai_header.get("text")) == "AI", "SignPanel should group interpretation under an AI header")
	var plan_label = panel.get_node_or_null("DisplayPanel/DisplayVBox/PlanLabel")
	_assert(plan_label != null, "SignPanel should expose a readable plan label")
	if plan_label != null:
		_assert(str(plan_label.get("text")).contains("tower range"), "SignPanel should fall back to the local top hint when no grounded AI plan exists")
	root.remove_child(panel)
	panel.queue_free()
	await process_frame


func _test_hud_enemy_counter_is_readable() -> void:
	var hud = HUDScene.instantiate()
	root.add_child(hud)
	await process_frame
	hud.call("update_state", {
		"day": 2,
		"phase": "night",
		"time_left": 12.0,
		"ari_hp": 80.0,
		"ari_max_hp": 100.0,
		"enemy_count": 4,
		"enemy_type_counts": {
			"zombie": 1,
			"runner": 1,
			"brute": 1,
			"flying": 1,
		},
		"stone": 12,
		"food": 2,
		"ari_action": "use_cover",
		"ari_job_reason": "Use existing wall.",
		"selected_build_name": "Tower",
		"selected_build_type": "bow_tower",
		"run_build_name": "Balanced",
		"ai_survival_theory": "Remote theory should stay out of the HUD.",
		"ai_top_grounded_plan": "Remote plan should stay out of the HUD.",
		"ai_top_hint": "build_tower",
		"ai_status": "AI: active",
	})
	var status_label = hud.get_node_or_null("StatusPanel/Content/StatusLabel")
	var mind_label = hud.get_node_or_null("StatusPanel/Content/MindLabel")
	var build_label = hud.get_node_or_null("StatusPanel/Content/BuildLabel")
	_assert(status_label != null, "HUD should expose its status label")
	if status_label != null:
		var text := str(status_label.get("text"))
		_assert(text.contains("SURVIVAL"), "HUD should group phase, HP, and enemies under Survival")
		_assert(text.contains("NIGHT"), "HUD should make night phase obvious")
		_assert(text.contains("Enemies 4"), "HUD should label the enemy counter with a readable word")
		_assert(text.contains("Z1 R1 B1 F1"), "HUD should preserve per-enemy-type counters")
	_assert(mind_label != null, "HUD should expose Ari state")
	if mind_label != null:
		var text := str(mind_label.get("text"))
		_assert(text.contains("ARI"), "HUD should group current behavior under Ari")
		_assert(not text.contains("AI theory"), "HUD should not duplicate AI theory from the SignPanel")
		_assert(not text.contains("AI plan"), "HUD should not duplicate AI plan from the SignPanel")
		_assert(not text.contains("Top hint"), "HUD should not duplicate sign hint text from the SignPanel")
		_assert(not text.contains("AI:"), "HUD should leave AI status to the SignPanel")
	_assert(build_label != null, "HUD should expose resources and build preset")
	if build_label != null:
		var text := str(build_label.get("text"))
		_assert(text.contains("RESOURCES"), "HUD should group stone, food, and TP under Resources")
		_assert(text.contains("Stone 12"), "HUD should keep stone readable")
		_assert(text.contains("Food 2"), "HUD should keep food readable")
		_assert(text.contains("Build: Tower"), "HUD should keep the current build preset readable")
		_assert(text.contains("Keys:"), "HUD should preserve compact keyboard hints")
	root.remove_child(hud)
	hud.queue_free()
	await process_frame


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

	for sky_case in [
		{"key": "build_storm_rod", "label": "build_storm_rod"},
		{"key": "anti_flying", "label": "anti_flying"},
		{"key": "sky_answer", "label": "sky_answer"},
	]:
		var storm_decision := ari_mind.choose_daytime_job(_base_mind_context({
			"wall_count": 2,
			"aura_orb_count": 1,
			"storm_rod_count": 0,
			"priority_hints": {
				str(sky_case.get("key", "")): 0.9,
			},
		}))
		_assert(storm_decision.get("job", "") == "build_storm_rod", "%s hint should make Ari build a Storm Rod after basic defenses exist" % str(sky_case.get("label", "")))
		_assert(str(storm_decision.get("reason", "")).to_lower().contains("sky") or str(storm_decision.get("reason", "")).to_lower().contains("anti-air"), "%s storm reason should explain the sky threat" % str(sky_case.get("label", "")))

	var flying_pressure_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 2,
		"aura_orb_count": 1,
		"bow_tower_count": 1,
		"storm_rod_count": 0,
		"enemy_type_counts": {
			"flying": 1,
		},
	}))
	_assert(flying_pressure_decision.get("job", "") == "build_storm_rod", "seen flying enemies should push Ari toward Storm Rod support")

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

	var close_fight_decision: Dictionary = ari_mind.call("choose_night_tactic", _base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 1,
		"nearest_enemy_distance": 32.0,
		"ari_hp_ratio": 0.9,
		"combat_stats": {"combat_level": 1.0, "sword_skill": 1.2, "attack_damage": 18.0, "armor": 0.18},
		"priority_hints": {
			"fight_head_on": 0.95,
		},
	}))
	_assert(close_fight_decision.get("job", "") == "fight_head_on", "strong melee intent should attack inside normal flee distance when Ari is ready")

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


func _test_survival_strategy_expansion_v1_contract(bridge: AIBridge) -> void:
	for key in [
		"fight_head_on",
		"train_sword",
		"smith_sword",
		"mine_ore",
		"build_forge",
		"use_armor",
		"rely_on_regen",
		"regen_on_kill",
		"stall_until_dawn",
		"hide_until_dawn",
		"avoid_killing",
		"survive_until_morning",
	]:
		_assert(bridge.DEEP_PRIORITY_KEYS.has(key), "AIBridge should pass through %s priority hints" % key)

	var bridge_response := bridge._validate_deep_interpretation({
		"interpretation": "Ari reads the sign as a direct sword plan.",
		"thought": "If I must kill them, I need a blade first.",
		"survival_theory": "sword_killer",
		"grounded_plan": [
			{"affordance_id": "fight_head_on", "priority": 1.4, "reason": "The sign rejects hiding."},
			{"affordance_id": "smith_sword", "priority": 0.8, "reason": "A better blade makes contact less desperate."},
			{"affordance_id": "unknown_berserk", "priority": 1.0, "reason": "Unknown keys should not pass."},
		],
		"priority_hints": {
			"fight_head_on": 1.2,
			"train_sword": 0.7,
			"smith_sword": 0.8,
			"mine_ore": 0.5,
			"regen_on_kill": 0.9,
			"hide_until_dawn": -1.0,
			"unknown_berserk": 1.0,
		},
		"sign_strength": 0.9,
		"resonance": 0.8,
	}, {"local_fallback": {}}, true, "remote_server")
	var bridge_hints: Dictionary = bridge_response.get("priority_hints", {})
	_assert(bridge_hints.get("fight_head_on", 0.0) == 1.0, "fight_head_on hint should clamp and pass through")
	_assert(bridge_hints.get("smith_sword", 0.0) == 0.8, "smith_sword hint should pass through")
	_assert(bridge_hints.get("regen_on_kill", 0.0) == 0.9, "regen_on_kill hint should pass through")
	_assert(bridge_hints.get("hide_until_dawn", 1.0) == 0.0, "hide_until_dawn hint should clamp low values")
	_assert(not bridge_hints.has("unknown_berserk"), "unknown sword hints should be ignored")

	var resource_system: ResourceSystem = ResourceSystemScript.new()
	resource_system.call("_ready")
	_assert(resource_system.has_method("add_ore"), "ResourceSystem should track ore for smithing")
	_assert(resource_system.has_method("get_ore"), "ResourceSystem should expose ore count")
	if resource_system.has_method("add_ore") and resource_system.has_method("get_ore"):
		resource_system.call("add_ore", 3)
		_assert(int(resource_system.call("get_ore")) >= 3, "ore should be added to run resources")
		_assert(bool(resource_system.call("can_afford", {"ore": 2})), "ore should participate in affordability checks")
		_assert(bool(resource_system.call("spend", {"ore": 2})), "ore should be spendable")
		_assert(int(resource_system.call("get_state").get("ore", 0)) >= 1, "resource state should include ore")
	resource_system.free()

	var mine_node: MineNode = MineNodeScript.new()
	_assert(mine_node.has_method("mine_ore"), "MineNode should support an ore-focused mining job")
	mine_node.free()

	_assert(ResourceLoader.exists("res://data/weapons.json"), "weapons.json should define sword tiers")
	var weapons := _load_json_file("res://data/weapons.json")
	var sword_tiers: Dictionary = weapons.get("sword_tiers", {})
	_assert(sword_tiers.has("crude_sword"), "weapons.json should include a crude sword tier")
	_assert(sword_tiers.has("iron_sword"), "weapons.json should include an iron sword tier")

	var run_build: RunBuild = RunBuildScript.new()
	root.add_child(run_build)
	await process_frame
	_assert(bool(run_build.call("apply_preset_key", 9)), "run build key 9 should select Sword Killer")
	_assert(str(run_build.call("get_preset_name")) == "Sword Killer", "Sword Killer preset should be named clearly")
	var sword_effects: Dictionary = run_build.call("get_effects")
	_assert(float(sword_effects.get("sword_strength", 0.0)) > 0.0, "Sword Killer should grant sword strength")
	_assert(float(sword_effects.get("attack_damage_bonus", 0.0)) > 0.0, "Sword Killer should improve melee damage")
	_assert(float(sword_effects.get("attack_speed_multiplier", 1.0)) > 1.0, "Sword Killer should improve melee attack speed")
	root.remove_child(run_build)
	run_build.queue_free()

	var ari: AriController = AriControllerScript.new()
	ari.call("apply_run_build_effects", {
		"sword_strength": 0.8,
		"attack_damage_bonus": 0.35,
		"attack_speed_multiplier": 1.25,
		"armor_bonus": 0.18,
		"passive_regen_per_second": 0.2,
		"regen_on_kill": 6.0,
	})
	var combat_stats: Dictionary = ari.call("get_combat_stats")
	for stat_key in ["sword_skill", "attack_damage", "attack_speed", "armor", "passive_regen", "regen_on_kill", "sword_tier"]:
		_assert(combat_stats.has(stat_key), "Ari combat stats should include %s" % stat_key)
	_assert(ari.has_method("advance_sword_training_job"), "Ari should have a sword training job")
	_assert(ari.has_method("restore_from_kill"), "Ari should be able to apply regen-on-kill")
	ari.free()

	var sign_mind: SignMind = SignMindScript.new()
	var aggressive := sign_mind.interpret_sign("do not hide, focus on killing enemies")
	var aggressive_hints: Dictionary = aggressive.get("priority_hints", {})
	_assert(float(aggressive_hints.get("fight_head_on", 0.0)) >= 0.7, "aggressive signs should push fight_head_on")
	_assert(float(aggressive_hints.get("train_sword", 0.0)) > 0.0, "aggressive signs should push sword training")
	_assert(float(aggressive_hints.get("hide_until_dawn", 0.0)) <= 0.2, "do-not-hide signs should not push hiding")
	var light_dead := sign_mind.interpret_sign("make the dead walk through light")
	var light_dead_hints: Dictionary = light_dead.get("priority_hints", {})
	_assert(float(light_dead_hints.get("aura_orb", 0.0)) > float(light_dead_hints.get("fight_head_on", 0.0)), "dead-through-light signs should stay aura-oriented instead of becoming melee intent")
	var dawn_sign := sign_mind.interpret_sign("just survive until morning")
	var dawn_hints: Dictionary = dawn_sign.get("priority_hints", {})
	_assert(float(dawn_hints.get("stall_until_dawn", 0.0)) >= 0.7, "morning survival signs should push stall_until_dawn")
	_assert(float(dawn_hints.get("survive_until_morning", 0.0)) >= 0.7, "morning survival signs should push survive_until_morning")
	_assert(float(dawn_hints.get("avoid_killing", 0.0)) > 0.0, "morning survival signs should allow avoiding kills")
	var sword_sign := sign_mind.interpret_sign("make a sword that gives you life when they die")
	var sword_hints: Dictionary = sword_sign.get("priority_hints", {})
	_assert(float(sword_hints.get("smith_sword", 0.0)) > 0.0, "sword crafting signs should push smith_sword")
	_assert(float(sword_hints.get("regen_on_kill", 0.0)) > 0.0, "life-on-kill signs should push regen_on_kill")
	sign_mind.free()

	var ari_mind: AriMind = AriMindScript.new()
	var mine_ore_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"ore": 0,
		"sword_tier": 0,
		"sword_next_ore_cost": 2,
		"priority_hints": {"smith_sword": 0.9, "mine_ore": 0.8},
		"run_build": {"points": {"sword": 5, "smithing": 4, "defense": 3}},
	}))
	_assert(mine_ore_decision.get("job", "") == "mine_ore", "smithing plans should mine ore before a sword upgrade")
	var smith_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"ore": 3,
		"sword_tier": 0,
		"sword_next_ore_cost": 2,
		"priority_hints": {"smith_sword": 0.9},
		"run_build": {"points": {"sword": 5, "smithing": 4, "defense": 3}},
	}))
	_assert(smith_decision.get("job", "") == "smith_sword", "enough ore should let Ari smith a better sword")
	var train_sword_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"ore": 3,
		"sword_tier": 1,
		"combat_stats": {"combat_level": 0.2, "sword_skill": 0.0},
		"priority_hints": {"train_sword": 0.9},
		"run_build": {"points": {"sword": 5, "defense": 3}},
	}))
	_assert(train_sword_decision.get("job", "") == "train_sword", "sword training hint should use the dummy for sword skill")
	var night_fight_decision: Dictionary = ari_mind.call("choose_night_tactic", _base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 1,
		"nearest_enemy_distance": 96.0,
		"ari_hp_ratio": 0.9,
		"combat_stats": {"combat_level": 1.0, "sword_skill": 1.2, "attack_damage": 18.0, "armor": 0.18},
		"priority_hints": {"fight_head_on": 0.95},
	}))
	_assert(night_fight_decision.get("job", "") == "fight_head_on", "strong melee intent should allow head-on fighting at night")
	var night_lifesteal_decision: Dictionary = ari_mind.call("choose_night_tactic", _base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 1,
		"nearest_enemy_distance": 36.0,
		"ari_hp_ratio": 0.86,
		"combat_stats": {"combat_level": 0.6, "sword_skill": 0.8, "attack_damage": 20.0, "armor": 0.12},
		"priority_hints": {"smith_sword": 0.85, "train_sword": 0.55, "regen_on_kill": 0.9},
	}))
	_assert(night_lifesteal_decision.get("job", "") == "fight_head_on", "sword plus life-on-kill intent should become visible melee when Ari is ready")
	var stall_decision: Dictionary = ari_mind.call("choose_night_tactic", _base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 2,
		"nearest_enemy_distance": 130.0,
		"ari_hp_ratio": 0.8,
		"wall_count": 1,
		"has_valid_cover": true,
		"priority_hints": {"survive_until_morning": 0.95, "stall_until_dawn": 0.9, "avoid_killing": 0.8},
	}))
	_assert(["stall_until_dawn", "hide_until_dawn"].has(str(stall_decision.get("job", ""))), "morning survival intent should become an explicit stall/hide night tactic")
	ari_mind.free()

	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for survival strategy expansion checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	_assert(world.get("forge_station") != null, "World should expose a forge station")
	_assert(world.has_method("_advance_ari_melee_job"), "World should advance a melee combat job")
	_assert(world.has_method("_advance_ari_smithing_job"), "World should advance a smithing job")
	_assert(world.has_method("_clear_enemies_for_dawn"), "World should clear enemies at dawn")
	world.call("spawn_enemy_at_edge", "zombie")
	await process_frame
	_assert(int(world.call("get_enemy_count")) > 0, "World should spawn a test enemy before dawn")
	world.call("_on_phase_changed", 2, "morning")
	_assert(int(world.call("get_enemy_count")) == 0, "Dawn should despawn remaining night enemies")
	_assert(str(world.get("status_message")).contains("Dawn") or str(world.get("latest_thought")).contains("Morning"), "Dawn despawn should be visible in status or thought")
	root.remove_child(world)
	world.queue_free()
	await process_frame


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


func _test_local_flying_storm_signs() -> void:
	var sign_mind: SignMind = SignMindScript.new()
	for sign_text in [
		"the wings come from above",
		"build a storm rod for the sky",
		"lightning should answer flying teeth",
		"air danger needs thunder",
		"the wings do not fear stone",
	]:
		var interpretation := sign_mind.interpret_sign(sign_text)
		var hints: Dictionary = interpretation.get("priority_hints", {})
		_assert(float(hints.get("build_storm_rod", 0.0)) > 0.0, "local SignMind should read '%s' as Storm Rod intent" % sign_text)
		if sign_text == "the wings do not fear stone":
			_assert(float(hints.get("build_storm_rod", 0.0)) > float(hints.get("build_fear_lantern", 0.0)), "wings should beat the fear keyword in local anti-flying signs")
			_assert(str(interpretation.get("interpretation_text", "")).to_lower().contains("sky"), "wings/stone sign should produce a sky interpretation")
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
	var research_reflect_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 2,
		"meaningful_event_count": 1,
		"run_build": {"points": {"curiosity": 7}},
		"needs": {"hunger": 24.0, "stamina": 90.0, "fear": 18.0},
	}))
	_assert(research_reflect_decision.get("job", "") == "reflect_library", "research build should reflect after a meaningful event when needs are stable")
	ari_mind.free()


func _test_permanent_upgrades_v1_contract() -> void:
	_assert(ResourceLoader.exists("res://scripts/progression/PermanentUpgrades.gd"), "Permanent Upgrades v1 should expose scripts/progression/PermanentUpgrades.gd")
	_assert(ResourceLoader.exists("res://data/permanent_upgrades.json"), "Permanent Upgrades v1 should use data/permanent_upgrades.json")
	var script = load("res://scripts/progression/PermanentUpgrades.gd")
	if script == null:
		return
	var save_path := "user://permanent_upgrades_test.json"
	var absolute_save_path := ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(absolute_save_path)
	var progression = script.new()
	progression.set("save_path", save_path)
	_assert(progression.has_method("get_state"), "PermanentUpgrades should expose progression state")
	_assert(progression.has_method("advance_survival"), "PermanentUpgrades should award Time Points while Ari lives")
	_assert(progression.has_method("reset_run"), "PermanentUpgrades should support run reset without wiping progression")
	_assert(progression.has_method("buy_upgrade"), "PermanentUpgrades should let the player buy upgrades")
	_assert(progression.has_method("grant_time_points"), "PermanentUpgrades should support controlled Time Point grants")
	_assert(progression.has_method("save_now") and progression.has_method("load_now"), "PermanentUpgrades should save/load user JSON")
	if not progression.has_method("get_state") or not progression.has_method("buy_upgrade"):
		return

	var state: Dictionary = progression.call("get_state")
	var rows: Array = state.get("upgrade_rows", [])
	var ids := []
	for row in rows:
		if typeof(row) == TYPE_DICTIONARY:
			ids.append(str(row.get("id", "")))
	for required_id in [
		"max_hp",
		"base_damage",
		"defense",
		"mining_efficiency",
		"building_efficiency",
		"farming_yield",
		"warding_power",
		"regeneration",
		"movement_speed_small",
		"sign_understanding",
	]:
		_assert(ids.has(required_id), "PermanentUpgrades should define %s" % required_id)

	progression.set("seconds_per_time_point", 1.0)
	progression.call("advance_survival", 3.0, false, true)
	var earned_points := int(progression.call("get_state").get("time_points", 0))
	_assert(earned_points >= 1, "Time Points should increase while Ari is alive")
	progression.call("advance_survival", 3.0, false, true)
	var longer_survival_points := int(progression.call("get_state").get("time_points", 0))
	_assert(longer_survival_points > earned_points, "surviving longer should give more Time Points")
	progression.call("advance_survival", 5.0, false, false)
	_assert(int(progression.call("get_state").get("time_points", 0)) == longer_survival_points, "Time Points should not increase after Ari dies")
	progression.call("reset_run")
	_assert(int(progression.call("get_state").get("time_points", 0)) == longer_survival_points, "run reset should keep Time Points")

	progression.call("grant_time_points", 200)
	for upgrade_id in ids:
		progression.call("buy_upgrade", upgrade_id)
	var effects: Dictionary = progression.call("get_effects")
	_assert(float(effects.get("max_hp_bonus", 0.0)) > 0.0, "max_hp should increase Ari max HP")
	_assert(float(effects.get("base_damage_multiplier", 1.0)) > 1.0, "base_damage should improve damage")
	_assert(float(effects.get("damage_taken_multiplier", 1.0)) < 1.0, "defense should reduce incoming damage")
	_assert(float(effects.get("mining_speed_multiplier", 1.0)) > 1.0, "mining_efficiency should improve mining")
	_assert(float(effects.get("stone_cost_multiplier", 1.0)) < 1.0, "building_efficiency should reduce build costs")
	_assert(float(effects.get("farming_yield_multiplier", 1.0)) > 1.0 or float(effects.get("farming_speed_multiplier", 1.0)) > 1.0, "farming_yield should improve food production")
	_assert(float(effects.get("aura_damage_multiplier", 1.0)) > 1.0, "warding_power should improve aura damage")
	_assert(float(effects.get("rest_recovery_multiplier", 1.0)) > 1.0, "regeneration should improve rest recovery")
	_assert(float(effects.get("movement_speed_multiplier", 1.0)) > 1.0, "movement_speed_small should improve movement")
	_assert(float(effects.get("movement_speed_multiplier", 1.0)) <= 1.12, "movement_speed_small should stay capped")
	_assert(float(effects.get("sign_strength_bonus", 0.0)) > 0.0, "sign_understanding should improve local sign reading")

	progression.call("save_now")
	var loaded = script.new()
	loaded.set("save_path", save_path)
	loaded.call("load_now")
	var loaded_state: Dictionary = loaded.call("get_state")
	_assert(int(loaded_state.get("time_points", 0)) == int(progression.call("get_state").get("time_points", 0)), "saved Time Points should load")
	var loaded_upgrades: Dictionary = loaded_state.get("upgrades", {})
	_assert(int(loaded_upgrades.get("max_hp", 0)) >= 1, "saved upgrade levels should load")
	progression.free()
	loaded.free()
	DirAccess.remove_absolute(absolute_save_path)


func _test_enemy_variety_stats() -> void:
	var zombie: EnemyController = EnemyControllerScript.new()
	zombie.configure_type("zombie")
	var runner: EnemyController = EnemyControllerScript.new()
	runner.configure_type("runner")
	var brute: EnemyController = EnemyControllerScript.new()
	brute.configure_type("brute")
	var flying: EnemyController = EnemyControllerScript.new()
	flying.configure_type("flying")

	_assert(float(runner.get("speed")) > float(zombie.get("speed")), "runner should be faster than zombie")
	_assert(float(runner.get("max_hp")) < float(zombie.get("max_hp")), "runner should have lower HP than zombie")
	_assert(float(runner.get("structure_attack_damage")) < float(zombie.get("structure_attack_damage")), "runner should have lower wall damage than zombie")
	_assert(float(brute.get("speed")) < float(zombie.get("speed")), "brute should be slower than zombie")
	_assert(float(brute.get("max_hp")) > float(zombie.get("max_hp")), "brute should have higher HP than zombie")
	_assert(float(brute.get("structure_attack_damage")) > float(zombie.get("structure_attack_damage")), "brute should have higher wall damage than zombie")
	_assert(str(flying.get("enemy_type")) == "flying", "flying beast should keep the flying enemy type")
	_assert(flying.get("ignores_walls") == true, "flying beast should ignore walls and ground blockers")
	_assert(float(flying.get("max_hp")) < float(brute.get("max_hp")), "flying beast should have lower HP than brute")
	_assert(float(flying.get("structure_attack_damage")) <= float(runner.get("structure_attack_damage")), "flying beast should not be a primary wall attacker")
	_assert(ResourceLoader.exists("res://scenes/enemies/FlyingBeast.tscn"), "Flying Beast should have a readable scene resource")

	zombie.free()
	runner.free()
	brute.free()
	flying.free()


func _test_wave_director_escalates_with_flying() -> void:
	var director: WaveDirector = WaveDirectorScript.new()
	_assert(director.has_method("choose_enemy_type_for_day"), "WaveDirector should expose deterministic enemy type choice")
	if not director.has_method("choose_enemy_type_for_day"):
		director.free()
		return
	_assert(director.call("choose_enemy_type_for_day", 1, 0.01) == "zombie", "day 1 should only spawn baseline zombies")
	_assert(director.call("choose_enemy_type_for_day", 2, 0.10) == "runner", "day 2 should begin adding runners")
	_assert(director.call("choose_enemy_type_for_day", 3, 0.05) == "brute", "day 3 should begin adding brutes")
	_assert(director.call("choose_enemy_type_for_day", 5, 0.01) != "flying", "flying enemies should wait until Ari has seen several ground nights")
	_assert(director.call("choose_enemy_type_for_day", 6, 0.01) == "flying", "later nights should begin adding flying enemies")
	director.free()


func _test_day_night_balance_v1_targets() -> void:
	var cycle: DayNightCycle = DayNightCycleScript.new()
	var prep_seconds := float(cycle.get("morning_seconds")) + float(cycle.get("midday_seconds")) + float(cycle.get("dusk_seconds"))
	_assert(prep_seconds >= 76.0, "day preparation should be long enough for several meaningful tasks")
	_assert(float(cycle.get("night_seconds")) >= 28.0, "night should last long enough to read whether defenses worked")
	cycle.free()

	var director: WaveDirector = WaveDirectorScript.new()
	_assert(float(director.get("spawn_interval_seconds")) >= 3.5, "night spawns should be paced for readability")
	_assert(int(director.get("max_enemies")) <= 7, "night enemy cap should keep early fights readable")
	director.free()

	var materials := _load_json_file("res://data/materials.json")
	var stone_material: Dictionary = materials.get("materials", {}).get("crumbly_stone", {})
	_assert(float(stone_material.get("wall_hp", 0.0)) >= 46.0, "basic walls should buy time without solving the night alone")

	var structures := _load_json_file("res://data/structures.json")
	var structure_defs: Dictionary = structures.get("structures", {})
	var aura: Dictionary = structure_defs.get("aura_orb", {})
	var tower: Dictionary = structure_defs.get("bow_tower", {})
	_assert(float(aura.get("damage_per_second", 0.0)) <= 6.8, "aura should help without becoming an automatic kill field")
	_assert(float(tower.get("damage", 0.0)) <= 9.0, "tower damage should be strong but not erase every ground enemy immediately")

	var upgrades := _load_json_file("res://data/permanent_upgrades.json")
	var upgrade_defs: Dictionary = upgrades.get("upgrades", {})
	_assert(int(upgrade_defs.get("mining_efficiency", {}).get("base_cost", 0)) >= 3, "cheap permanent upgrades should still require a real survival run")
	_assert(int(upgrade_defs.get("max_hp", {}).get("base_cost", 0)) >= 4, "core permanent upgrades should help without replacing sign understanding")

	var ari: AriController = AriControllerScript.new()
	var start_hunger := float(ari.get("hunger"))
	ari.call("advance_survival_needs", 76.0, "midday")
	_assert(float(ari.get("hunger")) - start_hunger <= 8.0, "one longer prep window should not make hunger dominate the loop")
	ari.set("hp", 60.0)
	ari.call("restore_from_rest", 5.0)
	_assert(float(ari.get("hp")) >= 69.0, "short rest should be visibly useful after damage")
	ari.free()


func _test_day_night_balance_v1_multiday_simulation() -> void:
	seed(55)
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for day/night balance simulation")
	if world_scene == null:
		return
	var test_save_path := "user://permanent_upgrades_balance_test.json"
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	_isolate_balance_progression(world, test_save_path)
	world.call("start_run")
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("local_stub")
	world.call("select_run_build_preset", 5, false)
	world.call("commit_sign", "build walls, let arrows rain from a mountain, and make the dead walk through light")
	var stats: Dictionary = await _simulate_balance_seconds(world, 420.0, 0.25)
	print("Balance sim: day=%d phase=%s hp=%.1f hunger=%.1f food=%d stone=%d structures=%d enemies=%d max_wall=%d max_aura=%d max_tower=%d flying_seen=%s max_night_enemies=%d" % [
		int(stats.get("day", 1)),
		str(stats.get("phase", "")),
		float(stats.get("hp", 0.0)),
		float(stats.get("hunger", 0.0)),
		int(stats.get("food", 0)),
		int(stats.get("stone", 0)),
		int(stats.get("structures", 0)),
		int(stats.get("enemies", 0)),
		int(stats.get("max_wall_count", 0)),
		int(stats.get("max_aura_orb_count", 0)),
		int(stats.get("max_bow_tower_count", 0)),
		str(stats.get("flying_seen", false)),
		int(stats.get("max_night_enemies", 0)),
	])
	_assert(bool(stats.get("alive", false)), "a coherent wall/light/tower sign should survive a four-day balance simulation")
	_assert(int(stats.get("day", 1)) >= 5, "four-day simulation should reach the next morning")
	_assert(int(stats.get("max_wall_count", 0)) >= 2, "Ari should build enough basic wall cover during a defensive run")
	_assert(int(stats.get("max_aura_orb_count", 0)) >= 1, "Ari should make aura/light matter when the sign asks for it")
	_assert(int(stats.get("max_bow_tower_count", 0)) >= 1, "Ari should make tower/ranged prep matter when the sign asks for it")
	_assert(float(stats.get("hunger", 100.0)) < 85.0, "hunger should matter without dominating a competent four-day run")
	_assert(not bool(stats.get("flying_seen", false)), "flying should not appear during the first four nights")
	_assert(int(stats.get("max_night_enemies", 99)) <= 7, "night simulation should respect the readable enemy cap")
	root.remove_child(world)
	world.queue_free()
	await process_frame
	var absolute_save_path := ProjectSettings.globalize_path(test_save_path)
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(absolute_save_path)


func _test_combat_survival_balance_v1_scenarios() -> void:
	var scenarios := [
		{
			"id": "survive_until_morning",
			"seed": 191,
			"preset_key": 11,
			"sign": "just survive until morning",
		},
		{
			"id": "sword_killer",
			"seed": 271,
			"preset_key": 9,
			"sign": "do not hide, focus on killing enemies",
		},
		{
			"id": "lifesteal_smith",
			"seed": 353,
			"preset_key": 12,
			"sign": "make a sword that gives you life when they die",
		},
		{
			"id": "heavy_armor_thorns",
			"seed": 419,
			"preset_key": 10,
			"sign": "heavy armor and thorns",
		},
		{
			"id": "tower_arrows",
			"seed": 557,
			"preset_key": 5,
			"sign": "build a mountain where arrows rain",
		},
		{
			"id": "aura_circle",
			"seed": 631,
			"preset_key": 2,
			"sign": "the circle should eat the dead",
		},
	]
	var results := {}
	for scenario in scenarios:
		var stats: Dictionary = await _run_combat_survival_scenario(
			str(scenario.get("id", "")),
			int(scenario.get("seed", 1)),
			int(scenario.get("preset_key", 0)),
			str(scenario.get("sign", ""))
		)
		results[str(scenario.get("id", ""))] = stats
		_print_combat_survival_stats(stats)

	var survival: Dictionary = results.get("survive_until_morning", {})
	_assert(int(survival.get("day", 1)) >= 3, "survival-until-morning sign should last beyond the first night")
	_assert(int(survival.get("dawn_vanished_total", 0)) > 0, "survival-until-morning sign should benefit from dawn clearing enemies")

	var killer: Dictionary = results.get("sword_killer", {})
	_assert(int(killer.get("day", 1)) >= 3, "direct-killing build should remain viable past the first night")
	_assert(int(killer.get("melee_hits", 0)) > 0, "direct-killing build should visibly engage enemies in melee")

	var lifesteal: Dictionary = results.get("lifesteal_smith", {})
	_assert(int(lifesteal.get("ore_mined_events", 0)) > 0, "life-from-sword sign should pursue ore")
	_assert(int(lifesteal.get("max_sword_tier", 0)) >= 1, "life-from-sword sign should reach at least a crude sword")
	_assert(int(lifesteal.get("melee_hits", 0)) > 0, "life-from-sword sign should eventually risk melee to use the blade")
	_assert(float(lifesteal.get("max_regen_healed", 0.0)) <= 6.0, "regen-on-kill should reward aggression without erasing damage")

	var armor: Dictionary = results.get("heavy_armor_thorns", {})
	_assert(float(armor.get("final_armor", 0.0)) >= 0.10, "heavy armor build should expose meaningful armor")
	_assert(int(armor.get("max_thorn_totem_count", 0)) >= 1 or int(armor.get("ari_damaged_events", 0)) <= 6, "armor/thorns build should either prepare thorns or visibly reduce punishment")

	var tower: Dictionary = results.get("tower_arrows", {})
	_assert(int(tower.get("max_bow_tower_count", 0)) >= 1, "tower sign should build a tower")
	_assert(int(tower.get("ranged_hits", 0)) > 0 or int(tower.get("day", 1)) >= 3, "tower sign should either fire shots or buy survival time")

	var aura: Dictionary = results.get("aura_circle", {})
	_assert(int(aura.get("max_aura_orb_count", 0)) >= 1, "aura sign should place an aura orb")
	_assert(int(aura.get("aura_damage_events", 0)) > 0 or int(aura.get("day", 1)) >= 3, "aura sign should either damage enemies or buy survival time")


func _run_combat_survival_scenario(id: String, scenario_seed: int, preset_key: int, sign: String) -> Dictionary:
	seed(scenario_seed)
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for combat/survival scenario %s" % id)
	if world_scene == null:
		return {}
	var test_save_path := "user://combat_survival_balance_%s.json" % id
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	_isolate_balance_progression(world, test_save_path)
	world.call("start_run")
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("local_stub")
	world.call("select_run_build_preset", preset_key, false)
	world.call("commit_sign", sign)
	var stats: Dictionary = await _simulate_balance_seconds(world, 312.0, 0.30)
	stats["scenario"] = id
	stats["sign"] = sign
	stats["preset_key"] = preset_key
	stats["current_job"] = str(world.get("current_job"))
	stats["latest_thought"] = str(world.get("latest_thought"))
	root.remove_child(world)
	world.queue_free()
	await process_frame
	var absolute_save_path := ProjectSettings.globalize_path(test_save_path)
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(absolute_save_path)
	return stats


func _print_combat_survival_stats(stats: Dictionary) -> void:
	print("Combat/survival sim %s: day=%d phase=%s alive=%s hp=%.1f hunger=%.1f food=%d stone=%d ore=%d sword=%d armor=%.2f kills=%d melee=%d ranged=%d aura=%d dawn_vanished=%d smithed=%d walls=%d aura_orbs=%d towers=%d thorns=%d" % [
		str(stats.get("scenario", "")),
		int(stats.get("day", 1)),
		str(stats.get("phase", "")),
		str(stats.get("alive", false)),
		float(stats.get("hp", 0.0)),
		float(stats.get("hunger", 0.0)),
		int(stats.get("food", 0)),
		int(stats.get("stone", 0)),
		int(stats.get("ore", 0)),
		int(stats.get("max_sword_tier", 0)),
		float(stats.get("final_armor", 0.0)),
		int(stats.get("enemy_kills", 0)),
		int(stats.get("melee_hits", 0)),
		int(stats.get("ranged_hits", 0)),
		int(stats.get("aura_damage_events", 0)),
		int(stats.get("dawn_vanished_total", 0)),
		int(stats.get("sword_smithed_events", 0)),
		int(stats.get("max_wall_count", 0)),
		int(stats.get("max_aura_orb_count", 0)),
		int(stats.get("max_bow_tower_count", 0)),
		int(stats.get("max_thorn_totem_count", 0)),
	])


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
		"run_build": {"points": {}},
		"current_job": "wait_or_idle",
	}
	for key in overrides.keys():
		context[key] = overrides[key]
	return context


func _load_json_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}


func _isolate_balance_progression(world: World, save_path: String) -> void:
	var progression = world.get("permanent_progression")
	if progression == null:
		return
	progression.set("save_path", save_path)
	var zero_upgrades := {}
	var state: Dictionary = progression.call("get_state")
	for row in state.get("upgrade_rows", []):
		if typeof(row) == TYPE_DICTIONARY:
			zero_upgrades[str(row.get("id", ""))] = 0
	progression.set("time_points", 0)
	progression.set("deaths", 0)
	progression.set("best_day", 1)
	progression.set("upgrades", zero_upgrades)


func _simulate_balance_seconds(world: World, seconds: float, step_seconds: float) -> Dictionary:
	var elapsed := 0.0
	var frame_count := 0
	var max_night_enemies := 0
	var max_wall_count := 0
	var max_aura_orb_count := 0
	var max_bow_tower_count := 0
	var max_thorn_totem_count := 0
	var max_storm_rod_count := 0
	var max_sword_tier := 0
	var max_ore := 0
	var min_hp := INF
	var flying_seen := false
	while elapsed < seconds:
		var ari = world.get("ari")
		if ari == null or not bool(ari.call("is_alive")):
			break
		min_hp = minf(min_hp, float(ari.get("hp")))
		var step := minf(step_seconds, seconds - elapsed)
		world.call("_process", step)
		for structure in world.call("get_structures"):
			if is_instance_valid(structure) and structure.has_method("_process"):
				structure.call("_process", step)
		for enemy in world.call("get_enemies"):
			if is_instance_valid(enemy) and enemy.has_method("_process"):
				enemy.call("_process", step)
		var day_night = world.get("day_night")
		if day_night != null and bool(day_night.call("is_night")):
			max_night_enemies = maxi(max_night_enemies, int(world.call("get_enemy_count")))
		max_wall_count = maxi(max_wall_count, int(world.call("get_wall_count")))
		max_aura_orb_count = maxi(max_aura_orb_count, int(world.call("get_aura_orb_count")))
		max_bow_tower_count = maxi(max_bow_tower_count, int(world.call("get_bow_tower_count")))
		max_thorn_totem_count = maxi(max_thorn_totem_count, int(world.call("get_thorn_totem_count")))
		max_storm_rod_count = maxi(max_storm_rod_count, int(world.call("get_storm_rod_count")))
		if world.has_method("_current_sword_tier"):
			max_sword_tier = maxi(max_sword_tier, int(world.call("_current_sword_tier")))
		var resource_system = world.get("resource_system")
		if resource_system != null and resource_system.has_method("get_ore"):
			max_ore = maxi(max_ore, int(resource_system.call("get_ore")))
		var counts: Dictionary = world.call("get_enemy_type_counts")
		flying_seen = flying_seen or int(counts.get("flying", 0)) > 0
		elapsed += step
		frame_count += 1
		if frame_count % 120 == 0:
			await process_frame
	var ari = world.get("ari")
	var needs: Dictionary = ari.call("get_needs") if ari != null else {}
	var resource_system = world.get("resource_system")
	var day_night = world.get("day_night")
	var ari_memory = world.get("ari_memory")
	var event_summary := _summarize_balance_events(ari_memory.call("get_recent_events", 300) if ari_memory != null else [])
	return {
		"alive": ari != null and bool(ari.call("is_alive")),
		"hp": float(ari.get("hp")) if ari != null else 0.0,
		"min_hp": min_hp if min_hp < INF else 0.0,
		"hunger": float(needs.get("hunger", 100.0)),
		"day": int(day_night.get("day")) if day_night != null else 1,
		"phase": str(day_night.get("phase")) if day_night != null else "",
		"food": int(resource_system.call("get_food")) if resource_system != null else 0,
		"stone": int(resource_system.call("get_stone")) if resource_system != null else 0,
		"ore": int(resource_system.call("get_ore")) if resource_system != null and resource_system.has_method("get_ore") else 0,
		"structures": int(world.call("get_structures").size()),
		"wall_count": int(world.call("get_wall_count")),
		"aura_orb_count": int(world.call("get_aura_orb_count")),
		"bow_tower_count": int(world.call("get_bow_tower_count")),
		"max_wall_count": max_wall_count,
		"max_aura_orb_count": max_aura_orb_count,
		"max_bow_tower_count": max_bow_tower_count,
		"max_thorn_totem_count": max_thorn_totem_count,
		"max_storm_rod_count": max_storm_rod_count,
		"max_sword_tier": max_sword_tier,
		"max_ore": max_ore,
		"final_armor": float(ari.get("armor")) if ari != null else 0.0,
		"enemies": int(world.call("get_enemy_count")),
		"flying_seen": flying_seen,
		"max_night_enemies": max_night_enemies,
		"event_counts": event_summary.get("event_counts", {}),
		"enemy_kills": int(event_summary.get("enemy_kills", 0)),
		"melee_hits": int(event_summary.get("melee_hits", 0)),
		"ranged_hits": int(event_summary.get("ranged_hits", 0)),
		"aura_damage_events": int(event_summary.get("aura_damage_events", 0)),
		"dawn_clear_events": int(event_summary.get("dawn_clear_events", 0)),
		"dawn_vanished_total": int(event_summary.get("dawn_vanished_total", 0)),
		"sword_smithed_events": int(event_summary.get("sword_smithed_events", 0)),
		"ore_mined_events": int(event_summary.get("ore_mined_events", 0)),
		"ari_damaged_events": int(event_summary.get("ari_damaged_events", 0)),
		"max_regen_healed": float(event_summary.get("max_regen_healed", 0.0)),
		"total_regen_healed": float(event_summary.get("total_regen_healed", 0.0)),
	}


func _summarize_balance_events(events: Array) -> Dictionary:
	var event_counts := {}
	var enemy_kills := 0
	var melee_hits := 0
	var ranged_hits := 0
	var aura_damage_events := 0
	var dawn_clear_events := 0
	var dawn_vanished_total := 0
	var sword_smithed_events := 0
	var ore_mined_events := 0
	var ari_damaged_events := 0
	var max_regen_healed := 0.0
	var total_regen_healed := 0.0
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		var event_type := str(event.get("type", ""))
		event_counts[event_type] = int(event_counts.get(event_type, 0)) + 1
		match event_type:
			"enemy_killed":
				enemy_kills += 1
				var healed := maxf(float(event.get("regen_healed", 0.0)), 0.0)
				total_regen_healed += healed
				max_regen_healed = maxf(max_regen_healed, healed)
			"ari_melee_hit":
				melee_hits += 1
			"ari_ranged_hit":
				ranged_hits += 1
			"aura_damage_success":
				aura_damage_events += 1
			"dawn_enemies_vanished":
				dawn_clear_events += 1
				dawn_vanished_total += maxi(int(event.get("count", 0)), 0)
			"sword_smithed":
				sword_smithed_events += 1
			"ore_mined":
				ore_mined_events += 1
			"ari_damaged":
				ari_damaged_events += 1
	return {
		"event_counts": event_counts,
		"enemy_kills": enemy_kills,
		"melee_hits": melee_hits,
		"ranged_hits": ranged_hits,
		"aura_damage_events": aura_damage_events,
		"dawn_clear_events": dawn_clear_events,
		"dawn_vanished_total": dawn_vanished_total,
		"sword_smithed_events": sword_smithed_events,
		"ore_mined_events": ore_mined_events,
		"ari_damaged_events": ari_damaged_events,
		"max_regen_healed": max_regen_healed,
		"total_regen_healed": total_regen_healed,
	}


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
