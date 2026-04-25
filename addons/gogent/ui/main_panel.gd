@tool
class_name GoGentMainPanel
extends Control

const MESSAGE_SCENE := preload("res://addons/gogent/ui/chat/message_item.tscn")
const AGENT_EDITOR_SCENE := preload("res://addons/gogent/ui/agent_editor/agent_editor_panel.tscn")

var _containers: Dictionary = {}
var _tab_buttons: Dictionary = {}
var _message_list: VBoxContainer
var _message_scroll: ScrollContainer
var _welcome: Label
var _user_input: TextEdit
var _send_button: Button
var _stream_toggle: CheckButton
var _model_button: OptionButton
var _agent_button: OptionButton
var _history_button: OptionButton
var _console_output: RichTextLabel
var _console_input: LineEdit
var _scene_output: RichTextLabel
var _scene_path: LineEdit
var _scene_root_class: LineEdit
var _scene_node_class: LineEdit
var _scene_parent_path: LineEdit
var _scene_node_name: LineEdit
var _scene_property_node_path: LineEdit
var _scene_property_name: LineEdit
var _scene_property_value: LineEdit
var _scene_script_node_path: LineEdit
var _scene_script_path: LineEdit
var _training_status: Label
var _training_progress: ProgressBar
var _training_episode: Label
var _training_reward: Label
var _training_epsilon: Label
var _feedback_state: LineEdit
var _feedback_next_state: LineEdit
var _feedback_action: SpinBox
var _feedback_reward: SpinBox
var _feedback_done: CheckBox
var _feedback_note: LineEdit
var _chart_holder: PanelContainer
var _settings_api_key: LineEdit
var _settings_api_url: LineEdit
var _settings_language: OptionButton
var _settings_history_enabled: CheckButton
var _settings_auto_apply_tools: CheckButton
var _settings_auto_continue_tools: CheckButton
var _settings_max_tool_rounds: SpinBox
var _settings_skill_zip_path: LineEdit
var _settings_provider_type: OptionButton
var _settings_model_name: LineEdit
var _settings_model_display_name: LineEdit
var _settings_model_max_tokens: SpinBox
var _settings_model_thinking: CheckButton
var _settings_model_tools: CheckButton
var _settings_model_vision: CheckButton
var _settings_temperature: SpinBox
var _settings_top_p: SpinBox
var _settings_max_tokens: SpinBox
var _settings_presence_penalty: SpinBox
var _settings_frequency_penalty: SpinBox
var _settings_reasoning_enabled: CheckButton
var _settings_tools_enabled: CheckButton
var _settings_json_mode: CheckButton
var _settings_timeout: SpinBox
var _settings_proxy_host: LineEdit
var _settings_proxy_port: SpinBox
var _settings_claude_command: LineEdit
var _settings_claude_enabled: CheckButton
var _settings_codex_command: LineEdit
var _settings_codex_enabled: CheckButton

var _messages: Array[Dictionary] = []
var _is_generating := false
var _stream_request_id := -1
var _auto_tool_round := 0
var _stream_item: GoGentMessageItem
var _stream_text := ""
var _stream_thinking := ""
var _chart_control: Control

func _ready() -> void:
	if get_child_count() == 0:
		_build_ui()
	_connect_signals()
	refresh_from_managers()
	_show_tutorial_if_needed.call_deferred()

func _process(delta: float) -> void:
	var stream = GoGentSingleton.get_instance().stream_manager
	if stream != null and stream.has_active_streams():
		stream.process_streams(delta)
	if _chart_control != null and is_instance_valid(_chart_control):
		_chart_control.queue_redraw()

func is_gogent_main_panel() -> bool:
	return true

func refresh_from_managers() -> void:
	_refresh_models()
	_refresh_agents()
	_refresh_history()
	_load_settings()

func _build_ui() -> void:
	anchors_preset = PRESET_FULL_RECT
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	var tabs := HFlowContainer.new()
	root.add_child(tabs)
	_add_tab(tabs, "Chat", "对话")
	_add_tab(tabs, "Console", "控制台")
	_add_tab(tabs, "Scene", "场景")
	_add_tab(tabs, "Training", "训练")
	_add_tab(tabs, "Agents", "Agent")
	_add_tab(tabs, "Settings", "设置")

	_containers["Chat"] = _build_chat(root)
	_containers["Console"] = _build_console(root)
	_containers["Scene"] = _build_scene(root)
	_containers["Training"] = _build_training(root)
	_containers["Agents"] = _build_agents(root)
	_containers["Settings"] = _build_settings(root)
	_show_tab("Chat")

func _add_tab(parent: Control, title: String, label_text: String) -> void:
	var button := Button.new()
	button.text = label_text
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(92, 0)
	button.pressed.connect(func(): _show_tab(title))
	parent.add_child(button)
	_tab_buttons[title] = button

func _show_tab(title: String) -> void:
	for key in _containers.keys():
		_containers[key].visible = key == title
	for key in _tab_buttons.keys():
		_tab_buttons[key].button_pressed = key == title

