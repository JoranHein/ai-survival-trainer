class_name SignMind
extends Node

const HINT_ORDER := [
	"combat_training",
	"range",
	"wall",
	"aura_orb",
	"mining",
	"farm_food",
	"build_trap",
	"build_tower",
	"build_tar_pit",
	"build_fear_lantern",
	"build_decoy_idol",
	"build_thorn_totem",
	"build_repair_bench",
	"repair_structure",
	"build_storm_rod",
	"rest",
	"reflect_library",
	"defensive_wait",
]

const KEYWORDS := {
	"combat_training": ["train", "training", "combat", "fight", "hurt", "attack", "weapon", "weapons", "sword", "bow", "arrow", "arrows", "kill", "teeth", "danger", "hands", "prepare", "ready", "hit", "hits", "hitting"],
	"range": ["bow", "arrow", "arrows", "shoot", "shooting", "range", "ranged", "distance", "far", "away"],
	"wall": ["wall", "walls", "stone", "fortress", "protect"],
	"aura_orb": ["light", "circle", "orb", "ward"],
	"mining": ["mine", "mining", "rock", "rocks", "stone"],
	"farm_food": ["farm", "food", "eat", "eating", "hungry", "hunger", "stomach", "crop", "crops", "harvest", "fruit", "full"],
	"build_trap": ["trap", "traps", "spike", "spikes", "floor", "ground", "punish", "snare"],
	"build_tower": ["tower", "towers", "height", "high", "above", "below", "mountain", "perch", "rain"],
	"build_tar_pit": ["slow", "slows", "mud", "tar", "sticky", "stuck", "sink", "mire"],
	"build_fear_lantern": ["lantern", "lamp", "fire", "warm", "warmth", "brave", "courage", "fear", "afraid", "safe", "safety"],
	"build_decoy_idol": ["decoy", "idol", "bait", "lure", "attract", "distract", "distraction", "false", "dummy"],
	"build_thorn_totem": ["thorn", "thorns", "skin", "bite", "biting", "touch", "touching", "recoil", "punish", "punishes"],
	"build_repair_bench": ["workbench", "bench", "tool", "tools", "fixer"],
	"repair_structure": ["repair", "repairs", "fix", "fixing", "mend", "mending", "patch", "patched", "broken"],
	"build_storm_rod": ["storm", "storms", "rod", "lightning", "thunder", "sky", "air", "flying", "wing", "wings"],
	"rest": ["rest", "sleep", "bed", "quiet", "calm", "heart", "tired", "heal", "safe", "safety", "breathe", "breath", "myself", "alone"],
	"reflect_library": ["library", "book", "books", "read", "note", "notes", "remember", "lesson", "learn", "think", "mistake", "mistakes", "why"],
	"defensive_wait": ["wait", "hide", "safe", "safety"],
}


const HINT_LABELS := {
	"combat_training": "training",
	"range": "distance",
	"wall": "walls",
	"aura_orb": "light",
	"mining": "stone",
	"farm_food": "food",
	"build_trap": "traps",
	"build_tower": "height",
	"build_tar_pit": "slow ground",
	"build_fear_lantern": "safe light",
	"build_decoy_idol": "decoy",
	"build_thorn_totem": "thorns",
	"build_repair_bench": "repair tools",
	"repair_structure": "repairs",
	"build_storm_rod": "storm",
	"rest": "quiet",
	"reflect_library": "memory",
	"defensive_wait": "safety",
}


