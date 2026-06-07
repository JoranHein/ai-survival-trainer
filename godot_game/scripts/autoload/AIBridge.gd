class_name AIBridge
extends Node

const PROVIDER_LOCAL_STUB := "local_stub"
const PROVIDER_REMOTE_SERVER := "remote_server"
const PROVIDER_CACHE := "cache"

const CONFIG_LOCAL_PATH := "res://data/ai_config.local.json"
const CONFIG_EXAMPLE_PATH := "res://data/ai_config.example.json"
const DEEP_CACHE_MAX_ENTRIES := 64
const SCRIBE_NOTE_SCHEMA := "ari.scribe.note.v2"
const INTERNAL_SCRIBE_EVENT_TYPES := {
	"agent_plan_created": true,
	"night_reflection_created": true,
	"note_reread": true,
	"learning_trace_created": true,
	"phase_changed": true,
}

const ENDPOINTS := {
	"deep_interpretation": "/ai/deep-interpretation",
	"agent_plan": "/ari/plan-v1",
	"fast_prediction": "/ari/predict-v1",
	"fast_thought": "/ai/fast-thought",
	"scribe": "/scribe",
	"library_reflection": "/library-reflection",
	"background_job": "/background-job",
	"sleep_plan": "/sleep-plan",
	"life_summary": "/life-summary",
	"wisdom_synthesis": "/wisdom-synthesis",
}

const DEFAULT_TIMEOUT_SECONDS := 5.0
const DEFAULT_KIND_TIMEOUTS := {
	"deep_interpretation": 5.0,
	"agent_plan": 5.0,
	"fast_prediction": 5.0,
	"background_job": 4.0,
	"scribe": 4.0,
	"library_reflection": 12.0,
	"fast_thought": 4.0,
}

const DEEP_PRIORITY_KEYS := [
	"mine_stone",
	"build_wall",
	"wait_or_idle",
	"use_existing_wall",
	"wait_behind_wall",
	"use_cover",
	"place_aura_orb",
	"lure_to_aura",
	"train_combat",
	"prepare_weapon",
	"ranged_attack",
	"use_tower",
	"train_bow",
	"farm_food",
	"eat",
	"eat_food",
	"build_trap",
	"build_spike_trap",
	"build_tower",
	"build_tar_pit",
	"lure_to_tar_pit",
	"build_fear_lantern",
	"use_fear_lantern",
	"build_decoy_idol",
	"use_decoy_idol",
	"build_thorn_totem",
	"build_repair_bench",
	"use_thorns",
	"rest",
	"reflect_library",
	"repair",
	"repair_structure",
	"flee",
	"fight",
	"fight_head_on",
	"train_sword",
	"smith_sword",
	"mine_ore",
	"build_forge",
	"use_armor",
	"rely_on_regen",
	"regen_on_kill",
	"stall_until_dawn",
	"hide_until_dawn",
	"avoid_killing",
	"survive_until_morning",
	"kite",
	"hide",
	"build_storm_rod",
	"anti_flying",
	"sky_answer",
	"anti_air_defense",
	"mining",
	"wall",
	"aura_orb",
	"combat_training",
	"range",
	"defensive_wait",
]

const LEGACY_PRIORITY_HINTS := {
	"mining": "mine_stone",
	"wall": "build_wall",
	"aura_orb": "place_aura_orb",
	"defensive_wait": "wait_or_idle",
	"combat_training": "train_combat",
	"repair_structure": "repair",
	"build_spike_trap": "build_trap",
}

var config: Dictionary = {}
var deep_interpretation_cache := {}
var deep_interpretation_cache_order: Array[String] = []


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
		"timeout_seconds": float(config.get("timeout_seconds", 5.0)),
		"fast_prediction_timeout_seconds": _timeout_for_kind("fast_prediction"),
		"background_timeout_seconds": _timeout_for_kind("background_job"),
		"library_reflection_timeout_seconds": _timeout_for_kind("library_reflection"),
		"enable_background_ai": bool(config.get("enable_background_ai", true)),
	}


func _timeout_for_kind(kind: String) -> float:
	var fallback := float(config.get("timeout_seconds", DEFAULT_TIMEOUT_SECONDS))
	var key := ""
	match kind:
		"deep_interpretation":
			key = "deep_interpretation_timeout_seconds"
		"agent_plan":
			key = "agent_plan_timeout_seconds"
		"fast_prediction":
			key = "fast_prediction_timeout_seconds"
		"background_job":
			key = "background_timeout_seconds"
		"scribe":
			key = "scribe_timeout_seconds"
		"library_reflection":
			key = "library_reflection_timeout_seconds"
		"fast_thought":
			key = "fast_thought_timeout_seconds"
		_:
			key = "%s_timeout_seconds" % kind
	var value = config.get(key, fallback)
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return fallback
	var numeric := float(value)
	var default_for_kind := float(DEFAULT_KIND_TIMEOUTS.get(kind, DEFAULT_TIMEOUT_SECONDS))
	if not is_equal_approx(fallback, DEFAULT_TIMEOUT_SECONDS) and is_equal_approx(numeric, default_for_kind):
		numeric = fallback
	return maxf(0.1, numeric)


func force_provider_mode(provider_mode: String) -> void:
	if provider_mode == PROVIDER_REMOTE_SERVER:
		config["provider_mode"] = PROVIDER_REMOTE_SERVER
		config["enabled"] = true
	else:
		config["provider_mode"] = PROVIDER_LOCAL_STUB
		config["enabled"] = false


func clear_deep_interpretation_cache() -> void:
	deep_interpretation_cache.clear()
	deep_interpretation_cache_order.clear()


func get_deep_interpretation_cache_size() -> int:
	return deep_interpretation_cache.size()


func request_deep_interpretation(payload: Dictionary, callback: Callable, bypass_cache := false) -> void:
	if not is_ai_enabled() or not is_inside_tree():
		_call_callback_deferred(callback, _deep_fallback(payload, "local_fallback", "disabled"))
		return

	if not bypass_cache:
		var cached := _cached_deep_interpretation(payload)
		if not cached.is_empty():
			_call_callback_deferred(callback, cached)
			return

	var url := _configured_endpoint("deep_interpretation", "/ai/deep-interpretation")
	if url == "":
		_call_callback_deferred(callback, _deep_fallback(payload, "missing_endpoint", "missing_endpoint"))
		return

	var http_request := HTTPRequest.new()
	http_request.timeout = _timeout_for_kind("deep_interpretation")
	add_child(http_request)

	var headers := _json_auth_headers()
	var body := JSON.stringify(payload)
	var started_ms := Time.get_ticks_msec()
	var endpoint_label := _safe_endpoint_label(url)
	print("AI deep request start endpoint=%s timeout=%.1fs bytes=%d" % [endpoint_label, http_request.timeout, body.length()])

	http_request.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, response_body: PackedByteArray) -> void:
		var response := _parse_deep_interpretation_response(payload, result, response_code, response_body)
		var latency_ms := Time.get_ticks_msec() - started_ms
		var failure_reason := str(response.get("failure_reason", ""))
		print("AI deep request done endpoint=%s result=%d http=%d latency_ms=%d status=%s" % [
			endpoint_label,
			result,
			response_code,
			latency_ms,
			"ok" if bool(response.get("ok", false)) else failure_reason,
		])
		if bool(response.get("ok", false)):
			_store_deep_interpretation_cache(payload, response)
		_safe_call_callback(callback, response)
		http_request.queue_free()
	)

	var err := http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http_request.queue_free()
		print("AI deep request start failed endpoint=%s error=%d" % [endpoint_label, err])
		_call_callback_deferred(callback, _deep_fallback(payload, "request_error", "request_error"))


func request_scribe(payload: Dictionary, callback: Callable) -> void:
	_request_ai("scribe", payload, callback, "enable_scribe")


func request_library_reflection(payload: Dictionary, callback: Callable) -> void:
	_request_ai("library_reflection", payload, callback, "enable_library_reflection")


func request_fast_prediction(payload: Dictionary, callback: Callable) -> void:
	if not bool(config.get("enable_fast_prediction", true)):
		_call_callback_deferred(callback, _validated_fallback("fast_prediction", payload))
		return
	if get_provider_mode() != PROVIDER_REMOTE_SERVER or not is_inside_tree():
		_call_callback_deferred(callback, _validated_fallback("fast_prediction", payload))
		return
	var server_base_url := str(config.get("server_base_url", ""))
	if server_base_url.strip_edges() == "":
		_call_callback_deferred(callback, _validated_fallback("fast_prediction", payload))
		return
	var url := _join_url(server_base_url, str(ENDPOINTS.get("fast_prediction", "/ari/predict-v1")))
	var http_request := HTTPRequest.new()
	http_request.timeout = _timeout_for_kind("fast_prediction")
	add_child(http_request)

	var headers := _json_auth_headers()
	var body := JSON.stringify(payload)
	var started_ms := Time.get_ticks_msec()
	var endpoint_label := _safe_endpoint_label(url)
	print("AI prediction request start endpoint=%s timeout=%.1fs bytes=%d" % [endpoint_label, http_request.timeout, body.length()])
	http_request.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, response_body: PackedByteArray) -> void:
		var response := _parse_fast_prediction_response(payload, result, response_code, response_body)
		var latency_ms := Time.get_ticks_msec() - started_ms
		print("AI prediction request done endpoint=%s result=%d http=%d latency_ms=%d status=%s" % [
			endpoint_label,
			result,
			response_code,
			latency_ms,
			"ok" if str(response.get("failure_reason", "")) == "" else str(response.get("failure_reason", "")),
		])
		_safe_call_callback(callback, response)
		http_request.queue_free()
	)
	var err := http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http_request.queue_free()
		_call_callback_deferred(callback, _validated_fallback("fast_prediction", payload))


func request_background_job(payload: Dictionary, callback: Callable) -> void:
	if not bool(config.get("enable_background_ai", true)):
		_call_callback_deferred(callback, _validated_fallback("background_job", payload))
		return
	if get_provider_mode() != PROVIDER_REMOTE_SERVER or not is_inside_tree():
		_call_callback_deferred(callback, _validated_fallback("background_job", payload))
		return
	var server_base_url := str(config.get("server_base_url", ""))
	if server_base_url.strip_edges() == "":
		_call_callback_deferred(callback, _validated_fallback("background_job", payload))
		return
	var url := _join_url(server_base_url, str(ENDPOINTS.get("background_job", "/background-job")))
	var http_request := HTTPRequest.new()
	http_request.timeout = _timeout_for_kind("background_job")
	add_child(http_request)

	var headers := _json_auth_headers()
	var body := JSON.stringify(payload)
	var started_ms := Time.get_ticks_msec()
	var endpoint_label := _safe_endpoint_label(url)
	print("AI background job request start endpoint=%s kind=%s timeout=%.1fs bytes=%d" % [
		endpoint_label,
		str(payload.get("kind", "")),
		http_request.timeout,
		body.length(),
	])
	http_request.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, response_body: PackedByteArray) -> void:
		var response := _parse_remote_response("background_job", payload, result, response_code, response_body)
		var latency_ms := Time.get_ticks_msec() - started_ms
		print("AI background job request done endpoint=%s result=%d http=%d latency_ms=%d status=%s" % [
			endpoint_label,
			result,
			response_code,
			latency_ms,
			str(response.get("status", response.get("failure_reason", ""))),
		])
		_safe_call_callback(callback, response)
		http_request.queue_free()
	)

	var err := http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http_request.queue_free()
		_call_callback_deferred(callback, _validated_fallback("background_job", payload))


func request_sleep_plan(payload: Dictionary, callback: Callable) -> void:
	_request_ai("sleep_plan", payload, callback, "enable_sleep_plan")


func request_life_summary(payload: Dictionary, callback: Callable) -> void:
	_request_ai("life_summary", payload, callback, "enable_life_summary")