func _build_chat(parent: Control) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(box)

	var model_row := HFlowContainer.new()
	box.add_child(model_row)
	_model_button = OptionButton.new()
	_model_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_model_button.item_selected.connect(_on_model_selected)
	model_row.add_child(_model_button)
	_agent_button = OptionButton.new()
	_agent_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	model_row.add_child(_agent_button)
	var new_button := Button.new()
	new_button.text = "新对话"
	new_button.pressed.connect(_new_chat)
	model_row.add_child(new_button)
	_history_button = OptionButton.new()
	_history_button.custom_minimum_size = Vector2(160, 0)
	model_row.add_child(_history_button)
	var load_history_button := Button.new()
	load_history_button.text = "加载历史"
	load_history_button.pressed.connect(_load_selected_history)
	model_row.add_child(load_history_button)
	var collaborate_button := Button.new()
	collaborate_button.text = "协作"
	collaborate_button.pressed.connect(_collaborate)
	model_row.add_child(collaborate_button)
	var claude_button := Button.new()
	claude_button.text = "Claude CLI"
	claude_button.pressed.connect(func(): _send_external_prompt("claude"))
	model_row.add_child(claude_button)
	var codex_button := Button.new()
	codex_button.text = "Codex CLI"
	codex_button.pressed.connect(func(): _send_external_prompt("codex"))
	model_row.add_child(codex_button)
	_stream_toggle = CheckButton.new()
	_stream_toggle.text = "流式"
	_stream_toggle.button_pressed = true
	model_row.add_child(_stream_toggle)

	_welcome = Label.new()
	_welcome.text = "GoGent\n对话、Agent 集群、工具调用、场景编辑和人机训练。"
	_welcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_welcome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_welcome.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_welcome)

	_message_scroll = ScrollContainer.new()
	_message_scroll.visible = false
	_message_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_message_scroll)
	_message_list = VBoxContainer.new()
	_message_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message_scroll.add_child(_message_list)

	var input_panel := PanelContainer.new()
	box.add_child(input_panel)
	var input_box := VBoxContainer.new()
	input_panel.add_child(input_box)
	_user_input = TextEdit.new()
	_user_input.custom_minimum_size = Vector2(0, 84)
	_user_input.placeholder_text = "输入任务。Enter 发送，Shift+Enter 换行。AI 可用 <gogent_tool> 调用项目工具。"
	_user_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_user_input.gui_input.connect(_on_input_gui)
	input_box.add_child(_user_input)
	_send_button = Button.new()
	_send_button.text = "发送"
	_send_button.pressed.connect(_send_message)
	input_box.add_child(_send_button)
	return box

func _build_console(parent: Control) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	_console_output = RichTextLabel.new()
	_console_output.bbcode_enabled = true
	_console_output.scroll_active = true
	_console_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_console_output.text = "[color=#42ffc2]GoGent 控制台已就绪。[/color]\n输入 help 查看命令。\n"
	box.add_child(_console_output)
	var row := HBoxContainer.new()
	box.add_child(row)
	_console_input = LineEdit.new()
	_console_input.placeholder_text = "命令"
	_console_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_console_input.text_submitted.connect(func(_text: String): _run_console_command())
	row.add_child(_console_input)
	var run_button := Button.new()
	run_button.text = "运行"
	run_button.pressed.connect(_run_console_command)
	row.add_child(run_button)
	var clear_button := Button.new()
	clear_button.text = "清空"
	clear_button.pressed.connect(func(): _console_output.text = "")
	row.add_child(clear_button)
	return box

func _build_scene(parent: Control) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	_scene_output = RichTextLabel.new()
	_scene_output.bbcode_enabled = true
	_scene_output.scroll_active = true
	_scene_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scene_output.text = "[color=#42ffc2]场景工具已就绪。[/color]\n"
	box.add_child(_scene_output)

	var scene_row := HBoxContainer.new()
	box.add_child(scene_row)
	_scene_path = _line(scene_row, "场景路径")
	_scene_path.placeholder_text = "res://scenes/demo.tscn"
	_scene_root_class = _line(scene_row, "根节点")
	_scene_root_class.text = "Node2D"
	var create_button := Button.new()
	create_button.text = "创建场景"
	create_button.pressed.connect(_scene_create_scene)
	scene_row.add_child(create_button)
	var list_button := Button.new()
	list_button.text = "列出节点"
	list_button.pressed.connect(_scene_list_nodes)
	scene_row.add_child(list_button)

	var add_row := HBoxContainer.new()
	box.add_child(add_row)
	_scene_node_class = _line(add_row, "节点类型")
	_scene_node_class.text = "Node2D"
	_scene_parent_path = _line(add_row, "父路径")
	_scene_parent_path.placeholder_text = "."
	_scene_node_name = _line(add_row, "节点名")
	var add_button := Button.new()
	add_button.text = "添加节点"
	add_button.pressed.connect(_scene_add_node)
	add_row.add_child(add_button)

	var prop_row := HBoxContainer.new()
	box.add_child(prop_row)
	_scene_property_node_path = _line(prop_row, "节点路径")
	_scene_property_name = _line(prop_row, "属性")
	_scene_property_value = _line(prop_row, "值")
	_scene_property_value.placeholder_text = "\"Player\" / 1.0 / Vector2(10, 20)"
	var prop_button := Button.new()
	prop_button.text = "设置属性"
	prop_button.pressed.connect(_scene_set_property)
	prop_row.add_child(prop_button)

	var script_row := HBoxContainer.new()
	box.add_child(script_row)
	_scene_script_node_path = _line(script_row, "脚本节点")
	_scene_script_path = _line(script_row, "脚本路径")
	_scene_script_path.placeholder_text = "res://scripts/player.gd"
	var script_button := Button.new()
	script_button.text = "挂载脚本"
	script_button.pressed.connect(_scene_attach_script)
	script_row.add_child(script_button)
	return box

