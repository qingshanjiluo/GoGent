@tool
class_name GoGentMainPanel
extends Control

## GoGent 主面板
## 整合 Agent 聊天、控制台、训练监控、Agent 编辑器、设置等功能
## 支持流式响应实时显示

signal send_message(message: Dictionary, message_content: String)

@onready var chat_container: VBoxContainer = %ChatContainer
@onready var console_container: VBoxContainer = %ConsoleContainer
@onready var training_container: VBoxContainer = %TrainingContainer
@onready var agent_editor_container: VBoxContainer = %AgentEditorContainer
@onready var settings_container: VBoxContainer = %SettingsContainer

@onready var tab_chat: Button = %TabChat
@onready var tab_console: Button = %TabConsole
@onready var tab_training: Button = %TabTraining
@onready var tab_agent_editor: Button = %TabAgentEditor
@onready var tab_settings: Button = %TabSettings

@onready var message_list: VBoxContainer = %MessageList
@onready var message_container: ScrollContainer = %MessageContainer
@onready var welcome_message: Control = %WelcomeMessage
@onready var user_input: TextEdit = %UserInput
@onready var send_button: Button = %SendButton
@onready var model_button: OptionButton = %ModelButton
@onready var agent_button: OptionButton = %AgentButton
@onready var new_chat_button: Button = %NewChatButton
@onready var collaborate_button: Button = %CollaborateButton
@onready var stream_toggle: CheckButton = %StreamToggle

@onready var console_output: RichTextLabel = %ConsoleOutput
@onready var console_input: LineEdit = %ConsoleInput
@onready var console_send: Button = %ConsoleSend
@onready var console_clear: Button = %ConsoleClear

@onready var training_status: Label = %TrainingStatus
@onready var training_progress: ProgressBar = %TrainingProgress
@onready var training_episode: Label = %TrainingEpisode
@onready var training_reward: Label = %TrainingReward
@onready var training_epsilon: Label = %TrainingEpsilon
@onready var training_start: Button = %TrainingStart
@onready var training_pause: Button = %TrainingPause
@onready var training_stop: Button = %TrainingStop
@onready var chart_container: MarginContainer = %ChartContainer
@onready var chart_placeholder: Label = %ChartPlaceholder

@onready var settings_api_key: LineEdit = %SettingsApiKey
@onready var settings_api_url: LineEdit = %SettingsApiUrl
@onready var settings_proxy_host: LineEdit = %SettingsProxyHost
@onready var settings_proxy_port: LineEdit = %SettingsProxyPort
@onready var settings_save: Button = %SettingsSave

# 容器列表
var container_list: Array[VBoxContainer] = []

# 当前消息
var current_message: String = ""
var messages: Array[Dictionary] = []
var first_chat: bool = true
var is_generating: bool = false

# 流式响应状态
var _stream_message_item = null
var _stream_request_id: int = -1
var _stream_full_response: String = ""
var _stream_full_thinking: String = ""

# 训练可视化
var _training_visualizer: GoGentTrainingVisualizer = null
var _chart_control: Control = null

func _ready() -> void:
	container_list = [chat_container, console_container, training_container, agent_editor_container, settings_container]
	
	# 连接 Tab 按钮
	tab_chat.pressed.connect(func(): _show_container(chat_container))
	tab_console.pressed.connect(func(): _show_container(console_container))
	tab_training.pressed.connect(func(): _show_container(training_container))
	tab_agent_editor.pressed.connect(func(): _show_container(agent_editor_container))
	tab_settings.pressed.connect(func(): _show_container(settings_container))
	
	# 连接聊天按钮
	send_button.pressed.connect(_on_send_message)
	new_chat_button.pressed.connect(_on_new_chat)
	collaborate_button.pressed.connect(_on_collaborate)
	
	# 输入框快捷键
	user_input.gui_input.connect(_on_user_input_gui_input)
	
	# 连接控制台
	console_send.pressed.connect(_on_console_send)
	console_clear.pressed.connect(_on_console_clear)
	console_input.text_submitted.connect(func(_t): _on_console_send())
	
	# 连接训练按钮
	training_start.pressed.connect(_on_training_start)
	training_pause.pressed.connect(_on_training_pause)
	training_stop.pressed.connect(_on_training_stop)
	
	# 连接设置
	settings_save.pressed.connect(_on_settings_save)
	
	# 初始化选择器
	_init_selectors()
	
	# 连接流式信号
	_connect_stream_signals()
	
	# 初始化训练可视化
	_init_training_visualizer()
	
	# 初始化 Agent 编辑器
	_init_agent_editor()

