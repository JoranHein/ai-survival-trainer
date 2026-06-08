class_name AriDoctrine
extends RefCounted

const MAX_DOCTRINES := 40
const MAX_BIAS_KEYS := 16
const MAX_PLAN_STEPS := 4
const MAX_CONTROL_ACTIONS := 6
const MAX_CONTROL_BREAK_REASONS := 6
const MAX_OUTCOME_REASON := 160
const CONTROL_ANCHOR_KINDS := [
	"safest_defense",
	"current_anchor",
	"tower",
	"aura",
	"cover",
	"wall",
	"storm_rod",
	"fear_lantern",
	"decoy_idol",
	"thorn_totem",
	"repair_target",
]
const CONTROL_BREAK_REASONS := [
	"danger_changed",
	"anchor_destroyed",
	"low_hp",
	"enemy_too_close",
	"anchor_invalid",
	"plan_completed",
	"resource_blocked",
	"required_resource_missing",
]
const CONTROL_ACTION_IDS := [
	"mine_stone",
	"build_wall",
	"wait_or_idle",
	"use_existing_wall",
	"wait_behind_wall",
	"use_cover",
	"place_aura_orb",
	"lure_to_aura",
	"train_combat",
	"prepare_weapon",
	"ranged_attack",
	"use_tower",
	"train_bow",
	"farm_food",
	"eat",
	"eat_food",
	"build_trap",
	"build_spike_trap",
	"build_tower",
	"build_tar_pit",
	"lure_to_tar_pit",
	"build_fear_lantern",
	"use_fear_lantern",
	"build_decoy_idol",
	"use_decoy_idol",
	"build_thorn_totem",
	"build_repair_bench",
	"use_thorns",
	"rest",
	"reflect_library",
	"repair",
	"repair_structure",
	"flee",
	"fight",
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
	"kite",
	"hide",
	"build_storm_rod",
	"anti_flying",
	"sky_answer",
	"anti_air_defense",
	"mining",
	"wall",
	"aura_orb",
	"combat_training",
	"range",
	"hold_best_defense",
	"defensive_wait",
]

var doctrines: Array = []


func clear() -> void:
	doctrines.clear()


func add_doctrine(raw_doctrine: Dictionary) -> Dictionary:
	var doctrine := _validate_doctrine(raw_doctrine)
	if doctrine.is_empty():
		return {}
	for i in range(doctrines.size()):
		if typeof(doctrines[i]) != TYPE_DICTIONARY:
			continue
		var existing: Dictionary = doctrines[i]
		if str(existing.get("id", "")) != str(doctrine.get("id", "")):
			continue
		if _doctrine_lessons_match(existing, doctrine):
			return {}
		doctrines[i] = _merge_doctrine(existing, doctrine)
		return doctrines[i].duplicate(true)
	doctrines.append(doctrine)
	while doctrines.size() > MAX_DOCTRINES:
		doctrines.pop_front()
	return doctrine.duplicate(true)


func add_doctrines(raw_doctrines) -> Array:
	var added := []
	if typeof(raw_doctrines) != TYPE_ARRAY:
		return added
	for raw_doctrine in raw_doctrines:
		if typeof(raw_doctrine) != TYPE_DICTIONARY:
			continue
		var doctrine := add_doctrine(raw_doctrine)
		if not doctrine.is_empty():
			added.append(doctrine)
	return added


func get_all_doctrines(max_count: int = MAX_DOCTRINES) -> Array:
	var count := clampi(max_count, 0, doctrines.size())
	var start := doctrines.size() - count
	var result := []
	for i in range(start, doctrines.size()):
		result.append(doctrines[i].duplicate(true))
	return result


func get_active_doctrines(context: Dictionary, max_count: int = 8) -> Array:
	var result := []
	for doctrine in doctrines:
		if typeof(doctrine) != TYPE_DICTIONARY:
			continue
		if not _matches_context(doctrine, context):
			continue
		result.append(doctrine.duplicate(true))
		if result.size() >= max_count:
			break
	return result