func request_wisdom_synthesis(payload: Dictionary, callback: Callable) -> void:
	_request_ai("wisdom_synthesis", payload, callback, "enable_wisdom_synthesis")


func request_agent_plan(payload: Dictionary, callback: Callable) -> void:
	if not bool(config.get("enable_agent_plan", true)):
		_call_callback_deferred(callback, _agent_plan_fallback(payload, "disabled"))
		return

	if not is_ai_enabled() or not is_inside_tree():
		_call_callback_deferred(callback, _agent_plan_fallback(payload, "disabled"))
		return

	var url := _configured_endpoint("agent_plan", "/ari/plan-v1")
	if url == "":
		_call_callback_deferred(callback, _agent_plan_fallback(payload, "missing_endpoint"))
		return

	var http_request := HTTPRequest.new()
	http_request.timeout = _timeout_for_kind("agent_plan")
	add_child(http_request)

	var headers := _json_auth_headers()
	var body := JSON.stringify(payload)
	var started_ms := Time.get_ticks_msec()
	var endpoint_label := _safe_endpoint_label(url)
	print("AI agent plan request start endpoint=%s timeout=%.1fs bytes=%d" % [endpoint_label, http_request.timeout, body.length()])

	http_request.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, response_body: PackedByteArray) -> void:
		var response := _parse_agent_plan_response(payload, result, response_code, response_body)
		var latency_ms := Time.get_ticks_msec() - started_ms
		var failure_reason := str(response.get("failure_reason", ""))
		print("AI agent plan request done endpoint=%s result=%d http=%d latency_ms=%d status=%s" % [
			endpoint_label,
			result,
			response_code,
			latency_ms,
			"ok" if bool(response.get("ok", false)) else failure_reason,
		])
		_safe_call_callback(callback, response)
		http_request.queue_free()
	)

	var err := http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http_request.queue_free()
		print("AI agent plan request start failed endpoint=%s error=%d" % [endpoint_label, err])
		_call_callback_deferred(callback, _agent_plan_fallback(payload, "request_error"))


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
	http_request.timeout = _timeout_for_kind("health")
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
	http_request.timeout = _timeout_for_kind(kind)
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
		var reason := _http_result_failure_reason(result)
		return _deep_fallback(payload, reason, reason)
	if response_code < 200 or response_code >= 300:
		var http_reason := _http_status_failure_reason(response_code)
		return _deep_fallback(payload, http_reason, http_reason)

	var parsed := _parse_json_dictionary(body.get_string_from_utf8())
	if parsed.is_empty():
		return _deep_fallback(payload, "parse", "parse")
	return _validate_deep_interpretation(parsed, payload, true, "remote_server")


func _parse_agent_plan_response(payload: Dictionary, result: int, response_code: int, body: PackedByteArray) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS:
		var reason := _http_result_failure_reason(result)
		return _agent_plan_fallback(payload, reason)
	if response_code < 200 or response_code >= 300:
		return _agent_plan_fallback(payload, _http_status_failure_reason(response_code))

	var parsed := _parse_json_dictionary(body.get_string_from_utf8())
	if parsed.is_empty():
		return _agent_plan_fallback(payload, "parse")
	return _validate_agent_plan(parsed, payload, true, "remote_server")


func _parse_fast_prediction_response(payload: Dictionary, result: int, response_code: int, body: PackedByteArray) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS:
		return _validated_fallback("fast_prediction", payload)
	if response_code < 200 or response_code >= 300:
		return _validated_fallback("fast_prediction", payload)
	var parsed := _parse_json_dictionary(body.get_string_from_utf8())
	if parsed.is_empty():
		return _validated_fallback("fast_prediction", payload)
	return _validate_fast_prediction(parsed, payload)


func _cached_deep_interpretation(payload: Dictionary) -> Dictionary:
	var key := _deep_cache_key(payload)
	if key == "" or not deep_interpretation_cache.has(key):
		return {}
	var cached = deep_interpretation_cache.get(key, {})
	if typeof(cached) != TYPE_DICTIONARY:
		return {}
	var result: Dictionary = cached.duplicate(true)
	result["source"] = PROVIDER_CACHE
	result["cached"] = true
	result["provider_mode"] = get_provider_mode()
	return result


func _store_deep_interpretation_cache(payload: Dictionary, response: Dictionary) -> void:
	if not bool(response.get("ok", false)):
		return
	var key := _deep_cache_key(payload)
	if key == "":
		return
	var stored := response.duplicate(true)
	stored["cached"] = false
	deep_interpretation_cache[key] = stored
	deep_interpretation_cache_order.erase(key)
	deep_interpretation_cache_order.append(key)
	while deep_interpretation_cache_order.size() > DEEP_CACHE_MAX_ENTRIES:
		var oldest_key := str(deep_interpretation_cache_order.pop_front())
		deep_interpretation_cache.erase(oldest_key)


func _deep_cache_key(payload: Dictionary) -> String:
	var sign_key := _normalize_cache_text(str(payload.get("sign_text", "")))
	if sign_key == "":
		return ""
	return "sign=%s|%s" % [sign_key, _deep_context_signature(payload)]


func _deep_context_signature(payload: Dictionary) -> String:
	var parts: Array[String] = []
	var world := _dictionary_value(payload.get("world", {}))
	for key in [
		"phase",
		"wall_count",
		"aura_orb_count",
		"bow_tower_count",
		"storm_rod_count",
		"enemy_count",
		"food",
		"stone",
		"ore",
		"sword_tier",
	]:
		if world.has(key):
			parts.append("%s=%s" % [str(key), str(world.get(key))])
	parts.append("enemies=%s" % _sorted_key_values(_dictionary_value(world.get("enemy_type_counts", {}))))
	parts.append("known=%s" % _sorted_string_values(world.get("known_enemy_types", [])))
	parts.append("structures=%s" % _structure_signature(world.get("structures", [])))
	parts.append("affordances=%s" % _affordance_signature(payload.get("current_affordances", [])))
	var perception := _dictionary_value(payload.get("perception", {}))
	parts.append("facts=%s" % _sorted_string_values(perception.get("tactical_facts", [])))
	parts.append("safe=%s" % _sorted_string_values(perception.get("available_safe_moves", [])))
	var latest_note := _normalize_cache_text(str(payload.get("latest_library_note", "")))
	if latest_note != "":
		parts.append("note=%s" % latest_note.substr(0, 80))
	return "|".join(parts)


func _normalize_cache_text(text: String) -> String:
	var cleaned := text.to_lower().replace("\n", " ").replace("\t", " ").strip_edges()
	var words := cleaned.split(" ", false)
	return " ".join(words)


func _dictionary_value(value) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}


func _sorted_key_values(value: Dictionary) -> String:
	var parts: Array[String] = []
	var keys := value.keys()
	keys.sort()
	for raw_key in keys:
		parts.append("%s:%s" % [str(raw_key), str(value[raw_key])])
	return ",".join(parts)


func _sorted_string_values(value) -> String:
	if typeof(value) != TYPE_ARRAY:
		return ""
	var items: Array[String] = []
	for item in value:
		items.append(str(item))
	items.sort()
	return ",".join(items)


func _structure_signature(value) -> String:
	if typeof(value) != TYPE_ARRAY:
		return ""
	var items: Array[String] = []
	for item in value:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		items.append("%s:%s" % [str(item.get("type", "")), str(item.get("status", ""))])
	items.sort()
	return ",".join(items)


func _affordance_signature(value) -> String:
	if typeof(value) != TYPE_ARRAY:
		return ""
	var items: Array[String] = []
	for item in value:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		items.append("%s:%s" % [str(item.get("id", "")), "1" if bool(item.get("available", false)) else "0"])
	items.sort()
	return ",".join(items)


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
		"timeout_seconds": 5.0,
		"deep_interpretation_timeout_seconds": 5.0,
		"agent_plan_timeout_seconds": 5.0,
		"fast_prediction_timeout_seconds": 5.0,
		"background_timeout_seconds": 4.0,
		"scribe_timeout_seconds": 4.0,
		"library_reflection_timeout_seconds": 12.0,
		"fast_thought_timeout_seconds": 4.0,
		"enable_scribe": true,
		"enable_library_reflection": true,
		"enable_fast_prediction": true,
		"enable_background_ai": true,
		"enable_sleep_plan": true,
		"enable_life_summary": true,
		"enable_wisdom_synthesis": true,
		"enable_agent_plan": true,
	}


func _parse_json_dictionary(text: String) -> Dictionary:
	if text.length() > 0 and text.unicode_at(0) == 0xFEFF:
		text = text.substr(1)
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data


func _deep_fallback(payload: Dictionary, source := "local_fallback", failure_reason := "") -> Dictionary:
	var local_fallback = payload.get("local_fallback", {})
	var local: Dictionary = local_fallback if typeof(local_fallback) == TYPE_DICTIONARY else {}
	var reason := str(failure_reason if failure_reason != "" else source)
	var data := {
		"interpretation": str(local.get("interpretation", "Ari falls back to his local reading.")),
		"thought": "I only understand part of the sign. I will stay careful.",
		"survival_theory": str(local.get("survival_theory", "local_fallback")),
		"emotion": str(local.get("emotion", "uncertain")),
		"grounded_plan": local.get("grounded_plan", []),
		"priority_hints": local.get("priority_hints", {}),
		"sign_strength": float(local.get("sign_strength", 0.0)),
		"resonance": float(local.get("resonance", 0.0)),
		"failure_reason": reason,
	}
	return _validate_deep_interpretation(data, payload, false, source)


func _agent_plan_fallback(payload: Dictionary, failure_reason := "local_fallback") -> Dictionary:
	var local_fallback = payload.get("local_fallback", {})
	var local: Dictionary = local_fallback if typeof(local_fallback) == TYPE_DICTIONARY else {}
	var data := local.duplicate(true)
	data["schema"] = "ari.agent.plan.v1"
	data["failure_reason"] = failure_reason
	if not data.has("goal"):
		data["goal"] = "survive_next_night"
	if not data.has("survival_theory"):
		data["survival_theory"] = "Use the safest legal action Ari can currently understand."
	if not data.has("thought"):
		data["thought"] = "I need a plan I can actually do."
	return _validate_agent_plan(data, payload, false, "local_fallback", failure_reason)


func _validate_deep_interpretation(data: Dictionary, payload: Dictionary, ok := true, source := "remote_server") -> Dictionary:
	var fallback = payload.get("local_fallback", {})
	if typeof(fallback) != TYPE_DICTIONARY:
		fallback = {}
	var priority_hints := _deep_priority_hints(data.get("priority_hints", fallback.get("priority_hints", {})))
	var grounded_plan := _deep_grounded_plan(data.get("grounded_plan", fallback.get("grounded_plan", [])))
	if grounded_plan.is_empty():
		grounded_plan = _grounded_plan_from_hints(priority_hints)
	_apply_grounded_plan_to_hints(priority_hints, grounded_plan)
	var result := {
		"ok": ok,
		"provider_mode": get_provider_mode(),
		"source": source,
		"interpretation": _limit_text(str(data.get("interpretation", fallback.get("interpretation", ""))), 240),
		"thought": _limit_text(str(data.get("thought", "")), 160),
		"survival_theory": _limit_text(str(data.get("survival_theory", "fallback" if not ok else "")), 64),
		"emotion": _limit_text(str(data.get("emotion", fallback.get("emotion", "uncertain"))), 64),
		"grounded_plan": grounded_plan,
		"priority_hints": priority_hints,
		"sign_strength": clampf(float(data.get("sign_strength", fallback.get("sign_strength", 0.0))), 0.0, 1.0),
		"resonance": clampf(float(data.get("resonance", fallback.get("resonance", 0.0))), 0.0, 1.0),
	}
	if not ok:
		result["failure_reason"] = _compact_failure_reason(str(data.get("failure_reason", source)))
	if str(result["thought"]).strip_edges() == "":
		result["thought"] = "I need to stay alive."
	return result


