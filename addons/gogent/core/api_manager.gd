@tool
class_name GoGentAPIManager
extends RefCounted

signal request_started
signal request_completed(success: bool, response: String, thinking: String)
signal stream_chunk(chunk: String, request_id: int)
signal stream_thinking_chunk(chunk: String, request_id: int)
signal stream_completed(success: bool, full_response: String, thinking: String, request_id: int)

var http_request: HTTPRequest
var stream_manager: GoGentStreamManager
var is_generating := false

# 请求频率限制
var _last_request_time: float = 0.0
var _request_count: int = 0
var _last_reset_time: float = 0.0
const RATE_LIMIT_WINDOW := 60.0  # 统计窗口（秒）
const MAX_REQUESTS_PER_WINDOW := 30  # 每窗口最大请求数

func _init() -> void:
	stream_manager = GoGentStreamManager.new()
	stream_manager.stream_chunk.connect(func(chunk: String, id: int): stream_chunk.emit(chunk, id))
	stream_manager.stream_thinking_chunk.connect(func(chunk: String, id: int): stream_thinking_chunk.emit(chunk, id))
	stream_manager.stream_completed.connect(func(text: String, thinking: String, id: int): stream_completed.emit(true, text, thinking, id))
	stream_manager.stream_error.connect(func(error: String, id: int): stream_completed.emit(false, error, "", id))
	_last_reset_time = Time.get_unix_time_from_system()

func send_chat_request(messages: Array[Dictionary], options: Dictionary = {}) -> void:
	# 频率限制检查
	if not _check_rate_limit():
		request_completed.emit(false, "请求过于频繁，请稍后再试（每秒最多 %d 次）。" % MAX_REQUESTS_PER_WINDOW, "")
		return
	var context := _build_request_context(messages, options, false)
	if context.is_empty():
		request_completed.emit(false, "No valid model is configured.", "")
		return
	var singleton = GoGentSingleton.get_instance()
	if http_request == null:
		http_request = HTTPRequest.new()
		if singleton.main_panel != null:
			singleton.main_panel.add_child(http_request)
		else:
			request_completed.emit(false, "GoGent panel is not available for HTTP requests.", "")
			return
		http_request.request_completed.connect(_on_request_completed)
	if singleton.config_manager != null:
		http_request.timeout = max(1, int(singleton.config_manager.get_setting("request_timeout", 120)))
	_apply_proxy(http_request)
	# 请求间隔延迟
	var delay_ms := int(singleton.config_manager.get_setting("api_request_delay_ms", 500)) if singleton.config_manager != null else 500
	if delay_ms > 0:
		OS.delay_msec(delay_ms)
	is_generating = true
	request_started.emit()
	var err := http_request.request(context["url"], context["headers"], HTTPClient.METHOD_POST, context["body"])
	if err != OK:
		is_generating = false
		request_completed.emit(false, "HTTP request failed to start: %s" % err, "")

func send_stream_chat_request(messages: Array[Dictionary], options: Dictionary = {}) -> int:
	# 频率限制检查
	if not _check_rate_limit():
		return -1
	var context := _build_request_context(messages, options, true)
	if context.is_empty():
		return -1
	if context.get("provider", "openai") == "anthropic":
		return -1
	var singleton = GoGentSingleton.get_instance()
	var delay_ms := int(singleton.config_manager.get_setting("api_request_delay_ms", 500)) if singleton.config_manager != null else 500
	if delay_ms > 0:
		OS.delay_msec(delay_ms)
	return stream_manager.send_stream_request(context)

func cancel_request() -> void:
	if http_request != null and is_generating:
		http_request.cancel_request()
	is_generating = false
	if stream_manager != null:
		stream_manager.cancel_all_streams()

