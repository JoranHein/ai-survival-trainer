class_name AIBridge
extends Node

const PROVIDER_LOCAL_STUB := "local_stub"
const PROVIDER_REMOTE_SERVER := "remote_server"

const CONFIG_LOCAL_PATH := "res://data/ai_config.local.json"
const CONFIG_EXAMPLE_PATH := "res://data/ai_config.example.json"

const ENDPOINTS := {
	"deep_interpretation": "/ai/deep-interpretation",
	"fast_thought": "/ai/fast-thought",
	"scribe": "/scribe",
	"library_reflection": "/library-reflection",
	"sleep_plan": "/sleep-plan",
	"life_summary": "/life-summary",
	"wisdom_synthesis": "/wisdom-synthesis",
}

const DEEP_PRIORITY_KEYS := [
	"mine_stone",
	"build_wall",
	"wait_or_idle",
	"use_existing_wall",
	"wait_behind_wall",
	"place_aura_orb",
	"lure_to_aura",
	"train_combat",
	"farm_food",
	"build_trap",
	"build_tower",
	"rest",
	"reflect_library",
	"repair",
	"flee",
	"fight",
	"kite",
	"hide",
	"use_cover",
]

const LEGACY_PRIORITY_HINTS := {
	"mining": "mine_stone",
	"wall": "build_wall",
	"aura_orb": "place_aura_orb",
	"defensive_wait": "wait_or_idle",
	"combat_training": "train_combat",
	"repair_structure": "repair",
}

var config: Dictionary = {}


func _init() -> void:
	_load_config()


func get_provider_mode() -> String:
	return str(config.get("provider_mode", PROVIDER_LOCAL_STUB))


func is_ai_enabled() -> bool:
	return bool(config.get("enabled", false)) and get_provider_mode() == PROVIDER_REMOTE_SERVER


func set_ai_enabled(enabled: bool) -> void:
	config["enabled"] = enabled
	config["provider_mode"] = PROVIDER_REMOTE_SERVER if enabled else PROVIDER_LOCAL_STUB


func get_ai_status() -> Dictionary:
	return {
		"enabled": is_ai_enabled(),
		"provider_mode": get_provider_mode(),
		"server_base_url": str(config.get("server_base_url", "")),
		"timeout_seconds": float(config.get("timeout_seconds", 8.0)),
	}


func force_provider_mode(provider_mode: String) -> void:
	if provider_mode == PROVIDER_REMOTE_SERVER:
		config["provider_mode"] = PROVIDER_REMOTE_SERVER
		config["enabled"] = true
	else:
		config["provider_mode"] = PROVIDER_LOCAL_STUB
		config["enabled"] = false


func request_deep_interpretation(payload: Dictionary, callback: Callable) -> void:
	if not is_ai_enabled() or not is_inside_tree():
		_call_callback_deferred(callback, _deep_fallback(payload, "local_fallback"))
		return

	var url := _configured_endpoint("deep_interpretation", "/ai/deep-interpretation")
	if url == "":
		_call_callback_deferred(callback, _deep_fallback(payload, "missing_endpoint"))
		return

	var http_request := HTTPRequest.new()
	http_request.timeout = float(config.get("timeout_seconds", 8.0))
	add_child(http_request)

	var headers := _json_auth_headers()
	var body := JSON.stringify(payload)

	http_request.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, response_body: PackedByteArray) -> void:
		var response := _parse_deep_interpretation_response(payload, result, response_code, response_body)
		_safe_call_callback(callback, response)
		http_request.queue_free()
	)

	var err := http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http_request.queue_free()
		_call_callback_deferred(callback, _deep_fallback(payload, "request_error"))


func request_scribe(payload: Dictionary, callback: Callable) -> void:
	_request_ai("scribe", payload, callback, "enable_scribe")


func request_library_reflection(payload: Dictionary, callback: Callable) -> void:
	_request_ai("library_reflection", payload, callback, "enable_library_reflection")


func request_sleep_plan(payload: Dictionary, callback: Callable) -> void:
	_request_ai("sleep_plan", payload, callback, "enable_sleep_plan")


func request_life_summary(payload: Dictionary, callback: Callable) -> void:
	_request_ai("life_summary", payload, callback, "enable_life_summary")


func request_wisdom_synthesis(payload: Dictionary, callback: Callable) -> void:
	_request_ai("wisdom_synthesis", payload, callback, "enable_wisdom_synthesis")