func _validate_agent_plan(data: Dictionary, payload: Dictionary, ok := true, source := "remote_server", failure_reason := "") -> Dictionary:
	if ok and str(data.get("schema", "")) != "ari.agent.plan.v1":
		return _agent_plan_fallback(payload, "invalid_schema")

	var legal_ids: Dictionary = _agent_legal_action_ids(payload)
	if ok and _agent_plan_has_illegal_action(data, legal_ids):
		return _agent_plan_fallback(payload, "invalid_action")

	var fallback = payload.get("local_fallback", {})
	if typeof(fallback) != TYPE_DICTIONARY:
		fallback = {}
	var fallback_action: Dictionary = _agent_action_choice(data.get("fallback_action", fallback.get("fallback_action", {})), legal_ids)
	var next_action: Dictionary = _agent_action_choice(data.get("next_action", fallback.get("next_action", {})), legal_ids)

	if next_action.is_empty():
		var fallback_id := str(fallback_action.get("action_id", ""))
		var first_id := _first_agent_action(payload, fallback_id)
		if first_id != "":
			next_action = {
				"action_id": first_id,
				"urgency": 0.35,
				"reason": "Local fallback selected the safest available action.",
			}
	if fallback_action.is_empty():
		var fallback_id := _first_agent_action(payload, str(next_action.get("action_id", "")))
		if fallback_id != "":
			fallback_action = {
				"action_id": fallback_id,
				"urgency": 0.25,
				"reason": "Fallback remains legal if the plan stalls.",
			}

	var plan: Array = _agent_plan_steps(data.get("plan", fallback.get("plan", [])), legal_ids)
	if plan.is_empty() and not next_action.is_empty():
		plan.append({
			"step_id": "next_action",
			"action_id": str(next_action.get("action_id", "")),
			"reason": str(next_action.get("reason", "Execute the next legal action.")),
			"success": "action_completed",
		})
	var doctrine_prerequisite := _agent_plan_doctrine_prerequisite_choice(payload, legal_ids, next_action)
	if not doctrine_prerequisite.is_empty():
		next_action = doctrine_prerequisite
		plan = [_agent_plan_step_from_choice(doctrine_prerequisite, "doctrine_prerequisite")]
	var safety_choice := _agent_plan_safety_choice(payload, legal_ids, next_action)
	if not safety_choice.is_empty():
		next_action = safety_choice
		plan = [_agent_plan_step_from_choice(safety_choice, "safety_guard")]

	var result := {
		"ok": ok,
		"provider_mode": get_provider_mode(),
		"source": source,
		"schema": "ari.agent.plan.v1",
		"goal": _limit_text(str(data.get("goal", fallback.get("goal", "survive_next_night"))), 120),
		"survival_theory": _limit_text(str(data.get("survival_theory", fallback.get("survival_theory", "fallback"))), 240),
		"plan": plan,
		"next_action": next_action,
		"fallback_action": fallback_action,
		"belief_updates": _agent_belief_updates(data.get("belief_updates", [])),
		"thought": _limit_text(str(data.get("thought", fallback.get("thought", "I need to stay alive."))), 180),
		"confidence": clampf(float(data.get("confidence", fallback.get("confidence", 0.3))), 0.0, 1.0),
		"replan_after_seconds": clampf(float(data.get("replan_after_seconds", fallback.get("replan_after_seconds", 8.0))), 3.0, 45.0),
	}
	if str(result["thought"]).strip_edges() == "":
		result["thought"] = "I need to stay alive."
	if not ok:
		result["failure_reason"] = _compact_failure_reason(str(failure_reason if failure_reason != "" else data.get("failure_reason", source)))
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


func _deep_grounded_plan(value) -> Array:
	var result := []
	var seen := {}
	if typeof(value) != TYPE_ARRAY:
		return result
	for raw_item in value:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue
		var affordance_id := str(raw_item.get("affordance_id", raw_item.get("id", "")))
		affordance_id = str(LEGACY_PRIORITY_HINTS.get(affordance_id, affordance_id))
		if not DEEP_PRIORITY_KEYS.has(affordance_id) or seen.has(affordance_id):
			continue
		var priority := clampf(float(raw_item.get("priority", 0.0)), 0.0, 1.0)
		if priority <= 0.0:
			continue
		result.append({
			"affordance_id": affordance_id,
			"priority": priority,
			"reason": _limit_text(str(raw_item.get("reason", "")), 180),
		})
		seen[affordance_id] = true
		if result.size() >= 4:
			break
	return result


func _grounded_plan_from_hints(priority_hints: Dictionary) -> Array:
	var candidates := []
	for raw_key in priority_hints.keys():
		var key := str(raw_key)
		var priority := clampf(float(priority_hints[raw_key]), 0.0, 1.0)
		if priority <= 0.0:
			continue
		candidates.append({
			"affordance_id": key,
			"priority": priority,
			"reason": "Local fallback made this the closest executable behavior.",
		})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("priority", 0.0)) > float(b.get("priority", 0.0))
	)
	return candidates.slice(0, mini(candidates.size(), 4))


func _apply_grounded_plan_to_hints(priority_hints: Dictionary, grounded_plan: Array) -> void:
	for item in grounded_plan:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var key := str(item.get("affordance_id", ""))
		if not priority_hints.has(key):
			continue
		priority_hints[key] = maxf(float(priority_hints.get(key, 0.0)), clampf(float(item.get("priority", 0.0)), 0.0, 1.0))


func _agent_legal_action_ids(payload: Dictionary) -> Dictionary:
	var result := {}
	var legal_actions = payload.get("legal_actions", [])
	if typeof(legal_actions) != TYPE_ARRAY:
		return result
	for raw_action in legal_actions:
		if typeof(raw_action) != TYPE_DICTIONARY:
			continue
		if raw_action.has("available") and not bool(raw_action.get("available", false)):
			continue
		var action_id := str(raw_action.get("id", raw_action.get("action_id", ""))).strip_edges()
		if action_id == "":
			continue
		result[action_id] = true
	return result


func _agent_plan_has_illegal_action(data: Dictionary, legal_ids: Dictionary) -> bool:
	for key in ["next_action", "fallback_action"]:
		var raw_choice = data.get(key, {})
		if typeof(raw_choice) == TYPE_DICTIONARY and _agent_choice_is_illegal(raw_choice, legal_ids):
			return true
	var raw_plan = data.get("plan", [])
	if typeof(raw_plan) != TYPE_ARRAY:
		return false
	for raw_step in raw_plan:
		if typeof(raw_step) != TYPE_DICTIONARY:
			continue
		var action_id := str(raw_step.get("action_id", raw_step.get("affordance_id", raw_step.get("id", "")))).strip_edges()
		if action_id != "" and not legal_ids.has(action_id):
			return true
	return false


func _agent_choice_is_illegal(choice: Dictionary, legal_ids: Dictionary) -> bool:
	var action_id := str(choice.get("action_id", choice.get("id", ""))).strip_edges()
	return action_id != "" and not legal_ids.has(action_id)


func _agent_action_choice(value, legal_ids: Dictionary) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var action_id := str(value.get("action_id", value.get("id", ""))).strip_edges()
	if action_id == "" or not legal_ids.has(action_id):
		return {}
	return {
		"action_id": action_id,
		"urgency": clampf(float(value.get("urgency", value.get("priority", 0.3))), 0.0, 1.0),
		"reason": _limit_text(str(value.get("reason", "")), 180),
	}


func _agent_plan_steps(value, legal_ids: Dictionary) -> Array:
	var result := []
	var seen := {}
	if typeof(value) != TYPE_ARRAY:
		return result
	for raw_step in value:
		if typeof(raw_step) != TYPE_DICTIONARY:
			continue
		var action_id := str(raw_step.get("action_id", raw_step.get("affordance_id", raw_step.get("id", "")))).strip_edges()
		if action_id == "" or not legal_ids.has(action_id) or seen.has(action_id):
			continue
		var step := {
			"step_id": _limit_text(str(raw_step.get("step_id", action_id)), 80),
			"action_id": action_id,
			"reason": _limit_text(str(raw_step.get("reason", "")), 180),
			"success": _limit_text(str(raw_step.get("success", "")), 120),
		}
		if raw_step.has("priority"):
			step["priority"] = clampf(float(raw_step.get("priority", 0.0)), 0.0, 1.0)
		result.append(step)
		seen[action_id] = true
		if result.size() >= 4:
			break
	return result


func _agent_plan_doctrine_prerequisite_choice(payload: Dictionary, legal_ids: Dictionary, current_next_action: Dictionary) -> Dictionary:
	var active_plan = payload.get("active_doctrine_plan", [])
	if typeof(active_plan) != TYPE_ARRAY:
		return {}
	var world = payload.get("world", {})
	if typeof(world) != TYPE_DICTIONARY:
		world = {}
	var current_action := str(current_next_action.get("action_id", "")).strip_edges()
	if _agent_doctrine_has_action(active_plan, "build_storm_rod") and _agent_world_count(world, ["storm_rod_count", "storm_rods"]) <= 0:
		var storm_choice := _agent_doctrine_prerequisite_action(
			"build_storm_rod",
			"mine_stone",
			"Storm Rod",
			current_action,
			legal_ids,
			payload
		)
		if not storm_choice.is_empty():
			return storm_choice
	if _agent_doctrine_has_action(active_plan, "build_tower") and _agent_doctrine_has_any_action(active_plan, ["use_tower", "ranged_attack", "train_bow"]) and _agent_world_count(world, ["bow_tower_count", "tower_count", "towers"]) <= 0:
		var tower_choice := _agent_doctrine_prerequisite_action(
			"build_tower",
			"mine_stone",
			"Bow Tower",
			current_action,
			legal_ids,
			payload
		)
		if not tower_choice.is_empty():
			return tower_choice
	if _agent_doctrine_has_action(active_plan, "place_aura_orb") and _agent_doctrine_has_action(active_plan, "lure_to_aura") and _agent_world_count(world, ["aura_orb_count", "aura_orbs"]) <= 0:
		var aura_choice := _agent_doctrine_prerequisite_action(
			"place_aura_orb",
			"mine_stone",
			"Aura Orb",
			current_action,
			legal_ids,
			payload
		)
		if not aura_choice.is_empty():
			return aura_choice
	return {}


func _agent_plan_safety_choice(payload: Dictionary, legal_ids: Dictionary, current_next_action: Dictionary) -> Dictionary:
	var world = payload.get("world", {})
	if typeof(world) != TYPE_DICTIONARY:
		world = {}
	var sign_text := _agent_payload_sign_text(payload)
	var current_action := str(current_next_action.get("action_id", "")).strip_edges()
	var enemy_count := int(world.get("enemy_count", 0))
	var enemy_counts = world.get("enemy_type_counts", {})
	var has_flying := false
	if typeof(enemy_counts) == TYPE_DICTIONARY:
		has_flying = int(enemy_counts.get("flying", 0)) > 0
	has_flying = has_flying or sign_text.contains("wing") or sign_text.contains("flying") or sign_text.contains("sky")

	if has_flying and _agent_world_count(world, ["storm_rod_count", "storm_rods"]) <= 0 and not ["build_storm_rod", "mine_stone"].has(current_action):
		if legal_ids.has("build_storm_rod"):
			return {
				"action_id": "build_storm_rod",
				"urgency": 0.92,
				"reason": "Flying danger bypasses ordinary cover; build the Storm Rod first.",
			}
		if legal_ids.has("mine_stone"):
			return {
				"action_id": "mine_stone",
				"urgency": 0.82,
				"reason": "Flying danger needs a Storm Rod; gather stone before ordinary cover.",
			}

	if current_action == "fight_head_on" and not _agent_plan_allows_direct_melee(payload, world):
		var wants_range := sign_text.contains("tower") or sign_text.contains("mountain") or sign_text.contains("arrow") or sign_text.contains("bow") or sign_text.contains("range") or sign_text.contains("high") or sign_text.contains("height")
		if wants_range and _agent_world_count(world, ["bow_tower_count", "tower_count", "towers"]) > 0 and legal_ids.has("use_tower"):
			return {
				"action_id": "use_tower",
				"urgency": 0.9,
				"reason": "The sign and built tower point to ranged survival, not direct melee.",
			}
		if _agent_world_count(world, ["aura_orb_count", "aura_orbs"]) > 0 and legal_ids.has("lure_to_aura"):
			return {
				"action_id": "lure_to_aura",
				"urgency": 0.86,
				"reason": "Existing aura damage is safer than direct melee.",
			}
		if enemy_count > 0 and legal_ids.has("use_cover"):
			return {
				"action_id": "use_cover",
				"urgency": 0.82,
				"reason": "Active enemies make unsupported direct melee unsafe; use cover.",
			}
		if enemy_count > 0 and legal_ids.has("flee"):
			return {
				"action_id": "flee",
				"urgency": 0.78,
				"reason": "Active enemies make unsupported direct melee unsafe; create distance.",
			}
	return {}