func _build_request_context(messages: Array[Dictionary], options: Dictionary, stream: bool) -> Dictionary:
	var singleton = GoGentSingleton.get_instance()
	var manager = singleton.model_manager
	if manager == null:
		return {}
	var supplier = manager.get_current_supplier()
	var model = manager.get_current_model()
	if supplier == null or model == null:
		return {}
	var selected_model := str(options.get("model", model.model_name))
	var provider := str(supplier.provider)
	var request_options := _merge_request_options(options, model.max_tokens)
	var body_data := _build_provider_body(provider, messages, selected_model, int(request_options["max_tokens"]), float(request_options["temperature"]), stream)
	body_data["top_p"] = float(request_options["top_p"])
	if provider != "anthropic":
		body_data["presence_penalty"] = float(request_options["presence_penalty"])
		body_data["frequency_penalty"] = float(request_options["frequency_penalty"])
		if bool(request_options["json_mode"]):
			# DeepSeek 等供应商要求 prompt 中包含 "json" 字样才能使用 json_object 响应格式
			# 自动检查并确保 messages 中包含 json 关键词
			var has_json_keyword := false
			for msg in messages:
				var content := str(msg.get("content", ""))
				if content.to_lower().contains("json"):
					has_json_keyword = true
					break
			if not has_json_keyword and messages.size() > 0:
				var last := messages[messages.size() - 1]
				last["content"] = str(last.get("content", "")) + "\n\n请以 JSON 格式返回。"
			body_data["response_format"] = {"type": "json_object"}
	if provider != "anthropic" and bool(request_options["tools_enabled"]) and options.has("tools") and model.supports_tools:
		body_data["tools"] = options["tools"]
		body_data["tool_choice"] = options.get("tool_choice", "auto")
	if provider != "anthropic" and supplier.id == "openrouter" and bool(request_options["reasoning_enabled"]) and (model.supports_thinking or options.get("supports_thinking", false)):
		body_data["include_reasoning"] = true
	var headers := PackedStringArray([
		"Accept: text/event-stream" if stream else "Accept: application/json",
		"Content-Type: application/json"
	])
	if provider == "anthropic":
		headers.append("anthropic-version: 2023-06-01")
		if not supplier.api_key.strip_edges().is_empty():
			headers.append("x-api-key: %s" % supplier.api_key.strip_edges())
	elif not supplier.api_key.strip_edges().is_empty():
		headers.append("Authorization: Bearer %s" % supplier.api_key.strip_edges())
	return {
		"url": _chat_url(supplier.base_url, provider),
		"headers": headers,
		"body": JSON.stringify(body_data),
		"supplier": supplier.to_dict(),
		"provider": provider,
		"model": model.to_dict(),
		"request_options": request_options,
		"proxy": _proxy_settings()
	}

func _merge_request_options(options: Dictionary, model_max_tokens: int) -> Dictionary:
	var cfg = GoGentSingleton.get_instance().config_manager
	var temperature := float(options.get("temperature", cfg.get_setting("default_temperature", 0.7) if cfg else 0.7))
	var top_p := float(options.get("top_p", cfg.get_setting("default_top_p", 1.0) if cfg else 1.0))
	var max_tokens := int(options.get("max_tokens", cfg.get_setting("default_max_tokens", model_max_tokens) if cfg else model_max_tokens))
	var presence_penalty := float(options.get("presence_penalty", cfg.get_setting("default_presence_penalty", 0.0) if cfg else 0.0))
	var frequency_penalty := float(options.get("frequency_penalty", cfg.get_setting("default_frequency_penalty", 0.0) if cfg else 0.0))
	return {
		"temperature": clamp(temperature, 0.0, 2.0),
		"top_p": clamp(top_p, 0.0, 1.0),
		"max_tokens": clamp(max_tokens, 1, max(1, model_max_tokens)),
		"presence_penalty": clamp(presence_penalty, -2.0, 2.0),
		"frequency_penalty": clamp(frequency_penalty, -2.0, 2.0),
		"reasoning_enabled": bool(options.get("reasoning_enabled", cfg.get_setting("default_reasoning_enabled", true) if cfg else true)),
		"tools_enabled": bool(options.get("tools_enabled", cfg.get_setting("default_tools_enabled", true) if cfg else true)),
		"json_mode": bool(options.get("json_mode", cfg.get_setting("default_json_mode", false) if cfg else false))
	}

