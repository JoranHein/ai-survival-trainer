class_name SignMind
extends Node

const HINT_ORDER := [
	"ranged_attack",
	"use_tower",
	"train_bow",
	"range",
	"combat_training",
	"fight_head_on",
	"train_sword",
	"smith_sword",
	"mine_ore",
	"use_armor",
	"rely_on_regen",
	"regen_on_kill",
	"use_existing_wall",
	"wait_behind_wall",
	"use_cover",
	"wall",
	"aura_orb",
	"lure_to_aura",
	"mining",
	"farm_food",
	"build_trap",
	"build_tower",
	"build_tar_pit",
	"lure_to_tar_pit",
	"build_fear_lantern",
	"use_fear_lantern",
	"build_decoy_idol",
	"use_decoy_idol",
	"build_thorn_totem",
	"use_thorns",
	"build_repair_bench",
	"repair_structure",
	"build_storm_rod",
	"rest",
	"reflect_library",
	"stall_until_dawn",
	"hide_until_dawn",
	"avoid_killing",
	"survive_until_morning",
	"hold_best_defense",
	"defensive_wait",
]

const KEYWORDS := {
	"combat_training": ["train", "training", "combat", "fight", "hurt", "attack", "weapon", "weapons", "sword", "bow", "arrow", "arrows", "kill", "teeth", "danger", "hands", "prepare", "ready", "hit", "hits", "hitting"],
	"fight_head_on": ["fight", "attack", "kill", "killing", "slay", "destroy"],
	"train_sword": ["train", "training", "practice", "dummy", "sword", "blade", "weapon"],
	"smith_sword": ["smith", "forge", "forging", "sword", "blade", "iron", "ore", "metal"],
	"mine_ore": ["ore", "iron", "metal", "mine", "mining"],
	"use_armor": ["armor", "armour", "skin", "shell", "tank", "endure"],
	"rely_on_regen": ["regen", "regenerate", "heal", "healing", "life", "recover"],
	"regen_on_kill": ["kill", "killing", "dead", "die", "dies", "life", "heal", "blood"],
	"ranged_attack": ["bow", "shoot", "shooting", "ranged", "range"],
	"use_tower": ["tower", "perch", "height", "above"],
	"train_bow": ["bow", "arrow", "arrows", "shoot", "shooting", "ranged", "range"],
	"range": ["bow", "arrow", "arrows", "shoot", "shooting", "range", "ranged", "distance", "far", "away"],
	"wall": ["wall", "walls", "stone", "fortress", "protect"],
	"aura_orb": ["light", "circle", "orb", "ward"],
	"lure_to_aura": ["circle", "light", "orb", "ward", "lure", "draw"],
	"mining": ["mine", "mining", "rock", "rocks", "stone"],
	"farm_food": ["farm", "food", "eat", "eating", "hungry", "hunger", "stomach", "crop", "crops", "harvest", "fruit", "full"],
	"build_trap": ["trap", "traps", "spike", "spikes", "floor", "ground", "punish", "snare"],
	"build_tower": ["tower", "towers", "height", "high", "above", "below", "mountain", "perch", "rain"],
	"build_tar_pit": ["slow", "slows", "mud", "tar", "sticky", "stuck", "sink", "mire"],
	"lure_to_tar_pit": ["mud", "tar", "sticky", "stuck", "sink", "mire", "feet", "reach"],
	"build_fear_lantern": ["lantern", "lamp", "fire", "warm", "warmth", "brave", "courage", "fear", "afraid", "safe", "safety"],
	"use_fear_lantern": ["lantern", "lamp", "fire", "warm", "warmth", "fear", "afraid", "safe", "safety"],
	"build_decoy_idol": ["decoy", "idol", "bait", "lure", "attract", "distract", "distraction", "false", "dummy"],
	"use_decoy_idol": ["decoy", "idol", "bait", "lure", "attract", "distract", "distraction", "false", "dummy"],
	"build_thorn_totem": ["thorn", "thorns", "skin", "bite", "biting", "touch", "touching", "recoil", "punish", "punishes"],
	"use_thorns": ["thorn", "thorns", "skin", "bite", "biting", "touch", "touching", "recoil", "punish", "punishes"],
	"build_repair_bench": ["workbench", "bench", "tool", "tools", "fixer"],
	"repair_structure": ["repair", "repairs", "fix", "fixing", "mend", "mending", "patch", "patched", "broken"],
	"build_storm_rod": ["storm", "storms", "rod", "rods", "lightning", "thunder", "sky", "air", "above", "flying", "fly", "flies", "wing", "wings"],
	"rest": ["rest", "sleep", "bed", "quiet", "calm", "heart", "tired", "heal", "safe", "safety", "breathe", "breath", "myself", "alone"],
	"reflect_library": ["library", "book", "books", "read", "note", "notes", "remember", "lesson", "learn", "think", "mistake", "mistakes", "why"],
	"stall_until_dawn": ["stall", "delay", "wait", "morning", "dawn", "sunrise", "survive"],
	"hide_until_dawn": ["hide", "hiding", "morning", "dawn", "sunrise", "survive"],
	"avoid_killing": ["avoid", "hide", "wait", "survive", "morning", "dawn"],
	"survive_until_morning": ["survive", "morning", "dawn", "sunrise", "daylight"],
	"hold_best_defense": ["safest", "defense", "defenses", "stay", "near", "hold", "anchor"],
	"defensive_wait": ["wait", "hide", "safe", "safety", "stay"],
}


