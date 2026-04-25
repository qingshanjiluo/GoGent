@tool
class_name GoGentStreamManager
extends RefCounted

## 流式 API 响应管理器
## 实现 Server-Sent Events (SSE) 流式请求
## 使用 HTTPClient 实现底层流式读取，支持实时显示 AI 回复

# 信号
signal stream_started(request_id: int)
signal stream_chunk(chunk: String, request_id: int)
signal stream_thinking_chunk(chunk: String, request_id: int)
signal stream_completed(full_response: String, thinking: String, request_id: int)
signal stream_error(error_msg: String, request_id: int)

# 流式请求状态
class StreamState:
	var request_id: int
	var http_client: HTTPClient
	var url: String
	var headers: PackedStringArray
	var body: String
	var buffer: String = ""
	var full_response: String = ""
	var full_thinking: String = ""
	var is_reading: bool = false
	var is_done: bool = false
	var last_chunk_time: float = 0.0
	var timeout: float = 60.0
	
	func _init(p_id: int, p_url: String, p_headers: PackedStringArray, p_body: String):
		request_id = p_id
		url = p_url
		headers = p_headers
		body = p_body
		http_client = HTTPClient.new()
		last_chunk_time = Time.get_unix_time_from_system()

var _active_streams: Dictionary = {}  # request_id -> StreamState
var _request_counter: int = 0
var _update_timer: float = 0.0
var _is_processing: bool = false

func _init() -> void:
	pass

## 发送流式聊天请求
func send_stream_request(messages: Array[Dictionary], options: Dictionary = {}) -> int:
	var singleton = GoGentSingleton.get_instance()
	var model_manager = singleton.model_manager
	if model_manager == null:
		push_error("模型管理器未初始化")
		return -1
	
	var supplier = model_manager.get_current_supplier()
	var model = model_manager.get_current_model()
	
	if supplier == null or model == null:
		push_error("未配置有效的模型")
		return -1
	
	var request_id = _request_counter
	_request_counter += 1
	
	# 准备请求头
	var headers = PackedStringArray([
		"Accept: text/event-stream",
		"Authorization: Bearer %s" % supplier.api_key,
		"Content-Type: application/json"
	])
	
	# 准备请求体 - 启用流式
	var request_data = {
		"messages": messages,
		"model": model.model_name,
		"max_tokens": options.get("max_tokens", model.max_tokens),
		"temperature": options.get("temperature", 1.0),
		"stream": true,
		"top_p": options.get("top_p", 1),
	}
	
	# 工具调用支持
	if options.get("tools", null) != null and model.supports_tools:
		request_data["tools"] = options["tools"]
		request_data["tool_choice"] = options.get("tool_choice", "auto")
	
	# 支持 reasoning/thinking 内容（如 DeepSeek Reasoner）
	if options.get("supports_thinking", model.supports_thinking):
		request_data["include_reasoning"] = true
	
	var request_body = JSON.stringify(request_data)
	
	# 构建 URL
	var url = supplier.base_url
	if url.ends_with("/"):
		url = url.substr(0, url.length() - 1)
	
	if not url.ends_with("/chat/completions"):
		if url.ends_with("/v1") or url.ends_with("/v3"):
			url += "/chat/completions"
		else:
			url += "/v1/chat/completions"
	
	# 创建流状态
	var state = StreamState.new(request_id, url, headers, request_body)
	_active_streams[request_id] = state
	
	# 开始连接
	_start_stream_connection(request_id)
	
	stream_started.emit(request_id)
	return request_id

## 开始流式连接
func _start_stream_connection(request_id: int) -> void:
	var state = _active_streams.get(request_id)
	if state == null:
		return
	
	var err = state.http_client.connect_to_host(state.url)
	if err != OK:
		_handle_stream_error(request_id, "连接失败: " + str(err))
		return
	
	state.is_reading = true

## 处理流式数据（需要在主循环中调用）
func process_streams(delta: float) -> void:
	if _active_streams.is_empty():
		return
	
	_update_timer += delta
	
	for request_id in _active_streams.keys():
		var state = _active_streams[request_id]
		if state == null or state.is_done:
			continue
		
		# 检查超时
		var now = Time.get_unix_time_from_system()
		if now - state.last_chunk_time > state.timeout:
			_handle_stream_error(request_id, "请求超时")
			continue
		
		_process_stream_state(request_id, state)