func request_health(callback: Callable) -> void:
	if not is_ai_enabled() or not is_inside_tree():
		_call_callback_deferred(callback, {
			"ok": true,
			"provider_mode": PROVIDER_LOCAL_STUB,
			"source": "local_stub",
		})
		return

	var server_base_url := str(config.get("server_base_url", ""))
	if server_base_url.strip_edges() == "":
		_call_callback_deferred(callback, {
			"ok": false,
			"provider_mode": PROVIDER_REMOTE_SERVER,
			"source": "missing_server_base_url",
		})
		return

	var http_request := HTTPRequest.new()
	http_request.timeout = float(config.get("timeout_seconds", 8.0))
	add_child(http_request)
	var headers := _auth_headers()

	http_request.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, response_body: PackedByteArray) -> void:
		var parsed := _parse_json_dictionary(response_body.get_string_from_utf8())
		parsed["ok"] = result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300
		parsed["provider_mode"] = PROVIDER_REMOTE_SERVER
		parsed["source"] = "remote_server"
		_safe_call_callback(callback, parsed)
		http_request.queue_free()
	)

	var err := http_request.request(_join_url(server_base_url, "/health"), headers, HTTPClient.METHOD_GET)
	if err != OK:
		http_request.queue_free()
		_call_callback_deferred(callback, {
			"ok": false,
			"provider_mode": PROVIDER_REMOTE_SERVER,
			"source": "request_error",
		})


func _request_ai(kind: String, payload: Dictionary, callback: Callable, enabled_key: String) -> void:
	if not bool(config.get(enabled_key, true)):
		_call_callback_deferred(callback, _validated_fallback(kind, payload))
		return

	if get_provider_mode() != PROVIDER_REMOTE_SERVER:
		_call_callback_deferred(callback, _validated_fallback(kind, payload))
		return

	if not is_inside_tree():
		_call_callback_deferred(callback, _validated_fallback(kind, payload))
		return

	var endpoint := str(ENDPOINTS.get(kind, ""))
	var server_base_url := str(config.get("server_base_url", ""))
	if endpoint == "" or server_base_url.strip_edges() == "":
		_call_callback_deferred(callback, _validated_fallback(kind, payload))
		return

	var http_request := HTTPRequest.new()
	http_request.timeout = float(config.get("timeout_seconds", 8.0))
	add_child(http_request)

	var url := _join_url(server_base_url, endpoint)
	var headers := _json_auth_headers()
	var body := JSON.stringify({"payload": payload})

	http_request.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, response_body: PackedByteArray) -> void:
		var response := _parse_remote_response(kind, payload, result, response_code, response_body)
		_safe_call_callback(callback, response)
		http_request.queue_free()
	)

	var err := http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http_request.queue_free()
		_call_callback_deferred(callback, _validated_fallback(kind, payload))


func _parse_remote_response(kind: String, payload: Dictionary, result: int, response_code: int, body: PackedByteArray) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS:
		return _validated_fallback(kind, payload)
	if response_code < 200 or response_code >= 300:
		return _validated_fallback(kind, payload)

	var response_text := body.get_string_from_utf8()
	var outer := _parse_json_dictionary(response_text)
	if outer.is_empty() or not outer.has("raw"):
		return _validated_fallback(kind, payload)

	var raw_value = outer.get("raw")
	var parsed_raw: Dictionary = {}
	if typeof(raw_value) == TYPE_DICTIONARY:
		parsed_raw = raw_value
	elif typeof(raw_value) == TYPE_STRING:
		parsed_raw = _parse_json_dictionary(str(raw_value))

	if parsed_raw.is_empty():
		return _validated_fallback(kind, payload)

	return _validate_response(kind, parsed_raw, payload)


func _parse_deep_interpretation_response(payload: Dictionary, result: int, response_code: int, body: PackedByteArray) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS:
		return _deep_fallback(payload, "request_failed")
	if response_code < 200 or response_code >= 300:
		return _deep_fallback(payload, "http_%d" % response_code)

	var parsed := _parse_json_dictionary(body.get_string_from_utf8())
	if parsed.is_empty():
		return _deep_fallback(payload, "invalid_json")
	return _validate_deep_interpretation(parsed, payload, true, "remote_server")