func _agent_payload_sign_text(payload: Dictionary) -> String:
	var sign = payload.get("sign", {})
	if typeof(sign) != TYPE_DICTIONARY:
		return ""
	return ("%s %s" % [str(sign.get("text", "")), str(sign.get("interpretation", ""))]).to_lower()


func _agent_plan_allows_direct_melee(payload: Dictionary, world: Dictionary) -> bool:
	var sign_text := _agent_payload_sign_text(payload)
	var direct_tokens := ["sword", "blade", "ore", "kill", "fight", "melee", "life when they die", "life-on-kill"]
	var direct_sign := false
	for token in direct_tokens:
		if sign_text.contains(str(token)):
			direct_sign = true
			break
	if not direct_sign:
		return false
	var sword_tier := _agent_world_count(world, ["sword_tier"])
	var combat_level := float(world.get("combat_level", world.get("combat", 0.0)))
	return sword_tier > 0 or combat_level >= 1.0


func _agent_doctrine_prerequisite_action(target_action: String, resource_action: String, label: String, current_action: String, legal_ids: Dictionary, payload: Dictionary) -> Dictionary:
	if current_action == target_action or current_action == resource_action:
		return {}
	if _agent_live_danger_allows_survival_override(payload, current_action):
		return {}
	if legal_ids.has(target_action):
		return {
			"action_id": target_action,
			"urgency": 0.9,
			"reason": "Active doctrine still needs %s before later steps." % label,
		}
	if legal_ids.has(resource_action):
		return {
			"action_id": resource_action,
			"urgency": 0.82,
			"reason": "Active doctrine still needs %s; gather resources before later steps." % label,
		}
	return {}


func _agent_live_danger_allows_survival_override(payload: Dictionary, current_action: String) -> bool:
	if not ["flee", "use_cover", "hide_until_dawn", "stall_until_dawn", "survive_until_morning"].has(current_action):
		return false
	var world = payload.get("world", {})
	if typeof(world) != TYPE_DICTIONARY:
		return false
	return int(world.get("enemy_count", 0)) > 0


func _agent_doctrine_has_action(active_plan: Array, action_id: String) -> bool:
	return _agent_doctrine_has_any_action(active_plan, [action_id])


func _agent_doctrine_has_any_action(active_plan: Array, action_ids: Array) -> bool:
	for item in active_plan:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var candidate := str(item.get("affordance_id", item.get("action_id", item.get("id", "")))).strip_edges()
		if action_ids.has(candidate):
			return true
	return false


func _agent_world_count(world: Dictionary, keys: Array) -> int:
	for raw_key in keys:
		var key := str(raw_key)
		if world.has(key):
			return maxi(int(world.get(key, 0)), 0)
	var structures = world.get("structures", {})
	if typeof(structures) == TYPE_DICTIONARY:
		for raw_key in keys:
			var key := str(raw_key)
			if structures.has(key):
				return maxi(int(structures.get(key, 0)), 0)
	return 0


func _agent_plan_step_from_choice(choice: Dictionary, step_id: String) -> Dictionary:
	return {
		"step_id": step_id,
		"action_id": str(choice.get("action_id", "")),
		"reason": str(choice.get("reason", "")),
		"success": "action_completed",
	}


func _agent_belief_updates(value) -> Array:
	var result := []
	if typeof(value) != TYPE_ARRAY:
		return result
	for raw_update in value:
		if typeof(raw_update) != TYPE_DICTIONARY:
			continue
		var key := _limit_text(str(raw_update.get("key", "")), 80)
		if key == "":
			continue
		result.append({
			"key": key,
			"delta": clampf(float(raw_update.get("delta", 0.0)), -1.0, 1.0),
			"reason": _limit_text(str(raw_update.get("reason", "")), 180),
		})
		if result.size() >= 6:
			break
	return result


func _first_agent_action(payload: Dictionary, preferred_id := "") -> String:
	var legal_actions = payload.get("legal_actions", [])
	var first_id := ""
	if typeof(legal_actions) != TYPE_ARRAY:
		return ""
	for raw_action in legal_actions:
		if typeof(raw_action) != TYPE_DICTIONARY:
			continue
		if raw_action.has("available") and not bool(raw_action.get("available", false)):
			continue
		var action_id := str(raw_action.get("id", raw_action.get("action_id", ""))).strip_edges()
		if action_id == "":
			continue
		if first_id == "":
			first_id = action_id
		if preferred_id != "" and action_id == preferred_id:
			return action_id
	return first_id


func _local_stub_agent_plan(payload: Dictionary) -> Dictionary:
	var local_fallback = payload.get("local_fallback", {})
	if typeof(local_fallback) == TYPE_DICTIONARY and not local_fallback.is_empty():
		var local: Dictionary = local_fallback.duplicate(true)
		local["schema"] = "ari.agent.plan.v1"
		return local

	var action_id := _choose_local_agent_action(payload)
	return {
		"schema": "ari.agent.plan.v1",
		"goal": "survive_next_night",
		"survival_theory": "Favor the strongest legal preparation that matches current danger.",
		"plan": [{
			"step_id": "local_first_step",
			"action_id": action_id,
			"reason": "Local Ari chose the best available survival action.",
			"success": "safer_position",
		}] if action_id != "" else [],
		"next_action": {"action_id": action_id, "urgency": 0.45, "reason": "Local fallback action."} if action_id != "" else {},
		"fallback_action": {"action_id": action_id, "urgency": 0.25, "reason": "Repeat the legal fallback if nothing better is safe."} if action_id != "" else {},
		"belief_updates": [],
		"thought": "I will do the thing I can actually do.",
		"confidence": 0.35,
		"replan_after_seconds": 8.0,
	}


func _choose_local_agent_action(payload: Dictionary) -> String:
	var legal_ids: Dictionary = _agent_legal_action_ids(payload)
	var world := _dictionary_value(payload.get("world", {}))
	var enemy_counts := _dictionary_value(world.get("enemy_type_counts", payload.get("enemy_type_counts", {})))
	var raw_sign = payload.get("sign_text", "")
	if raw_sign == "":
		var sign_data := _dictionary_value(payload.get("sign", {}))
		raw_sign = sign_data.get("text", "")
	var sign_text := str(raw_sign).to_lower()

	if int(enemy_counts.get("flying", 0)) > 0 and legal_ids.has("build_storm_rod"):
		return "build_storm_rod"
	if (sign_text.contains("arrow") or sign_text.contains("bow") or sign_text.contains("tower") or sign_text.contains("mountain")) and legal_ids.has("build_tower"):
		return "build_tower"
	if legal_ids.has("use_cover"):
		return "use_cover"
	if legal_ids.has("flee"):
		return "flee"
	return _first_agent_action(payload)


func _validated_fallback(kind: String, payload: Dictionary) -> Dictionary:
	return _validate_response(kind, _local_stub_response(kind, payload), payload)


func _local_stub_response(kind: String, payload: Dictionary) -> Dictionary:
	match kind:
		"agent_plan":
			return _local_stub_agent_plan(payload)
		"fast_prediction":
			return _local_stub_fast_prediction(payload)
		"scribe":
			return _local_stub_scribe(payload)
		"library_reflection":
			return _local_stub_library_reflection(payload)
		"background_job":
			return _local_stub_background_job(payload)
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


func _apply_flying_scribe_priority_hints(priority_hints: Dictionary, storm_priority: float = 0.55) -> void:
	priority_hints["build_storm_rod"] = maxf(float(priority_hints.get("build_storm_rod", 0.0)), storm_priority)
	priority_hints["build_tower"] = maxf(float(priority_hints.get("build_tower", 0.0)), 0.35)
	priority_hints["use_tower"] = maxf(float(priority_hints.get("use_tower", 0.0)), 0.25)