func _build_training(parent: Control) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	_training_status = _label("Idle")
	_training_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_training_status)
	_training_progress = ProgressBar.new()
	box.add_child(_training_progress)
	_training_episode = _label("Episode: 0")
	_training_reward = _label("Reward: 0.00")
	_training_epsilon = _label("Epsilon: 1.000")
	box.add_child(_training_episode)
	box.add_child(_training_reward)
	box.add_child(_training_epsilon)
	_chart_holder = PanelContainer.new()
	_chart_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_chart_holder)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	var start_button := Button.new()
	start_button.text = "Start"
	start_button.pressed.connect(_start_training)
	buttons.add_child(start_button)
	var pause_button := Button.new()
	pause_button.text = "Pause"
	pause_button.pressed.connect(func(): GoGentSingleton.get_instance().training_manager.pause_training())
	buttons.add_child(pause_button)
	var resume_button := Button.new()
	resume_button.text = "Resume"
	resume_button.pressed.connect(func(): GoGentSingleton.get_instance().training_manager.resume_training())
	buttons.add_child(resume_button)
	var stop_button := Button.new()
	stop_button.text = "Stop"
	stop_button.pressed.connect(func(): GoGentSingleton.get_instance().training_manager.stop_training())
	buttons.add_child(stop_button)

	var feedback_title := _label("人工反馈")
	box.add_child(feedback_title)
	_feedback_state = _line(box, "状态")
	_feedback_state.text = "[0,0,0,0]"
	_feedback_next_state = _line(box, "下一状态")
	_feedback_next_state.text = "[0,0,0,0]"
	var feedback_row := HBoxContainer.new()
	box.add_child(feedback_row)
	feedback_row.add_child(_label("动作"))
	_feedback_action = SpinBox.new()
	_feedback_action.min_value = 0
	_feedback_action.max_value = 32
	_feedback_action.step = 1
	feedback_row.add_child(_feedback_action)
	feedback_row.add_child(_label("奖励"))
	_feedback_reward = SpinBox.new()
	_feedback_reward.min_value = -1000
	_feedback_reward.max_value = 1000
	_feedback_reward.step = 0.1
	_feedback_reward.value = 1.0
	feedback_row.add_child(_feedback_reward)
	_feedback_done = CheckBox.new()
	_feedback_done.text = "终止"
	feedback_row.add_child(_feedback_done)
	_feedback_note = _line(box, "备注")
	var feedback_button := Button.new()
	feedback_button.text = "记录人工反馈"
	feedback_button.pressed.connect(_record_human_feedback)
	box.add_child(feedback_button)
	return box

func _build_agents(parent: Control) -> Control:
	var panel := AGENT_EDITOR_SCENE.instantiate()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	return panel

func _build_settings(parent: Control) -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	box.add_child(_label("基础设置"))
	var language_row := HBoxContainer.new()
	box.add_child(language_row)
	language_row.add_child(_label("语言"))
	_settings_language = OptionButton.new()
	_settings_language.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_language.add_item("中文")
	_settings_language.set_item_metadata(0, "zh_CN")
	_settings_language.add_item("English")
	_settings_language.set_item_metadata(1, "en_US")
	language_row.add_child(_settings_language)
	_settings_history_enabled = CheckButton.new()
	_settings_history_enabled.text = "保存对话历史"
	box.add_child(_settings_history_enabled)
	_settings_auto_apply_tools = CheckButton.new()
	_settings_auto_apply_tools.text = "自动执行 AI 工具调用"
	box.add_child(_settings_auto_apply_tools)
	_settings_auto_continue_tools = CheckButton.new()
	_settings_auto_continue_tools.text = "工具执行后自动续作"
	box.add_child(_settings_auto_continue_tools)
	_settings_max_tool_rounds = _spin(box, "续作轮数", 1, 20, 1, 4)

	box.add_child(_label("模型供应商"))
	var provider_row := HBoxContainer.new()
	box.add_child(provider_row)
	provider_row.add_child(_label("接口类型"))
	_settings_provider_type = OptionButton.new()
	_settings_provider_type.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in [
		{"id": "deepseek", "name": "DeepSeek"},
		{"id": "openai", "name": "OpenAI"},
		{"id": "openai_compatible", "name": "OpenAI 兼容"},
		{"id": "anthropic", "name": "Anthropic Claude"},
		{"id": "ollama", "name": "Ollama"}
	]:
		_settings_provider_type.add_item(item["name"])
		_settings_provider_type.set_item_metadata(_settings_provider_type.get_item_count() - 1, item["id"])
	provider_row.add_child(_settings_provider_type)
	_settings_api_key = _line(box, "API Key", true)
	_settings_api_url = _line(box, "Base URL")

	box.add_child(_label("当前模型"))
	_settings_model_display_name = _line(box, "显示名称")
	_settings_model_name = _line(box, "模型名")
	_settings_model_max_tokens = _spin(box, "模型上限", 1, 262144, 1, 8192)
	_settings_model_thinking = CheckButton.new()
	_settings_model_thinking.text = "支持推理内容"
	box.add_child(_settings_model_thinking)
	_settings_model_tools = CheckButton.new()
	_settings_model_tools.text = "支持工具调用"
	box.add_child(_settings_model_tools)
	_settings_model_vision = CheckButton.new()
	_settings_model_vision.text = "支持视觉输入"
	box.add_child(_settings_model_vision)
	var add_model_button := Button.new()
	add_model_button.text = "把模型名添加到当前供应商"
	add_model_button.pressed.connect(_add_model_from_settings)
	box.add_child(add_model_button)

	box.add_child(_label("AI 请求参数"))
	_settings_temperature = _spin(box, "温度", 0.0, 2.0, 0.05, 0.7)
	_settings_top_p = _spin(box, "Top P", 0.0, 1.0, 0.05, 1.0)
	_settings_max_tokens = _spin(box, "输出上限", 1, 262144, 1, 8192)
	_settings_presence_penalty = _spin(box, "存在惩罚", -2.0, 2.0, 0.05, 0.0)
	_settings_frequency_penalty = _spin(box, "频率惩罚", -2.0, 2.0, 0.05, 0.0)
	_settings_timeout = _spin(box, "超时秒数", 1, 600, 1, 120)
	_settings_reasoning_enabled = CheckButton.new()
	_settings_reasoning_enabled.text = "启用推理内容适配"
	box.add_child(_settings_reasoning_enabled)
	_settings_tools_enabled = CheckButton.new()
	_settings_tools_enabled.text = "允许工具参数"
	box.add_child(_settings_tools_enabled)
	_settings_json_mode = CheckButton.new()
	_settings_json_mode.text = "JSON 输出模式"
	box.add_child(_settings_json_mode)

	box.add_child(_label("Skill ZIP"))
	_settings_skill_zip_path = _line(box, "ZIP 路径")
	_settings_skill_zip_path.placeholder_text = "C:/skills/godot-skill.zip 或 res://skills.zip"
	var import_skill_button := Button.new()
	import_skill_button.text = "导入 Skill ZIP"
	import_skill_button.pressed.connect(_import_skill_zip)
	box.add_child(import_skill_button)

	_settings_proxy_host = _line(box, "Proxy Host")
	var proxy_row := HBoxContainer.new()
	box.add_child(proxy_row)
	proxy_row.add_child(_label("Proxy Port"))
	_settings_proxy_port = SpinBox.new()
	_settings_proxy_port.min_value = 0
	_settings_proxy_port.max_value = 65535
	_settings_proxy_port.step = 1
	_settings_proxy_port.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	proxy_row.add_child(_settings_proxy_port)

	var sep := HSeparator.new()
	box.add_child(sep)
	box.add_child(_label("External Agent Links"))
	_settings_claude_enabled = CheckButton.new()
	_settings_claude_enabled.text = "Enable Claude Code CLI"
	box.add_child(_settings_claude_enabled)
	_settings_claude_command = _line(box, "Claude Cmd")
	var claude_check := Button.new()
	claude_check.text = "Check Claude"
	claude_check.pressed.connect(func(): _check_external_tool("claude"))
	box.add_child(claude_check)

	_settings_codex_enabled = CheckButton.new()
	_settings_codex_enabled.text = "Enable Codex CLI"
	box.add_child(_settings_codex_enabled)
	_settings_codex_command = _line(box, "Codex Cmd")
	var codex_check := Button.new()
	codex_check.text = "Check Codex"
	codex_check.pressed.connect(func(): _check_external_tool("codex"))
	box.add_child(codex_check)

	var save := Button.new()
	save.text = "Save Settings"
	save.pressed.connect(_save_settings)
	box.add_child(save)
	return scroll