func _load_config() -> void:
	config = _default_config()
	var config_path := ""
	if FileAccess.file_exists(CONFIG_LOCAL_PATH):
		config_path = CONFIG_LOCAL_PATH
	elif FileAccess.file_exists(CONFIG_EXAMPLE_PATH):
		config_path = CONFIG_EXAMPLE_PATH

	if config_path == "":
		return

	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		return

	var parsed := _parse_json_dictionary(file.get_as_text())
	if parsed.is_empty():
		return

	for key in parsed.keys():
		config[key] = parsed[key]
	if bool(config.get("enabled", false)):
		config["provider_mode"] = PROVIDER_REMOTE_SERVER
	elif str(config.get("provider_mode", PROVIDER_LOCAL_STUB)) != PROVIDER_REMOTE_SERVER:
		config["provider_mode"] = PROVIDER_LOCAL_STUB
		config["enabled"] = false


func _default_config() -> Dictionary:
	return {
		"enabled": false,
		"provider_mode": PROVIDER_LOCAL_STUB,
		"server_base_url": "http://91.99.219.229:8088",
		"deep_interpretation_url": "",
		"fast_thought_url": "",
		"api_key": "",
		"timeout_seconds": 30.0,
		"enable_scribe": true,
		"enable_library_reflection": true,
		"enable_sleep_plan": true,
		"enable_life_summary": true,
		"enable_wisdom_synthesis": true,
	}


func _parse_json_dictionary(text: String) -> Dictionary:
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data


func _deep_fallback(payload: Dictionary, source := "local_fallback") -> Dictionary:
	var local_fallback = payload.get("local_fallback", {})
	var local: Dictionary = local_fallback if typeof(local_fallback) == TYPE_DICTIONARY else {}
	var data := {
		"interpretation": str(local.get("interpretation", "Ari falls back to his local reading.")),
		"thought": "I only understand part of the sign. I will stay careful.",
		"survival_theory": "local_fallback",
		"priority_hints": local.get("priority_hints", {}),
		"sign_strength": float(local.get("sign_strength", 0.0)),
		"resonance": float(local.get("resonance", 0.0)),
	}
	return _validate_deep_interpretation(data, payload, false, source)


func _validate_deep_interpretation(data: Dictionary, payload: Dictionary, ok := true, source := "remote_server") -> Dictionary:
	var fallback = payload.get("local_fallback", {})
	if typeof(fallback) != TYPE_DICTIONARY:
		fallback = {}
	var result := {
		"ok": ok,
		"provider_mode": get_provider_mode(),
		"source": source,
		"interpretation": _limit_text(str(data.get("interpretation", fallback.get("interpretation", ""))), 240),
		"thought": _limit_text(str(data.get("thought", "")), 160),
		"survival_theory": _limit_text(str(data.get("survival_theory", "fallback" if not ok else "")), 64),
		"priority_hints": _deep_priority_hints(data.get("priority_hints", fallback.get("priority_hints", {}))),
		"sign_strength": clampf(float(data.get("sign_strength", fallback.get("sign_strength", 0.0))), 0.0, 1.0),
		"resonance": clampf(float(data.get("resonance", fallback.get("resonance", 0.0))), 0.0, 1.0),
	}
	if str(result["thought"]).strip_edges() == "":
		result["thought"] = "I need to stay alive."
	return result


func _deep_priority_hints(value) -> Dictionary:
	var result := {}
	for key in DEEP_PRIORITY_KEYS:
		result[str(key)] = 0.0
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for raw_key in value.keys():
		var key := str(raw_key)
		key = str(LEGACY_PRIORITY_HINTS.get(key, key))
		if not result.has(key):
			continue
		result[key] = maxf(float(result[key]), clampf(float(value[raw_key]), 0.0, 1.0))
	return result


func _validated_fallback(kind: String, payload: Dictionary) -> Dictionary:
	return _validate_response(kind, _local_stub_response(kind, payload), payload)


func _local_stub_response(kind: String, payload: Dictionary) -> Dictionary:
	match kind:
		"scribe":
			return _local_stub_scribe(payload)
		"library_reflection":
			return {
				"title": "Ari's rough local reflection",
				"markdown": "# Ari's rough local reflection\n\nI remember fragments of what happened. I do not have the deeper mind yet, but I can still learn that preparation matters.",
				"hypothesis": "Preparation before night improves survival.",
				"plan": {
					"primary": "prepare",
					"secondary": "stay_safe",
					"avoid": "panic",
				},
				"priority_bias": {
					"prepare": 0.2,
					"rest": 0.05,
				},
				"confidence": 0.35,
				"thought": "I should prepare before the night gets close.",
			}
		"sleep_plan":
			return _local_stub_sleep_plan(payload)
		"life_summary":
			return {
				"life_summary_markdown": "# Life Summary\n\nAri lived, struggled, and learned a little. Better summaries will come from the remote model later.",
				"candidate_insights": [
					{
						"title": "Prepare Before Night",
						"summary": "Ari should begin preparing before night arrives.",
						"conditions": ["dusk", "night"],
						"suggested_actions": ["prepare", "rest"],
						"counters": [],
						"confidence": 0.35,
					},
				],
				"next_life_hint": "Prepare earlier.",
			}
		"wisdom_synthesis":
			return {
				"new_insights": [],
				"updated_insights": [],
				"weakened_insights": [],
				"merged_insights": [],
				"retired_insights": [],
			}
	return {}