func _local_stub_scribe(payload: Dictionary) -> Dictionary:
	var recent_events: Array = payload.get("recent_events", [])
	var last_event_type := "none"
	for i in range(recent_events.size() - 1, -1, -1):
		if typeof(recent_events[i]) != TYPE_DICTIONARY:
			continue
		var candidate := str(recent_events[i].get("type", "unknown"))
		if not bool(INTERNAL_SCRIBE_EVENT_TYPES.get(candidate, false)):
			last_event_type = candidate
			break

	var ari: Dictionary = payload.get("ari", {})
	var current_action := str(ari.get("current_action", payload.get("current_action", "unknown")))
	var current_reason := str(ari.get("current_reason", payload.get("current_reason", "")))
	var fear := float(ari.get("fear", payload.get("fear", 0.0)))
	var phase := str(payload.get("phase", ari.get("phase", ""))).strip_edges()
	var facts: Array[String] = []
	var actions := []
	var dangers := []
	var world_changes: Array[String] = []
	var priority_hints := {}
	var resource_blockers: Array[String] = []
	var nearest_danger_type := ""
	var nearest_danger_distance := 0.0
	var recent_damage := 0.0
	var planned_action := ""
	var body_alignment := {}
	var evidence_ids: Array[String] = []
	var active_plan = payload.get("active_plan", {})
	if typeof(active_plan) == TYPE_DICTIONARY:
		var raw_next_action = active_plan.get("next_action", "")
		if typeof(raw_next_action) == TYPE_DICTIONARY:
			planned_action = str(raw_next_action.get("action_id", raw_next_action.get("id", ""))).strip_edges()
		else:
			planned_action = str(raw_next_action).strip_edges()
	var payload_alignment = payload.get("body_alignment", {})
	if typeof(payload_alignment) == TYPE_DICTIONARY:
		body_alignment = payload_alignment.duplicate(true)
	var snapshots: Array = payload.get("snapshots", payload.get("recent_snapshots", []))
	var snapshot_rows: Array = []
	for snapshot in snapshots:
		if typeof(snapshot) == TYPE_DICTIONARY:
			snapshot_rows.append(snapshot)
	if not snapshot_rows.is_empty():
		var latest: Dictionary = snapshot_rows[snapshot_rows.size() - 1]
		var latest_ari = latest.get("ari", {})
		if typeof(latest_ari) == TYPE_DICTIONARY:
			current_action = str(latest_ari.get("current_action", latest_ari.get("current_job", current_action)))
			current_reason = str(latest_ari.get("current_reason", current_reason))
			fear = float(latest_ari.get("fear", fear))
		var latest_plan = latest.get("plan", {})
		if typeof(latest_plan) == TYPE_DICTIONARY and planned_action == "":
			planned_action = str(latest_plan.get("next_action", "")).strip_edges()
		var latest_alignment = latest.get("body_alignment", {})
		if typeof(latest_alignment) == TYPE_DICTIONARY:
			body_alignment = latest_alignment.duplicate(true)
			if planned_action == "":
				planned_action = str(body_alignment.get("planned_action", "")).strip_edges()
		var evidence := _select_scribe_evidence_snapshot(snapshot_rows)
		var evidence_id := str(evidence.get("snapshot_id", "")).strip_edges()
		if evidence_id != "":
			evidence_ids.append(evidence_id)
		var evidence_world = evidence.get("world", {})
		if typeof(evidence_world) == TYPE_DICTIONARY:
			var nearest_danger = evidence_world.get("nearest_danger", {})
			if typeof(nearest_danger) == TYPE_DICTIONARY:
				var danger_type := str(nearest_danger.get("type", "")).strip_edges()
				var distance := maxf(0.0, float(nearest_danger.get("distance", 0.0)))
				if danger_type != "" and danger_type != "none":
					nearest_danger_type = danger_type
					nearest_danger_distance = distance
					dangers.append({"type": danger_type, "distance": distance, "severity": 0.7})
					facts.append("Nearest danger was %s at %.0f distance." % [danger_type, distance])
					if danger_type == "flying":
						_apply_flying_scribe_priority_hints(priority_hints, 0.45)
			var enemies = evidence_world.get("enemies", {})
			if typeof(enemies) == TYPE_DICTIONARY:
				var enemy_count := int(enemies.get("count", 0))
				if enemy_count > 0:
					facts.append("Ari saw %d enemy threat(s)." % enemy_count)
				var enemy_types = enemies.get("types", {})
				if typeof(enemy_types) == TYPE_DICTIONARY and int(enemy_types.get("flying", 0)) > 0:
					var flying_fact := "Flying enemies were present; ordinary walls may not solve them."
					if not facts.has(flying_fact):
						facts.append(flying_fact)
					_apply_flying_scribe_priority_hints(priority_hints, 0.55)
			var resources = evidence_world.get("resources", {})
			if typeof(resources) == TYPE_DICTIONARY and float(resources.get("stone", 99.0)) <= 3.0:
				resource_blockers.append("low_stone")
			recent_damage = maxf(recent_damage, float(evidence_world.get("recent_damage", 0.0)))
			world_changes = _string_array(evidence_world.get("notable_changes", []), 6, 80)
	_preserve_recent_flying_scribe_evidence(snapshot_rows, facts, world_changes, priority_hints, evidence_ids)
	var plan_relation := _scribe_plan_relation(current_action, current_reason, planned_action)
	var alignment_relation := str(body_alignment.get("relation", "")).strip_edges()
	var alignment_reason := str(body_alignment.get("reason", "")).strip_edges()
	if alignment_relation == "accepted":
		plan_relation = "aligned"
	elif alignment_relation == "prerequisite_progress" or alignment_relation == "safety_substitution":
		plan_relation = "support"
	elif alignment_relation == "mismatch":
		plan_relation = "mismatch"
	var plan_body_mismatch := plan_relation == "mismatch"
	var plan_support := plan_relation == "support"
	current_reason = _sanitize_scribe_current_reason(current_reason, current_action)
	if current_action != "" and current_action != "unknown":
		actions.append({"action": current_action, "status": "in_progress", "reason": current_reason})
		facts.push_front("Ari was %s." % _scribe_action_phrase(current_action))
	if plan_body_mismatch:
		actions.append({"action": planned_action, "status": "planned", "reason": "Ari's active plan expected this action."})
		facts.append("Ari's body action did not match the active plan: planned %s." % _humanize_key(planned_action))
	elif plan_support:
		var support_reason := alignment_reason if alignment_reason != "" else "Ari's current action prepared or protected this plan."
		actions.append({"action": planned_action, "status": "supported", "reason": support_reason})
		facts.append("Ari's body action supported the active plan: planned %s." % _humanize_key(planned_action))
	if last_event_type != "none":
		facts.append("Recent event was %s." % _humanize_key(last_event_type))
	if world_changes.is_empty() and last_event_type != "none":
		world_changes.append(last_event_type)
	var tags: Array[String] = ["local_stub"]
	if nearest_danger_type != "":
		tags.append("danger:%s" % nearest_danger_type)
	if float(priority_hints.get("build_storm_rod", 0.0)) > 0.0 and not tags.has("danger:flying"):
		tags.append("danger:flying")
	if fear > 70.0:
		tags.append("fear_high")
	if phase == "dusk" or phase == "night":
		tags.append(phase)
	if plan_body_mismatch:
		tags.append("plan_body_mismatch")
		if not world_changes.has("plan_body_mismatch"):
			world_changes.append("plan_body_mismatch")
	elif plan_support:
		tags.append("plan_support")
		if not world_changes.has("plan_support"):
			world_changes.append("plan_support")
	if alignment_relation == "prerequisite_progress" and not world_changes.has("prerequisite_progress"):
		world_changes.append("prerequisite_progress")
	elif alignment_relation == "safety_substitution" and not world_changes.has("safety_substitution"):
		world_changes.append("safety_substitution")
	elif alignment_relation == "blocked" and not world_changes.has("plan_blocked"):
		world_changes.append("plan_blocked")
	var plan_alignment := "mismatch" if plan_body_mismatch else "supporting" if plan_support else "aligned" if planned_action != "" else "unknown"
	var immediate_risk := _scribe_immediate_risk(nearest_danger_type, nearest_danger_distance, recent_damage, plan_alignment)
	var risk_reason := _scribe_risk_reason(nearest_danger_type, nearest_danger_distance, recent_damage, plan_alignment)
	var mistake_candidates: Array[String] = []
	var opportunity_candidates: Array[String] = []
	var lesson_candidates: Array[String] = []
	if plan_body_mismatch:
		mistake_candidates.append("body action %s diverged from planned %s" % [_normalize_scribe_action_key(current_action), _normalize_scribe_action_key(planned_action)])
		lesson_candidates.append("compare Ari's body action with the active plan before trusting the moment")
	if nearest_danger_type == "flying" or float(priority_hints.get("build_storm_rod", 0.0)) > 0.0:
		opportunity_candidates.append("build storm rod before ordinary wall work")
		lesson_candidates.append("when wings appear, answer the sky first")
	elif plan_support and planned_action != "":
		opportunity_candidates.append("continue support toward %s" % _normalize_scribe_action_key(planned_action))
	elif nearest_danger_type != "":
		opportunity_candidates.append("respond to nearest danger before routine chores")
	var note_parts: Array[String] = ["Ari was %s" % _scribe_action_phrase(current_action if current_action != "" else "acting")]
	if current_reason.strip_edges() != "":
		note_parts.append("because %s" % current_reason.strip_edges())
	if nearest_danger_type != "":
		note_parts.append("nearest danger was %s at %.0f" % [_humanize_key(nearest_danger_type), nearest_danger_distance])
	if plan_body_mismatch:
		note_parts.append("while plan expected %s" % _humanize_key(planned_action))
	elif plan_support:
		note_parts.append("supporting plan %s" % _humanize_key(planned_action))
	elif planned_action != "":
		note_parts.append("plan was %s" % _humanize_key(planned_action))
	if last_event_type != "none":
		note_parts.append("recent event was %s" % _humanize_key(last_event_type))

	return {
		"schema": SCRIBE_NOTE_SCHEMA,
		"t_start": float(payload.get("t_start", 0.0)),
		"t_end": float(payload.get("t_end", 0.0)),
		"note": _limit_text("; ".join(note_parts) + ".", 300),
		"tags": tags,
		"facts": facts,
		"actions": actions,
		"dangers": dangers,
		"world_changes": world_changes,
		"priority_hints": priority_hints,
		"plan_alignment": plan_alignment,
		"immediate_risk": immediate_risk,
		"risk_reason": risk_reason,
		"resource_blockers": resource_blockers,
		"mistake_candidates": mistake_candidates,
		"opportunity_candidates": opportunity_candidates,
		"lesson_candidates": lesson_candidates,
		"confidence": 0.25,
		"salience": 0.45 if last_event_type != "none" else 0.3,
		"source": "local_fallback",
		"failure_reason": "local_fallback",
		"origin": "deterministic_scribe",
		"evidence_ids": evidence_ids,
	}


func _sanitize_scribe_current_reason(reason: String, current_action: String) -> String:
	var text := reason.strip_edges()
	if not _scribe_reason_overstates_sign_hiding(text):
		return text
	var categories := _scribe_action_categories(_normalize_scribe_action_key(current_action))
	if categories.has("combat"):
		return "Ari chose direct fighting under danger"
	if categories.has("cover"):
		return "Ari chose cover under danger"
	return "Ari chose this action under pressure"


func _scribe_immediate_risk(danger_type: String, distance: float, recent_damage: float, plan_alignment: String) -> String:
	if recent_damage >= 40.0:
		return "lethal"
	if danger_type == "flying":
		return "high"
	if danger_type != "":
		if distance <= 32.0 or recent_damage >= 20.0:
			return "high"
		if distance <= 150.0 or plan_alignment == "mismatch":
			return "medium"
		return "low"
	if plan_alignment == "mismatch":
		return "medium"
	return "none"


func _scribe_risk_reason(danger_type: String, distance: float, recent_damage: float, plan_alignment: String) -> String:
	if danger_type == "flying":
		return "Flying enemies can bypass ordinary wall safety."
	if danger_type != "":
		return "Nearest danger was %s at %.0f distance." % [_humanize_key(danger_type), distance]
	if recent_damage > 0.0:
		return "Ari recently took %.0f damage." % recent_damage
	if plan_alignment == "mismatch":
		return "Ari's body action diverged from the active plan."
	return ""


func _scribe_action_phrase(action_id: String) -> String:
	var action := _normalize_scribe_action_key(action_id)
	var phrases := {
		"acting": "acting",
		"build_storm_rod": "building storm rod",
		"build_tower": "building tower",
		"fight_head_on": "fighting head on",
		"hide_until_dawn": "hiding until dawn",
		"mine_ore": "mining ore",
		"mine_stone": "mining stone",
		"repair_structure": "repairing structure",
		"stall_until_dawn": "stalling until dawn",
		"use_cover": "using cover",
		"use_tower": "using tower perch",
	}
	if phrases.has(action):
		return str(phrases[action])
	if action.begins_with("moving_to_"):
		return "moving to %s" % _humanize_key(action.substr("moving_to_".length()))
	if action.begins_with("build_"):
		return "building %s" % _humanize_key(action.substr("build_".length()))
	if action.begins_with("use_"):
		return "using %s" % _humanize_key(action.substr("use_".length()))
	if action.begins_with("train_"):
		return "training %s" % _humanize_key(action.substr("train_".length()))
	return _humanize_key(action_id)


func _scribe_reason_overstates_sign_hiding(reason: String) -> bool:
	var text := reason.strip_edges().to_lower().replace("-", " ")
	for pattern in [
		"sign rejected hiding",
		"sign rejects hiding",
		"sign says not to hide",
		"sign said not to hide",
		"sign told ari not to hide",
		"do not hide",
		"don't hide",
	]:
		if text.contains(pattern):
			return true
	return false


func _select_scribe_evidence_snapshot(snapshots: Array) -> Dictionary:
	var best: Dictionary = snapshots[snapshots.size() - 1] if not snapshots.is_empty() and typeof(snapshots[snapshots.size() - 1]) == TYPE_DICTIONARY else {}
	var best_score := -1.0
	for index in range(snapshots.size()):
		if typeof(snapshots[index]) != TYPE_DICTIONARY:
			continue
		var snapshot: Dictionary = snapshots[index]
		var score := float(snapshot.get("salience", 0.0)) + float(index) * 0.001
		var world = snapshot.get("world", {})
		if typeof(world) == TYPE_DICTIONARY:
			var nearest_danger = world.get("nearest_danger", {})
			if typeof(nearest_danger) == TYPE_DICTIONARY:
				var danger_type := str(nearest_danger.get("type", "")).strip_edges()
				if danger_type != "" and danger_type != "none":
					score += 0.4
					if danger_type == "flying":
						score += 1.2
			var enemies = world.get("enemies", {})
			if typeof(enemies) == TYPE_DICTIONARY:
				var enemy_types = enemies.get("types", {})
				if typeof(enemy_types) == TYPE_DICTIONARY and int(enemy_types.get("flying", 0)) > 0:
					score += 1.2
			var notable_changes = world.get("notable_changes", [])
			if typeof(notable_changes) == TYPE_ARRAY and not notable_changes.is_empty():
				score += 0.2
				for change in notable_changes:
					var change_text := str(change).to_lower()
					if change_text.contains("flying") or change_text.contains("wing"):
						score += 0.8
						break
		if score > best_score:
			best_score = score
			best = snapshot
	return best