func apply_outcome_feedback(outcome: Dictionary) -> Array:
	var action_id := _normalize_id(str(outcome.get("action_id", "")))
	if action_id == "":
		return []
	var delta := _feedback_delta(str(outcome.get("outcome", "")))
	if is_zero_approx(delta):
		return []
	var changed := []
	for i in range(doctrines.size()):
		if typeof(doctrines[i]) != TYPE_DICTIONARY:
			continue
		var doctrine: Dictionary = doctrines[i]
		if not _doctrine_mentions_action(doctrine, action_id):
			continue
		var confidence := clampf(float(doctrine.get("confidence", 1.0)) + delta, 0.0, 1.0)
		doctrine["confidence"] = confidence
		var feedback_record := {
			"action_id": action_id,
			"outcome": _limit_text(str(outcome.get("outcome", "")), 60),
			"reason": _limit_text(str(outcome.get("reason", "")), MAX_OUTCOME_REASON),
		}
		doctrine["last_outcome"] = feedback_record
		if delta < 0.0:
			doctrine["failure_count"] = int(doctrine.get("failure_count", 0)) + 1
		else:
			doctrine["success_count"] = int(doctrine.get("success_count", 0)) + 1
		doctrines[i] = doctrine
		changed.append(doctrine.duplicate(true))
	return changed


func get_active_bias(context: Dictionary) -> Dictionary:
	var result := {}
	for doctrine in doctrines:
		if typeof(doctrine) != TYPE_DICTIONARY:
			continue
		if not _matches_context(doctrine, context):
			continue
		var confidence := clampf(float(doctrine.get("confidence", 1.0)), 0.0, 1.0)
		var bias: Dictionary = doctrine.get("bias", {})
		for key in bias.keys():
			var action_id := str(key)
			var value := clampf(float(bias[key]) * confidence, -1.0, 1.0)
			result[action_id] = clampf(float(result.get(action_id, 0.0)) + value, -1.0, 1.0)
		var control: Dictionary = doctrine.get("control", {})
		if not control.is_empty():
			if str(control.get("preferred_anchor_kind", "")).strip_edges() != "":
				result["hold_best_defense"] = clampf(float(result.get("hold_best_defense", 0.0)) + (0.45 * confidence), -1.0, 1.0)
			var avoid_actions = control.get("avoid_action_ids", [])
			if typeof(avoid_actions) == TYPE_ARRAY:
				for raw_action_id in avoid_actions:
					var control_action_id := _normalize_id(str(raw_action_id))
					if control_action_id == "":
						continue
					result[control_action_id] = clampf(float(result.get(control_action_id, 0.0)) - (0.35 * confidence), -1.0, 1.0)
	return result


func get_active_plan(context: Dictionary) -> Array:
	var candidates := []
	var seen := {}
	for doctrine in doctrines:
		if typeof(doctrine) != TYPE_DICTIONARY:
			continue
		if not _matches_context(doctrine, context):
			continue
		var confidence := clampf(float(doctrine.get("confidence", 1.0)), 0.0, 1.0)
		var plan: Array = doctrine.get("plan", [])
		for step in plan:
			if typeof(step) != TYPE_DICTIONARY:
				continue
			var affordance_id := str(step.get("affordance_id", step.get("action_id", "")))
			if affordance_id == "" or seen.has(affordance_id):
				continue
			var priority := clampf(float(step.get("priority", 0.0)) * confidence, 0.0, 1.0)
			if priority <= 0.0:
				continue
			candidates.append({
				"affordance_id": affordance_id,
				"priority": priority,
				"reason": _limit_text(str(step.get("reason", "")), 180),
			})
			seen[affordance_id] = true

		var bias: Dictionary = doctrine.get("bias", {})
		for key in bias.keys():
			var action_id := str(key)
			if seen.has(action_id):
				continue
			var priority := clampf(float(bias[key]) * confidence, 0.0, 1.0)
			if priority <= 0.0:
				continue
			candidates.append({
				"affordance_id": action_id,
				"priority": priority,
				"reason": _limit_text(str(doctrine.get("summary", "Doctrine bias is active.")), 180),
			})
			seen[action_id] = true

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("priority", 0.0)) > float(b.get("priority", 0.0))
	)
	return candidates.slice(0, mini(candidates.size(), MAX_PLAN_STEPS))


