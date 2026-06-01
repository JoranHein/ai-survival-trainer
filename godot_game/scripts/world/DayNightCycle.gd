class_name DayNightCycle
extends Node

signal phase_changed(day: int, phase: String)

@export var morning_seconds := 24.0
@export var midday_seconds := 36.0
@export var dusk_seconds := 16.0
@export var night_seconds := 28.0

var day := 1
var phase := "morning"
var phase_elapsed := 0.0

var _phase_index := 0


func restart() -> void:
	day = 1
	_phase_index = 0
	phase = _phase_name(_phase_index)
	phase_elapsed = 0.0
	phase_changed.emit(day, phase)


func advance(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	if safe_delta <= 0.0:
		return

	phase_elapsed += safe_delta
	while phase_elapsed >= _phase_length(_phase_index):
		phase_elapsed -= _phase_length(_phase_index)
		_phase_index += 1
		if _phase_index >= 4:
			_phase_index = 0
			day += 1
		phase = _phase_name(_phase_index)
		phase_changed.emit(day, phase)


func is_night() -> bool:
	return phase == "night"


func get_time_left() -> float:
	return maxf(0.0, _phase_length(_phase_index) - phase_elapsed)


func get_darkness_alpha() -> float:
	if phase == "dusk":
		return lerpf(0.0, 0.38, _phase_progress())
	if phase == "night":
		return lerpf(0.48, 0.62, _phase_progress())
	return 0.0


func _phase_progress() -> float:
	var length := _phase_length(_phase_index)
	if length <= 0.0:
		return 1.0
	return clampf(phase_elapsed / length, 0.0, 1.0)


func _phase_name(index: int) -> String:
	match index:
		0:
			return "morning"
		1:
			return "midday"
		2:
			return "dusk"
	return "night"


func _phase_length(index: int) -> float:
	match index:
		0:
			return morning_seconds
		1:
			return midday_seconds
		2:
			return dusk_seconds
	return night_seconds
