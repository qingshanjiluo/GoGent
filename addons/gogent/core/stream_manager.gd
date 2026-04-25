@tool
class_name GoGentStreamManager
extends RefCounted

signal stream_started(request_id: int)
signal stream_chunk(chunk: String, request_id: int)
signal stream_thinking_chunk(chunk: String, request_id: int)
signal stream_completed(full_response: String, thinking: String, request_id: int)
signal stream_error(error_msg: String, request_id: int)

class StreamState:
	var request_id := 0
	var client := HTTPClient.new()
	var host := ""
	var port := -1
	var tls := false
	var path := "/"
	var headers := PackedStringArray()
	var body := ""
	var proxy := {}
	var sent := false
	var buffer := ""
	var full_response := ""
	var thinking := ""
	var timeout := 90.0
	var last_activity := 0.0
	# 流式 JSON 校验相关
	var tool_calls_buffer: String = ""  # 累积的工具调用 JSON
	var pending_tool_calls: Array[Dictionary] = []  # 已完成的工具调用

var _streams: Dictionary = {}
var _next_request_id := 1

func send_stream_request(context: Dictionary) -> int:
	var parsed := _parse_url(str(context.get("url", "")))
	if parsed.is_empty():
		return -1
	var id := _next_request_id
	_next_request_id += 1
	var state := StreamState.new()
	state.request_id = id
	state.host = parsed["host"]
	state.port = parsed["port"]
	state.tls = parsed["tls"]
	state.path = parsed["path"]
	state.headers = context["headers"]
	state.body = context["body"]
	state.proxy = context.get("proxy", {})
	state.last_activity = Time.get_unix_time_from_system()
	_streams[id] = state
	_connect(state)
	stream_started.emit(id)
	return id

func process_streams(_delta: float) -> void:
	for id in _streams.keys():
		if not _streams.has(id):
			continue
		var state: StreamState = _streams[id]
		if Time.get_unix_time_from_system() - state.last_activity > state.timeout:
			_fail(id, "Stream timed out.")
			continue
		_process_state(state)

func has_active_streams() -> bool:
	return not _streams.is_empty()

func get_active_stream_count() -> int:
	return _streams.size()

func cancel_stream(request_id: int) -> bool:
	if not _streams.has(request_id):
		return false
	var state: StreamState = _streams[request_id]
	state.client.close()
	_streams.erase(request_id)
	return true

func cancel_all_streams() -> void:
	for id in _streams.keys():
		cancel_stream(id)

func _connect(state: StreamState) -> void:
	var err := OK
	if not state.proxy.is_empty():
		err = state.client.connect_to_host(state.proxy["host"], state.proxy["port"])
	else:
		err = state.client.connect_to_host(state.host, state.port, TLSOptions.client() if state.tls else null)
	if err != OK:
		_fail(state.request_id, "Failed to connect: %s" % err)

func _process_state(state: StreamState) -> void:
	var client := state.client
	client.poll()
	match client.get_status():
		HTTPClient.STATUS_CONNECTED:
			if not state.sent:
				var err := client.request(HTTPClient.METHOD_POST, state.path, state.headers, state.body)
				state.sent = true
				if err != OK:
					_fail(state.request_id, "Failed to send request: %s" % err)
		HTTPClient.STATUS_BODY:
			_read_body(state)
		HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_CANT_CONNECT, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			_fail(state.request_id, "HTTP connection error.")
		HTTPClient.STATUS_DISCONNECTED:
			if state.sent:
				_finish(state.request_id)

func _read_body(state: StreamState) -> void:
	var code := state.client.get_response_code()
	if code >= 400:
		var error_text := ""
		while state.client.get_status() == HTTPClient.STATUS_BODY:
			state.client.poll()
			var err_chunk := state.client.read_response_body_chunk()
			if err_chunk.is_empty():
				break
			error_text += err_chunk.get_string_from_utf8()
		_fail(state.request_id, "HTTP %d: %s" % [code, error_text.left(1000)])
		return
	while state.client.get_status() == HTTPClient.STATUS_BODY:
		state.client.poll()
		var chunk := state.client.read_response_body_chunk()
		if chunk.is_empty():
			break
		state.last_activity = Time.get_unix_time_from_system()
		state.buffer += chunk.get_string_from_utf8()
		_parse_sse(state)

func _parse_sse(state: StreamState) -> void:
	var normalized := state.buffer.replace("\r\n", "\n")
	var events: Array = Array(normalized.split("\n\n", false))
	if not normalized.ends_with("\n\n"):
		state.buffer = events.pop_back() if not events.is_empty() else normalized
	else:
		state.buffer = ""
	for event in events:
		for raw_line in event.split("\n", false):
			var line: String = raw_line.strip_edges()
			if not line.begins_with("data:"):
				continue
			var payload: String = line.substr(5).strip_edges()
			if payload == "[DONE]":
				_finish(state.request_id)
				return
			var parsed = JSON.parse_string(payload)
			if not (parsed is Dictionary):
				continue
			_apply_delta(state, parsed)