func _local_stub_scribe(payload: Dictionary) -> Dictionary:
	var recent_events: Array = payload.get("recent_events", [])
	var last_event_type := "none"
	if not recent_events.is_empty() and typeof(recent_events[-1]) == TYPE_DICTIONARY:
		last_event_type = str(recent_events[-1].get("type", "unknown"))

	var ari: Dictionary = payload.get("ari", {})
	var current_action := str(ari.get("current_action", payload.get("current_action", "unknown")))
	var fear := float(ari.get("fear", payload.get("fear", 0.0)))
	var phase := str(payload.get("phase", ari.get("phase", ""))).strip_edges()
	var tags: Array[String] = ["local_stub"]
	if fear > 70.0:
		tags.append("fear_high")
	if phase == "dusk" or phase == "night":
		tags.append(phase)

	return {
		"t_start": float(payload.get("t_start", 0.0)),
		"t_end": float(payload.get("t_end", 0.0)),
		"note": "Ari was %s while fear was %.0f. Recent event: %s." % [current_action, fear, last_event_type],
		"tags": tags,
		"salience": 0.45 if last_event_type != "none" else 0.3,
	}


func _local_stub_sleep_plan(payload: Dictionary) -> Dictionary:
	var latest_note: Dictionary = payload.get("latest_note", {})
	var dominant_memory := "I remember that preparation matters."
	if not latest_note.is_empty():
		dominant_memory = _limit_text(str(latest_note.get("hypothesis", latest_note.get("title", dominant_memory))), 500)

	return {
		"dominant_memory": dominant_memory,
		"tomorrow_focus": ["prepare"],
		"priority_bias": {
			"prepare": 0.2,
			"rest": 0.05,
		},
		"wake_thought": "I read the last note again. I should prepare earlier.",
	}


func _validate_response(kind: String, data: Dictionary, _payload: Dictionary = {}) -> Dictionary:
	match kind:
		"scribe":
			return _validate_scribe_note(data)
		"library_reflection":
			return _validate_library_reflection(data)
		"sleep_plan":
			return _validate_sleep_plan(data)
		"life_summary":
			return _validate_life_summary(data)
		"wisdom_synthesis":
			return _validate_wisdom_synthesis(data)
	return {}


func _validate_scribe_note(data: Dictionary) -> Dictionary:
	return {
		"t_start": float(data.get("t_start", 0.0)),
		"t_end": float(data.get("t_end", 0.0)),
		"note": _limit_text(str(data.get("note", "Ari noticed recent events but has no remote scribe yet.")), 300),
		"tags": _string_array(data.get("tags", ["local_stub"]), 8, 40),
		"salience": clampf(float(data.get("salience", 0.3)), 0.0, 1.0),
	}


func _validate_library_reflection(data: Dictionary) -> Dictionary:
	return {
		"title": _limit_text(str(data.get("title", "Ari's rough local reflection")), 120),
		"markdown": _limit_text(str(data.get("markdown", "# Ari's rough local reflection\n\nPreparation before night improves survival.")), 2000),
		"hypothesis": _limit_text(str(data.get("hypothesis", "Preparation before night improves survival.")), 300),
		"plan": _string_dictionary(data.get("plan", {"primary": "prepare", "secondary": "stay_safe", "avoid": "panic"}), 12, 80),
		"priority_bias": _priority_bias(data.get("priority_bias", {"prepare": 0.2})),
		"confidence": clampf(float(data.get("confidence", 0.35)), 0.0, 1.0),
		"thought": _limit_text(str(data.get("thought", "I should prepare before the night gets close.")), 300),
	}


func _validate_sleep_plan(data: Dictionary) -> Dictionary:
	return {
		"dominant_memory": _limit_text(str(data.get("dominant_memory", "Preparation before night improves survival.")), 500),
		"tomorrow_focus": _string_array(data.get("tomorrow_focus", ["prepare"]), 8, 50),
		"priority_bias": _priority_bias(data.get("priority_bias", {"prepare": 0.2})),
		"wake_thought": _limit_text(str(data.get("wake_thought", "I read the last note again. I should prepare earlier.")), 300),
	}


