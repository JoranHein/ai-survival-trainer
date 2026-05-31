class_name MindLog
extends CanvasLayer

const DISPLAY_LINE_LIMIT := 58

@export var max_lines := 3

@onready var title_label: Label = %TitleLabel
@onready var lines_label: Label = %LinesLabel

var _lines: Array[String] = []
var _last_thought := ""


func update_state(state: Dictionary) -> void:
	var latest_thought := str(state.get("latest_thought", "")).strip_edges()
	if latest_thought != "" and latest_thought != _last_thought:
		_last_thought = latest_thought
		_lines.append(latest_thought)
		_trim_lines()

	var latest_lesson := str(state.get("latest_lesson_title", "")).strip_edges()
	var header := "ARI'S RECENT THOUGHTS"
	if latest_lesson != "":
		header = "ARI'S RECENT THOUGHTS | %s" % _limit_text(latest_lesson, 30)

	var text_lines := PackedStringArray()
	for line in _lines:
		text_lines.append("\"%s\"" % _limit_text(line, DISPLAY_LINE_LIMIT))
	title_label.text = header
	lines_label.text = "\n".join(text_lines) if not text_lines.is_empty() else "No recent thought yet."


func _trim_lines() -> void:
	while _lines.size() > max_lines:
		_lines.remove_at(_lowest_signal_index())


func _lowest_signal_index() -> int:
	var latest_index := _lines.size() - 1
	var lowest_index := 0
	var lowest_priority := INF
	for index in range(_lines.size()):
		if index == latest_index:
			continue
		var priority := _thought_priority(_lines[index])
		if priority < lowest_priority:
			lowest_priority = priority
			lowest_index = index
	return lowest_index


func _thought_priority(text: String) -> float:
	var lower_text := text.to_lower()
	if _contains_any(lower_text, ["died", "death", "dead", "fell", "not enough"]):
		return 90.0
	if _contains_any(lower_text, ["hurt", "too close", "broke", "broken", "reached", "teeth"]):
		return 70.0
	if _contains_any(lower_text, ["sign", "strange", "understand", "read the last note", "lesson"]):
		return 55.0
	if _contains_any(lower_text, ["wall", "light", "distance", "cover", "fear", "hunger", "stamina"]):
		return 40.0
	if _contains_any(lower_text, ["rest", "mine", "build", "farm", "train"]):
		return 20.0
	return 10.0


func _contains_any(text: String, needles: Array[String]) -> bool:
	for needle in needles:
		if text.contains(needle):
			return true
	return false


func _limit_text(text: String, max_length: int) -> String:
	if text.length() <= max_length:
		return text
	return "%s..." % text.substr(0, max_length - 3)