func _build_provider_body(provider: String, messages: Array[Dictionary], model_name: String, max_tokens: int, temperature: float, stream: bool) -> Dictionary:
	if provider == "anthropic":
		var system_parts: Array[String] = []
		var anthropic_messages: Array[Dictionary] = []
		for item in messages:
			var role := str(item.get("role", "user"))
			var content := str(item.get("content", ""))
			if role == "system":
				system_parts.append(content)
			else:
				anthropic_messages.append({"role": "assistant" if role == "assistant" else "user", "content": content})
		var body := {
			"model": model_name,
			"messages": anthropic_messages,
			"max_tokens": max_tokens,
			"temperature": temperature,
			"stream": stream
		}
		if not system_parts.is_empty():
			body["system"] = "\n\n".join(system_parts)
		return body
	return {
		"model": model_name,
		"messages": messages,
		"temperature": temperature,
		"max_tokens": max_tokens,
		"stream": stream
	}

func _chat_url(base_url: String, provider: String = "openai") -> String:
	var url := base_url.strip_edges()
	if url.is_empty():
		url = "https://api.anthropic.com" if provider == "anthropic" else "https://api.openai.com"
	if url.ends_with("/"):
		url = url.substr(0, url.length() - 1)
	if provider == "anthropic":
		if url.ends_with("/v1/messages"):
			return url
		if url.ends_with("/v1"):
			return url + "/messages"
		return url + "/v1/messages"
	if url.ends_with("/chat/completions"):
		return url
	if url.ends_with("/v1") or url.ends_with("/v3"):
		return url + "/chat/completions"
	return url + "/v1/chat/completions"

func _proxy_settings() -> Dictionary:
	var cfg = GoGentSingleton.get_instance().config_manager
	if cfg == null:
		return {}
	var host := str(cfg.get_setting("http_proxy_host", "")).strip_edges()
	var port := int(cfg.get_setting("http_proxy_port", 0))
	if host.is_empty() or port <= 0:
		return {}
	return {"host": host, "port": port}

func _apply_proxy(request: HTTPRequest) -> void:
	var proxy := _proxy_settings()
	if proxy.is_empty():
		return
	request.set_http_proxy(proxy["host"], proxy["port"])
	request.set_https_proxy(proxy["host"], proxy["port"])

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	is_generating = false
	var text := body.get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS:
		request_completed.emit(false, "HTTP request failed: result=%s code=%s body=%s" % [result, response_code, text], "")
		return
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		request_completed.emit(false, "Invalid JSON response: %s" % text.left(500), "")
		return
	if parsed.has("error"):
		var error = parsed["error"]
		var message := str(error.get("message", error)) if error is Dictionary else str(error)
		request_completed.emit(false, message, "")
		return
	if parsed.has("content") and parsed["content"] is Array:
		var content_parts: Array[String] = []
		for part in parsed["content"]:
			if part is Dictionary and part.get("type", "") == "text":
				content_parts.append(str(part.get("text", "")))
		request_completed.emit(true, "\n".join(content_parts), "")
		return
	var choices: Array = parsed.get("choices", [])
	if choices.is_empty():
		request_completed.emit(false, "Response did not contain choices.", "")
		return
	var message: Dictionary = choices[0].get("message", {})
	request_completed.emit(true, str(message.get("content", "")), str(message.get("reasoning_content", "")))

static func build_message(role: String, content: String) -> Dictionary:
	return {"role": role, "content": content}

# 检查请求频率限制
func _check_rate_limit() -> bool:
	var now := Time.get_unix_time_from_system()
	# 每 RATE_LIMIT_WINDOW 秒重置计数器
	if now - _last_reset_time >= RATE_LIMIT_WINDOW:
		_request_count = 0
		_last_reset_time = now
	# 检查是否超过限制
	if _request_count >= MAX_REQUESTS_PER_WINDOW:
		return false
	_request_count += 1
	return true