func _init_selectors() -> void:
	await get_tree().process_frame
	var singleton = GoGentSingleton.get_instance()
	
	# 初始化模型选择器
	if singleton.model_manager:
		model_button.clear()
		for supplier in singleton.model_manager.suppliers:
			for model in supplier.models:
				model_button.add_item("{0} - {1}".format([supplier.name, model.name]))
	
	# 初始化 Agent 选择器
	if singleton.agent_manager:
		agent_button.clear()
		for agent in singleton.agent_manager.agents:
			agent_button.add_item(agent.name)

func _connect_stream_signals() -> void:
	var singleton = GoGentSingleton.get_instance()
	if singleton.api_manager and singleton.api_manager.stream_manager:
		var sm = singleton.api_manager.stream_manager
		if not sm.stream_chunk.is_connected(_on_stream_chunk_received):
			sm.stream_chunk.connect(_on_stream_chunk_received)
		if not sm.stream_thinking_chunk.is_connected(_on_stream_thinking_chunk_received):
			sm.stream_thinking_chunk.connect(_on_stream_thinking_chunk_received)
		if not sm.stream_completed.is_connected(_on_stream_completed_received):
			sm.stream_completed.connect(_on_stream_completed_received)
		if not sm.stream_error.is_connected(_on_stream_error_received):
			sm.stream_error.connect(_on_stream_error_received)

func _init_training_visualizer() -> void:
	"""初始化训练可视化"""
	_training_visualizer = GoGentTrainingVisualizer.new()
	
	# 连接训练管理器的信号到可视化
	var singleton = GoGentSingleton.get_instance()
	if singleton.training_manager:
		if not singleton.training_manager.training_episode_completed.is_connected(_on_training_episode_for_chart):
			singleton.training_manager.training_episode_completed.connect(_on_training_episode_for_chart)

func _init_agent_editor() -> void:
	"""初始化 Agent 编辑器面板"""
	var editor_panel = preload("res://addons/gogent/ui/agent_editor/agent_editor_panel.tscn").instantiate()
	editor_panel.name = "AgentEditorPanelInstance"
	
	# 替换占位的 HSplitContainer
	var placeholder = %AgentEditorPanel
	if placeholder and placeholder.get_parent():
		var parent = placeholder.get_parent()
		var idx = placeholder.get_index()
		placeholder.queue_free()
		parent.add_child(editor_panel)
		parent.move_child(editor_panel, idx)

func _show_container(container: VBoxContainer) -> void:
	for c in container_list:
		c.visible = c == container
	
	# 更新 Tab 状态
	tab_chat.button_pressed = container == chat_container
	tab_console.button_pressed = container == console_container
	tab_training.button_pressed = container == training_container
	tab_agent_editor.button_pressed = container == agent_editor_container
	tab_settings.button_pressed = container == settings_container

# ========== 聊天功能 ==========

func _on_user_input_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		var is_enter = event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER
		var is_shift = event.shift_pressed
		
		# Enter 发送，Shift+Enter 换行
		if is_enter and not is_shift:
			accept_event()
			_on_send_message()

func _on_send_message() -> void:
	var text = user_input.text.strip_edges()
	if text.is_empty() or is_generating:
		return
	
	user_input.text = ""
	
	# 显示用户消息
	welcome_message.hide()
	message_container.show()
	
	messages.append({"role": "user", "content": text})
	_add_user_message(text)
	
	# 判断是否使用流式
	var use_stream = stream_toggle != null and stream_toggle.button_pressed
	
	if use_stream:
		_send_stream_to_api()
	else:
		_send_to_api()

func _send_to_api() -> void:
	var singleton = GoGentSingleton.get_instance()
	if singleton.api_manager == null:
		_add_assistant_message("[color='#ff7085']API 管理器未初始化，请先在设置中配置 API[/color]")
		return
	
	is_generating = true
	send_button.disabled = true
	send_button.text = "发送中..."
	
	# 连接响应信号
	if not singleton.api_manager.request_completed.is_connected(_on_api_response):
		singleton.api_manager.request_completed.connect(_on_api_response)
	
	singleton.api_manager.send_chat_request(messages)

func _send_stream_to_api() -> void:
	var singleton = GoGentSingleton.get_instance()
	if singleton.api_manager == null:
		_add_assistant_message("[color='#ff7085']API 管理器未初始化[/color]")
		return
	
	is_generating = true
	send_button.disabled = true
	send_button.text = "停止"
	
	# 创建流式消息项
	_stream_message_item = preload("res://addons/gogent/ui/chat/message_item.tscn").instantiate()
	message_list.add_child(_stream_message_item)
	_stream_message_item.set_assistant_message("", "")
	
	# 重置流式状态
	_stream_full_response = ""
	_stream_full_thinking = ""
	
	# 发送流式请求
	_stream_request_id = singleton.api_manager.send_stream_chat_request(messages)
	
	if _stream_request_id < 0:
		is_generating = false
		send_button.disabled = false
		send_button.text = "发送"
		_add_assistant_message("[color='#ff7085']流式请求发送失败[/color]")

