extends CanvasLayer

@onready var label: Label = %StatusLabel


func update_state(state: Dictionary) -> void:
	var day := int(state.get("day", 1))
	var phase := str(state.get("phase", "morning"))
	var time_left := float(state.get("time_left", 0.0))
	var ari_hp := float(state.get("ari_hp", 0.0))
	var ari_max_hp := float(state.get("ari_max_hp", 0.0))
	var enemy_count := int(state.get("enemy_count", 0))
	var wall_count := int(state.get("wall_count", 0))
	var aura_orb_count := int(state.get("aura_orb_count", 0))
	var stone := int(state.get("stone", 0))
	var wall_cost := int(state.get("wall_cost", 0))
	var orb_cost := int(state.get("orb_cost", 0))
	var selected_build_name := str(state.get("selected_build_name", "Wall"))
	var build_mode := false
	var build_mode_value = state.get("build_mode", false)
	if typeof(build_mode_value) == TYPE_BOOL:
		build_mode = build_mode_value
	var mining_enabled := false
	var mining_value = state.get("mining_enabled", false)
	if typeof(mining_value) == TYPE_BOOL:
		mining_enabled = mining_value
	var ari_job := str(state.get("ari_job", "wait_or_idle"))
	var ari_job_reason := str(state.get("ari_job_reason", "Waiting"))
	var ari_action := str(state.get("ari_action", "idle"))
	var personality_summary := str(state.get("personality_summary", "Ari: balanced"))
	var run_build_summary := str(state.get("run_build_summary", "Balanced"))
	var status_message := str(state.get("status_message", ""))
	var ari_alive := true
	var alive_value = state.get("ari_alive", true)
	if typeof(alive_value) == TYPE_BOOL:
		ari_alive = alive_value

	var lines := [
		"Day: %d" % day,
		"Phase: %s" % phase,
		"Time left: %.1fs" % time_left,
		"Ari HP: %.0f/%.0f" % [ari_hp, ari_max_hp],
		personality_summary,
		"Run Build: %s" % run_build_summary,
		"Presets: 1 Builder 2 Aura 3 Fast 4 Curious",
		"Stone: %d (wall %d, orb %d)" % [stone, wall_cost, orb_cost],
		"Enemies: %d" % enemy_count,
		"Walls: %d" % wall_count,
		"Orbs: %d" % aura_orb_count,
		"Place: %s - %s" % ["ON" if build_mode else "OFF", selected_build_name],
		"Mining: %s" % ("ON" if mining_enabled else "OFF"),
		"Job: %s" % ari_job,
		"Reason: %s" % ari_job_reason,
		"Ari: %s" % ari_action,
	]
	if status_message != "":
		lines.append(status_message)
	if not ari_alive:
		lines.append("")
		lines.append("Ari died. Press R to restart.")
	label.text = "\n".join(lines)