func interpret_sign(sign_text: String, personality := {}, run_build := {}) -> Dictionary:
	var clean_text := sign_text.strip_edges()
	var hints := _empty_hints()
	if clean_text == "":
		return {
			"interpretation_text": "No sign yet.",
			"priority_hints": hints,
			"sign_strength": 0.0,
			"resonance": 0.0,
		}

	var tokens := _tokenize(clean_text)
	var matched_keyword_count := 0
	for hint_name in HINT_ORDER:
		var hint_key := str(hint_name)
		var keywords_value = KEYWORDS.get(hint_key, [])
		var keywords: Array = keywords_value if typeof(keywords_value) == TYPE_ARRAY else []
		var count := _count_keyword_matches(tokens, keywords)
		matched_keyword_count += count
		hints[hint_key] = clampf(float(count) / 2.0, 0.0, 1.0)
	_apply_personality_to_hints(hints, tokens, matched_keyword_count, personality)
	_apply_run_build_to_hints(hints, run_build)
	var sign_strength := _calculate_sign_strength(tokens.size(), matched_keyword_count, hints, personality, run_build)

	return {
		"interpretation_text": _build_interpretation_text(hints),
		"priority_hints": hints,
		"sign_strength": sign_strength,
		"resonance": _calculate_resonance(hints, personality, run_build, sign_strength),
	}


func describe_action_focus(priority_hints: Dictionary, current_job: String, current_reason: String) -> String:
	var best_hint := _best_hint(priority_hints)
	if best_hint == "":
		return ""
	var label := str(HINT_LABELS.get(best_hint, best_hint))
	if _job_matches_hint(best_hint, current_job):
		return "Sign pull: %s -> Ari is following it." % label
	if current_job == "mine_stone" and _job_needs_stone_for_hint(best_hint, current_reason):
		return "Sign pull: %s -> Ari is mining first." % label
	if best_hint == "range" and current_job == "wait_or_idle" and current_reason.to_lower().find("no bow") >= 0:
		return "Sign pull: distance -> Ari has no bow answer yet."
	var blocker := _action_blocker_text(current_job, current_reason)
	if blocker != "":
		return "Sign pull: %s -> %s" % [label, blocker]
	return "Sign pull: %s -> another need is louder." % label


func thought_for_interpretation(sign_text: String, interpretation: Dictionary, personality := {}, run_build := {}) -> String:
	if sign_text.strip_edges() == "":
		return "The sign is empty. I have to choose for myself."

	var hints := _extract_hints(interpretation)
	var best_hint := _best_hint(hints)
	if best_hint == "combat_training":
		if sign_text.to_lower().find("teeth") >= 0:
			return "The sign says teeth. I should prepare my hands."
		return "The dummy does not bite. I can practice here."
	if best_hint == "range" and _trait(personality, "fearfulness") >= 0.62:
		return "Distance sounds like safety."
	if best_hint == "defensive_wait" and _trait(personality, "aggression") >= 0.62:
		return "The sign wants stillness, but my blood wants motion."
	if best_hint == "" and (_trait(personality, "curiosity") >= 0.62 or _build_strength(run_build, "curiosity") >= 0.62):
		return "That is strange. I want to understand it."
	if (_trait(personality, "sign_faith") >= 0.72 or _build_strength(run_build, "sign_faith") >= 0.72) and best_hint != "":
		return "The sign feels loud enough to follow."

	match best_hint:
		"range":
			return "The sign says arrows, but I do not have arrows yet."
		"wall":
			return "The sign says stone. I think it wants walls."
		"aura_orb":
			return "The sign says light. Maybe the orb is the answer."
		"mining":
			return "The sign says stone. I should mine before I trust anything."
		"farm_food":
			return "The sign says food. A full stomach might keep fear quiet."
		"build_trap":
			return "The sign says the floor can fight. I should set teeth for teeth."
		"build_tower":
			return "The sign wants height. Maybe arrows need a mountain."
		"build_tar_pit":
			return "The sign wants the ground to slow them."
		"build_fear_lantern":
			return "The sign wants a warm light against fear."
		"build_decoy_idol":
			return "The sign wants something else to draw teeth away."
		"build_thorn_totem":
			return "The sign wants touch to hurt them back."
		"build_repair_bench", "repair_structure":
			return "The sign wants broken things made strong again."
		"build_storm_rod":
			return "The sign points upward. The sky may need a weapon."
		"rest":
			return "The sign asks for quiet. I should recover before night."
		"reflect_library":
			return "The sign wants memory. I should read what happened."
		"defensive_wait":
			return "The sign says safe. I should stay where protection exists."
	return "The sign is strange. I only understand pieces of it."