func _connect_signals() -> void:
	var singleton = GoGentSingleton.get_instance()
	if singleton.api_manager != null:
		var api = singleton.api_manager
		if not api.request_completed.is_connected(_on_api_response):
			api.request_completed.connect(_on_api_response)
		if not api.stream_chunk.is_connected(_on_stream_chunk):
			api.stream_chunk.connect(_on_stream_chunk)
		if not api.stream_thinking_chunk.is_connected(_on_stream_thinking):
			api.stream_thinking_chunk.connect(_on_stream_thinking)
		if not api.stream_completed.is_connected(_on_stream_completed):
			api.stream_completed.connect(_on_stream_completed)
	if singleton.console_manager != null and not singleton.console_message.is_connected(_on_console_message):
		singleton.console_message.connect(_on_console_message)
	if singleton.training_manager != null:
		var training = singleton.training_manager
		if not training.training_started.is_connected(_on_training_started):
			training.training_started.connect(_on_training_started)
		if not training.training_episode_completed.is_connected(_on_training_episode):
			training.training_episode_completed.connect(_on_training_episode)
		if not training.training_completed.is_connected(_on_training_completed):
			training.training_completed.connect(_on_training_completed)
		if not training.human_feedback_recorded.is_connected(_on_human_feedback_recorded):
			training.human_feedback_recorded.connect(_on_human_feedback_recorded)

func _refresh_models() -> void:
	if _model_button == null:
		return
	_model_button.clear()
	var manager = GoGentSingleton.get_instance().model_manager
	if manager == null:
		return
	var selected_index := 0
	var index := 0
	for supplier in manager.suppliers:
		for model in supplier.models:
			_model_button.add_item("%s / %s" % [supplier.name, model.name])
			_model_button.set_item_metadata(index, {"supplier_id": supplier.id, "model_id": model.id})
			if supplier.id == manager.current_supplier_id and model.id == manager.current_model_id:
				selected_index = index
			index += 1
	if _model_button.get_item_count() > 0:
		_model_button.select(selected_index)

func _refresh_agents() -> void:
	if _agent_button == null:
		return
	_agent_button.clear()
	var manager = GoGentSingleton.get_instance().agent_manager
	if manager == null:
		return
	for agent in manager.agents:
		_agent_button.add_item(agent.name)
		_agent_button.set_item_metadata(_agent_button.get_item_count() - 1, agent.id)

func _refresh_history() -> void:
	if _history_button == null:
		return
	_history_button.clear()
	var manager = GoGentSingleton.get_instance().conversation_manager
	if manager == null:
		return
	for item in manager.list_conversations():
		_history_button.add_item("%s (%d)" % [item.get("title", item.get("id", "")), int(item.get("message_count", 0))])
		_history_button.set_item_metadata(_history_button.get_item_count() - 1, item.get("id", ""))

func _load_settings() -> void:
	var singleton = GoGentSingleton.get_instance()
	var model_manager = singleton.model_manager
	var supplier = model_manager.get_current_supplier() if model_manager else null
	if supplier != null:
		_settings_api_key.text = supplier.api_key
		_settings_api_url.text = supplier.base_url
		_select_provider_type(supplier.provider)
	var model = model_manager.get_current_model() if model_manager else null
	if model != null:
		_settings_model_display_name.text = model.name
		_settings_model_name.text = model.model_name
		_settings_model_max_tokens.value = model.max_tokens
		_settings_model_thinking.button_pressed = model.supports_thinking
		_settings_model_tools.button_pressed = model.supports_tools
		_settings_model_vision.button_pressed = model.supports_vision
	var cfg = singleton.config_manager
	if cfg != null:
		_select_language(str(cfg.get_setting("language", "zh_CN")))
		_settings_history_enabled.button_pressed = bool(cfg.get_setting("conversation_history_enabled", true))
		_settings_auto_apply_tools.button_pressed = bool(cfg.get_setting("auto_apply_tool_calls", true))
		_settings_auto_continue_tools.button_pressed = bool(cfg.get_setting("auto_continue_tool_calls", true))
		_settings_max_tool_rounds.value = int(cfg.get_setting("max_auto_tool_rounds", 4))
		_settings_proxy_host.text = str(cfg.get_setting("http_proxy_host", ""))
		_settings_proxy_port.value = int(cfg.get_setting("http_proxy_port", 0))
		_settings_temperature.value = float(cfg.get_setting("default_temperature", 0.7))
		_settings_top_p.value = float(cfg.get_setting("default_top_p", 1.0))
		_settings_max_tokens.value = int(cfg.get_setting("default_max_tokens", 8192))
		_settings_presence_penalty.value = float(cfg.get_setting("default_presence_penalty", 0.0))
		_settings_frequency_penalty.value = float(cfg.get_setting("default_frequency_penalty", 0.0))
		_settings_reasoning_enabled.button_pressed = bool(cfg.get_setting("default_reasoning_enabled", true))
		_settings_tools_enabled.button_pressed = bool(cfg.get_setting("default_tools_enabled", true))
		_settings_json_mode.button_pressed = bool(cfg.get_setting("default_json_mode", false))
		_settings_timeout.value = int(cfg.get_setting("request_timeout", 120))
		_stream_toggle.button_pressed = bool(cfg.get_setting("stream_by_default", true))
		_settings_claude_enabled.button_pressed = bool(cfg.get_setting("claude_enabled", true))
		_settings_claude_command.text = str(cfg.get_setting("claude_command", "claude"))
		_settings_codex_enabled.button_pressed = bool(cfg.get_setting("codex_enabled", true))
		_settings_codex_command.text = str(cfg.get_setting("codex_command", "codex"))

