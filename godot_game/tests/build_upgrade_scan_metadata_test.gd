extends SceneTree

const RunBuildScript := preload("res://scripts/ari/RunBuild.gd")
const PermanentProgressionScript := preload("res://scripts/world/PermanentProgression.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_run_build_context_has_scan_metadata()
	_test_upgrade_rows_have_scan_metadata()

	if failures.is_empty():
		print("Build and upgrade scan metadata tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_run_build_context_has_scan_metadata() -> void:
	var run_build = RunBuildScript.new()
	root.add_child(run_build)
	await process_frame
	_assert(run_build.apply_preset("fast_coward"), "RunBuild should apply Fast Coward")
	var context := run_build.get_context()
	var tags = context.get("tags", [])
	var top_categories = context.get("top_categories", [])
	_assert(str(context.get("role", "")) != "", "run build context should include a readable role")
	var tags_ok: bool = typeof(tags) == TYPE_ARRAY and tags.size() >= 2
	_assert(tags_ok, "run build context should include short scan tags")
	_assert(typeof(top_categories) == TYPE_ARRAY and top_categories.size() >= 2, "run build context should include top categories")
	if tags_ok:
		_assert(str(tags[0]).length() <= 16, "run build tags should be compact")
	root.remove_child(run_build)
	run_build.free()


func _test_upgrade_rows_have_scan_metadata() -> void:
	var progression = PermanentProgressionScript.new()
	var state: Dictionary = progression.get_state()
	var rows = state.get("upgrade_rows", [])
	_assert(typeof(rows) == TYPE_ARRAY and rows.size() > 0, "permanent progression should expose upgrade rows")
	for row in rows:
		var upgrade_row: Dictionary = row
		var tags = upgrade_row.get("tags", [])
		_assert(str(upgrade_row.get("role", "")) != "", "upgrade row should include a readable role")
		var tags_ok: bool = typeof(tags) == TYPE_ARRAY and tags.size() >= 2
		_assert(tags_ok, "upgrade row should include scan tags")
		if tags_ok:
			_assert(str(tags[0]).length() <= 14, "upgrade tags should be compact")
	progression.free()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
