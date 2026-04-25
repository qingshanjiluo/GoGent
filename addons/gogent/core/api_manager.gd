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

func _init() -> void:
	stream_manager = GoGentStreamManager.new()
	stream_manager.stream_chunk.connect(func(chunk: String, id: int): stream_chunk.emit(chunk, id))
	stream_manager.stream_thinking_chunk.connect(func(chunk: String, id: int): stream_thinking_chunk.emit(chunk, id))
	stream_manager.stream_completed.connect(func(text: String, thinking: String, id: int): stream_completed.emit(true, text, thinking, id))
	stream_manager.stream_error.connect(func(error: String, id: int): stream_completed.emit(false, error, "", id))

func send_chat_request(messages: Array[Dictionary], options: Dictionary = {}) -> void:
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
	_apply_proxy(http_request)
	is_generating = true
	request_started.emit()
	var err := http_request.request(context["url"], context["headers"], HTTPClient.METHOD_POST, context["body"])
	if err != OK:
		is_generating = false
		request_completed.emit(false, "HTTP request failed to start: %s" % err, "")

func send_stream_chat_request(messages: Array[Dictionary], options: Dictionary = {}) -> int:
	var context := _build_request_context(messages, options, true)
	if context.is_empty():
		return -1
	if context.get("provider", "openai") == "anthropic":
		return -1
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
	var body_data := _build_provider_body(provider, messages, selected_model, int(options.get("max_tokens", model.max_tokens)), float(options.get("temperature", singleton.config_manager.get_setting("default_temperature", 0.7) if singleton.config_manager else 0.7)), stream)
	if options.has("top_p"):
		body_data["top_p"] = options["top_p"]
	if provider != "anthropic" and options.has("tools") and model.supports_tools:
		body_data["tools"] = options["tools"]
		body_data["tool_choice"] = options.get("tool_choice", "auto")
	if provider != "anthropic" and (model.supports_thinking or options.get("supports_thinking", false)):
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
		"proxy": _proxy_settings()
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
