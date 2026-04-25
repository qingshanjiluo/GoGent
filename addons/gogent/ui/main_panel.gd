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
var _console_output: RichTextLabel
var _console_input: LineEdit
var _training_status: Label
var _training_progress: ProgressBar
var _training_episode: Label
var _training_reward: Label
var _training_epsilon: Label
var _chart_holder: PanelContainer
var _settings_api_key: LineEdit
var _settings_api_url: LineEdit
var _settings_proxy_host: LineEdit
var _settings_proxy_port: SpinBox
var _settings_claude_command: LineEdit
var _settings_claude_enabled: CheckButton
var _settings_codex_command: LineEdit
var _settings_codex_enabled: CheckButton

var _messages: Array[Dictionary] = []
var _is_generating := false
var _stream_request_id := -1
var _stream_item: GoGentMessageItem
var _stream_text := ""
var _stream_thinking := ""
var _chart_control: Control

func _ready() -> void:
	if get_child_count() == 0:
		_build_ui()
	_connect_signals()
	refresh_from_managers()

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
	_load_settings()

func _build_ui() -> void:
	anchors_preset = PRESET_FULL_RECT
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	var tabs := HBoxContainer.new()
	root.add_child(tabs)
	_add_tab(tabs, "Chat")
	_add_tab(tabs, "Console")
	_add_tab(tabs, "Training")
	_add_tab(tabs, "Agents")
	_add_tab(tabs, "Settings")

	_containers["Chat"] = _build_chat(root)
	_containers["Console"] = _build_console(root)
	_containers["Training"] = _build_training(root)
	_containers["Agents"] = _build_agents(root)
	_containers["Settings"] = _build_settings(root)
	_show_tab("Chat")

func _add_tab(parent: Control, title: String) -> void:
	var button := Button.new()
	button.text = title
	button.toggle_mode = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

	var model_row := HBoxContainer.new()
	box.add_child(model_row)
	_model_button = OptionButton.new()
	_model_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_model_button.item_selected.connect(_on_model_selected)
	model_row.add_child(_model_button)
	_agent_button = OptionButton.new()
	_agent_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	model_row.add_child(_agent_button)
	var new_button := Button.new()
	new_button.text = "New"
	new_button.pressed.connect(_new_chat)
	model_row.add_child(new_button)
	var collaborate_button := Button.new()
	collaborate_button.text = "Collaborate"
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
	_stream_toggle.text = "Stream"
	_stream_toggle.button_pressed = true
	model_row.add_child(_stream_toggle)

	_welcome = Label.new()
	_welcome.text = "GoGent\nAI chat, agents, console tools, and training monitor."
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
	_user_input.placeholder_text = "Type a message. Enter sends, Shift+Enter inserts a newline."
	_user_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_user_input.gui_input.connect(_on_input_gui)
	input_box.add_child(_user_input)
	_send_button = Button.new()
	_send_button.text = "Send"
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
	_console_output.text = "[color=#42ffc2]GoGent console ready.[/color]\nType help for commands.\n"
	box.add_child(_console_output)
	var row := HBoxContainer.new()
	box.add_child(row)
	_console_input = LineEdit.new()
	_console_input.placeholder_text = "Command"
	_console_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_console_input.text_submitted.connect(func(_text: String): _run_console_command())
	row.add_child(_console_input)
	var run_button := Button.new()
	run_button.text = "Run"
	run_button.pressed.connect(_run_console_command)
	row.add_child(run_button)
	var clear_button := Button.new()
	clear_button.text = "Clear"
	clear_button.pressed.connect(func(): _console_output.text = "")
	row.add_child(clear_button)
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
	return box

func _build_agents(parent: Control) -> Control:
	var panel := AGENT_EDITOR_SCENE.instantiate()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	return panel

func _build_settings(parent: Control) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	_settings_api_key = _line(box, "API Key", true)
	_settings_api_url = _line(box, "Base URL")
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
	return box

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

func _load_settings() -> void:
	var singleton = GoGentSingleton.get_instance()
	var model_manager = singleton.model_manager
	var supplier = model_manager.get_current_supplier() if model_manager else null
	if supplier != null:
		_settings_api_key.text = supplier.api_key
		_settings_api_url.text = supplier.base_url
	var cfg = singleton.config_manager
	if cfg != null:
		_settings_proxy_host.text = str(cfg.get_setting("http_proxy_host", ""))
		_settings_proxy_port.value = int(cfg.get_setting("http_proxy_port", 0))
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
	_add_user_message(text)
	_messages.append({"role": "user", "content": text})
	_welcome.visible = false
	_message_scroll.visible = true
	_is_generating = true
	_send_button.text = "Stop"
	if _stream_toggle.button_pressed:
		var supplier = GoGentSingleton.get_instance().model_manager.get_current_supplier()
		if supplier != null and supplier.provider == "anthropic":
			GoGentSingleton.get_instance().api_manager.send_chat_request(_messages)
		else:
			_start_stream_request()
	else:
		GoGentSingleton.get_instance().api_manager.send_chat_request(_messages)

func _start_stream_request() -> void:
	_stream_text = ""
	_stream_thinking = ""
	_stream_item = _new_message_item()
	_stream_item.set_assistant_message("")
	_stream_request_id = GoGentSingleton.get_instance().api_manager.send_stream_chat_request(_messages)
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
		_add_assistant_message(response, thinking)
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
		_stream_item.set_assistant_message(response, thinking)
	else:
		_stream_item.set_assistant_message("[color=#ff7085]%s[/color]" % response)
	_stream_item = null
	_stream_request_id = -1

func _finish_generation() -> void:
	_is_generating = false
	_send_button.text = "Send"

func _new_chat() -> void:
	_messages.clear()
	for child in _message_list.get_children():
		child.queue_free()
	_welcome.visible = true
	_message_scroll.visible = false

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
	var result: Dictionary = manager.run_prompt(tool_id, text, "Godot project: %s" % ProjectSettings.globalize_path("res://"))
	var prefix := "Claude Code" if tool_id == "claude" else "Codex"
	var color := "#42ffc2" if result.get("success", false) else "#ff7085"
	_add_assistant_message("[color=%s][b]%s[/b][/color]\n%s" % [color, prefix, result.get("output", "")])

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
			"stream_by_default": _stream_toggle.button_pressed,
			"claude_enabled": _settings_claude_enabled.button_pressed,
			"claude_command": _settings_claude_command.text.strip_edges(),
			"codex_enabled": _settings_codex_enabled.button_pressed,
			"codex_command": _settings_codex_command.text.strip_edges()
		})
	if singleton.model_manager:
		singleton.model_manager.set_current_credentials(_settings_api_key.text, _settings_api_url.text)
	if singleton.external_tool_manager:
		singleton.external_tool_manager.load_from_settings()
	_refresh_models()
	GoGentSingleton.print_gogent_console("Settings saved.", "success")

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

func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(92, 0)
	return label