func _preserve_recent_flying_scribe_evidence(snapshots: Array, facts: Array[String], world_changes: Array[String], priority_hints: Dictionary, evidence_ids: Array[String]) -> bool:
	var saw_flying := false
	for snapshot in snapshots:
		if typeof(snapshot) != TYPE_DICTIONARY:
			continue
		var snapshot_dict: Dictionary = snapshot
		if not _snapshot_has_flying_scribe_evidence(snapshot_dict):
			continue
		saw_flying = true
		var snapshot_id := str(snapshot_dict.get("snapshot_id", "")).strip_edges()
		if snapshot_id != "" and not evidence_ids.has(snapshot_id):
			evidence_ids.append(snapshot_id)
		var world = snapshot_dict.get("world", {})
		if typeof(world) == TYPE_DICTIONARY:
			for change in _string_array(world.get("notable_changes", []), 6, 80):
				var change_text := str(change)
				var lower := change_text.to_lower()
				if world_changes.size() >= 6:
					break
				if not world_changes.has(change_text) and (lower.contains("flying") or lower.contains("wing") or change_text == "first_flying_enemy_seen"):
					world_changes.append(change_text)
	if not saw_flying:
		return false
	var flying_fact := "Flying enemies were present; ordinary walls may not solve them."
	if not facts.has(flying_fact):
		facts.append(flying_fact)
	_apply_flying_scribe_priority_hints(priority_hints, 0.55)
	return true


func _snapshot_has_flying_scribe_evidence(snapshot: Dictionary) -> bool:
	var world = snapshot.get("world", {})
	if typeof(world) != TYPE_DICTIONARY:
		return false
	var nearest_danger = world.get("nearest_danger", {})
	if typeof(nearest_danger) == TYPE_DICTIONARY and str(nearest_danger.get("type", "")).strip_edges().to_lower() == "flying":
		return true
	var enemies = world.get("enemies", {})
	if typeof(enemies) == TYPE_DICTIONARY:
		var enemy_types = enemies.get("types", {})
		if typeof(enemy_types) == TYPE_DICTIONARY and int(enemy_types.get("flying", 0)) > 0:
			return true
	var notable_changes = world.get("notable_changes", [])
	if typeof(notable_changes) == TYPE_ARRAY:
		for change in notable_changes:
			var lower := str(change).to_lower()
			if lower.contains("flying") or lower.contains("wing"):
				return true
	return false


func _scribe_plan_relation(current_action: String, current_reason: String, planned_action: String) -> String:
	if planned_action == "" or _scribe_actions_aligned(current_action, planned_action):
		return "aligned"
	if _scribe_action_supports_plan(current_action, current_reason, planned_action):
		return "support"
	return "mismatch"


func _scribe_actions_aligned(current_action: String, planned_action: String) -> bool:
	var current := _normalize_scribe_action_key(current_action)
	var planned := _normalize_scribe_action_key(planned_action)
	if current == "" or planned == "" or ["unknown", "idle", "acting", "waiting_near_defenses"].has(current):
		return true
	if current == planned or current.contains(planned) or planned.contains(current):
		return true
	if current == "moving_to_build_site" and (planned.begins_with("build_") or planned.begins_with("place_")):
		return true
	if ["moving_to_mine", "mining", "mining_ore"].has(current) and planned.begins_with("mine_"):
		return true
	var current_categories := _scribe_action_categories(current)
	var planned_categories := _scribe_action_categories(planned)
	for category in current_categories:
		if planned_categories.has(category):
			return true
	return current_categories.is_empty() or planned_categories.is_empty()


func _scribe_action_supports_plan(current_action: String, current_reason: String, planned_action: String) -> bool:
	var current := _normalize_scribe_action_key(current_action)
	var planned := _normalize_scribe_action_key(planned_action)
	var reason := _normalize_scribe_action_key(current_reason)
	if current == "" or planned == "":
		return false
	var current_categories := _scribe_action_categories(current)
	var planned_categories := _scribe_action_categories(planned)
	if current_categories.has("repair") and (planned.begins_with("use_") or _categories_overlap(planned_categories, ["tower", "storm", "cover", "aura", "thorn", "lantern", "decoy"])):
		return true
	if current_categories.has("mine") and (planned.begins_with("build_") or planned.begins_with("place_") or ["smith_sword", "repair_structure"].has(planned) or _categories_overlap(planned_categories, ["tower", "storm", "cover", "aura", "thorn", "lantern", "decoy"])):
		return true
	if current_categories.has("rest") and reason.contains("recover") and _categories_overlap(planned_categories, ["tower", "storm", "combat", "cover"]):
		return true
	if current_categories.has("food") and _categories_overlap(planned_categories, ["combat", "tower", "storm", "cover"]):
		return true
	if _categories_overlap(current_categories, ["cover", "thorn", "lantern", "decoy"]) \
			and _categories_overlap(planned_categories, ["tower", "storm", "cover", "aura", "thorn", "lantern", "decoy"]) \
			and (reason.contains("night_is_quiet") or reason.contains("before") or reason.contains("hold") or reason.contains("stage") or reason.contains("safe")):
		return true
	return false


func _categories_overlap(categories: Array[String], candidates: Array[String]) -> bool:
	for category in categories:
		if candidates.has(category):
			return true
	return false


func _normalize_scribe_action_key(value: String) -> String:
	return value.strip_edges().to_lower().replace("-", "_").replace(" ", "_")


func _scribe_action_categories(action_id: String) -> Array[String]:
	var categories: Array[String] = []
	if action_id.contains("tower") or action_id.contains("bow") or action_id.contains("ranged"):
		categories.append("tower")
	if action_id.contains("aura") or action_id.contains("lure") or action_id.contains("light"):
		categories.append("aura")
	if action_id.contains("storm") or action_id.contains("anti_air"):
		categories.append("storm")
	if action_id.contains("wall") or action_id.contains("cover") or action_id.contains("hide") or action_id.contains("stall") or action_id.contains("survive"):
		categories.append("cover")
	if action_id.contains("repair"):
		categories.append("repair")
	if action_id.contains("mine") or action_id.contains("mining"):
		categories.append("mine")
	if action_id.contains("farm") or action_id.contains("food"):
		categories.append("food")
	if action_id.contains("rest") or action_id.contains("bed") or action_id.contains("sleep"):
		categories.append("rest")
	if action_id.contains("sword") or action_id.contains("combat") or action_id.contains("fight") or action_id.contains("weapon"):
		categories.append("combat")
	if action_id.contains("thorn"):
		categories.append("thorn")
	if action_id.contains("lantern"):
		categories.append("lantern")
	if action_id.contains("decoy"):
		categories.append("decoy")
	return categories


