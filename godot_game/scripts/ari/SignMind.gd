class_name SignMind
extends Node

const HINT_ORDER := [
	"range",
	"wall",
	"aura_orb",
	"mining",
	"defensive_wait",
]

const KEYWORDS := {
	"range": ["bow", "arrow", "arrows", "distance", "far", "fight", "hurt", "attack", "weapon", "weapons"],
	"wall": ["wall", "walls", "stone", "fortress", "protect"],
	"aura_orb": ["light", "circle", "orb", "ward"],
	"mining": ["mine", "mining", "rock", "rocks", "stone"],
	"defensive_wait": ["wait", "hide", "safe", "safety"],
}


func interpret_sign(sign_text: String, personality := {}, run_build := {}) -> Dictionary:
	var clean_text := sign_text.strip_edges()
	var hints := _empty_hints()
	if clean_text == "":
		return {
			"interpretation_text": "No sign yet.",
			"priority_hints": hints,
			"confusion": _calculate_confusion(0, 0, personality, run_build),
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

	return {
		"interpretation_text": _build_interpretation_text(hints),
		"priority_hints": hints,
		"confusion": _calculate_confusion(tokens.size(), matched_keyword_count, personality, run_build),
	}


func thought_for_interpretation(sign_text: String, interpretation: Dictionary, personality := {}, run_build := {}) -> String:
	if sign_text.strip_edges() == "":
		return "The sign is empty. I have to choose for myself."

	var hints := _extract_hints(interpretation)
	var best_hint := _best_hint(hints)
	if best_hint == "range" and _trait(personality, "fearfulness") >= 0.62:
		return "Distance sounds like safety."
	if best_hint == "defensive_wait" and _trait(personality, "aggression") >= 0.62:
		return "The sign wants stillness, but my blood wants motion."
	if best_hint == "" and (_trait(personality, "curiosity") >= 0.62 or _build_strength(run_build, "curiosity") >= 0.62):
		return "I do not know what that means. That makes it louder."
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
		"defensive_wait":
			return "The sign says safe. I should stay where protection exists."
	return "The sign is strange. I only understand pieces of it."


func _empty_hints() -> Dictionary:
	return {
		"range": 0.0,
		"wall": 0.0,
		"aura_orb": 0.0,
		"mining": 0.0,
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
		"range":
			return "Ari hears distance and arrows, but has no bow answer yet."
		"wall":
			return "Ari reads stone and protection. He thinks walls matter."
		"aura_orb":
			return "Ari reads light and thinks the orb may answer."
		"mining":
			return "Ari reads stone and thinks mining comes first."
		"defensive_wait":
			return "Ari reads safety and wants to stay near defenses."
	return "Ari can read the words, but not a useful plan yet."


func _apply_personality_to_hints(hints: Dictionary, tokens: PackedStringArray, matched_keyword_count: int, personality: Dictionary) -> void:
	var fearfulness := _trait(personality, "fearfulness")
	var aggression := _trait(personality, "aggression")
	var curiosity := _trait(personality, "curiosity")
	var perseverance := _trait(personality, "perseverance")
	var sign_faith := _trait(personality, "sign_faith")
	var faith_scale := lerpf(0.85, 1.25, sign_faith)

	for hint_name in HINT_ORDER:
		var hint_key := str(hint_name)
		var value := float(hints.get(hint_key, 0.0))
		if value > 0.0:
			value *= faith_scale
			value += maxf(perseverance - 0.5, 0.0) * 0.20
		hints[hint_key] = value

	if float(hints.get("range", 0.0)) > 0.0:
		hints["range"] = float(hints.get("range", 0.0)) + aggression * 0.22
	if float(hints.get("wall", 0.0)) > 0.0:
		hints["wall"] = float(hints.get("wall", 0.0)) + fearfulness * 0.24
	if float(hints.get("aura_orb", 0.0)) > 0.0:
		hints["aura_orb"] = float(hints.get("aura_orb", 0.0)) + fearfulness * 0.16 + curiosity * 0.10
	if float(hints.get("mining", 0.0)) > 0.0:
		hints["mining"] = float(hints.get("mining", 0.0)) + curiosity * 0.12
	if float(hints.get("defensive_wait", 0.0)) > 0.0:
		hints["defensive_wait"] = float(hints.get("defensive_wait", 0.0)) + fearfulness * 0.30 - aggression * 0.20

	if matched_keyword_count <= 0 and tokens.size() > 0 and curiosity >= 0.62:
		hints["mining"] = float(hints.get("mining", 0.0)) + (curiosity - 0.5) * 0.35
		hints["aura_orb"] = float(hints.get("aura_orb", 0.0)) + (curiosity - 0.5) * 0.18

	for hint_name in HINT_ORDER:
		var hint_key := str(hint_name)
		hints[hint_key] = clampf(float(hints.get(hint_key, 0.0)), 0.0, 1.0)


func _apply_run_build_to_hints(hints: Dictionary, run_build) -> void:
	var sign_faith := _build_strength(run_build, "sign_faith")
	var mining := _build_strength(run_build, "mining")
	var building := _build_strength(run_build, "building")
	var warding := _build_strength(run_build, "warding")

	for hint_name in HINT_ORDER:
		var hint_key := str(hint_name)
		var value := float(hints.get(hint_key, 0.0))
		if value > 0.0:
			value *= 1.0 + sign_faith * 0.20
		hints[hint_key] = value

	if float(hints.get("mining", 0.0)) > 0.0:
		hints["mining"] = float(hints.get("mining", 0.0)) + mining * 0.18
	if float(hints.get("wall", 0.0)) > 0.0:
		hints["wall"] = float(hints.get("wall", 0.0)) + building * 0.20
	if float(hints.get("aura_orb", 0.0)) > 0.0:
		hints["aura_orb"] = float(hints.get("aura_orb", 0.0)) + warding * 0.22

	for hint_name in HINT_ORDER:
		var hint_key := str(hint_name)
		hints[hint_key] = clampf(float(hints.get(hint_key, 0.0)), 0.0, 1.0)


func _calculate_confusion(token_count: int, matched_keyword_count: int, personality: Dictionary, run_build) -> float:
	var curiosity := _trait(personality, "curiosity")
	var sign_faith := _trait(personality, "sign_faith")
	var build_curiosity := _build_strength(run_build, "curiosity")
	var build_sign_faith := _build_strength(run_build, "sign_faith")
	if matched_keyword_count <= 0:
		return clampf(0.85 - curiosity * 0.35 - sign_faith * 0.08 - build_curiosity * 0.22 - build_sign_faith * 0.06, 0.22, 0.95)
	var loose_words := maxf(float(token_count - matched_keyword_count), 0.0)
	return clampf(0.65 - float(matched_keyword_count) * 0.12 + loose_words * 0.015 - curiosity * 0.08 - sign_faith * 0.08 - build_curiosity * 0.10 - build_sign_faith * 0.06, 0.08, 0.75)


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
	return best_name


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
