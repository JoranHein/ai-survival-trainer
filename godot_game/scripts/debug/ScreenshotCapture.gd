class_name ScreenshotCapture
extends Node

@export var output_dir := "res://artifacts/screenshots"

var _counter := 0


func capture(label: String = "screenshot") -> String:
	# Wait until the current frame has drawn before reading the viewport texture.
	await RenderingServer.frame_post_draw

	_counter += 1
	_ensure_output_dir()
	var clean_label := _safe_label(label)
	var timestamp := int(Time.get_unix_time_from_system())
	var path := "%s/%04d_%s_%d.png" % [output_dir, _counter, clean_label, timestamp]
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		push_error("Screenshot save failed: %s (error %d)" % [path, error])
		return ""
	print("Screenshot saved: ", ProjectSettings.globalize_path(path))
	return path


func get_output_dir() -> String:
	return output_dir


func _ensure_output_dir() -> void:
	var absolute_dir := ProjectSettings.globalize_path(output_dir)
	DirAccess.make_dir_recursive_absolute(absolute_dir)


func _safe_label(label: String) -> String:
	var safe := label.to_lower().strip_edges()
	for character in [" ", "\\", "/", ":", "*", "?", "\"", "<", ">", "|"]:
		safe = safe.replace(character, "_")
	if safe == "":
		return "screenshot"
	return safe