func _local_stub_library_reflection(payload: Dictionary) -> Dictionary:
	var mentions_flying := _payload_mentions_any_text(payload, ["flying", "wings", "winged"])
	if not mentions_flying and _payload_mentions_text(payload, "plan_support") and (_payload_mentions_text(payload, "repair_structure") or _payload_mentions_text(payload, "use_tower")):
		return {
			"schema": "ari.night_reflection.v1",
			"title": "Ari's rough local reflection",
			"markdown": "# Ari's rough local reflection\n\nAri remembers a plan_support moment: repair_structure kept the use_tower plan alive instead of contradicting it.",
			"hypothesis": "Repairing a damaged tower can support the ranged plan instead of delaying it.",
			"what_changed": ["tower_damaged", "ranged_hits_succeeded"],
			"worked": ["repair_structure supported use_tower"],
			"went_wrong": ["damaged tower support reduced the ranged plan's safety"],
			"misunderstood": [],
			"lesson": "When the tower plan is working but damaged, repair_structure before continuing use_tower.",
			"tags": ["local_fallback", "plan_support", "structure:tower"],
			"priority_hints": {
				"use_tower": 0.45,
				"repair_structure": 0.35,
				"build_tower": 0.2,
			},
			"priority_bias": {
				"use_tower": 0.28,
				"repair_structure": 0.24,
				"build_tower": 0.12,
			},
			"belief_updates": [{
				"key": "repair_can_support_ranged_plan",
				"delta": 0.2,
				"reason": "Structured notes showed repair_structure supporting use_tower.",
			}],
			"doctrines": [{
				"id": "local_tower_repair_supports_ranged_plan",
				"summary": "If the ranged tower plan is active and the tower is damaged, repair it before relying on it.",
				"when": {"min_day": 1},
				"bias": {
					"repair_structure": 0.24,
					"use_tower": 0.22,
					"build_tower": 0.1,
				},
				"plan": [
					{
						"affordance_id": "repair_structure",
						"priority": 0.62,
						"reason": "Patch the damaged tower so the ranged plan stays safe.",
					},
					{
						"affordance_id": "use_tower",
						"priority": 0.52,
						"reason": "Use the perch after repair restores the ranged advantage.",
					},
				],
				"confidence": 0.42,
			}],
			"confidence": 0.35,
			"thought": "Repair was not hesitation; it kept the arrow plan alive.",
			"source": "local_fallback",
			"failure_reason": "local_fallback",
		}
	if not mentions_flying and _payload_mentions_text(payload, "plan_body_mismatch") and _payload_mentions_text(payload, "fight_head_on"):
		return {
			"schema": "ari.night_reflection.v1",
			"title": "Ari's rough local reflection",
			"markdown": "# Ari's rough local reflection\n\nAri remembers a plan_body_mismatch: his body chose fight_head_on while the safer plan expected hide_until_dawn.",
			"hypothesis": "When direct fighting causes a mismatch with survival, cover should come before more contact.",
			"what_changed": ["near_death_warning", "ari_melee_hit"],
			"worked": [],
			"went_wrong": ["fight_head_on contradicted hide_until_dawn"],
			"misunderstood": ["Ari treated direct fighting as safe even when the survival plan disagreed"],
			"lesson": "If fight_head_on creates a plan_body_mismatch under danger, use_cover or flee before taking more hits.",
			"tags": ["local_fallback", "plan_body_mismatch", "danger:brute"],
			"priority_hints": {
				"use_cover": 0.5,
				"flee": 0.25,
				"hide_until_dawn": 0.2,
			},
			"priority_bias": {
				"use_cover": 0.34,
				"flee": 0.18,
				"fight_head_on": -0.18,
			},
			"belief_updates": [{
				"key": "open_melee_needs_cover_when_hurt",
				"delta": 0.2,
				"reason": "Structured notes showed fight_head_on diverging from hide_until_dawn.",
			}],
			"doctrines": [{
				"id": "local_overcommit_requires_cover",
				"summary": "When direct combat causes near-death or plan mismatch, Ari should use cover before more contact.",
				"when": {"max_hp_ratio": 0.65},
				"bias": {
					"use_cover": 0.34,
					"flee": 0.16,
					"fight_head_on": -0.18,
				},
				"plan": [
					{
						"affordance_id": "use_cover",
						"priority": 0.68,
						"reason": "Break direct contact before continuing a risky combat plan.",
					},
					{
						"affordance_id": "flee",
						"priority": 0.42,
						"reason": "Create distance if cover is not immediately safe.",
					},
				],
				"confidence": 0.4,
			}],
			"confidence": 0.35,
			"thought": "A brave body still needs a place to stop bleeding.",
			"source": "local_fallback",
			"failure_reason": "local_fallback",
		}
	if mentions_flying:
		return {
			"schema": "ari.night_reflection.v1",
			"title": "Ari's rough local reflection",
			"markdown": "# Ari's rough local reflection\n\nAri remembers flying danger. Ordinary walls were not enough by themselves, so the local anti_air_defense lesson is to answer the sky before stacking more wall.",
			"hypothesis": "Flying enemies need a sky answer before ordinary wall stacking.",
			"plan": {
				"primary": "build_storm_rod",
				"secondary": "use_tower",
				"avoid": "wall_only_thinking",
			},
			"priority_hints": {
				"anti_air_defense": 0.65,
				"build_storm_rod": 0.55,
				"build_tower": 0.35,
				"use_tower": 0.25,
			},
			"priority_bias": {
				"anti_air_defense": 0.35,
				"build_storm_rod": 0.45,
				"build_tower": 0.22,
				"use_tower": 0.18,
				"build_wall": -0.1,
			},
			"doctrines": [{
				"id": "local_flying_requires_sky_answer",
				"summary": "When flying enemies appear, Ari should answer the sky before stacking ordinary walls.",
				"when": {"enemy_type_present": "flying"},
				"bias": {
					"build_storm_rod": 0.45,
					"build_tower": 0.22,
					"use_tower": 0.18,
					"build_wall": -0.1,
				},
				"plan": [
					{
						"affordance_id": "build_storm_rod",
						"priority": 0.75,
						"reason": "Flying danger needs a sky defense.",
					},
					{
						"affordance_id": "build_tower",
						"priority": 0.55,
						"reason": "After the storm answer, ranged support keeps Ari away from wings.",
					},
					{
						"affordance_id": "use_tower",
						"priority": 0.45,
						"reason": "Use the ranged perch once it exists.",
					},
				],
				"confidence": 0.45,
			}],
			"confidence": 0.35,
			"thought": "Wings need an answer above the wall.",
			"source": "local_fallback",
			"failure_reason": "local_fallback",
		}
	return {
		"schema": "ari.night_reflection.v1",
		"title": "Ari's rough local reflection",
		"markdown": "# Ari's rough local reflection\n\nI remember fragments of what happened. I do not have the deeper mind yet, but I can still learn that preparation matters.",
		"hypothesis": "Preparation before night improves survival.",
		"plan": {
			"primary": "prepare",
			"secondary": "stay_safe",
			"avoid": "panic",
		},
		"priority_hints": {
			"prepare": 0.2,
			"rest": 0.05,
		},
		"priority_bias": {
			"prepare": 0.2,
			"rest": 0.05,
		},
		"confidence": 0.35,
		"thought": "I should prepare before the night gets close.",
		"source": "local_fallback",
		"failure_reason": "local_fallback",
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


func _local_stub_background_job(payload: Dictionary) -> Dictionary:
	var nested_payload = payload.get("payload", {})
	var strategy_packet := {}
	if typeof(nested_payload) == TYPE_DICTIONARY and typeof(nested_payload.get("strategy_packet", {})) == TYPE_DICTIONARY:
		strategy_packet = nested_payload.get("strategy_packet", {})
	return {
		"schema": "ari.background_result.v1",
		"job_id": str(payload.get("job_id", "local_background_job")),
		"kind": str(payload.get("kind", "strategy_candidate")),
		"context_hash": str(payload.get("context_hash", "")),
		"status": "fallback",
		"notes": ["Background AI fallback kept deterministic strategy evidence available."],
		"priority_hints": strategy_packet.get("priority_hints", {}) if typeof(strategy_packet) == TYPE_DICTIONARY else {},
		"strategy_packet": strategy_packet,
		"confidence": 0.25,
		"source": "local_fallback",
		"failure_reason": "local_fallback",
	}


func _local_stub_fast_prediction(payload: Dictionary) -> Dictionary:
	var legal_ids := _prediction_legal_ids(payload)
	var risk_level := _prediction_risk_level_from_payload(payload)
	var priority_hints := _known_priority_bias(payload.get("strategy_packet", {}).get("priority_hints", {}) if typeof(payload.get("strategy_packet", {})) == TYPE_DICTIONARY else {})
	var action_id := _prediction_fallback_action(payload, legal_ids, priority_hints)
	if action_id != "":
		priority_hints[action_id] = maxf(float(priority_hints.get(action_id, 0.0)), 0.65 if risk_level == "high" or risk_level == "lethal" else 0.45)
	var reason := _prediction_reason(payload, action_id, risk_level)
	return {
		"schema": "ari.prediction.v1",
		"context_hash": str(payload.get("context_hash", "")),
		"risk_level": risk_level,
		"prediction": reason,
		"next_action_bias": {
			"action_id": action_id,
			"urgency": _prediction_urgency(risk_level),
			"reason": reason,
		},
		"priority_hints": priority_hints,
		"avoid": _prediction_avoid_list(payload),
		"confidence": 0.35,
		"stale_after_seconds": 5.0,
		"source": "local_fallback",
		"failure_reason": "local_fallback",
	}


func _validate_response(kind: String, data: Dictionary, _payload: Dictionary = {}) -> Dictionary:
	match kind:
		"agent_plan":
			return _validate_agent_plan(data, _payload, true, "local_stub")
		"fast_prediction":
			return _validate_fast_prediction(data, _payload)
		"scribe":
			return _validate_scribe_note(data)
		"library_reflection":
			return _validate_library_reflection(data)
		"background_job":
			return _validate_background_result(data, _payload)
		"sleep_plan":
			return _validate_sleep_plan(data)
		"life_summary":
			return _validate_life_summary(data)
		"wisdom_synthesis":
			return _validate_wisdom_synthesis(data)
	return {}


func _validate_scribe_note(data: Dictionary) -> Dictionary:
	return {
		"schema": SCRIBE_NOTE_SCHEMA,
		"note_id": _limit_text(str(data.get("note_id", data.get("id", ""))), 120),
		"t_start": float(data.get("t_start", 0.0)),
		"t_end": float(data.get("t_end", 0.0)),
		"note": _limit_text(str(data.get("note", "Ari noticed recent events but has no remote scribe yet.")), 300),
		"tags": _string_array(data.get("tags", ["local_stub"]), 8, 40),
		"facts": _string_array(data.get("facts", []), 8, 120),
		"actions": _scribe_action_array(data.get("actions", []), 4),
		"dangers": _scribe_danger_array(data.get("dangers", []), 4),
		"world_changes": _string_array(data.get("world_changes", data.get("notable_changes", [])), 6, 80),
		"priority_hints": _priority_bias(data.get("priority_hints", {})),
		"plan_alignment": _scribe_plan_alignment(data.get("plan_alignment", "unknown")),
		"immediate_risk": _scribe_risk_level(data.get("immediate_risk", "none")),
		"risk_reason": _limit_text(str(data.get("risk_reason", "")), 180),
		"resource_blockers": _string_array(data.get("resource_blockers", []), 5, 80),
		"mistake_candidates": _string_array(data.get("mistake_candidates", []), 5, 140),
		"opportunity_candidates": _string_array(data.get("opportunity_candidates", []), 5, 140),
		"lesson_candidates": _string_array(data.get("lesson_candidates", []), 5, 140),
		"confidence": clampf(float(data.get("confidence", 0.25)), 0.0, 1.0),
		"salience": clampf(float(data.get("salience", 0.3)), 0.0, 1.0),
		"source": str(data.get("source", "")),
		"failure_reason": str(data.get("failure_reason", "")),
		"origin": _limit_text(str(data.get("origin", "")), 80),
		"evidence_ids": _string_array(data.get("evidence_ids", data.get("evidence_snapshot_ids", [])), 12, 120),
	}


func _validate_background_result(data: Dictionary, payload: Dictionary = {}) -> Dictionary:
	var status := str(data.get("status", "ok")).strip_edges().to_lower()
	if not ["ok", "fallback", "stale"].has(status):
		status = "fallback"
	var strategy_packet := _validate_strategy_packet(data.get("strategy_packet", _background_payload_strategy(payload)))
	return {
		"schema": "ari.background_result.v1",
		"job_id": _limit_text(str(data.get("job_id", payload.get("job_id", "background_job"))), 120),
		"kind": _background_job_kind(data.get("kind", payload.get("kind", "strategy_candidate"))),
		"context_hash": _limit_text(str(data.get("context_hash", payload.get("context_hash", ""))), 160),
		"status": status,
		"notes": _string_array(data.get("notes", []), 6, 180),
		"priority_hints": _known_priority_bias(data.get("priority_hints", strategy_packet.get("priority_hints", {}))),
		"strategy_packet": strategy_packet,
		"confidence": clampf(float(data.get("confidence", strategy_packet.get("confidence", 0.35))), 0.0, 1.0),
		"source": _limit_text(str(data.get("source", "")), 64),
		"failure_reason": _limit_text(str(data.get("failure_reason", "")), 64),
	}


func _validate_fast_prediction(data: Dictionary, payload: Dictionary = {}) -> Dictionary:
	var fallback := _local_stub_fast_prediction(payload)
	var legal_ids := _prediction_legal_ids(payload)
	var action_bias := _prediction_action_bias(data.get("next_action_bias", {}), legal_ids)
	if action_bias.is_empty():
		action_bias = _prediction_action_bias(fallback.get("next_action_bias", {}), legal_ids)
	var priority_hints := _known_priority_bias(data.get("priority_hints", fallback.get("priority_hints", {})))
	return {
		"schema": "ari.prediction.v1",
		"context_hash": _limit_text(str(data.get("context_hash", payload.get("context_hash", ""))), 160),
		"risk_level": _prediction_risk_level(data.get("risk_level", fallback.get("risk_level", "none"))),
		"prediction": _limit_text(str(data.get("prediction", fallback.get("prediction", "Ari should keep the safest known action."))), 220),
		"next_action_bias": action_bias,
		"priority_hints": priority_hints,
		"avoid": _string_array(data.get("avoid", fallback.get("avoid", [])), 5, 120),
		"confidence": clampf(float(data.get("confidence", fallback.get("confidence", 0.35))), 0.0, 1.0),
		"stale_after_seconds": clampf(float(data.get("stale_after_seconds", 5.0)), 1.0, 5.0),
		"source": _limit_text(str(data.get("source", "")), 64),
		"failure_reason": _limit_text(str(data.get("failure_reason", "")), 64),
	}


func _prediction_legal_ids(payload: Dictionary) -> Dictionary:
	var result := {}
	var legal_actions = payload.get("legal_actions", [])
	if typeof(legal_actions) != TYPE_ARRAY:
		return result
	for item in legal_actions:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var action_id := str(item.get("id", item.get("action_id", ""))).strip_edges()
		if action_id != "" and bool(item.get("available", true)):
			result[action_id] = true
	return result


func _prediction_action_bias(value, legal_ids: Dictionary) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var action_id := str(value.get("action_id", value.get("id", ""))).strip_edges()
	if action_id == "" or (not legal_ids.is_empty() and not legal_ids.has(action_id)):
		return {}
	return {
		"action_id": action_id,
		"urgency": clampf(float(value.get("urgency", 0.5)), 0.0, 1.0),
		"reason": _limit_text(str(value.get("reason", "")), 140),
	}


func _prediction_risk_level(value) -> String:
	var text := str(value).strip_edges().to_lower().replace("-", "_").replace(" ", "_")
	if ["none", "low", "medium", "high", "lethal"].has(text):
		return text
	return "none"


func _prediction_risk_level_from_payload(payload: Dictionary) -> String:
	var max_severity := 0.0
	var risks = payload.get("risks", [])
	if typeof(risks) == TYPE_ARRAY:
		for risk in risks:
			if typeof(risk) == TYPE_DICTIONARY:
				max_severity = maxf(max_severity, clampf(float(risk.get("severity", 0.0)), 0.0, 1.0))
	if max_severity >= 0.9:
		return "high"
	if max_severity >= 0.65:
		return "medium"
	if max_severity > 0.0:
		return "low"
	return "none"


func _prediction_fallback_action(payload: Dictionary, legal_ids: Dictionary, priority_hints: Dictionary) -> String:
	var risk_types := {}
	for risk in payload.get("risks", []):
		if typeof(risk) == TYPE_DICTIONARY:
			risk_types[str(risk.get("type", "")).to_lower()] = true
	if risk_types.has("flying") and legal_ids.has("build_storm_rod"):
		return "build_storm_rod"
	var ari_state = payload.get("ari", {})
	if typeof(ari_state) == TYPE_DICTIONARY:
		var hp := float(ari_state.get("hp", 100.0))
		var max_hp := maxf(1.0, float(ari_state.get("max_hp", 100.0)))
		if hp / max_hp <= 0.35:
			for action_id in ["use_cover", "flee", "rest"]:
				if legal_ids.has(action_id):
					return action_id
	var keys: Array = priority_hints.keys()
	keys.sort_custom(func(a, b) -> bool:
		return float(priority_hints[a]) > float(priority_hints[b])
	)
	for key in keys:
		if legal_ids.has(str(key)):
			return str(key)
	var current_plan = payload.get("current_plan", {})
	if typeof(current_plan) == TYPE_DICTIONARY:
		var raw_next = current_plan.get("next_action", "")
		var next_id := str(raw_next.get("action_id", "") if typeof(raw_next) == TYPE_DICTIONARY else raw_next).strip_edges()
		if legal_ids.has(next_id):
			return next_id
	for action_id in ["use_cover", "flee", "mine_stone", "build_wall", "wait_or_idle"]:
		if legal_ids.has(action_id):
			return action_id
	return str(legal_ids.keys()[0]) if not legal_ids.is_empty() else "wait_or_idle"


func _prediction_reason(payload: Dictionary, action_id: String, risk_level: String) -> String:
	var risk_types := {}
	for risk in payload.get("risks", []):
		if typeof(risk) == TYPE_DICTIONARY:
			risk_types[str(risk.get("type", "")).to_lower()] = true
	if risk_types.has("flying") and action_id == "build_storm_rod":
		return "Flying danger is present, so Ari should answer the sky before ordinary walls."
	if ["high", "lethal"].has(risk_level) and ["use_cover", "flee"].has(action_id):
		return "Immediate danger is high, so Ari should create distance before slower work."
	if action_id == "mine_stone":
		return "Ari needs resources before the stronger defensive action is possible."
	return "Ari should bias toward %s for the next few seconds." % action_id.replace("_", " ")


func _prediction_urgency(risk_level: String) -> float:
	match risk_level:
		"lethal":
			return 1.0
		"high":
			return 0.85
		"medium":
			return 0.65
		"low":
			return 0.45
	return 0.3


func _prediction_avoid_list(payload: Dictionary) -> Array:
	var result := []
	var strategy = payload.get("strategy_packet", {})
	if typeof(strategy) == TYPE_DICTIONARY:
		for item in _string_array(strategy.get("avoid_repeating", []), 4, 120):
			result.append(item)
	var has_flying := false
	for risk in payload.get("risks", []):
		if typeof(risk) == TYPE_DICTIONARY and str(risk.get("type", "")).to_lower() == "flying":
			has_flying = true
	if has_flying and not result.has("ordinary walls before sky answer"):
		result.append("ordinary walls before sky answer")
	return result


func _background_payload_strategy(payload: Dictionary) -> Dictionary:
	var nested_payload = payload.get("payload", {})
	if typeof(nested_payload) == TYPE_DICTIONARY and typeof(nested_payload.get("strategy_packet", {})) == TYPE_DICTIONARY:
		return nested_payload.get("strategy_packet", {})
	return {}


func _background_job_kind(value) -> String:
	var text := str(value).strip_edges()
	if ["scribe_enrich", "summary_review", "reflection_draft", "strategy_candidate", "doctrine_review", "playtest_analysis"].has(text):
		return text
	return "strategy_candidate"


func _validate_strategy_packet(value) -> Dictionary:
	var data: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
	return {
		"schema": "ari.strategy_packet.v1",
		"day": max(0, int(data.get("day", 0))),
		"main_risks": _string_array(data.get("main_risks", []), 8, 80),
		"current_lessons": _string_array(data.get("current_lessons", []), 8, 140),
		"active_doctrines": _strategy_doctrine_array(data.get("active_doctrines", []), 5),
		"priority_hints": _known_priority_bias(data.get("priority_hints", {})),
		"avoid_repeating": _string_array(data.get("avoid_repeating", []), 8, 140),
		"try_next": _string_array(data.get("try_next", []), 8, 100),
		"evidence": _string_array(data.get("evidence", []), 14, 180),
		"confidence": clampf(float(data.get("confidence", 0.35)), 0.0, 1.0),
	}


func _strategy_doctrine_array(value, max_count: int) -> Array:
	var results := []
	if typeof(value) != TYPE_ARRAY:
		return results
	for item in value:
		if typeof(item) == TYPE_DICTIONARY:
			results.append({
				"id": _limit_text(str(item.get("id", "")), 120),
				"summary": _limit_text(str(item.get("summary", item.get("title", ""))), 180),
				"confidence": clampf(float(item.get("confidence", 0.35)), 0.0, 1.0),
			})
		else:
			results.append({
				"id": _limit_text(str(item), 120),
				"summary": _limit_text(str(item), 180),
				"confidence": 0.35,
			})
		if results.size() >= max_count:
			break
	return results


func _known_priority_bias(value) -> Dictionary:
	var result := {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for raw_key in value.keys():
		var key := str(raw_key)
		key = str(LEGACY_PRIORITY_HINTS.get(key, key))
		if not DEEP_PRIORITY_KEYS.has(key):
			continue
		result[key] = clampf(float(value[raw_key]), -1.0, 1.0)
	return result


func _scribe_plan_alignment(value) -> String:
	var text := str(value).strip_edges().to_lower().replace("-", "_").replace(" ", "_")
	if text == "support":
		text = "supporting"
	if ["aligned", "supporting", "mismatch", "unknown"].has(text):
		return text
	return "unknown"


func _scribe_risk_level(value) -> String:
	var text := str(value).strip_edges().to_lower().replace("-", "_").replace(" ", "_")
	if ["none", "low", "medium", "high", "lethal"].has(text):
		return text
	return "none"


func _validate_library_reflection(data: Dictionary) -> Dictionary:
	return {
		"schema": str(data.get("schema", "ari.night_reflection.v1")),
		"title": _limit_text(str(data.get("title", "Ari's rough local reflection")), 120),
		"markdown": _limit_text(str(data.get("markdown", "# Ari's rough local reflection\n\nPreparation before night improves survival.")), 2000),
		"markdown_text": _limit_text(str(data.get("markdown_text", data.get("markdown", "# Ari's rough local reflection\n\nPreparation before night improves survival."))), 2000),
		"hypothesis": _limit_text(str(data.get("hypothesis", "Preparation before night improves survival.")), 300),
		"plan": _string_dictionary(data.get("plan", {"primary": "prepare", "secondary": "stay_safe", "avoid": "panic"}), 12, 80),
		"priority_hints": _priority_bias(data.get("priority_hints", data.get("priority_bias", {"prepare": 0.2}))),
		"priority_bias": _priority_bias(data.get("priority_bias", {"prepare": 0.2})),
		"doctrines": _doctrines(data.get("doctrines", [])),
		"confidence": clampf(float(data.get("confidence", 0.35)), 0.0, 1.0),
		"thought": _limit_text(str(data.get("thought", "I should prepare before the night gets close.")), 300),
		"source": str(data.get("source", "")),
		"failure_reason": str(data.get("failure_reason", "")),
		"origin": _limit_text(str(data.get("origin", "")), 80),
		"reflection_id": _limit_text(str(data.get("reflection_id", "")), 120),
		"summary_id": _limit_text(str(data.get("summary_id", "")), 120),
		"evidence_ids": _string_array(data.get("evidence_ids", data.get("evidence_snapshot_ids", [])), 20, 120),
	}


func _validate_sleep_plan(data: Dictionary) -> Dictionary:
	return {
		"dominant_memory": _limit_text(str(data.get("dominant_memory", "Preparation before night improves survival.")), 500),
		"tomorrow_focus": _string_array(data.get("tomorrow_focus", ["prepare"]), 8, 50),
		"priority_bias": _priority_bias(data.get("priority_bias", {"prepare": 0.2})),
		"doctrines": _doctrines(data.get("doctrines", [])),
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


func _scribe_action_array(value, max_count: int) -> Array:
	var result := []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var action := _limit_text(str(item.get("action", item.get("action_id", item.get("id", "")))), 80)
		if action == "":
			continue
		result.append({
			"action": action,
			"status": _limit_text(str(item.get("status", item.get("outcome", "observed"))), 40),
			"reason": _limit_text(str(item.get("reason", "")), 160),
		})
		if result.size() >= max_count:
			break
	return result


func _scribe_danger_array(value, max_count: int) -> Array:
	var result := []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var danger_type := _limit_text(str(item.get("type", item.get("enemy_type", ""))), 60)
		if danger_type == "":
			continue
		result.append({
			"type": danger_type,
			"distance": maxf(0.0, float(item.get("distance", 0.0))),
			"severity": clampf(float(item.get("severity", item.get("salience", 0.0))), 0.0, 1.0),
		})
		if result.size() >= max_count:
			break
	return result


func _doctrines(value) -> Array:
	var doctrine_validator := AriDoctrine.new()
	return doctrine_validator.add_doctrines(value)


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


func _humanize_key(value) -> String:
	return _limit_text(str(value).replace("_", " ").strip_edges(), 80)


func _payload_mentions_text(value, needle: String) -> bool:
	var target := needle.to_lower()
	match typeof(value):
		TYPE_DICTIONARY:
			for key in value.keys():
				if _payload_mentions_text(key, target) or _payload_mentions_text(value[key], target):
					return true
		TYPE_ARRAY:
			for item in value:
				if _payload_mentions_text(item, target):
					return true
		_:
			return str(value).to_lower().contains(target)
	return false


func _payload_mentions_any_text(value, needles: Array) -> bool:
	for needle in needles:
		if _payload_mentions_text(value, str(needle)):
			return true
	return false


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


func _safe_endpoint_label(url: String) -> String:
	var clean_url := url.strip_edges()
	var query_index := clean_url.find("?")
	if query_index >= 0:
		clean_url = clean_url.substr(0, query_index)
	return clean_url


func _http_result_failure_reason(result: int) -> String:
	match result:
		HTTPRequest.RESULT_TIMEOUT:
			return "timeout"
		HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CANT_RESOLVE, HTTPRequest.RESULT_CONNECTION_ERROR, HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR, HTTPRequest.RESULT_NO_RESPONSE:
			return "offline"
		HTTPRequest.RESULT_REQUEST_FAILED:
			return "request_canceled"
	return "request_failed"


func _http_status_failure_reason(response_code: int) -> String:
	if response_code == 401 or response_code == 403:
		return "auth"
	return "http_%d" % response_code


func _compact_failure_reason(reason: String) -> String:
	var clean_reason := reason.strip_edges().to_lower()
	match clean_reason:
		"timeout", "parse", "auth", "offline", "request_canceled", "request_failed", "request_error", "missing_endpoint", "disabled", "invalid_action", "invalid_schema":
			return clean_reason
	if clean_reason.begins_with("http_"):
		return clean_reason
	if clean_reason == "invalid_json":
		return "parse"
	return "fallback"


func _call_callback_deferred(callback: Callable, result: Dictionary) -> void:
	_safe_call_callback(callback, result)


func _safe_call_callback(callback: Callable, result: Dictionary) -> void:
	if callback.is_valid():
		callback.call(result)