func _empty_hints() -> Dictionary:
	return {
		"combat_training": 0.0,
		"range": 0.0,
		"wall": 0.0,
		"aura_orb": 0.0,
		"mining": 0.0,
		"farm_food": 0.0,
		"build_trap": 0.0,
		"build_tower": 0.0,
		"build_tar_pit": 0.0,
		"build_fear_lantern": 0.0,
		"build_decoy_idol": 0.0,
		"build_thorn_totem": 0.0,
		"build_repair_bench": 0.0,
		"repair_structure": 0.0,
		"build_storm_rod": 0.0,
		"rest": 0.0,
		"reflect_library": 0.0,
		"defensive_wait": 0.0,
	}


func _tokenize(text: String) -> PackedStringArray:
	var normalized := text.to_lower()
	for character in [".", ",", ";", ":", "!", "?", "\"", "'", "(", ")", "[", "]", "{", "}", "/", "\\", "-", "_", "\n", "\t"]:
		normalized = normalized.replace(character, " ")
	return normalized.split(" ", false)


func _count_keyword_matches(tokens: PackedStringArray, keywords: Array) -> int:
	var count := 0
	for keyword in keywords:
		if tokens.has(str(keyword)):
			count += 1
	return count


func _build_interpretation_text(hints: Dictionary) -> String:
	match _best_hint(hints):
		"combat_training":
			return "Ari reads danger and practice. The dummy may help."
		"range":
			return "Ari hears distance and arrows, but has no bow answer yet."
		"wall":
			return "Ari reads stone and protection. He thinks walls matter."
		"aura_orb":
			return "Ari reads light and thinks the orb may answer."
		"mining":
			return "Ari reads stone and thinks mining comes first."
		"farm_food":
			return "Ari reads food and thinks survival starts with his stomach."
		"build_trap":
			return "Ari reads the floor as a weapon. A trap may answer."
		"build_tower":
			return "Ari reads height and arrows. A tower may answer."
		"build_tar_pit":
			return "Ari reads mud and delay. The ground can buy time."
		"build_fear_lantern":
			return "Ari reads warm safety. A lantern may quiet fear."
		"build_decoy_idol":
			return "Ari reads bait and distraction. An idol may pull teeth away."
		"build_thorn_totem":
			return "Ari reads painful contact. Thorns may punish bites."
		"build_repair_bench":
			return "Ari reads tools and repair. A bench may keep defenses standing."
		"repair_structure":
			return "Ari reads broken defenses. He wants to mend what still stands."
		"build_storm_rod":
			return "Ari reads wings and storm. A rod may answer the sky."
		"rest":
			return "Ari reads quiet and thinks recovery may steady him."
		"reflect_library":
			return "Ari reads memory and wants the library's lesson."
		"defensive_wait":
			return "Ari reads safety and wants to stay near defenses."
	return "Ari can read the words, but not a useful plan yet."


