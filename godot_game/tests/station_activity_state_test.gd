extends SceneTree

const MineNodeScript := preload("res://scripts/stations/MineNode.gd")
const TrainingDummyScript := preload("res://scripts/stations/TrainingDummy.gd")
const FarmPlotScript := preload("res://scripts/stations/FarmPlot.gd")
const BedStationScript := preload("res://scripts/stations/BedStation.gd")
const LibraryStationScript := preload("res://scripts/stations/LibraryStation.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_mine_activity_state()
	_test_training_activity_state()
	_test_farm_activity_state()
	_test_bed_activity_state()
	_test_library_activity_state()

	if failures.is_empty():
		print("Station activity state tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_mine_activity_state() -> void:
	var station = MineNodeScript.new()
	root.add_child(station)
	_assert(station.has_method("get_activity_state"), "Mine should expose activity state")
	if not station.has_method("get_activity_state"):
		return
	_assert(not bool(station.call("get_activity_state").get("active", true)), "Mine should start inactive")
	station.mine(0.4, null)
	var state: Dictionary = station.call("get_activity_state")
	_assert(state.get("kind", "") == "mine", "Mine state should identify mine activity")
	_assert(bool(state.get("active", false)), "Mine should become active after mining")
	_assert(float(state.get("progress", 0.0)) > 0.0, "Mine activity should report progress")


func _test_training_activity_state() -> void:
	var station = TrainingDummyScript.new()
	root.add_child(station)
	_assert(station.has_method("get_activity_state"), "Training dummy should expose activity state")
	if not station.has_method("get_activity_state"):
		return
	station.train(0.4)
	var state: Dictionary = station.call("get_activity_state")
	_assert(state.get("kind", "") == "train", "Training state should identify train activity")
	_assert(bool(state.get("active", false)), "Training dummy should become active after training")
	_assert(float(state.get("progress", 0.0)) > 0.0, "Training activity should report progress")


func _test_farm_activity_state() -> void:
	var station = FarmPlotScript.new()
	root.add_child(station)
	_assert(station.has_method("get_activity_state"), "Farm should expose activity state")
	if not station.has_method("get_activity_state"):
		return
	station.farm(0.4, null)
	var state: Dictionary = station.call("get_activity_state")
	_assert(state.get("kind", "") == "farm", "Farm state should identify farm activity")
	_assert(bool(state.get("active", false)), "Farm should become active after farming")
	_assert(float(state.get("progress", 0.0)) > 0.0, "Farm activity should report progress")


func _test_bed_activity_state() -> void:
	var station = BedStationScript.new()
	root.add_child(station)
	_assert(station.has_method("get_activity_state"), "Bed should expose activity state")
	if not station.has_method("get_activity_state"):
		return
	station.rest(0.4, null)
	var state: Dictionary = station.call("get_activity_state")
	_assert(state.get("kind", "") == "rest", "Bed state should identify rest activity")
	_assert(bool(state.get("active", false)), "Bed should become active after resting")
	_assert(float(state.get("progress", 0.0)) == 1.0, "Bed rest should report full activity while active")


func _test_library_activity_state() -> void:
	var station = LibraryStationScript.new()
	root.add_child(station)
	_assert(station.has_method("get_activity_state"), "Library should expose activity state")
	if not station.has_method("get_activity_state"):
		return
	station.reflect(0.4)
	var state: Dictionary = station.call("get_activity_state")
	_assert(state.get("kind", "") == "reflect", "Library state should identify reflection activity")
	_assert(bool(state.get("active", false)), "Library should become active after reflection")
	_assert(float(state.get("progress", 0.0)) > 0.0, "Library activity should report progress")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