func _on_model_selected(index: int) -> void:
	var meta: Dictionary = _model_button.get_item_metadata(index)
	GoGentSingleton.get_instance().model_manager.set_current_model(meta["supplier_id"], meta["model_id"])
	_load_settings()

func _send_message() -> void:
	if _is_generating:
		_cancel_generation()
		return
	var text := _user_input.text.strip_edges()
	if text.is_empty():
		return
	_user_input.text = ""
	_auto_tool_round = 0
	_add_user_message(text)
	_messages.append({"role": "user", "content": text})
	_save_conversation_message("user", text)
	_welcome.visible = false
	_message_scroll.visible = true
	_is_generating = true
	_send_button.text = "Stop"
	var request_messages := _build_request_messages()
	if _stream_toggle.button_pressed:
		var supplier = GoGentSingleton.get_instance().model_manager.get_current_supplier()
		if supplier != null and supplier.provider == "anthropic":
			GoGentSingleton.get_instance().api_manager.send_chat_request(request_messages)
		else:
			_start_stream_request(request_messages)
	else:
		GoGentSingleton.get_instance().api_manager.send_chat_request(request_messages)

func _start_stream_request(request_messages: Array[Dictionary]) -> void:
	_stream_text = ""
	_stream_thinking = ""
	_stream_item = _new_message_item()
	_stream_item.set_assistant_message("")
	_stream_request_id = GoGentSingleton.get_instance().api_manager.send_stream_chat_request(request_messages)
	if _stream_request_id < 0:
		_finish_generation()
		_stream_item.set_assistant_message("[color=#ff7085]Unable to start stream request.[/color]")

func _cancel_generation() -> void:
	GoGentSingleton.get_instance().api_manager.cancel_request()
	_finish_generation()

func _on_api_response(success: bool, response: String, thinking: String) -> void:
	_finish_generation()
	if success:
		_messages.append({"role": "assistant", "content": response})
		_save_conversation_message("assistant", response, {"thinking": thinking})
		_add_assistant_message(response, thinking)
		_process_tool_calls(response)
	else:
		_add_assistant_message("[color=#ff7085]%s[/color]" % response)

func _on_stream_chunk(chunk: String, request_id: int) -> void:
	if request_id != _stream_request_id:
		return
	_stream_text += chunk
	_stream_item.set_assistant_message(_stream_text, _stream_thinking)
	_scroll_to_bottom()

func _on_stream_thinking(chunk: String, request_id: int) -> void:
	if request_id != _stream_request_id:
		return
	_stream_thinking += chunk
	_stream_item.set_assistant_message(_stream_text, _stream_thinking)

func _on_stream_completed(success: bool, response: String, thinking: String, request_id: int) -> void:
	if request_id != _stream_request_id:
		return
	_finish_generation()
	if success:
		_messages.append({"role": "assistant", "content": response})
		_save_conversation_message("assistant", response, {"thinking": thinking})
		_stream_item.set_assistant_message(response, thinking)
		_process_tool_calls(response)
	else:
		_stream_item.set_assistant_message("[color=#ff7085]%s[/color]" % response)
	_stream_item = null
	_stream_request_id = -1

func _finish_generation() -> void:
	_is_generating = false
	_send_button.text = "发送"

func _new_chat() -> void:
	_messages.clear()
	var conversation = GoGentSingleton.get_instance().conversation_manager
	if conversation != null:
		conversation.new_conversation()
	for child in _message_list.get_children():
		child.queue_free()
	_welcome.visible = true
	_message_scroll.visible = false
	_refresh_history()

func _collaborate() -> void:
	var text := _user_input.text.strip_edges()
	if text.is_empty():
		return
	var manager = GoGentSingleton.get_instance().agent_manager
	var ids: Array[String] = []
	for agent in manager.agents:
		if agent.enabled:
			ids.append(agent.id)
	var tasks = manager.collaborate(text, ids)
	_add_user_message(text + " [collaboration]")
	for task in tasks:
		_add_assistant_message("[b]%s[/b]\nPrepared %d messages for this agent. Send each agent independently by selecting it from the agent list." % [task["agent_name"], task["messages"].size()])
	_welcome.visible = false
	_message_scroll.visible = true
	_user_input.text = ""

func _send_external_prompt(tool_id: String) -> void:
	var text := _user_input.text.strip_edges()
	if text.is_empty():
		return
	var manager = GoGentSingleton.get_instance().external_tool_manager
	if manager == null:
		_add_assistant_message("[color=#ff7085]External tool manager is not ready.[/color]")
		return
	_user_input.text = ""
	_welcome.visible = false
	_message_scroll.visible = true
	_add_user_message(text + " [%s]" % tool_id)
	_save_conversation_message("user", text + " [%s]" % tool_id)
	var result: Dictionary = manager.run_prompt(tool_id, text, "Godot project: %s" % ProjectSettings.globalize_path("res://"))
	var prefix := "Claude Code" if tool_id == "claude" else "Codex"
	var color := "#42ffc2" if result.get("success", false) else "#ff7085"
	var output := "[color=%s][b]%s[/b][/color]\n%s" % [color, prefix, result.get("output", "")]
	_add_assistant_message(output)
	_save_conversation_message("assistant", output)