func _apply_personality_to_hints(hints: Dictionary, tokens: PackedStringArray, matched_keyword_count: int, personality: Dictionary) -> void:
	var fearfulness := _trait(personality, "fearfulness")
	var aggression := _trait(personality, "aggression")
	var curiosity := _trait(personality, "curiosity")
	var sign_faith := _trait(personality, "sign_faith")
	var faith_scale := lerpf(0.85, 1.25, sign_faith)

	for hint_name in HINT_ORDER:
		var hint_key := str(hint_name)
		var value := float(hints.get(hint_key, 0.0))
		if value > 0.0:
			value *= faith_scale
		hints[hint_key] = value

	if float(hints.get("range", 0.0)) > 0.0:
		hints["range"] = float(hints.get("range", 0.0)) + aggression * 0.22
	if float(hints.get("combat_training", 0.0)) > 0.0:
		hints["combat_training"] = float(hints.get("combat_training", 0.0)) + aggression * 0.24 + fearfulness * 0.08
	if float(hints.get("wall", 0.0)) > 0.0:
		hints["wall"] = float(hints.get("wall", 0.0)) + fearfulness * 0.24
	if float(hints.get("aura_orb", 0.0)) > 0.0:
		hints["aura_orb"] = float(hints.get("aura_orb", 0.0)) + fearfulness * 0.16 + curiosity * 0.10
	if float(hints.get("mining", 0.0)) > 0.0:
		hints["mining"] = float(hints.get("mining", 0.0)) + curiosity * 0.12
	if float(hints.get("farm_food", 0.0)) > 0.0:
		hints["farm_food"] = float(hints.get("farm_food", 0.0)) + fearfulness * 0.08 + curiosity * 0.06
	if float(hints.get("build_trap", 0.0)) > 0.0:
		hints["build_trap"] = float(hints.get("build_trap", 0.0)) + aggression * 0.12 + curiosity * 0.10
	if float(hints.get("build_tower", 0.0)) > 0.0 or float(hints.get("range", 0.0)) > 0.0:
		hints["build_tower"] = float(hints.get("build_tower", 0.0)) + float(hints.get("range", 0.0)) * 0.65 + curiosity * 0.05
	if float(hints.get("build_tar_pit", 0.0)) > 0.0:
		hints["build_tar_pit"] = float(hints.get("build_tar_pit", 0.0)) + fearfulness * 0.12 + curiosity * 0.08
	if float(hints.get("build_fear_lantern", 0.0)) > 0.0:
		hints["build_fear_lantern"] = float(hints.get("build_fear_lantern", 0.0)) + fearfulness * 0.24 + sign_faith * 0.08
	if float(hints.get("build_decoy_idol", 0.0)) > 0.0:
		hints["build_decoy_idol"] = float(hints.get("build_decoy_idol", 0.0)) + fearfulness * 0.16 + curiosity * 0.06
	if float(hints.get("build_thorn_totem", 0.0)) > 0.0:
		hints["build_thorn_totem"] = float(hints.get("build_thorn_totem", 0.0)) + aggression * 0.16 + fearfulness * 0.10
	if float(hints.get("build_repair_bench", 0.0)) > 0.0:
		hints["build_repair_bench"] = float(hints.get("build_repair_bench", 0.0)) + fearfulness * 0.12 + sign_faith * 0.08
	if float(hints.get("repair_structure", 0.0)) > 0.0:
		hints["repair_structure"] = float(hints.get("repair_structure", 0.0)) + fearfulness * 0.18
	if float(hints.get("build_storm_rod", 0.0)) > 0.0:
		hints["build_storm_rod"] = float(hints.get("build_storm_rod", 0.0)) + fearfulness * 0.12 + curiosity * 0.10
	if float(hints.get("rest", 0.0)) > 0.0:
		hints["rest"] = float(hints.get("rest", 0.0)) + fearfulness * 0.18
	if float(hints.get("reflect_library", 0.0)) > 0.0:
		hints["reflect_library"] = float(hints.get("reflect_library", 0.0)) + curiosity * 0.22 + sign_faith * 0.08
	if float(hints.get("defensive_wait", 0.0)) > 0.0:
		hints["defensive_wait"] = float(hints.get("defensive_wait", 0.0)) + fearfulness * 0.30 - aggression * 0.20

	if matched_keyword_count <= 0 and tokens.size() > 0 and curiosity >= 0.62:
		hints["aura_orb"] = float(hints.get("aura_orb", 0.0)) + (curiosity - 0.5) * 0.10
		hints["reflect_library"] = float(hints.get("reflect_library", 0.0)) + (curiosity - 0.5) * 0.12

	for hint_name in HINT_ORDER:
		var hint_key := str(hint_name)
		hints[hint_key] = clampf(float(hints.get(hint_key, 0.0)), 0.0, 1.0)