## 流式数据块接收
func _on_stream_chunk_received(chunk: String, request_id: int) -> void:
	if request_id != _stream_request_id:
		return
	
	_stream_full_response += chunk
	
	# 实时更新消息项
	if _stream_message_item and is_instance_valid(_stream_message_item):
		_stream_message_item.set_assistant_message(_stream_full_response, _stream_full_thinking)
		_scroll_to_bottom()

func _on_stream_thinking_chunk_received(chunk: String, request_id: int) -> void:
	if request_id != _stream_request_id:
		return
	
	_stream_full_thinking += chunk
	
	if _stream_message_item and is_instance_valid(_stream_message_item):
		_stream_message_item.set_assistant_message(_stream_full_response, _stream_full_thinking)

func _on_stream_completed_received(success: bool, full_response: String, thinking: String, request_id: int) -> void:
	if request_id != _stream_request_id:
		return
	
	is_generating = false
	send_button.disabled = false
	send_button.text = "发送"
	
	if success:
		messages.append({"role": "assistant", "content": full_response})
		# 最终更新消息项
		if _stream_message_item and is_instance_valid(_stream_message_item):
			_stream_message_item.set_assistant_message(full_response, thinking)
	else:
		if _stream_message_item and is_instance_valid(_stream_message_item):
			_stream_message_item.set_assistant_message(
				"[color='#ff7085']流式请求失败[/color]"
			)
	
	_stream_message_item = null
	_stream_request_id = -1

func _on_stream_error_received(error_msg: String, request_id: int) -> void:
	if request_id != _stream_request_id:
		return
	
	is_generating = false
	send_button.disabled = false
	send_button.text = "发送"
	
	_add_assistant_message("[color='#ff7085']流式错误: {0}[/color]".format([error_msg]))
	_stream_message_item = null
	_stream_request_id = -1

func _on_api_response(success: bool, response: String, thinking: String) -> void:
	is_generating = false
	send_button.disabled = false
	send_button.text = "发送"
	
	if success:
		messages.append({"role": "assistant", "content": response})
		_add_assistant_message(response, thinking)
	else:
		_add_assistant_message("[color='#ff7085']API 请求失败: {0}[/color]".format([response]))

func _on_new_chat() -> void:
	messages.clear()
	first_chat = true
	current_message = ""
	welcome_message.show()
	message_container.hide()
	
	# 清空消息列表
	for child in message_list.get_children():
		child.queue_free()
	
	# 重置流式状态
	_stream_message_item = null
	_stream_request_id = -1

func _on_collaborate() -> void:
	var text = user_input.text.strip_edges()
	if text.is_empty():
		return
	
	user_input.text = ""
	
	# 启动 Agent 协作
	var singleton = GoGentSingleton.get_instance()
	if singleton.agent_manager and singleton.agent_manager.collaboration_enabled:
		var agent_ids = []
		for agent in singleton.agent_manager.agents:
			if agent.enabled:
				agent_ids.append(agent.id)
		
		if agent_ids.is_empty():
			_add_console_message("没有启用的 Agent", "warning")
			return
		
		var results = singleton.agent_manager.collaborate(text, agent_ids)
		welcome_message.hide()
		message_container.show()
		
		# 显示用户消息
		_add_user_message(text + " [协作模式]")
		
		# 显示每个 Agent 的响应
		for result in results:
			var agent_name = result.agent_name
			_add_assistant_message("[color='#42ffc2']Agent [{0}]:[/color]\n已收到协作请求，正在处理...".format([agent_name]))
			_add_console_message("Agent [{0}] 已收到协作请求".format([agent_name]), "info")

func _add_user_message(text: String) -> void:
	var msg_item = preload("res://addons/gogent/ui/chat/message_item.tscn").instantiate()
	message_list.add_child(msg_item)
	msg_item.set_user_message(text)
	_scroll_to_bottom()

func _add_assistant_message(text: String, thinking: String = "") -> void:
	var msg_item = preload("res://addons/gogent/ui/chat/message_item.tscn").instantiate()
	message_list.add_child(msg_item)
	msg_item.set_assistant_message(text, thinking)
	_scroll_to_bottom()

func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	if message_container.get_v_scroll_bar():
		message_container.get_v_scroll_bar().set_as_ratio(1.0)

# ========== 控制台功能 ==========

func _on_console_send() -> void:
	var text = console_input.text.strip_edges()
	if text.is_empty():
		return
	
	console_input.text = ""
	_add_console_message("> " + text, "command")
	
	var singleton = GoGentSingleton.get_instance()
	if singleton.console_manager:
		singleton.console_manager.execute_command(text)
		# 显示执行结果
		var msgs = singleton.console_manager.messages
		if not msgs.is_empty():
			var last_msg = msgs[-1]
			_add_console_message(last_msg.text, last_msg.type)