func _build_request_messages() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var system_prompt := _build_tool_system_prompt()
	if not system_prompt.is_empty():
		result.append({"role": "system", "content": system_prompt})
	result.append_array(_messages)
	return result

func _build_tool_system_prompt() -> String:
	var tools = GoGentSingleton.get_instance().workspace_tool_manager
	if tools == null:
		return ""
	var lines := PackedStringArray()
	lines.append("你正在 Godot 编辑器插件 GoGent 中工作。你可以像 RooCode 一样先观察项目、再计划、再调用工具真实修改项目。")
	lines.append("需要调用工具时，请输出一个或多个 <gogent_tool>{\"tool\":\"工具名\",\"args\":{...}}</gogent_tool> 标签。工具执行结果会回填到对话中，你可以继续工作。")
	lines.append("可用工具：")
	for tool in tools.get_tool_manifest():
		lines.append("- %s：%s" % [tool.get("name", ""), tool.get("description", "")])
	lines.append("重要：write_file 和 append_file 会真实修改 Godot 项目文件；console 可以调用场景编辑、训练、Claude/Codex 外部 Agent 等命令。")
	return "\n".join(lines)

func _process_tool_calls(response: String) -> void:
	var cfg = GoGentSingleton.get_instance().config_manager
	if cfg == null or not bool(cfg.get_setting("auto_apply_tool_calls", true)):
		return
	var calls := _extract_tool_calls(response)
	if calls.is_empty():
		_auto_tool_round = 0
		return
	var tools = GoGentSingleton.get_instance().workspace_tool_manager
	if tools == null:
		return
	var results: Array[Dictionary] = []
	for call in calls:
		var result: Dictionary = tools.execute_tool_call(call)
		results.append({"call": call, "result": result})
	var text := "工具执行结果：\n" + JSON.stringify(results, "\t")
	_add_assistant_message("[color=#42ffc2]工具执行完成[/color]\n" + text)
	_messages.append({"role": "user", "content": text})
	_save_conversation_message("tool", text, {"results": results})
	if bool(cfg.get_setting("auto_continue_tool_calls", true)) and _auto_tool_round < int(cfg.get_setting("max_auto_tool_rounds", 4)):
		_auto_tool_round += 1
		_is_generating = true
		_send_button.text = "Stop"
		GoGentSingleton.get_instance().api_manager.send_chat_request(_build_request_messages())
	else:
		_auto_tool_round = 0