func _apply_run_build_to_hints(hints: Dictionary, run_build) -> void:
	var sign_faith := _build_strength(run_build, "sign_faith")
	var mining := _build_strength(run_build, "mining")
	var building := _build_strength(run_build, "building")
	var warding := _build_strength(run_build, "warding")
	var defense := _build_strength(run_build, "defense")
	var fear_control := _build_strength(run_build, "fear_control")
	var curiosity := _build_strength(run_build, "curiosity")
	var farming := _build_strength(run_build, "farming")
	var trapcraft := _build_strength(run_build, "trapcraft")
	var bow := _build_strength(run_build, "bow")
	var attack_range := _build_strength(run_build, "attack_range")
	var thorns := _build_strength(run_build, "thorns")

	for hint_name in HINT_ORDER:
		var hint_key := str(hint_name)
		var value := float(hints.get(hint_key, 0.0))
		if value > 0.0:
			value *= 1.0 + sign_faith * 0.20
		hints[hint_key] = value

	if float(hints.get("mining", 0.0)) > 0.0:
		hints["mining"] = float(hints.get("mining", 0.0)) + mining * 0.18
	if float(hints.get("combat_training", 0.0)) > 0.0:
		hints["combat_training"] = float(hints.get("combat_training", 0.0)) + defense * 0.12 + fear_control * 0.10
	if float(hints.get("wall", 0.0)) > 0.0:
		hints["wall"] = float(hints.get("wall", 0.0)) + building * 0.20
	if float(hints.get("aura_orb", 0.0)) > 0.0:
		hints["aura_orb"] = float(hints.get("aura_orb", 0.0)) + warding * 0.22 + curiosity * 0.08
	if float(hints.get("farm_food", 0.0)) > 0.0:
		hints["farm_food"] = float(hints.get("farm_food", 0.0)) + farming * 0.22
	if float(hints.get("build_trap", 0.0)) > 0.0:
		hints["build_trap"] = float(hints.get("build_trap", 0.0)) + trapcraft * 0.28
	if float(hints.get("build_tower", 0.0)) > 0.0:
		hints["build_tower"] = float(hints.get("build_tower", 0.0)) + bow * 0.22 + attack_range * 0.20
	if float(hints.get("build_tar_pit", 0.0)) > 0.0:
		hints["build_tar_pit"] = float(hints.get("build_tar_pit", 0.0)) + trapcraft * 0.18 + defense * 0.08
	if float(hints.get("build_fear_lantern", 0.0)) > 0.0:
		hints["build_fear_lantern"] = float(hints.get("build_fear_lantern", 0.0)) + fear_control * 0.22 + warding * 0.08
	if float(hints.get("build_decoy_idol", 0.0)) > 0.0:
		hints["build_decoy_idol"] = float(hints.get("build_decoy_idol", 0.0)) + trapcraft * 0.14 + defense * 0.08
	if float(hints.get("build_thorn_totem", 0.0)) > 0.0:
		hints["build_thorn_totem"] = float(hints.get("build_thorn_totem", 0.0)) + thorns * 0.30 + defense * 0.10
	if float(hints.get("build_repair_bench", 0.0)) > 0.0:
		hints["build_repair_bench"] = float(hints.get("build_repair_bench", 0.0)) + building * 0.16 + defense * 0.08
	if float(hints.get("repair_structure", 0.0)) > 0.0:
		hints["repair_structure"] = float(hints.get("repair_structure", 0.0)) + building * 0.12 + defense * 0.12
	if float(hints.get("build_storm_rod", 0.0)) > 0.0:
		hints["build_storm_rod"] = float(hints.get("build_storm_rod", 0.0)) + attack_range * 0.20 + warding * 0.10 + curiosity * 0.08
	if float(hints.get("rest", 0.0)) > 0.0:
		hints["rest"] = float(hints.get("rest", 0.0)) + fear_control * 0.18
	if float(hints.get("reflect_library", 0.0)) > 0.0:
		hints["reflect_library"] = float(hints.get("reflect_library", 0.0)) + curiosity * 0.22

	for hint_name in HINT_ORDER:
		var hint_key := str(hint_name)
		hints[hint_key] = clampf(float(hints.get(hint_key, 0.0)), 0.0, 1.0)