func _validate_life_summary(data: Dictionary) -> Dictionary:
	var candidate_insights := []
	var raw_insights = data.get("candidate_insights", [])
	if typeof(raw_insights) == TYPE_ARRAY:
		for insight in raw_insights:
			if typeof(insight) == TYPE_DICTIONARY:
				candidate_insights.append(_validate_insight(insight))
			if candidate_insights.size() >= 8:
				break

	return {
		"life_summary_markdown": _limit_text(str(data.get("life_summary_markdown", "# Life Summary\n\nAri lived, struggled, and learned a little.")), 2500),
		"candidate_insights": candidate_insights,
		"next_life_hint": _limit_text(str(data.get("next_life_hint", "Prepare earlier.")), 300),
	}


func _validate_wisdom_synthesis(data: Dictionary) -> Dictionary:
	return {
		"new_insights": _insight_array(data.get("new_insights", []), 8),
		"updated_insights": _insight_array(data.get("updated_insights", []), 8),
		"weakened_insights": _insight_array(data.get("weakened_insights", []), 8),
		"merged_insights": _insight_array(data.get("merged_insights", []), 8),
		"retired_insights": _string_array(data.get("retired_insights", []), 16, 120),
	}


func _validate_insight(data: Dictionary) -> Dictionary:
	var title := _limit_text(str(data.get("title", "Untitled Insight")), 120)
	return {
		"id": _limit_text(str(data.get("id", _normalize_key(title))), 120),
		"title": title,
		"summary": _limit_text(str(data.get("summary", "")), 500),
		"conditions": _string_array(data.get("conditions", []), 12, 80),
		"suggested_actions": _string_array(data.get("suggested_actions", []), 12, 80),
		"counters": _string_array(data.get("counters", []), 12, 80),
		"confidence": clampf(float(data.get("confidence", 0.35)), 0.0, 1.0),
		"times_confirmed": max(0, int(data.get("times_confirmed", 1))),
		"times_failed": max(0, int(data.get("times_failed", 0))),
		"source_lives": _string_array(data.get("source_lives", []), 20, 120),
	}


func _insight_array(value, max_count: int) -> Array:
	var results := []
	if typeof(value) != TYPE_ARRAY:
		return results
	for item in value:
		if typeof(item) == TYPE_DICTIONARY:
			results.append(_validate_insight(item))
		if results.size() >= max_count:
			break
	return results


func _priority_bias(value) -> Dictionary:
	var result := {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for key in value.keys():
		result[_limit_text(str(key), 80)] = clampf(float(value[key]), -1.0, 1.0)
	return result


func _string_dictionary(value, max_count: int, max_length: int) -> Dictionary:
	var result := {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for key in value.keys():
		result[_limit_text(str(key), max_length)] = _limit_text(str(value[key]), max_length)
		if result.size() >= max_count:
			break
	return result


func _string_array(value, max_count: int, max_length: int) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		result.append(_limit_text(str(item), max_length))
		if result.size() >= max_count:
			break
	return result


func _limit_text(text: String, max_length: int) -> String:
	var cleaned := text.strip_edges()
	if cleaned.length() <= max_length:
		return cleaned
	return cleaned.substr(0, max_length)


func _normalize_key(text: String) -> String:
	var normalized := text.to_lower().strip_edges()
	normalized = normalized.replace(" ", "_")
	normalized = normalized.replace("-", "_")
	return normalized


func _auth_headers() -> PackedStringArray:
	var headers := PackedStringArray()
	var api_key := str(config.get("api_key", "")).strip_edges()
	if api_key != "":
		headers.append("X-API-Key: " + api_key)
	return headers


func _json_auth_headers() -> PackedStringArray:
	var headers := _auth_headers()
	headers.append("Content-Type: application/json")
	return headers


func _configured_endpoint(kind: String, default_endpoint: String) -> String:
	var explicit_url := str(config.get("%s_url" % kind, "")).strip_edges()
	if explicit_url != "":
		return explicit_url
	var server_base_url := str(config.get("server_base_url", "")).strip_edges()
	if server_base_url == "":
		return ""
	return _join_url(server_base_url, default_endpoint)


func _join_url(server_base_url: String, endpoint: String) -> String:
	return server_base_url.trim_suffix("/") + endpoint


func _call_callback_deferred(callback: Callable, result: Dictionary) -> void:
	_safe_call_callback(callback, result)


func _safe_call_callback(callback: Callable, result: Dictionary) -> void:
	if callback.is_valid():
		callback.call(result)
