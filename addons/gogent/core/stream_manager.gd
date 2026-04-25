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
	var finish = choice.get("finish_reason", null)
	if finish != null:
		_finish(state.request_id)

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