func _calculate_sign_strength(token_count: int, matched_keyword_count: int, hints: Dictionary, personality: Dictionary, run_build) -> float:
	var curiosity := _trait(personality, "curiosity")
	var sign_faith := _trait(personality, "sign_faith")
	var build_curiosity := _build_strength(run_build, "curiosity")
	var build_sign_faith := _build_strength(run_build, "sign_faith")
	if token_count <= 0:
		return 0.0
	if matched_keyword_count <= 0:
		return clampf(0.08 + curiosity * 0.12 + sign_faith * 0.05 + build_curiosity * 0.10 + build_sign_faith * 0.04, 0.05, 0.42)
	var loose_words := maxf(float(token_count - matched_keyword_count), 0.0)
	return clampf(
		0.28
		+ float(matched_keyword_count) * 0.14
		+ _best_hint_value(hints) * 0.22
		+ sign_faith * 0.12
		+ build_sign_faith * 0.08
		+ curiosity * 0.04
		+ build_curiosity * 0.04
		- loose_words * 0.01,
		0.12,
		1.0
	)


func _calculate_resonance(hints: Dictionary, personality: Dictionary, run_build, sign_strength: float) -> float:
	var best_hint := _best_hint(hints)
	if best_hint == "":
		return sign_strength

	var fearfulness := _trait(personality, "fearfulness")
	var aggression := _trait(personality, "aggression")
	var curiosity := _trait(personality, "curiosity")
	var sign_faith := _trait(personality, "sign_faith")
	var value := sign_strength + sign_faith * 0.12 + _build_strength(run_build, "sign_faith") * 0.10
	match best_hint:
		"combat_training", "range":
			value += aggression * 0.16 + _build_strength(run_build, "defense") * 0.06
		"wall", "defensive_wait":
			value += fearfulness * 0.16 + _build_strength(run_build, "building") * 0.08
		"aura_orb":
			value += fearfulness * 0.10 + curiosity * 0.10 + _build_strength(run_build, "warding") * 0.12
		"mining":
			value += curiosity * 0.10 + _build_strength(run_build, "mining") * 0.12
		"farm_food":
			value += fearfulness * 0.08 + _build_strength(run_build, "farming") * 0.14
		"build_trap":
			value += aggression * 0.10 + curiosity * 0.08 + _build_strength(run_build, "trapcraft") * 0.18
		"build_tower":
			value += _build_strength(run_build, "bow") * 0.16 + _build_strength(run_build, "attack_range") * 0.14 + curiosity * 0.08
		"build_tar_pit":
			value += fearfulness * 0.10 + curiosity * 0.06 + _build_strength(run_build, "trapcraft") * 0.12
		"build_fear_lantern":
			value += fearfulness * 0.14 + _build_strength(run_build, "fear_control") * 0.14 + _build_strength(run_build, "warding") * 0.06
		"build_decoy_idol":
			value += fearfulness * 0.12 + curiosity * 0.08 + _build_strength(run_build, "trapcraft") * 0.10
		"build_thorn_totem":
			value += aggression * 0.10 + fearfulness * 0.08 + _build_strength(run_build, "thorns") * 0.18
		"build_repair_bench", "repair_structure":
			value += fearfulness * 0.10 + _build_strength(run_build, "building") * 0.10 + _build_strength(run_build, "defense") * 0.10
		"build_storm_rod":
			value += fearfulness * 0.08 + curiosity * 0.10 + _build_strength(run_build, "attack_range") * 0.12 + _build_strength(run_build, "warding") * 0.08
		"rest":
			value += fearfulness * 0.12 + _build_strength(run_build, "fear_control") * 0.14
		"reflect_library":
			value += curiosity * 0.18 + _build_strength(run_build, "curiosity") * 0.14
	return clampf(value, 0.0, 1.0)


func _extract_hints(interpretation: Dictionary) -> Dictionary:
	var hints = interpretation.get("priority_hints", {})
	if typeof(hints) == TYPE_DICTIONARY:
		return hints
	return _empty_hints()


