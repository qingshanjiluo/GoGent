@tool
class_name GoGentAPIManager
extends RefCounted

## API 管理器
## 管理所有 AI API 的调用（OpenAI 兼容接口、Claude、Gemini 等）
## 支持流式 (SSE) 和非流式请求

# 信号
signal request_completed(success: bool, response: String, thinking: String)
signal stream_chunk(chunk: String, request_id: int)
signal stream_thinking_chunk(chunk: String, request_id: int)
signal stream_completed(success: bool, full_response: String, thinking: String, request_id: int)

# 当前 HTTP 请求
var http_request: HTTPRequest = null
var is_generating: bool = false

# 流式管理器
var stream_manager: GoGentStreamManager = null

func _init() -> void:
	stream_manager = GoGentStreamManager.new()
	_connect_stream_signals()

func _connect_stream_signals() -> void:
	if stream_manager:
		stream_manager.stream_chunk.connect(_on_stream_chunk)
		stream_manager.stream_thinking_chunk.connect(_on_stream_thinking_chunk)
		stream_manager.stream_completed.connect(_on_stream_completed)
		stream_manager.stream_error.connect(_on_stream_error)

## 发送聊天请求（非流式）
func send_chat_request(messages: Array[Dictionary], options: Dictionary = {}) -> void:
	var singleton = GoGentSingleton.get_instance()
	var model_manager = singleton.model_manager
	if model_manager == null:
		push_error("模型管理器未初始化")
		return
	
	var supplier = model_manager.get_current_supplier()
	var model = model_manager.get_current_model()
	
	if supplier == null or model == null:
		push_error("未配置有效的模型")
		return
	
	# 创建 HTTP 请求节点
	if http_request == null:
		http_request = HTTPRequest.new()
		if singleton.main_panel:
			singleton.main_panel.add_child(http_request)
	
	# 准备请求头
	var headers = [
		"Accept: application/json",
		"Authorization: Bearer %s" % supplier.api_key,
		"Content-Type: application/json"
	]
	
	# 准备请求体
	var request_data = {
		"messages": messages,
		"model": model.model_name,
		"max_tokens": options.get("max_tokens", model.max_tokens),
		"temperature": options.get("temperature", 1.0),
		"stream": false,
		"top_p": options.get("top_p", 1),
	}
	
	# 工具调用支持
	if options.get("tools", null) != null and model.supports_tools:
		request_data["tools"] = options["tools"]
		request_data["tool_choice"] = options.get("tool_choice", "auto")
	
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
	
	# 发送请求
	if not http_request.request_completed.is_connected(_on_request_completed):
		http_request.request_completed.connect(_on_request_completed)
	
	is_generating = true
	var err = http_request.request(url, headers, HTTPClient.METHOD_POST, request_body)
	if err != OK:
		push_error("请求发送失败: " + str(err))
		is_generating = false
		request_completed.emit(false, "", "")

## 发送流式聊天请求（SSE 实时响应）
func send_stream_chat_request(messages: Array[Dictionary], options: Dictionary = {}) -> int:
	if stream_manager == null:
		push_error("流式管理器未初始化")
		return -1
	
	return stream_manager.send_stream_request(messages, options)

## 处理流式数据块
func _on_stream_chunk(chunk: String, request_id: int) -> void:
	stream_chunk.emit(chunk, request_id)

func _on_stream_thinking_chunk(chunk: String, request_id: int) -> void:
	stream_thinking_chunk.emit(chunk, request_id)

func _on_stream_completed(full_response: String, thinking: String, request_id: int) -> void:
	stream_completed.emit(true, full_response, thinking, request_id)

func _on_stream_error(error_msg: String, request_id: int) -> void:
	push_error("流式请求错误: " + error_msg)
	stream_completed.emit(false, "", "", request_id)

## 处理非流式请求完成
func _on_request_completed(_result, _response_code, _headers, body: PackedByteArray) -> void:
	is_generating = false
	
	var json = JSON.new()
	var err = json.parse(body.get_string_from_utf8())
	if err != OK:
		push_error("JSON 解析错误: " + json.get_error_message())
		request_completed.emit(false, "", "")
		return
	
	var data = json.get_data()
	if data and data.has("choices"):
		var choices := data["choices"] as Array
		if choices.size() > 0:
			var message_data = choices[0].get("message", {})
			var content = message_data.get("content", "")
			var think_msg = message_data.get("reasoning_content", "")
			request_completed.emit(true, content, think_msg)
			return
	
	# 错误处理
	if data.has("error"):
		var error_info = data["error"]
		var error_msg = "API 错误"
		if error_info is Dictionary:
			error_msg = error_info.get("message", error_msg)
		push_error(error_msg)
	
	request_completed.emit(false, "", "")

## 取消请求
func cancel_request() -> void:
	if http_request and is_generating:
		http_request.cancel_request()
		is_generating = false
	
	# 取消所有流式请求
	if stream_manager:
		stream_manager.cancel_all_streams()

## 构建消息
static func build_message(role: String, content: String) -> Dictionary:
	return {"role": role, "content": content}

static func build_system_message(content: String) -> Dictionary:
	return build_message("system", content)

static func build_user_message(content: String) -> Dictionary:
	return build_message("user", content)

static func build_assistant_message(content: String) -> Dictionary:
	return build_message("assistant", content)