## 处理单个流状态
func _process_stream_state(request_id: int, state: StreamState) -> void:
	var client = state.http_client
	
	match client.get_status():
		HTTPClient.STATUS_DISCONNECTED:
			# 尝试连接
			var err = client.connect_to_host(state.url)
			if err != OK:
				_handle_stream_error(request_id, "连接失败: " + str(err))
		
		HTTPClient.STATUS_CONNECTING:
			# 等待连接完成
			client.poll()
		
		HTTPClient.STATUS_CONNECTED:
			# 发送请求
			var err = client.request(HTTPClient.METHOD_POST, state.url, state.headers, state.body)
			if err != OK:
				_handle_stream_error(request_id, "请求发送失败: " + str(err))
		
		HTTPClient.STATUS_REQUESTING:
			client.poll()
		
		HTTPClient.STATUS_BODY:
			# 读取响应体
			_read_stream_body(request_id, state)
		
		HTTPClient.STATUS_CONNECTION_ERROR:
			_handle_stream_error(request_id, "连接错误")
		
		_:  # 其他状态
			if client.get_status() == HTTPClient.STATUS_DISCONNECTED:
				_finish_stream(request_id, state)

## 读取流式响应体
func _read_stream_body(request_id: int, state: StreamState) -> void:
	var client = state.http_client
	client.poll()
	
	var response_code = client.get_response_code()
	if response_code != 200:
		var response_body = ""
		while client.get_status() == HTTPClient.STATUS_BODY:
			client.poll()
			var chunk = client.read_response_body_chunk()
			if chunk.size() > 0:
				response_body += chunk.get_string_from_utf8()
		_handle_stream_error(request_id, "API 返回错误代码: %d, Body: %s" % [response_code, response_body])
		return
	
	# 读取数据块
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk = client.read_response_body_chunk()
		if chunk.size() == 0:
			break
		
		var text = chunk.get_string_from_utf8()
		state.buffer += text
		state.last_chunk_time = Time.get_unix_time_from_system()
		
		# 解析 SSE 数据
		_parse_sse_data(request_id, state)

## 解析 SSE (Server-Sent Events) 数据
func _parse_sse_data(request_id: int, state: StreamState) -> void:
	# SSE 格式: "data: {...}\n\n"
	var lines = state.buffer.split("\n")
	state.buffer = ""  # 清空缓冲区，已处理的行将被移除
	
	var remaining_lines = []
	for i in range(lines.size()):
		var line = lines[i].strip_edges()
		
		if line.begins_with("data: "):
			var json_str = line.substr(6).strip_edges()
			
			# 检查是否为结束标记
			if json_str == "[DONE]":
				continue
			
			var json = JSON.parse_string(json_str)
			if json == null:
				continue
			
			# 解析 OpenAI 兼容的流式格式
			if json.has("choices") and json.choices.size() > 0:
				var choice = json.choices[0]
				
				# 处理 delta 内容
				if choice.has("delta"):
					var delta = choice.delta
					if delta.has("content") and delta.content != null:
						var content_chunk = str(delta.content)
						state.full_response += content_chunk
						stream_chunk.emit(content_chunk, request_id)
					
					# 处理 reasoning/thinking 内容
					if delta.has("reasoning_content") and delta.reasoning_content != null:
						var thinking_chunk = str(delta.reasoning_content)
						state.full_thinking += thinking_chunk
						stream_thinking_chunk.emit(thinking_chunk, request_id)
				
				# 处理 finish_reason
				if choice.has("finish_reason") and choice.finish_reason != null:
					if choice.finish_reason == "stop" or choice.finish_reason == "length":
						_finish_stream(request_id, state)
						return
		elif line.begins_with(":"):
			# 注释行，忽略
			pass
		else:
			# 非 SSE 行，保留
			remaining_lines.append(line)
	
	# 保留未处理的行
	if not remaining_lines.is_empty():
		state.buffer = "\n".join(remaining_lines)

## 完成流式请求
func _finish_stream(request_id: int, state: StreamState) -> void:
	if state.is_done:
		return
	state.is_done = true
	state.is_reading = false
	
	if state.http_client:
		state.http_client.close()
	
	stream_completed.emit(state.full_response, state.full_thinking, request_id)
	_active_streams.erase(request_id)

## 处理流式错误
func _handle_stream_error(request_id: int, error_msg: String) -> void:
	var state = _active_streams.get(request_id)
	if state:
		state.is_done = true
		state.is_reading = false
		if state.http_client:
			state.http_client.close()
	
	stream_error.emit(error_msg, request_id)
	_active_streams.erase(request_id)

## 取消流式请求
func cancel_stream(request_id: int) -> bool:
	var state = _active_streams.get(request_id)
	if state == null:
		return false
	
	state.is_done = true
	state.is_reading = false
	if state.http_client:
		state.http_client.close()
	
	_active_streams.erase(request_id)
	return true

## 取消所有流式请求
func cancel_all_streams() -> void:
	for request_id in _active_streams.keys():
		cancel_stream(request_id)

## 是否有活跃的流
func has_active_streams() -> bool:
	return not _active_streams.is_empty()

## 获取活跃流数量
func get_active_stream_count() -> int:
	return _active_streams.size()