func _validate_doctrine(raw_doctrine: Dictionary) -> Dictionary:
	var when := _validate_when(raw_doctrine.get("when", {}))
	if when.is_empty():
		return {}
	var bias := _validate_bias(raw_doctrine.get("bias", {}))
	var plan := _validate_plan(raw_doctrine.get("plan", []))
	var control := _validate_control(raw_doctrine.get("control", {}))
	if bias.is_empty() and plan.is_empty() and control.is_empty():
		return {}
	var raw_id := str(raw_doctrine.get("id", raw_doctrine.get("title", "doctrine")))
	return {
		"id": _normalize_id(raw_id),
		"summary": _limit_text(str(raw_doctrine.get("summary", raw_doctrine.get("hypothesis", raw_id))), 240),
		"when": when,
		"bias": bias,
		"plan": plan,
		"control": control,
		"confidence": clampf(float(raw_doctrine.get("confidence", 1.0)), 0.0, 1.0),
		"failure_count": maxi(int(raw_doctrine.get("failure_count", 0)), 0),
		"success_count": maxi(int(raw_doctrine.get("success_count", 0)), 0),
		"source": _limit_text(str(raw_doctrine.get("source", "")), 64),
		"failure_reason": _limit_text(str(raw_doctrine.get("failure_reason", "")), 64),
		"origin": _limit_text(str(raw_doctrine.get("origin", "")), 80),
		"reflection_id": _limit_text(str(raw_doctrine.get("reflection_id", "")), 120),
		"summary_id": _limit_text(str(raw_doctrine.get("summary_id", "")), 120),
		"evidence_ids": _string_array(raw_doctrine.get("evidence_ids", raw_doctrine.get("evidence_snapshot_ids", [])), 20, 120),
	}


func _doctrine_lessons_match(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("id", "")) == str(b.get("id", "")) \
		and str(a.get("summary", "")) == str(b.get("summary", "")) \
		and a.get("when", {}) == b.get("when", {}) \
		and a.get("bias", {}) == b.get("bias", {}) \
		and a.get("plan", []) == b.get("plan", []) \
		and a.get("control", {}) == b.get("control", {})


func _merge_doctrine(existing: Dictionary, incoming: Dictionary) -> Dictionary:
	var merged := incoming.duplicate(true)
	merged["confidence"] = maxf(float(existing.get("confidence", 1.0)), float(incoming.get("confidence", 1.0)))
	merged["failure_count"] = maxi(int(existing.get("failure_count", 0)), int(incoming.get("failure_count", 0)))
	merged["success_count"] = maxi(int(existing.get("success_count", 0)), int(incoming.get("success_count", 0)))
	if existing.has("last_outcome") and not merged.has("last_outcome"):
		merged["last_outcome"] = existing.get("last_outcome")
	for key in ["source", "failure_reason", "origin", "reflection_id", "summary_id"]:
		if str(merged.get(key, "")).strip_edges() == "" and str(existing.get(key, "")).strip_edges() != "":
			merged[key] = existing.get(key)
	if existing.has("control") and (not merged.has("control") or merged.get("control", {}).is_empty()):
		merged["control"] = existing.get("control")
	var evidence_ids := _string_array(merged.get("evidence_ids", []), 20, 120)
	for item in _string_array(existing.get("evidence_ids", []), 20, 120):
		if not evidence_ids.has(item):
			evidence_ids.append(item)
		if evidence_ids.size() >= 20:
			break
	merged["evidence_ids"] = evidence_ids
	return merged


