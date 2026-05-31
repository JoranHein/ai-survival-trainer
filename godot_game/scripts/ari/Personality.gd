class_name Personality
extends Node

const TRAIT_NAMES := [
	"fearfulness",
	"aggression",
	"curiosity",
	"sign_faith",
]

var traits := {}

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	randomize_for_run()


func randomize_for_run() -> void:
	traits = {}
	for trait_name in TRAIT_NAMES:
		traits[str(trait_name)] = _rng.randf_range(0.0, 1.0)


func get_traits() -> Dictionary:
	return traits.duplicate(true)


func get_summary() -> String:
	var labels := []
	_append_label(labels, "fearfulness", "fearful", "brave")
	_append_label(labels, "aggression", "aggressive", "low aggression")
	_append_label(labels, "curiosity", "curious", "practical")
	_append_label(labels, "sign_faith", "sign-faithful", "sign-doubtful")
	if labels.is_empty():
		labels.append("balanced")

	var shown := PackedStringArray()
	for label in labels:
		shown.append(str(label))
		if shown.size() >= 3:
			break
	return "Ari: %s" % ", ".join(shown)


func get_run_start_thought() -> String:
	var strongest := _strongest_trait()
	match strongest:
		"fearfulness":
			if _trait("fearfulness") >= 0.55:
				return "I do not like the dark. I need something between me and them."
		"aggression":
			if _trait("aggression") >= 0.55:
				return "If they come close, I want to hurt them first."
		"curiosity":
			if _trait("curiosity") >= 0.55:
				return "The sign is strange. I want to understand it."
		"sign_faith":
			if _trait("sign_faith") >= 0.55:
				return "The sign matters. I need to listen closely."
	return "I will listen, then choose what keeps me alive."


func _append_label(labels: Array, trait_name: String, high_label: String, low_label: String) -> void:
	var value := _trait(trait_name)
	if value >= 0.66:
		labels.append(high_label)
	elif value <= 0.34:
		labels.append(low_label)


func _trait(trait_name: String) -> float:
	return clampf(float(traits.get(trait_name, 0.5)), 0.0, 1.0)


func _strongest_trait() -> String:
	var best_name := ""
	var best_distance := 0.0
	for trait_name in TRAIT_NAMES:
		var trait_key := str(trait_name)
		var distance := absf(_trait(trait_key) - 0.5)
		if distance > best_distance:
			best_name = trait_key
			best_distance = distance
	return best_name