func _on_console_clear() -> void:
	console_output.text = ""
	var singleton = GoGentSingleton.get_instance()
	if singleton.console_manager:
		singleton.console_manager.clear_messages()

func _add_console_message(text: String, type: String = "info") -> void:
	var color = "#abc9ff"
	match type:
		"info": color = "#abc9ff"
		"success": color = "#42ffc2"
		"warning": color = "#ffb373"
		"error": color = "#ff7085"
		"system": color = "#ffeda1"
		"command": color = "#ffffff"
	
	console_output.append_text("[color='{0}'][{1}] {2}\n[/color]".format([color, type.to_upper(), text]))
	console_output.scroll_to_line(console_output.get_line_count() - 1)

# ========== 训练功能 ==========

func _on_training_start() -> void:
	var singleton = GoGentSingleton.get_instance()
	if singleton.training_manager:
		# 连接信号
		if not singleton.training_manager.training_episode_completed.is_connected(_on_training_episode):
			singleton.training_manager.training_episode_completed.connect(_on_training_episode)
		if not singleton.training_manager.training_completed.is_connected(_on_training_completed):
			singleton.training_manager.training_completed.connect(_on_training_completed)
		
		singleton.training_manager.start_training()
		training_start.disabled = true
		training_pause.disabled = false
		training_stop.disabled = false
		training_status.text = "训练中..."

func _on_training_pause() -> void:
	var singleton = GoGentSingleton.get_instance()
	if singleton.training_manager:
		singleton.training_manager.pause_training()
		training_status.text = "已暂停"
		training_pause.disabled = true

func _on_training_stop() -> void:
	var singleton = GoGentSingleton.get_instance()
	if singleton.training_manager:
		singleton.training_manager.stop_training()
		_reset_training_ui()

func _on_training_episode(episode: int, reward: float, epsilon: float) -> void:
	training_episode.text = "轮次: {0}".format([episode])
	training_reward.text = "奖励: {0:.2f}".format([reward])
	training_epsilon.text = "探索率: {0:.3f}".format([epsilon])
	
	var singleton = GoGentSingleton.get_instance()
	if singleton.training_manager:
		var total = singleton.training_manager.config.episodes
		training_progress.value = float(episode) / float(total) * 100.0

func _on_training_completed(stats: Dictionary) -> void:
	_reset_training_ui()
	training_status.text = "训练完成！平均奖励: {0:.2f}".format([stats.get("avg_reward", 0.0)])

func _reset_training_ui() -> void:
	training_start.disabled = false
	training_pause.disabled = true
	training_stop.disabled = true

## 训练轮次完成 - 更新图表
func _on_training_episode_for_chart(episode: int, reward: float, epsilon: float) -> void:
	if _training_visualizer == null:
		return
	
	# 记录训练数据
	var singleton = GoGentSingleton.get_instance()
	if singleton.training_manager:
		var stats = singleton.training_manager.stats
		_training_visualizer.record_reward(episode, reward, stats.avg_reward, stats.max_reward)
		_training_visualizer.record_epsilon(episode, epsilon)
	
	# 创建或更新图表
	_update_chart()

func _update_chart() -> void:
	"""更新训练图表"""
	if _training_visualizer == null:
		return
	
	# 移除旧图表
	if _chart_control and is_instance_valid(_chart_control):
		_chart_control.queue_free()
		_chart_control = null
	
	# 隐藏占位文本
	if chart_placeholder:
		chart_placeholder.visible = false
	
	# 创建新图表
	_chart_control = _training_visualizer.create_chart_control()
	_chart_control.name = "TrainingChart"
	_chart_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chart_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chart_control.custom_minimum_size = Vector2(200, 150)
	
	# 添加到图表容器
	if chart_container:
		var chart_panel = chart_container.get_child(0) if chart_container.get_child_count() > 0 else null
		if chart_panel:
			chart_panel.add_child(_chart_control)

# ========== 设置功能 ==========

func _on_settings_save() -> void:
	var singleton = GoGentSingleton.get_instance()
	if singleton.config_manager:
		singleton.config_manager.set_setting("api_key", settings_api_key.text)
		singleton.config_manager.set_setting("api_url", settings_api_url.text)
		singleton.config_manager.set_setting("http_proxy_host", settings_proxy_host.text)
		singleton.config_manager.set_setting("http_proxy_port", settings_proxy_port.text)
		_add_console_message("设置已保存", "success")

# ========== 工具函数 ==========

## 用于场景树查找的标识方法
func is_gogent_main_panel() -> bool:
	return true
