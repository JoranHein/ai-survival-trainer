class_name VisualReviewScenario
extends Node

signal scenario_finished(paths: Array)

const MOMENTS := [
	"morning_idle",
	"midday_alive",
	"dusk_darkening",
	"night_zombies",
	"ari_dead_or_damaged",
]

var world: Node
var screenshot_capture: Node
var _running := false


func setup(world_node: Node, capture_node: Node) -> void:
	world = world_node
	screenshot_capture = capture_node


func start_sequence() -> void:
	if _running:
		return
	_running = true
	call_deferred("_run_sequence")


func is_running() -> bool:
	return _running


func _run_sequence() -> void:
	var paths := []
	for moment in MOMENTS:
		if world == null or screenshot_capture == null:
			break
		world.call("stage_visual_review_moment", moment)
		await get_tree().process_frame
		await get_tree().process_frame
		var path: String = await screenshot_capture.capture(moment)
		paths.append(path)

	_running = false
	print("Visual review screenshots complete: ", paths)
	scenario_finished.emit(paths)