func _apply_delta(state: StreamState, data: Dictionary) -> void:
	var choices: Array = data.get("choices", [])
	if choices.is_empty():
		return
	var choice: Dictionary = choices[0]
	var delta: Dictionary = choice.get("delta", {})
	var content = delta.get("content", null)
	if content != null:
		var text := str(content)
		state.full_response += text
		stream_chunk.emit(text, state.request_id)
	var reasoning = delta.get("reasoning_content", null)
	if reasoning != null:
		var thought := str(reasoning)
		state.thinking += thought
		stream_thinking_chunk.emit(thought, state.request_id)

	# 处理工具调用（流式累积）
	var tool_calls_data = delta.get("tool_calls", null)
	if tool_calls_data != null and tool_calls_data is Array:
		_process_tool_calls_delta(state, tool_calls_data)

	var finish = choice.get("finish_reason", null)
	if finish != null:
		# 在完成时尝试解析累积的工具调用 JSON
		_finalize_tool_calls(state)
		_finish(state.request_id)

## 处理流式工具调用 delta
## 参考 OpenAI 的流式工具调用格式：tool_calls[i].function.arguments 是分块传输的
func _process_tool_calls_delta(state: StreamState, tool_calls_data: Array) -> void:
	for tc_data in tool_calls_data:
		if not (tc_data is Dictionary):
			continue
		var index := int(tc_data.get("index", 0))
		var func_data = tc_data.get("function", {})
		if func_data is Dictionary:
			var name := str(func_data.get("name", ""))
			var args_chunk := str(func_data.get("arguments", ""))
			var tc_id := str(tc_data.get("id", ""))

			# 确保 pending_tool_calls 数组足够大
			while state.pending_tool_calls.size() <= index:
				state.pending_tool_calls.append({
					"id": "",
					"type": "function",
					"function": {"name": "", "arguments": ""}
				})

			var tc := state.pending_tool_calls[index]
			if not tc_id.is_empty():
				tc["id"] = tc_id
			if not name.is_empty():
				tc["function"]["name"] = name
			if not args_chunk.is_empty():
				tc["function"]["arguments"] += args_chunk

## 在流结束时最终化工具调用
## 校验累积的 JSON 参数是否完整
func _finalize_tool_calls(state: StreamState) -> void:
	if state.pending_tool_calls.is_empty():
		return

	# 尝试验证每个工具调用的 arguments 是否为完整 JSON
	for tc in state.pending_tool_calls:
		var args_str := str(tc.get("function", {}).get("arguments", ""))
		if args_str.is_empty():
			continue
		# 校验 JSON 完整性
		if _is_valid_json_string(args_str):
			var parsed = JSON.parse_string(args_str)
			if parsed != null:
				tc["function"]["arguments"] = parsed
		else:
			# JSON 不完整，尝试修复
			var fixed := _try_fix_json(args_str)
			if fixed != null:
				tc["function"]["arguments"] = fixed
			# 如果修复失败，保留原始字符串

## 校验 JSON 字符串是否完整（括号匹配 + 引号匹配）
## 防止流式传输中 JSON 被截断导致解析失败
static func _is_valid_json_string(json_str: String) -> bool:
	var brace_count := 0
	var bracket_count := 0
	var in_string := false
	var escape_next := false

	for i in range(json_str.length()):
		var ch := json_str[i]

		if escape_next:
			escape_next = false
			continue

		if ch == "\\":
			escape_next = true
			continue

		if ch == "\"":
			in_string = not in_string
			continue

		if in_string:
			continue

		match ch:
			"{":
				brace_count += 1
			"}":
				brace_count -= 1
				if brace_count < 0:
					return false
			"[":
				bracket_count += 1
			"]":
				bracket_count -= 1
				if bracket_count < 0:
					return false

	return brace_count == 0 and bracket_count == 0 and not in_string

## 尝试修复不完整的 JSON（补充缺失的括号）
static func _try_fix_json(json_str: String) -> Variant:
	var fixed := json_str.strip_edges()

	# 计算缺失的括号数
	var open_braces := 0
	var close_braces := 0
	var open_brackets := 0
	var close_brackets := 0
	var in_str := false
	var esc := false

	for i in range(fixed.length()):
		var ch := fixed[i]
		if esc:
			esc = false
			continue
		if ch == "\\":
			esc = true
			continue
		if ch == "\"":
			in_str = not in_str
			continue
		if in_str:
			continue
		match ch:
			"{": open_braces += 1
			"}": close_braces += 1
			"[": open_brackets += 1
			"]": close_brackets += 1

	# 补充缺失的闭合括号
	for _i in range(open_braces - close_braces):
		fixed += "}"
	for _i in range(open_brackets - close_brackets):
		fixed += "]"

	if fixed != json_str:
		var parsed = JSON.parse_string(fixed)
		if parsed != null:
			return parsed

	return null

func _finish(request_id: int) -> void:
	if not _streams.has(request_id):
		return
	var state: StreamState = _streams[request_id]
	state.client.close()
	_streams.erase(request_id)
	stream_completed.emit(state.full_response, state.thinking, request_id)

func _fail(request_id: int, message: String) -> void:
	if _streams.has(request_id):
		var state: StreamState = _streams[request_id]
		state.client.close()
		_streams.erase(request_id)
	stream_error.emit(message, request_id)

static func _parse_url(url: String) -> Dictionary:
	var work := url.strip_edges()
	var tls := false
	if work.begins_with("https://"):
		tls = true
		work = work.substr(8)
	elif work.begins_with("http://"):
		work = work.substr(7)
	else:
		return {}
	var slash := work.find("/")
	var authority := work if slash == -1 else work.substr(0, slash)
	var path := "/" if slash == -1 else work.substr(slash)
	var host := authority
	var port := 443 if tls else 80
	var colon := authority.rfind(":")
	if colon > -1:
		host = authority.substr(0, colon)
		port = int(authority.substr(colon + 1))
	return {"host": host, "port": port, "path": path, "tls": tls}