func _validate_when(value) -> Dictionary:
	var result := {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	if value.has("enemy_type_present"):
		var enemy_type := _limit_text(str(value.get("enemy_type_present", "")), 60)
		if enemy_type != "":
			result["enemy_type_present"] = enemy_type
	if value.has("phase"):
		var phase = value.get("phase")
		if typeof(phase) == TYPE_ARRAY:
			var phases := []
			for raw_phase in phase:
				var phase_text := _limit_text(str(raw_phase), 40)
				if phase_text != "" and not phases.has(phase_text):
					phases.append(phase_text)
			if not phases.is_empty():
				result["phase"] = phases
		else:
			var phase_text := _limit_text(str(phase), 40)
			if phase_text != "":
				result["phase"] = phase_text
	if value.has("min_day"):
		result["min_day"] = max(1, int(value.get("min_day", 1)))
	if value.has("max_hp_ratio"):
		result["max_hp_ratio"] = clampf(float(value.get("max_hp_ratio", 1.0)), 0.0, 1.0)
	if value.has("structure_destroyed"):
		var destroyed = value.get("structure_destroyed")
		if typeof(destroyed) == TYPE_BOOL:
			result["structure_destroyed"] = destroyed
		else:
			var destroyed_text := _limit_text(str(destroyed), 60)
			if destroyed_text != "":
				result["structure_destroyed"] = destroyed_text
	var behavior_pattern := ""
	if value.has("behavior_pattern"):
		behavior_pattern = _limit_text(str(value.get("behavior_pattern", "")), 80)
	elif value.has("pattern"):
		behavior_pattern = _limit_text(str(value.get("pattern", "")), 80)
	if behavior_pattern != "":
		result["behavior_pattern"] = behavior_pattern
	if value.has("danger_changed"):
		result["danger_changed"] = bool(value.get("danger_changed", false))
	return result


func _validate_bias(value) -> Dictionary:
	var result := {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for raw_key in value.keys():
		var key := _normalize_id(str(raw_key))
		if key == "":
			continue
		var bias_value := clampf(float(value[raw_key]), -1.0, 1.0)
		if is_zero_approx(bias_value):
			continue
		result[key] = bias_value
		if result.size() >= MAX_BIAS_KEYS:
			break
	return result


func _validate_plan(value) -> Array:
	var result := []
	var seen := {}
	if typeof(value) != TYPE_ARRAY:
		return result
	for raw_step in value:
		if typeof(raw_step) != TYPE_DICTIONARY:
			continue
		var affordance_id := _normalize_id(str(raw_step.get("affordance_id", raw_step.get("action_id", raw_step.get("id", "")))))
		if affordance_id == "" or seen.has(affordance_id):
			continue
		var priority := clampf(float(raw_step.get("priority", raw_step.get("urgency", 0.0))), 0.0, 1.0)
		if priority <= 0.0:
			continue
		result.append({
			"affordance_id": affordance_id,
			"priority": priority,
			"reason": _limit_text(str(raw_step.get("reason", "")), 180),
		})
		seen[affordance_id] = true
		if result.size() >= MAX_PLAN_STEPS:
			break
	return result


func _validate_control(value) -> Dictionary:
	var result := {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	var anchor := _normalize_id(str(value.get("preferred_anchor_kind", value.get("anchor_kind", value.get("preferred_anchor", "")))))
	if CONTROL_ANCHOR_KINDS.has(anchor):
		result["preferred_anchor_kind"] = anchor
	if value.has("min_hold_seconds"):
		result["min_hold_seconds"] = clampf(float(value.get("min_hold_seconds", 0.0)), 3.0, 45.0)
	var avoid_actions := []
	var raw_avoid_actions = value.get("avoid_action_ids", value.get("avoid_actions", []))
	if typeof(raw_avoid_actions) == TYPE_ARRAY:
		for raw_action in raw_avoid_actions:
			var action_id := _normalize_id(str(raw_action))
			if not CONTROL_ACTION_IDS.has(action_id) or avoid_actions.has(action_id):
				continue
			avoid_actions.append(action_id)
			if avoid_actions.size() >= MAX_CONTROL_ACTIONS:
				break
	if not avoid_actions.is_empty():
		result["avoid_action_ids"] = avoid_actions
	var break_reasons := []
	var raw_break_reasons = value.get("allowed_break_reasons", value.get("break_reasons", []))
	if typeof(raw_break_reasons) == TYPE_ARRAY:
		for raw_reason in raw_break_reasons:
			var reason_id := _normalize_id(str(raw_reason))
			if not CONTROL_BREAK_REASONS.has(reason_id) or break_reasons.has(reason_id):
				continue
			break_reasons.append(reason_id)
			if break_reasons.size() >= MAX_CONTROL_BREAK_REASONS:
				break
	if not break_reasons.is_empty():
		result["allowed_break_reasons"] = break_reasons
	return result


func _matches_context(doctrine: Dictionary, context: Dictionary) -> bool:
	var when: Dictionary = doctrine.get("when", {})
	if when.has("enemy_type_present"):
		var enemy_type := str(when.get("enemy_type_present", ""))
		if not _matches_enemy_type_present(enemy_type, context):
			return false
	if when.has("phase") and not _matches_phase(when.get("phase"), str(context.get("phase", ""))):
		return false
	if when.has("min_day") and int(context.get("day", 1)) < int(when.get("min_day", 1)):
		return false
	if when.has("max_hp_ratio") and clampf(float(context.get("ari_hp_ratio", 1.0)), 0.0, 1.0) > float(when.get("max_hp_ratio", 1.0)):
		return false
	if when.has("structure_destroyed") and not _matches_structure_destroyed(when.get("structure_destroyed"), context):
		return false
	if when.has("behavior_pattern") and not _matches_behavior_pattern(str(when.get("behavior_pattern", "")), context):
		return false
	if when.has("danger_changed") and bool(context.get("danger_changed", false)) != bool(when.get("danger_changed", false)):
		return false
	return true


func _matches_enemy_type_present(enemy_type: String, context: Dictionary) -> bool:
	var counts = context.get("enemy_type_counts", {})
	if typeof(counts) == TYPE_DICTIONARY and int(counts.get(enemy_type, 0)) > 0:
		return true
	var known_types = context.get("known_enemy_types", [])
	if typeof(known_types) != TYPE_ARRAY:
		return false
	for raw_type in known_types:
		if str(raw_type) == enemy_type:
			return true
	return false


func _matches_phase(predicate, phase: String) -> bool:
	if typeof(predicate) == TYPE_ARRAY:
		for item in predicate:
			if str(item) == phase:
				return true
		return false
	return str(predicate) == phase


func _matches_structure_destroyed(predicate, context: Dictionary) -> bool:
	if context.has("structure_destroyed"):
		var direct = context.get("structure_destroyed")
		if typeof(predicate) == TYPE_BOOL:
			return bool(direct) == bool(predicate)
		return str(direct) == str(predicate)
	var events = context.get("recent_events", [])
	if typeof(events) != TYPE_ARRAY:
		return false
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		var event_type := str(event.get("type", ""))
		if event_type != "structure_destroyed" and event_type != "wall_destroyed":
			continue
		if typeof(predicate) == TYPE_BOOL:
			return bool(predicate)
		var structure_type := str(event.get("structure_type", ""))
		if structure_type == str(predicate) or event_type == str(predicate):
			return true
	return false


func _matches_behavior_pattern(pattern: String, context: Dictionary) -> bool:
	if pattern == "":
		return false
	if str(context.get("behavior_pattern", "")) == pattern:
		return true
	var patterns = context.get("behavior_patterns", [])
	if typeof(patterns) == TYPE_ARRAY:
		for item in patterns:
			if str(item) == pattern:
				return true
	var evidence_items = context.get("behavior_evidence", [])
	if typeof(evidence_items) == TYPE_ARRAY:
		for evidence in evidence_items:
			if typeof(evidence) == TYPE_DICTIONARY and str(evidence.get("primary_pattern", "")) == pattern:
				return true
	elif typeof(evidence_items) == TYPE_DICTIONARY and str(evidence_items.get("primary_pattern", "")) == pattern:
		return true
	return false


func _feedback_delta(outcome: String) -> float:
	var normalized := _normalize_id(outcome)
	match normalized:
		"ari_died", "death":
			return -0.40
		"near_death", "ari_near_death":
			return -0.28
		"structure_destroyed", "action_failed":
			return -0.22
		"action_blocked":
			return -0.18
		"action_completed":
			return 0.05
		"dawn_survived":
			return 0.10
		"enemy_killed":
			return 0.06
	return 0.0


func _doctrine_mentions_action(doctrine: Dictionary, action_id: String) -> bool:
	var bias: Dictionary = doctrine.get("bias", {})
	for key in bias.keys():
		if _actions_equivalent(_normalize_id(str(key)), action_id):
			return true
	var plan: Array = doctrine.get("plan", [])
	for step in plan:
		if typeof(step) != TYPE_DICTIONARY:
			continue
		var step_action := _normalize_id(str(step.get("affordance_id", step.get("action_id", ""))))
		if _actions_equivalent(step_action, action_id):
			return true
	var control: Dictionary = doctrine.get("control", {})
	var avoid_actions = control.get("avoid_action_ids", [])
	if typeof(avoid_actions) == TYPE_ARRAY:
		for raw_action in avoid_actions:
			if _actions_equivalent(_normalize_id(str(raw_action)), action_id):
				return true
	return false


func _actions_equivalent(left: String, right: String) -> bool:
	if left == right:
		return true
	if left == "build_tower" and right == "build_bow_tower":
		return true
	if left == "build_bow_tower" and right == "build_tower":
		return true
	return false


func _normalize_id(text: String) -> String:
	var normalized := text.to_lower().strip_edges()
	normalized = normalized.replace(" ", "_")
	normalized = normalized.replace("-", "_")
	return _limit_text(normalized, 80)


func _string_array(value, max_count: int, max_length: int) -> Array:
	var result := []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		if result.size() >= max_count:
			break
		var text := _limit_text(str(item), max_length)
		if text != "" and not result.has(text):
			result.append(text)
	return result


func _limit_text(text: String, max_length: int) -> String:
	var cleaned := text.strip_edges()
	return cleaned if cleaned.length() <= max_length else cleaned.substr(0, max_length)