func _extract_tool_calls(text: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var start := text.find("<gogent_tool>")
	while start >= 0:
		var content_start := start + "<gogent_tool>".length()
		var end := text.find("</gogent_tool>", content_start)
		if end < 0:
			break
		var payload := text.substr(content_start, end - content_start).strip_edges()
		var parsed = JSON.parse_string(payload)
		if parsed is Dictionary:
			result.append(parsed)
		start = text.find("<gogent_tool>", end + "</gogent_tool>".length())
	return result

func _save_conversation_message(role: String, content: String, meta: Dictionary = {}) -> void:
	var manager = GoGentSingleton.get_instance().conversation_manager
	if manager != null:
		manager.add_message(role, content, meta)
		_refresh_history()

func _load_selected_history() -> void:
	if _history_button == null or _history_button.get_item_count() == 0:
		return
	var manager = GoGentSingleton.get_instance().conversation_manager
	if manager == null:
		return
	var id := str(_history_button.get_item_metadata(_history_button.selected))
	if not manager.load_conversation(id):
		return
	_messages.clear()
	for child in _message_list.get_children():
		child.queue_free()
	for item in manager.messages:
		var role := str(item.get("role", ""))
		var content := str(item.get("content", ""))
		if role == "user":
			_messages.append({"role": "user", "content": content})
			_add_user_message(content)
		elif role == "assistant":
			_messages.append({"role": "assistant", "content": content})
			_add_assistant_message(content, str(item.get("meta", {}).get("thinking", "")))
		elif role == "tool":
			_messages.append({"role": "user", "content": content})
			_add_assistant_message("[color=#42ffc2]历史工具结果[/color]\n" + content)
	_welcome.visible = _messages.is_empty()
	_message_scroll.visible = not _messages.is_empty()

func _add_user_message(text: String) -> void:
	var item := _new_message_item()
	item.set_user_message(text)
	_scroll_to_bottom()

func _add_assistant_message(text: String, thinking: String = "") -> void:
	var item := _new_message_item()
	item.set_assistant_message(text, thinking)
	_scroll_to_bottom()

func _new_message_item() -> GoGentMessageItem:
	var item: GoGentMessageItem = MESSAGE_SCENE.instantiate()
	_message_list.add_child(item)
	return item

func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	var bar := _message_scroll.get_v_scroll_bar()
	if bar != null:
		bar.value = bar.max_value

func _run_console_command() -> void:
	var text := _console_input.text.strip_edges()
	if text.is_empty():
		return
	_console_input.text = ""
	var result = GoGentSingleton.get_instance().console_manager.execute_command(text)
	if result.is_empty():
		return

func _on_console_message(message: String, kind: String) -> void:
	var color := {
		"info": "#abc9ff",
		"success": "#42ffc2",
		"warning": "#ffb373",
		"error": "#ff7085",
		"command": "#ffffff",
		"system": "#ffeda1"
	}.get(kind, "#abc9ff")
	_console_output.append_text("[color=%s][%s] %s[/color]\n" % [color, kind.to_upper(), message])
	_console_output.scroll_to_line(max(0, _console_output.get_line_count() - 1))

func _scene_create_scene() -> void:
	var manager = GoGentSingleton.get_instance().node_editor_manager
	if manager == null:
		_scene_append({"success": false, "error": "节点编辑管理器未就绪。"})
		return
	_scene_append(manager.create_scene(_scene_path.text.strip_edges(), _scene_root_class.text.strip_edges()))

func _scene_list_nodes() -> void:
	var manager = GoGentSingleton.get_instance().node_editor_manager
	if manager == null:
		_scene_append({"success": false, "error": "节点编辑管理器未就绪。"})
		return
	var result: Dictionary = manager.list_scene_nodes(_scene_path.text.strip_edges(), false)
	if not result.get("success", false):
		_scene_append(result)
		return
	_scene_output.append_text("[color=#42ffc2]场景：%s[/color]\n" % result.get("scene", ""))
	for item in result.get("nodes", []):
		_scene_output.append_text("  %s <%s> children=%d script=%s\n" % [item.get("path", "."), item.get("type", ""), int(item.get("child_count", 0)), item.get("script", "")])
	_scene_output.scroll_to_line(max(0, _scene_output.get_line_count() - 1))

func _scene_add_node() -> void:
	var manager = GoGentSingleton.get_instance().node_editor_manager
	if manager == null:
		_scene_append({"success": false, "error": "节点编辑管理器未就绪。"})
		return
	_scene_append(manager.add_node(_scene_node_class.text.strip_edges(), _scene_parent_path.text.strip_edges(), _scene_node_name.text.strip_edges(), _scene_path.text.strip_edges()))

func _scene_set_property() -> void:
	var manager = GoGentSingleton.get_instance().node_editor_manager
	if manager == null:
		_scene_append({"success": false, "error": "节点编辑管理器未就绪。"})
		return
	_scene_append(manager.set_node_property(_scene_property_node_path.text.strip_edges(), _scene_property_name.text.strip_edges(), _scene_property_value.text.strip_edges(), _scene_path.text.strip_edges()))

func _scene_attach_script() -> void:
	var manager = GoGentSingleton.get_instance().node_editor_manager
	if manager == null:
		_scene_append({"success": false, "error": "节点编辑管理器未就绪。"})
		return
	_scene_append(manager.attach_script(_scene_script_node_path.text.strip_edges(), _scene_script_path.text.strip_edges(), _scene_path.text.strip_edges()))

func _scene_append(result: Dictionary) -> void:
	var color := "#42ffc2" if result.get("success", false) else "#ff7085"
	_scene_output.append_text("[color=%s]%s[/color]\n" % [color, JSON.stringify(result, "\t")])
	_scene_output.scroll_to_line(max(0, _scene_output.get_line_count() - 1))

func _start_training() -> void:
	GoGentSingleton.get_instance().training_manager.start_training()

func _on_training_started(_config: Dictionary) -> void:
	_training_status.text = "Running"
	_training_progress.value = 0
	_ensure_chart()

func _on_training_episode(episode: int, reward: float, epsilon: float) -> void:
	var training = GoGentSingleton.get_instance().training_manager
	_training_episode.text = "Episode: %d" % episode
	_training_reward.text = "Reward: %.2f" % reward
	_training_epsilon.text = "Epsilon: %.3f" % epsilon
	_training_progress.value = float(episode) / max(1.0, float(training.config.episodes)) * 100.0
	_ensure_chart()

func _on_training_completed(stats: Dictionary) -> void:
	_training_status.text = "Completed avg %.2f" % float(stats.get("avg_reward", 0.0))
	_training_progress.value = 100

func _record_human_feedback() -> void:
	var manager = GoGentSingleton.get_instance().training_manager
	if manager == null:
		GoGentSingleton.print_gogent_console("训练管理器未就绪。", "error")
		return
	var state_vector := _parse_json_array(_feedback_state.text)
	var next_state := _parse_json_array(_feedback_next_state.text)
	if state_vector.is_empty():
		GoGentSingleton.print_gogent_console("人工反馈状态必须是 JSON 数组。", "error")
		return
	manager.record_human_feedback(state_vector, int(_feedback_action.value), float(_feedback_reward.value), next_state, _feedback_done.button_pressed, _feedback_note.text)

func _on_human_feedback_recorded(action: int, reward: float, note: String) -> void:
	_training_status.text = "已记录人工反馈 action=%d reward=%.2f" % [action, reward]
	_training_reward.text = "Reward: %.2f" % reward
	if not note.is_empty():
		GoGentSingleton.print_gogent_console("人工反馈: " + note, "success")
	_ensure_chart()

func _parse_json_array(text: String) -> Array:
	var parsed = JSON.parse_string(text.strip_edges())
	if parsed is Array:
		return parsed
	return []

func _ensure_chart() -> void:
	if _chart_control != null and is_instance_valid(_chart_control):
		return
	for child in _chart_holder.get_children():
		child.queue_free()
	_chart_control = GoGentSingleton.get_instance().training_manager.visualizer.create_chart_control()
	_chart_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chart_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chart_holder.add_child(_chart_control)

func _save_settings() -> void:
	var singleton = GoGentSingleton.get_instance()
	if singleton.config_manager:
		singleton.config_manager.set_many({
			"http_proxy_host": _settings_proxy_host.text.strip_edges(),
			"http_proxy_port": int(_settings_proxy_port.value),
			"language": _get_selected_language(),
			"conversation_history_enabled": _settings_history_enabled.button_pressed,
			"auto_apply_tool_calls": _settings_auto_apply_tools.button_pressed,
			"auto_continue_tool_calls": _settings_auto_continue_tools.button_pressed,
			"max_auto_tool_rounds": int(_settings_max_tool_rounds.value),
			"default_temperature": float(_settings_temperature.value),
			"default_top_p": float(_settings_top_p.value),
			"default_max_tokens": int(_settings_max_tokens.value),
			"default_presence_penalty": float(_settings_presence_penalty.value),
			"default_frequency_penalty": float(_settings_frequency_penalty.value),
			"default_reasoning_enabled": _settings_reasoning_enabled.button_pressed,
			"default_tools_enabled": _settings_tools_enabled.button_pressed,
			"default_json_mode": _settings_json_mode.button_pressed,
			"request_timeout": int(_settings_timeout.value),
			"stream_by_default": _stream_toggle.button_pressed,
			"claude_enabled": _settings_claude_enabled.button_pressed,
			"claude_command": _settings_claude_command.text.strip_edges(),
			"codex_enabled": _settings_codex_enabled.button_pressed,
			"codex_command": _settings_codex_command.text.strip_edges()
		})
	if singleton.model_manager:
		singleton.model_manager.update_current_supplier({
			"api_key": _settings_api_key.text,
			"base_url": _settings_api_url.text,
			"provider": _get_selected_provider_type()
		})
		singleton.model_manager.update_current_model({
			"name": _settings_model_display_name.text,
			"model_name": _settings_model_name.text,
			"max_tokens": int(_settings_model_max_tokens.value),
			"supports_thinking": _settings_model_thinking.button_pressed,
			"supports_tools": _settings_model_tools.button_pressed,
			"supports_vision": _settings_model_vision.button_pressed
		})
	if singleton.external_tool_manager:
		singleton.external_tool_manager.load_from_settings()
	_refresh_models()
	GoGentSingleton.print_gogent_console("Settings saved.", "success")

func _add_model_from_settings() -> void:
	var singleton = GoGentSingleton.get_instance()
	if singleton.model_manager == null:
		GoGentSingleton.print_gogent_console("模型管理器未就绪。", "error")
		return
	var model_name := _settings_model_name.text.strip_edges()
	if model_name.is_empty():
		GoGentSingleton.print_gogent_console("模型名不能为空。", "error")
		return
	var ok: bool = singleton.model_manager.add_model_to_current(
		model_name,
		_settings_model_display_name.text.strip_edges(),
		int(_settings_model_max_tokens.value),
		_settings_model_thinking.button_pressed,
		_settings_model_tools.button_pressed,
		_settings_model_vision.button_pressed
	)
	_refresh_models()
	GoGentSingleton.print_gogent_console("模型已添加。" if ok else "模型添加失败。", "success" if ok else "error")

func _import_skill_zip() -> void:
	var manager = GoGentSingleton.get_instance().skill_manager
	if manager == null:
		GoGentSingleton.print_gogent_console("Skill 管理器未就绪。", "error")
		return
	var result: Dictionary = manager.import_skill_zip(_settings_skill_zip_path.text.strip_edges())
	GoGentSingleton.print_gogent_console(JSON.stringify(result), "success" if result.get("success", false) else "error")

func _get_selected_provider_type() -> String:
	if _settings_provider_type == null or _settings_provider_type.get_selected_id() < 0:
		return "openai"
	var meta = _settings_provider_type.get_item_metadata(_settings_provider_type.selected)
	return str(meta)

func _get_selected_language() -> String:
	if _settings_language == null:
		return "zh_CN"
	return str(_settings_language.get_item_metadata(_settings_language.selected))

func _select_language(language: String) -> void:
	if _settings_language == null:
		return
	for i in range(_settings_language.get_item_count()):
		if str(_settings_language.get_item_metadata(i)) == language:
			_settings_language.select(i)
			return

func _select_provider_type(provider: String) -> void:
	if _settings_provider_type == null:
		return
	for i in range(_settings_provider_type.get_item_count()):
		if str(_settings_provider_type.get_item_metadata(i)) == provider:
			_settings_provider_type.select(i)
			return

func _show_tutorial_if_needed() -> void:
	var cfg = GoGentSingleton.get_instance().config_manager
	if cfg == null or bool(cfg.get_setting("tutorial_seen", false)):
		return
	var dialog := AcceptDialog.new()
	dialog.title = "GoGent 使用教程"
	dialog.min_size = Vector2(620, 460)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.text = "[b]欢迎使用 GoGent[/b]\n\n1. 在设置中选择语言、模型供应商、API Key、代理和 Claude/Codex 命令。\n2. 在对话页输入任务，AI 可以通过 <gogent_tool> 调用工具读取/写入项目文件。\n3. 在场景页可以创建场景、添加节点、设置属性和挂载脚本。\n4. 在训练页可以启动训练并记录人工反馈。\n5. 通过 Skill ZIP 可以导入新的技能模板。\n\n默认语言为中文；教程只会在第一次打开时显示。"
	dialog.add_child(text)
	add_child(dialog)
	dialog.confirmed.connect(func():
		cfg.set_setting("tutorial_seen", true)
		dialog.queue_free()
	)
	dialog.canceled.connect(func():
		cfg.set_setting("tutorial_seen", true)
		dialog.queue_free()
	)
	dialog.popup_centered()

func _check_external_tool(tool_id: String) -> void:
	var manager = GoGentSingleton.get_instance().external_tool_manager
	if manager == null:
		GoGentSingleton.print_gogent_console("External tool manager is not ready.", "error")
		return
	if tool_id == "claude":
		manager.save_tool("claude", _settings_claude_command.text, _settings_claude_enabled.button_pressed)
	elif tool_id == "codex":
		manager.save_tool("codex", _settings_codex_command.text, _settings_codex_enabled.button_pressed)
	var status: Dictionary = manager.get_status(tool_id)
	GoGentSingleton.print_gogent_console(status.get("message", "unknown"), "success" if status.get("available", false) else "warning")

func _on_input_gui(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		var enter: bool = event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER
		if enter and not event.shift_pressed:
			accept_event()
			_send_message()

func _line(parent: Control, label_text: String, secret: bool = false) -> LineEdit:
	var row := HBoxContainer.new()
	parent.add_child(row)
	row.add_child(_label(label_text))
	var line := LineEdit.new()
	line.secret = secret
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(line)
	return line

func _spin(parent: Control, label_text: String, min_value: float, max_value: float, step: float, default_value: float) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)
	row.add_child(_label(label_text))
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.value = default_value
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spin)
	return spin

func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(92, 0)
	return label