func _best_hint(hints: Dictionary) -> String:
	var best_name := ""
	var best_value := 0.0
	for hint_name in HINT_ORDER:
		var hint_key := str(hint_name)
		var value := clampf(float(hints.get(hint_key, 0.0)), 0.0, 1.0)
		if value > best_value:
			best_name = hint_key
			best_value = value
	if best_value < 0.15:
		return ""
	return best_name


func _best_hint_value(hints: Dictionary) -> float:
	var best_value := 0.0
	for hint_name in HINT_ORDER:
		var hint_key := str(hint_name)
		best_value = maxf(best_value, clampf(float(hints.get(hint_key, 0.0)), 0.0, 1.0))
	return best_value


func _job_matches_hint(hint_name: String, current_job: String) -> bool:
	match hint_name:
		"combat_training":
			return current_job == "train_combat"
		"range", "build_tower":
			return current_job == "build_bow_tower" or current_job == "use_tower"
		"wall":
			return current_job == "build_wall"
		"aura_orb":
			return current_job == "place_aura_orb"
		"mining":
			return current_job == "mine_stone"
		"farm_food":
			return current_job == "farm_food" or current_job == "eat_food"
		"build_trap":
			return current_job == "build_spike_trap"
		"build_tar_pit":
			return current_job == "build_tar_pit"
		"build_fear_lantern":
			return current_job == "build_fear_lantern"
		"build_decoy_idol":
			return current_job == "build_decoy_idol"
		"build_thorn_totem":
			return current_job == "build_thorn_totem"
		"build_repair_bench":
			return current_job == "build_repair_bench"
		"repair_structure":
			return current_job == "repair_structure"
		"build_storm_rod":
			return current_job == "build_storm_rod"
		"rest":
			return current_job == "rest"
		"reflect_library":
			return current_job == "reflect_library"
		"defensive_wait":
			return current_job == "wait_or_idle"
	return false


func _job_needs_stone_for_hint(hint_name: String, current_reason: String) -> bool:
	var reason := current_reason.to_lower()
	if reason.find("stone") < 0:
		return false
	match hint_name:
		"wall":
			return reason.find("wall") >= 0
		"aura_orb":
			return reason.find("aura") >= 0 or reason.find("light") >= 0
		"build_trap":
			return reason.find("trap") >= 0
		"build_tower", "range":
			return reason.find("tower") >= 0
		"build_tar_pit":
			return reason.find("tar") >= 0
		"build_fear_lantern":
			return reason.find("lantern") >= 0
		"build_decoy_idol":
			return reason.find("decoy") >= 0
		"build_thorn_totem":
			return reason.find("thorn") >= 0
		"build_repair_bench", "repair_structure":
			return reason.find("repair") >= 0
		"build_storm_rod":
			return reason.find("storm") >= 0
	return false


func _action_blocker_text(current_job: String, current_reason: String) -> String:
	var reason := current_reason.to_lower()
	if current_job == "eat_food" or reason.find("hunger") >= 0 or reason.find("food") >= 0:
		return "hunger is louder first."
	if current_job == "rest" or reason.find("calm") >= 0 or reason.find("quiet") >= 0:
		return "fear needs calming first."
	if current_job == "farm_food":
		return "food stores are not ready."
	if current_job == "repair_structure" or reason.find("repair") >= 0 or reason.find("patch") >= 0:
		return "broken defenses need repair first."
	if reason.find("night is close") >= 0 or reason.find("stay near defenses") >= 0:
		return "night is too close to wander."
	if reason.find("stone") >= 0:
		return "stone is blocking the plan."
	return ""


func _trait(personality, trait_name: String) -> float:
	if typeof(personality) == TYPE_DICTIONARY:
		return clampf(float(personality.get(trait_name, 0.5)), 0.0, 1.0)
	return 0.5


func _build_strength(run_build, category: String) -> float:
	return clampf(float(_build_points(run_build, category)) / 7.0, 0.0, 1.0)


func _build_points(run_build, category: String) -> int:
	if typeof(run_build) != TYPE_DICTIONARY:
		return 0
	var points = run_build.get("points", {})
	if typeof(points) == TYPE_DICTIONARY:
		return int(points.get(category, 0))
	return int(run_build.get(category, 0))