const HINT_LABELS := {
	"combat_training": "training",
	"fight_head_on": "head-on fight",
	"train_sword": "sword training",
	"smith_sword": "smithing",
	"mine_ore": "ore",
	"use_armor": "armor",
	"rely_on_regen": "regen",
	"regen_on_kill": "kill regen",
	"ranged_attack": "ranged attack",
	"use_tower": "tower range",
	"train_bow": "bow practice",
	"range": "distance",
	"use_existing_wall": "existing cover",
	"wait_behind_wall": "wait behind wall",
	"use_cover": "cover",
	"wall": "walls",
	"aura_orb": "light",
	"lure_to_aura": "light lure",
	"mining": "stone",
	"farm_food": "food",
	"build_trap": "traps",
	"build_tower": "height",
	"build_tar_pit": "slow ground",
	"lure_to_tar_pit": "mud lure",
	"build_fear_lantern": "safe light",
	"use_fear_lantern": "lantern safety",
	"build_decoy_idol": "decoy",
	"use_decoy_idol": "decoy bait",
	"build_thorn_totem": "thorns",
	"use_thorns": "thorn ground",
	"build_repair_bench": "repair tools",
	"repair_structure": "repairs",
	"build_storm_rod": "storm",
	"rest": "quiet",
	"reflect_library": "memory",
	"stall_until_dawn": "last until dawn",
	"hide_until_dawn": "hide until dawn",
	"avoid_killing": "avoid killing",
	"survive_until_morning": "survive morning",
	"hold_best_defense": "safe anchor",
	"defensive_wait": "safety",
}


func interpret_sign(sign_text: String, run_build := {}) -> Dictionary:
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
	_apply_phrase_overrides(hints, tokens)
	_apply_run_build_to_hints(hints, run_build)
	_apply_storm_aliases(hints, tokens)
	var sign_strength := _calculate_sign_strength(tokens.size(), matched_keyword_count, hints, run_build)

	return {
		"interpretation_text": _build_interpretation_text(hints),
		"priority_hints": hints,
		"sign_strength": sign_strength,
		"resonance": _calculate_resonance(hints, run_build, sign_strength),
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


func thought_for_interpretation(sign_text: String, interpretation: Dictionary, run_build := {}) -> String:
	if sign_text.strip_edges() == "":
		return "The sign is empty. I have to choose for myself."

	var hints := _extract_hints(interpretation)
	var best_hint := _best_hint(hints)
	if best_hint == "combat_training":
		if sign_text.to_lower().find("teeth") >= 0:
			return "The sign says teeth. I should prepare my hands."
		return "The dummy does not bite. I can practice here."
	if best_hint == "fight_head_on":
		return "The sign says not to hide. If I fight, I need to make it quick."
	if best_hint == "train_sword":
		return "The sign wants a blade. I should practice before the teeth arrive."
	if best_hint == "smith_sword":
		return "The sign says sword. Ore and the forge might make my hands less weak."
	if best_hint == "mine_ore":
		return "Stone is not enough for a blade. I need ore."
	if best_hint == "regen_on_kill" or best_hint == "rely_on_regen":
		return "The sign says life from death. I should trust recovery only if I can kill."
	if best_hint == "ranged_attack" or best_hint == "use_tower" or best_hint == "train_bow" or best_hint == "range":
		return "The sign wants distance. I should use the bow before teeth reach me."
	if best_hint == "" and _build_strength(run_build, "curiosity") >= 0.62:
		return "That is strange. I want to understand it."
	if _build_strength(run_build, "sign_faith") >= 0.72 and best_hint != "":
		return "The sign feels loud enough to follow."

	match best_hint:
		"range":
			return "The sign wants distance. I should use the bow before teeth reach me."
		"wall":
			return "The sign says stone. I think it wants walls."
		"aura_orb":
			return "The sign says light. Maybe the orb is the answer."
		"lure_to_aura":
			return "The sign wants the light circle to do the killing."
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
		"lure_to_tar_pit":
			return "The sign wants them dragged through slow ground."
		"build_fear_lantern":
			return "The sign wants a warm light against fear."
		"use_fear_lantern":
			return "The sign wants Ari to stay where the warm light reaches him."
		"build_decoy_idol":
			return "The sign wants something else to draw teeth away."
		"use_decoy_idol":
			return "The sign wants Ari to let the false Ari take the teeth."
		"build_thorn_totem":
			return "The sign wants touch to hurt them back."
		"use_thorns":
			return "The sign wants Ari to hold ground where thorns punish contact."
		"build_repair_bench", "repair_structure":
			return "The sign wants broken things made strong again."
		"build_storm_rod":
			return "The sign points upward. The sky may need a weapon."
		"rest":
			return "The sign asks for quiet. I should recover before night."
		"reflect_library":
			return "The sign wants memory. I should read what happened."
		"stall_until_dawn", "hide_until_dawn", "survive_until_morning":
			return "The sign says morning matters. I do not have to kill the whole dark."
		"avoid_killing":
			return "The sign says survive, not win. I can let morning finish the night."
		"defensive_wait":
			return "The sign says safe. I should stay where protection exists."
	return "The sign is strange. I only understand pieces of it."


func _empty_hints() -> Dictionary:
	return {
		"combat_training": 0.0,
		"fight_head_on": 0.0,
		"train_sword": 0.0,
		"smith_sword": 0.0,
		"mine_ore": 0.0,
		"use_armor": 0.0,
		"rely_on_regen": 0.0,
		"regen_on_kill": 0.0,
		"ranged_attack": 0.0,
		"use_tower": 0.0,
		"train_bow": 0.0,
		"range": 0.0,
		"use_existing_wall": 0.0,
		"wait_behind_wall": 0.0,
		"use_cover": 0.0,
		"wall": 0.0,
		"avoid_build_wall": 0.0,
		"aura_orb": 0.0,
		"lure_to_aura": 0.0,
		"mining": 0.0,
		"farm_food": 0.0,
		"build_trap": 0.0,
		"build_tower": 0.0,
		"build_tar_pit": 0.0,
		"lure_to_tar_pit": 0.0,
		"build_fear_lantern": 0.0,
		"use_fear_lantern": 0.0,
		"build_decoy_idol": 0.0,
		"use_decoy_idol": 0.0,
		"build_thorn_totem": 0.0,
		"use_thorns": 0.0,
		"build_repair_bench": 0.0,
		"repair_structure": 0.0,
		"build_storm_rod": 0.0,
		"anti_flying": 0.0,
		"sky_answer": 0.0,
		"rest": 0.0,
		"reflect_library": 0.0,
		"stall_until_dawn": 0.0,
		"hide_until_dawn": 0.0,
		"avoid_killing": 0.0,
		"survive_until_morning": 0.0,
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


func _apply_phrase_overrides(hints: Dictionary, tokens: PackedStringArray) -> void:
	var bow_language := _has_any_token(tokens, ["bow", "bows", "arrow", "arrows", "shoot", "shooting", "ranged", "range"])
	if bow_language:
		hints["range"] = maxf(float(hints.get("range", 0.0)), 0.90)
		hints["train_bow"] = maxf(float(hints.get("train_bow", 0.0)), 0.74)
		if _has_any_token(tokens, ["use", "attack", "shoot", "shooting"]):
			hints["ranged_attack"] = maxf(float(hints.get("ranged_attack", 0.0)), 0.88)
			hints["use_tower"] = maxf(float(hints.get("use_tower", 0.0)), 0.76)
		if _has_any_token(tokens, ["build", "make", "mountain", "height", "above", "rain"]):
			hints["build_tower"] = maxf(float(hints.get("build_tower", 0.0)), 0.72)
		hints["combat_training"] = minf(float(hints.get("combat_training", 0.0)), 0.42)

	if _has_any_token(tokens, ["behind", "cover"]) and _has_any_token(tokens, ["wall", "walls", "stone"]):
		hints["use_existing_wall"] = maxf(float(hints.get("use_existing_wall", 0.0)), 0.9)
		hints["wait_behind_wall"] = maxf(float(hints.get("wait_behind_wall", 0.0)), 0.8)
		hints["use_cover"] = maxf(float(hints.get("use_cover", 0.0)), 0.85)
		hints["defensive_wait"] = maxf(float(hints.get("defensive_wait", 0.0)), 0.45)
	if _has_any_token(tokens, ["already", "enough"]) and _has_any_token(tokens, ["wall", "walls", "stone"]):
		hints["use_existing_wall"] = maxf(float(hints.get("use_existing_wall", 0.0)), 0.88)
		hints["use_cover"] = maxf(float(hints.get("use_cover", 0.0)), 0.82)
		hints["wall"] = minf(float(hints.get("wall", 0.0)), 0.20)

	var wall_language := _has_any_token(tokens, ["wall", "walls", "fortress"])
	var explicit_wall_negation := wall_language and _has_negation_token(tokens) and _has_any_token(tokens, ["build", "make", "hide", "behind", "cover", "use"])
	var bare_no_wall_alternative := tokens.has("no") and wall_language and _has_any_token(tokens, ["only", "instead", "without", "light", "circle", "orb", "trap", "tower", "storm", "bow"]) and not _has_any_token(tokens, ["yet", "first"])
	var instead_of_walls_alternative := wall_language and tokens.has("instead") and _has_any_token(tokens, ["light", "circle", "orb", "trap", "tower", "storm", "rod", "rods", "bow", "mud", "tar"])
	if explicit_wall_negation or bare_no_wall_alternative or instead_of_walls_alternative:
		hints["wall"] = 0.0
		hints["avoid_build_wall"] = maxf(float(hints.get("avoid_build_wall", 0.0)), 0.90)
		hints["use_existing_wall"] = minf(float(hints.get("use_existing_wall", 0.0)), 0.20)
		hints["wait_behind_wall"] = minf(float(hints.get("wait_behind_wall", 0.0)), 0.20)
		hints["use_cover"] = minf(float(hints.get("use_cover", 0.0)), 0.25)
		if _has_any_token(tokens, ["light", "circle", "orb", "ward"]):
			hints["aura_orb"] = maxf(float(hints.get("aura_orb", 0.0)), 0.85)
		if _has_any_token(tokens, ["trap", "traps", "floor", "ground", "spike", "spikes"]):
			hints["build_trap"] = maxf(float(hints.get("build_trap", 0.0)), 0.75)
		if _has_any_token(tokens, ["tower", "bow", "arrow", "arrows", "height"]):
			hints["build_tower"] = maxf(float(hints.get("build_tower", 0.0)), 0.70)
		if _has_any_token(tokens, ["storm", "rod", "rods", "sky", "air", "fly", "flies", "flying", "wing", "wings"]):
			hints["build_storm_rod"] = maxf(float(hints.get("build_storm_rod", 0.0)), 0.86)
		if not _has_any_token(tokens, ["mine", "mining", "rock", "rocks"]):
			hints["mining"] = minf(float(hints.get("mining", 0.0)), 0.25)

	var aura_kills_language := _has_any_token(tokens, ["circle", "light", "orb", "ward"]) and _has_any_token(tokens, ["eat", "eats", "eating", "dead", "teeth", "enemy", "enemies"])
	if aura_kills_language:
		hints["aura_orb"] = maxf(float(hints.get("aura_orb", 0.0)), 0.88)
		hints["lure_to_aura"] = maxf(float(hints.get("lure_to_aura", 0.0)), 0.78)
		hints["defensive_wait"] = maxf(float(hints.get("defensive_wait", 0.0)), 0.42)
		if not _has_any_token(tokens, ["food", "farm", "stomach", "hunger", "hungry", "crop", "crops", "harvest", "fruit", "full"]):
			hints["farm_food"] = minf(float(hints.get("farm_food", 0.0)), 0.12)

	var ground_grab_language := _has_any_token(tokens, ["ground", "feet", "foot"]) and _has_any_token(tokens, ["grab", "grabs", "grabbing", "hold", "holds", "stuck", "sink"])
	if ground_grab_language:
		hints["build_tar_pit"] = maxf(float(hints.get("build_tar_pit", 0.0)), 0.88)
		hints["lure_to_tar_pit"] = maxf(float(hints.get("lure_to_tar_pit", 0.0)), 0.82)
		if not _has_any_token(tokens, ["trap", "traps", "spike", "spikes", "floor", "fight", "punish"]):
			hints["build_trap"] = minf(float(hints.get("build_trap", 0.0)), 0.35)
	var slow_ground_language := _has_any_token(tokens, ["slow", "slows", "mud", "tar", "sticky", "stuck", "sink", "mire"]) and _has_any_token(tokens, ["reach", "arrive", "arrives", "before", "feet", "teeth", "dead", "enemy", "enemies"])
	if slow_ground_language:
		hints["build_tar_pit"] = maxf(float(hints.get("build_tar_pit", 0.0)), 0.78)
		hints["lure_to_tar_pit"] = maxf(float(hints.get("lure_to_tar_pit", 0.0)), 0.76)

	var morning_language := _has_any_token(tokens, ["morning", "dawn", "sunrise", "daylight"])
	if morning_language and _has_any_token(tokens, ["survive", "survival", "last", "stall", "hide", "wait", "until"]):
		hints["survive_until_morning"] = maxf(float(hints.get("survive_until_morning", 0.0)), 0.9)
		hints["stall_until_dawn"] = maxf(float(hints.get("stall_until_dawn", 0.0)), 0.85)
		hints["hide_until_dawn"] = maxf(float(hints.get("hide_until_dawn", 0.0)), 0.65)
		hints["avoid_killing"] = maxf(float(hints.get("avoid_killing", 0.0)), 0.55)

	var direct_killing_language := _has_any_token(tokens, ["kill", "killing", "fight", "attack", "slay", "destroy"])
	if direct_killing_language and _has_any_token(tokens, ["enemy", "enemies", "dead", "teeth"]):
		hints["fight_head_on"] = maxf(float(hints.get("fight_head_on", 0.0)), 0.85)
		hints["train_sword"] = maxf(float(hints.get("train_sword", 0.0)), 0.45)
	if direct_killing_language and tokens.has("hide") and _has_any_token(tokens, ["not", "dont", "don't", "never"]):
		hints["fight_head_on"] = maxf(float(hints.get("fight_head_on", 0.0)), 0.95)
		hints["train_sword"] = maxf(float(hints.get("train_sword", 0.0)), 0.65)
		hints["smith_sword"] = maxf(float(hints.get("smith_sword", 0.0)), 0.45)
		hints["hide_until_dawn"] = 0.0
		hints["stall_until_dawn"] = 0.0
		hints["defensive_wait"] = minf(float(hints.get("defensive_wait", 0.0)), 0.2)

	var sword_language := _has_any_token(tokens, ["sword", "blade", "forge", "smith", "iron", "ore", "metal"])
	if sword_language:
		hints["smith_sword"] = maxf(float(hints.get("smith_sword", 0.0)), 0.70)
		hints["train_sword"] = maxf(float(hints.get("train_sword", 0.0)), 0.45)
		if _has_any_token(tokens, ["ore", "iron", "metal"]):
			hints["mine_ore"] = maxf(float(hints.get("mine_ore", 0.0)), 0.65)
	if sword_language and _has_any_token(tokens, ["life", "heal", "regen", "recover", "die", "dead", "kill"]):
		hints["regen_on_kill"] = maxf(float(hints.get("regen_on_kill", 0.0)), 0.85)
		hints["rely_on_regen"] = maxf(float(hints.get("rely_on_regen", 0.0)), 0.55)

	var no_touch_language := _has_any_token(tokens, ["touch", "touching"]) and _has_any_token(tokens, ["not", "dont", "don't", "never", "avoid"])
	if no_touch_language:
		hints["fight_head_on"] = minf(float(hints.get("fight_head_on", 0.0)), 0.12)
		hints["combat_training"] = minf(float(hints.get("combat_training", 0.0)), 0.25)
		hints["avoid_killing"] = maxf(float(hints.get("avoid_killing", 0.0)), 0.55)
		hints["defensive_wait"] = maxf(float(hints.get("defensive_wait", 0.0)), 0.45)
		if _has_any_token(tokens, ["floor", "ground", "trap", "traps", "spike", "spikes"]):
			hints["build_trap"] = maxf(float(hints.get("build_trap", 0.0)), 0.90)

	var thorn_ground_language := _has_any_token(tokens, ["skin", "thorn", "thorns", "touch", "bite", "biting"]) and _has_any_token(tokens, ["armor", "armour", "patient", "punish", "punishes", "heavy", "endure"])
	if thorn_ground_language:
		hints["build_thorn_totem"] = maxf(float(hints.get("build_thorn_totem", 0.0)), 0.78)
		hints["use_thorns"] = maxf(float(hints.get("use_thorns", 0.0)), 0.68)
		hints["use_armor"] = maxf(float(hints.get("use_armor", 0.0)), 0.66)

	var weapon_anxiety_language := _has_any_token(tokens, ["anxious", "anxiety", "afraid", "fear", "scared"]) and _has_any_token(tokens, ["weapon", "weapons", "bow", "arrow", "arrows", "sword", "blade"])
	if weapon_anxiety_language:
		hints["build_fear_lantern"] = maxf(float(hints.get("build_fear_lantern", 0.0)), 0.62)
		hints["use_fear_lantern"] = maxf(float(hints.get("use_fear_lantern", 0.0)), 0.54)
		hints["rest"] = maxf(float(hints.get("rest", 0.0)), 0.28)

	var warm_fear_language := _has_any_token(tokens, ["warm", "warmth", "light", "lantern", "lamp", "fire"]) and _has_any_token(tokens, ["fear", "afraid", "scared", "smaller", "safe", "safety", "brave", "courage"])
	if warm_fear_language:
		hints["build_fear_lantern"] = maxf(float(hints.get("build_fear_lantern", 0.0)), 0.82)
		hints["use_fear_lantern"] = maxf(float(hints.get("use_fear_lantern", 0.0)), 0.74)

	var moon_coward_language := _has_any_token(tokens, ["moon", "night", "dark", "darkness"]) and _has_any_token(tokens, ["coward", "cowards", "brave", "bravery", "courage"])
	if moon_coward_language:
		hints["survive_until_morning"] = maxf(float(hints.get("survive_until_morning", 0.0)), 0.66)
		hints["defensive_wait"] = maxf(float(hints.get("defensive_wait", 0.0)), 0.56)
		hints["build_fear_lantern"] = maxf(float(hints.get("build_fear_lantern", 0.0)), 0.52)
		hints["use_fear_lantern"] = maxf(float(hints.get("use_fear_lantern", 0.0)), 0.48)

	var false_me_language := _has_any_token(tokens, ["false", "decoy", "idol", "bait", "dummy"]) and _has_any_token(tokens, ["me", "myself", "teeth", "take", "draw", "lure", "distract"])
	if false_me_language:
		hints["build_decoy_idol"] = maxf(float(hints.get("build_decoy_idol", 0.0)), 0.82)
		hints["use_decoy_idol"] = maxf(float(hints.get("use_decoy_idol", 0.0)), 0.74)

	var stable_anchor_language := _has_any_token(tokens, ["stay", "hold", "near", "safest", "safe", "safety", "defense", "defenses"]) and _has_any_token(tokens, ["stay", "hold", "near", "safest", "defense", "defenses"])
	var no_back_and_forth := _has_any_token(tokens, ["back", "forth", "switch", "switching", "wander", "wandering"]) and _has_negation_token(tokens)
	if stable_anchor_language or no_back_and_forth:
		hints["hold_best_defense"] = maxf(float(hints.get("hold_best_defense", 0.0)), 0.82 if stable_anchor_language else 0.70)
		hints["defensive_wait"] = maxf(float(hints.get("defensive_wait", 0.0)), 0.76)
		hints["use_cover"] = maxf(float(hints.get("use_cover", 0.0)), 0.42)

	var sky_language := _has_any_token(tokens, ["wing", "wings", "flying", "fly", "flies", "sky", "air"])
	if not sky_language:
		return
	hints["build_storm_rod"] = maxf(float(hints.get("build_storm_rod", 0.0)), 0.85)
	if _has_any_token(tokens, ["fear", "afraid"]):
		hints["build_fear_lantern"] = minf(float(hints.get("build_fear_lantern", 0.0)), 0.35)
	if _has_any_token(tokens, ["stone", "wall", "walls"]):
		hints["wall"] = minf(float(hints.get("wall", 0.0)), 0.35)
		hints["mining"] = minf(float(hints.get("mining", 0.0)), 0.35)
	var sky_stone_distrust := _has_negation_token(tokens) and _has_any_token(tokens, ["wall", "walls", "stone"]) and _has_any_token(tokens, ["trust", "fear", "afraid", "care", "cares"])
	if sky_stone_distrust:
		hints["avoid_build_wall"] = maxf(float(hints.get("avoid_build_wall", 0.0)), 0.38)
		hints["wall"] = minf(float(hints.get("wall", 0.0)), 0.24)


func _has_any_token(tokens: PackedStringArray, words: Array) -> bool:
	for word in words:
		if tokens.has(str(word)):
			return true
	return false


func _has_negation_token(tokens: PackedStringArray) -> bool:
	return _has_any_token(tokens, ["not", "dont", "don", "never", "avoid"])


func _build_interpretation_text(hints: Dictionary) -> String:
	match _best_hint(hints):
		"combat_training":
			return "Ari reads danger and practice. The dummy may help."
		"fight_head_on":
			return "Ari reads a command to stop hiding and kill directly."
		"train_sword":
			return "Ari reads the blade as something he must practice."
		"smith_sword":
			return "Ari reads ore and forge work as a path to a stronger sword."
		"mine_ore":
			return "Ari reads metal as the missing resource."
		"use_armor":
			return "Ari reads skin and armor as permission to endure contact."
		"rely_on_regen", "regen_on_kill":
			return "Ari reads recovery as part of the killing plan."
		"ranged_attack", "use_tower", "train_bow", "range":
			return "Ari reads this as a ranged-fighting sign."
		"use_existing_wall", "wait_behind_wall", "use_cover":
			return "Ari reads the wall as cover that already exists."
		"wall":
			return "Ari reads stone and protection. He thinks walls matter."
		"aura_orb":
			return "Ari reads light and thinks the orb may answer."
		"lure_to_aura":
			return "Ari reads the light circle as a place where teeth should die."
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
		"lure_to_tar_pit":
			return "Ari reads mud as a trap he must make them cross."
		"build_fear_lantern":
			return "Ari reads warm safety. A lantern may quiet fear."
		"use_fear_lantern":
			return "Ari reads the lantern as a place to hold when fear rises."
		"build_decoy_idol":
			return "Ari reads bait and distraction. An idol may pull teeth away."
		"use_decoy_idol":
			return "Ari reads the false self as bait he should not stand beside."
		"build_thorn_totem":
			return "Ari reads painful contact. Thorns may punish bites."
		"use_thorns":
			return "Ari reads patient skin as a place where contact should hurt them."
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
		"stall_until_dawn", "hide_until_dawn", "survive_until_morning":
			return "Ari reads the goal as lasting until dawn, not winning the night."
		"avoid_killing":
			return "Ari reads survival as avoiding unnecessary fights."
		"hold_best_defense":
			return "Ari reads the sign as choosing one safe defense and staying with it."
		"defensive_wait":
			return "Ari reads safety and wants to stay near defenses."
	return "Ari can read the words, but not a useful plan yet."


func _apply_run_build_to_hints(hints: Dictionary, run_build) -> void:
	var sign_faith := _build_strength(run_build, "sign_faith")
	var mining := _build_strength(run_build, "mining")
	var building := _build_strength(run_build, "building")
	var warding := _build_strength(run_build, "warding")
	var movement := _build_strength(run_build, "movement")
	var defense := _build_strength(run_build, "defense")
	var fear_control := _build_strength(run_build, "fear_control")
	var curiosity := _build_strength(run_build, "curiosity")
	var farming := _build_strength(run_build, "farming")
	var trapcraft := _build_strength(run_build, "trapcraft")
	var bow := _build_strength(run_build, "bow")
	var attack_range := _build_strength(run_build, "attack_range")
	var thorns := _build_strength(run_build, "thorns")
	var sword := _build_strength(run_build, "sword")
	var attack_damage := _build_strength(run_build, "attack_damage")
	var attack_speed := _build_strength(run_build, "attack_speed")
	var armor := _build_strength(run_build, "armor")
	var smithing := _build_strength(run_build, "smithing")
	var regeneration := _build_strength(run_build, "regeneration")

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
	if float(hints.get("fight_head_on", 0.0)) > 0.0:
		hints["fight_head_on"] = float(hints.get("fight_head_on", 0.0)) + sword * 0.20 + attack_damage * 0.18 + defense * 0.08
	if float(hints.get("train_sword", 0.0)) > 0.0:
		hints["train_sword"] = float(hints.get("train_sword", 0.0)) + sword * 0.22 + attack_speed * 0.10
	if float(hints.get("smith_sword", 0.0)) > 0.0:
		hints["smith_sword"] = float(hints.get("smith_sword", 0.0)) + smithing * 0.24 + mining * 0.08
	if float(hints.get("mine_ore", 0.0)) > 0.0:
		hints["mine_ore"] = float(hints.get("mine_ore", 0.0)) + mining * 0.18 + smithing * 0.16
	if float(hints.get("use_armor", 0.0)) > 0.0:
		hints["use_armor"] = float(hints.get("use_armor", 0.0)) + armor * 0.25 + defense * 0.12
	if float(hints.get("rely_on_regen", 0.0)) > 0.0:
		hints["rely_on_regen"] = float(hints.get("rely_on_regen", 0.0)) + regeneration * 0.22
	if float(hints.get("regen_on_kill", 0.0)) > 0.0:
		hints["regen_on_kill"] = float(hints.get("regen_on_kill", 0.0)) + regeneration * 0.22 + sword * 0.08
	if float(hints.get("wall", 0.0)) > 0.0:
		hints["wall"] = float(hints.get("wall", 0.0)) + building * 0.20
	if float(hints.get("aura_orb", 0.0)) > 0.0:
		hints["aura_orb"] = float(hints.get("aura_orb", 0.0)) + warding * 0.22 + curiosity * 0.08
	if float(hints.get("lure_to_aura", 0.0)) > 0.0:
		hints["lure_to_aura"] = float(hints.get("lure_to_aura", 0.0)) + warding * 0.14 + movement * 0.08
	if float(hints.get("farm_food", 0.0)) > 0.0:
		hints["farm_food"] = float(hints.get("farm_food", 0.0)) + farming * 0.22
	if float(hints.get("build_trap", 0.0)) > 0.0:
		hints["build_trap"] = float(hints.get("build_trap", 0.0)) + trapcraft * 0.28
	if float(hints.get("build_tower", 0.0)) > 0.0:
		hints["build_tower"] = float(hints.get("build_tower", 0.0)) + bow * 0.22 + attack_range * 0.20
	if float(hints.get("build_tar_pit", 0.0)) > 0.0:
		hints["build_tar_pit"] = float(hints.get("build_tar_pit", 0.0)) + trapcraft * 0.18 + defense * 0.08
	if float(hints.get("lure_to_tar_pit", 0.0)) > 0.0:
		hints["lure_to_tar_pit"] = float(hints.get("lure_to_tar_pit", 0.0)) + trapcraft * 0.14 + movement * 0.08
	if float(hints.get("build_fear_lantern", 0.0)) > 0.0:
		hints["build_fear_lantern"] = float(hints.get("build_fear_lantern", 0.0)) + fear_control * 0.22 + warding * 0.08
	if float(hints.get("use_fear_lantern", 0.0)) > 0.0:
		hints["use_fear_lantern"] = float(hints.get("use_fear_lantern", 0.0)) + fear_control * 0.16 + warding * 0.06
	if float(hints.get("build_decoy_idol", 0.0)) > 0.0:
		hints["build_decoy_idol"] = float(hints.get("build_decoy_idol", 0.0)) + trapcraft * 0.14 + defense * 0.08
	if float(hints.get("use_decoy_idol", 0.0)) > 0.0:
		hints["use_decoy_idol"] = float(hints.get("use_decoy_idol", 0.0)) + trapcraft * 0.12 + movement * 0.08 + defense * 0.06
	if float(hints.get("build_thorn_totem", 0.0)) > 0.0:
		hints["build_thorn_totem"] = float(hints.get("build_thorn_totem", 0.0)) + thorns * 0.30 + defense * 0.10
	if float(hints.get("use_thorns", 0.0)) > 0.0:
		hints["use_thorns"] = float(hints.get("use_thorns", 0.0)) + thorns * 0.22 + armor * 0.10 + defense * 0.08
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
	if float(hints.get("stall_until_dawn", 0.0)) > 0.0:
		hints["stall_until_dawn"] = float(hints.get("stall_until_dawn", 0.0)) + fear_control * 0.14 + defense * 0.08
	if float(hints.get("hide_until_dawn", 0.0)) > 0.0:
		hints["hide_until_dawn"] = float(hints.get("hide_until_dawn", 0.0)) + movement * 0.12 + fear_control * 0.10
	if float(hints.get("survive_until_morning", 0.0)) > 0.0:
		hints["survive_until_morning"] = float(hints.get("survive_until_morning", 0.0)) + defense * 0.08 + fear_control * 0.10
	if float(hints.get("hold_best_defense", 0.0)) > 0.0:
		hints["hold_best_defense"] = float(hints.get("hold_best_defense", 0.0)) + defense * 0.12 + fear_control * 0.06

	for hint_name in HINT_ORDER:
		var hint_key := str(hint_name)
		hints[hint_key] = clampf(float(hints.get(hint_key, 0.0)), 0.0, 1.0)


func _apply_storm_aliases(hints: Dictionary, tokens: PackedStringArray) -> void:
	var storm_value := clampf(float(hints.get("build_storm_rod", 0.0)), 0.0, 1.0)
	if storm_value <= 0.0:
		return
	hints["anti_flying"] = maxf(clampf(float(hints.get("anti_flying", 0.0)), 0.0, 1.0), storm_value)
	hints["sky_answer"] = maxf(clampf(float(hints.get("sky_answer", 0.0)), 0.0, 1.0), storm_value)
	hints["use_tower"] = maxf(clampf(float(hints.get("use_tower", 0.0)), 0.0, 1.0), storm_value * 0.74)
	hints["ranged_attack"] = maxf(clampf(float(hints.get("ranged_attack", 0.0)), 0.0, 1.0), storm_value * 0.68)
	hints["build_tower"] = maxf(clampf(float(hints.get("build_tower", 0.0)), 0.0, 1.0), storm_value * 0.54)
	if _has_any_token(tokens, ["fear", "afraid"]) and not _has_any_token(tokens, ["warm", "warmth", "lantern", "lamp", "safe", "scared"]):
		hints["build_fear_lantern"] = minf(clampf(float(hints.get("build_fear_lantern", 0.0)), 0.0, 1.0), 0.24)


func _calculate_sign_strength(token_count: int, matched_keyword_count: int, hints: Dictionary, run_build) -> float:
	var build_curiosity := _build_strength(run_build, "curiosity")
	var build_sign_faith := _build_strength(run_build, "sign_faith")
	if token_count <= 0:
		return 0.0
	if matched_keyword_count <= 0:
		return clampf(0.08 + build_curiosity * 0.12 + build_sign_faith * 0.08, 0.05, 0.42)
	var loose_words := maxf(float(token_count - matched_keyword_count), 0.0)
	return clampf(
		0.28
		+ float(matched_keyword_count) * 0.14
		+ _best_hint_value(hints) * 0.22
		+ build_sign_faith * 0.12
		+ build_curiosity * 0.06
		- loose_words * 0.01,
		0.12,
		1.0
	)


func _calculate_resonance(hints: Dictionary, run_build, sign_strength: float) -> float:
	var best_hint := _best_hint(hints)
	if best_hint == "":
		return sign_strength

	var value := sign_strength + _build_strength(run_build, "sign_faith") * 0.14
	match best_hint:
		"combat_training", "range", "ranged_attack", "use_tower", "train_bow":
			value += _build_strength(run_build, "defense") * 0.08 + _build_strength(run_build, "bow") * 0.08
		"fight_head_on":
			value += _build_strength(run_build, "sword") * 0.16 + _build_strength(run_build, "attack_damage") * 0.12
		"train_sword":
			value += _build_strength(run_build, "sword") * 0.18 + _build_strength(run_build, "attack_speed") * 0.08
		"smith_sword", "mine_ore":
			value += _build_strength(run_build, "smithing") * 0.18 + _build_strength(run_build, "mining") * 0.10
		"use_armor":
			value += _build_strength(run_build, "armor") * 0.18 + _build_strength(run_build, "defense") * 0.10
		"rely_on_regen", "regen_on_kill":
			value += _build_strength(run_build, "regeneration") * 0.18
		"wall", "hold_best_defense", "defensive_wait":
			value += _build_strength(run_build, "building") * 0.12 + _build_strength(run_build, "defense") * 0.06
		"aura_orb":
			value += _build_strength(run_build, "warding") * 0.16
		"lure_to_aura":
			value += _build_strength(run_build, "warding") * 0.14 + _build_strength(run_build, "movement") * 0.08
		"mining":
			value += _build_strength(run_build, "mining") * 0.14 + _build_strength(run_build, "curiosity") * 0.06
		"farm_food":
			value += _build_strength(run_build, "farming") * 0.16
		"build_trap":
			value += _build_strength(run_build, "trapcraft") * 0.20
		"build_tower":
			value += _build_strength(run_build, "bow") * 0.18 + _build_strength(run_build, "attack_range") * 0.16
		"build_tar_pit", "lure_to_tar_pit":
			value += _build_strength(run_build, "trapcraft") * 0.14
		"build_fear_lantern", "use_fear_lantern":
			value += _build_strength(run_build, "fear_control") * 0.18 + _build_strength(run_build, "warding") * 0.08
		"build_decoy_idol", "use_decoy_idol":
			value += _build_strength(run_build, "trapcraft") * 0.12 + _build_strength(run_build, "curiosity") * 0.06
		"build_thorn_totem", "use_thorns":
			value += _build_strength(run_build, "thorns") * 0.20
		"build_repair_bench", "repair_structure":
			value += _build_strength(run_build, "building") * 0.12 + _build_strength(run_build, "defense") * 0.12
		"build_storm_rod":
			value += _build_strength(run_build, "attack_range") * 0.14 + _build_strength(run_build, "warding") * 0.10
		"rest":
			value += _build_strength(run_build, "fear_control") * 0.16
		"reflect_library":
			value += _build_strength(run_build, "curiosity") * 0.20
		"stall_until_dawn", "hide_until_dawn", "avoid_killing", "survive_until_morning":
			value += _build_strength(run_build, "fear_control") * 0.12 + _build_strength(run_build, "movement") * 0.08
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
		"fight_head_on":
			return current_job == "fight_head_on"
		"train_sword":
			return current_job == "train_sword"
		"smith_sword":
			return current_job == "smith_sword"
		"mine_ore":
			return current_job == "mine_ore"
		"stall_until_dawn", "hide_until_dawn", "survive_until_morning", "avoid_killing":
			return current_job == "stall_until_dawn" or current_job == "hide_until_dawn" or current_job == "use_cover" or current_job == "flee"
		"ranged_attack", "use_tower", "train_bow", "range", "build_tower":
			return current_job == "build_bow_tower" or current_job == "use_tower"
		"use_existing_wall", "wait_behind_wall", "use_cover":
			return current_job == "use_cover" or current_job == "wait_or_idle"
		"wall":
			return current_job == "build_wall"
		"aura_orb":
			return current_job == "place_aura_orb"
		"lure_to_aura":
			return current_job == "place_aura_orb" or current_job == "lure_to_aura"
		"mining":
			return current_job == "mine_stone"
		"farm_food":
			return current_job == "farm_food" or current_job == "eat_food"
		"build_trap":
			return current_job == "build_spike_trap"
		"build_tar_pit":
			return current_job == "build_tar_pit"
		"lure_to_tar_pit":
			return current_job == "lure_to_tar_pit"
		"build_fear_lantern":
			return current_job == "build_fear_lantern"
		"use_fear_lantern":
			return current_job == "use_fear_lantern"
		"build_decoy_idol":
			return current_job == "build_decoy_idol"
		"use_decoy_idol":
			return current_job == "use_decoy_idol"
		"build_thorn_totem":
			return current_job == "build_thorn_totem"
		"use_thorns":
			return current_job == "use_thorns"
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
		"hold_best_defense", "defensive_wait":
			return current_job == "wait_or_idle" or current_job == "use_cover" or current_job == "use_tower" or current_job == "lure_to_aura" or current_job == "use_fear_lantern"
	return false


func _job_needs_stone_for_hint(hint_name: String, current_reason: String) -> bool:
	var reason := current_reason.to_lower()
	if reason.find("stone") < 0:
		return false
	match hint_name:
		"wall":
			return reason.find("wall") >= 0
		"aura_orb", "lure_to_aura":
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


func _build_strength(run_build, category: String) -> float:
	return clampf(float(_build_points(run_build, category)) / 7.0, 0.0, 1.0)


func _build_points(run_build, category: String) -> int:
	if typeof(run_build) != TYPE_DICTIONARY:
		return 0
	var points = run_build.get("points", {})
	if typeof(points) == TYPE_DICTIONARY:
		return int(points.get(category, 0))
	return int(run_build.get(category, 0))
