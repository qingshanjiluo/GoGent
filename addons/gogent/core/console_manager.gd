@tool
class_name GoGentConsoleManager
extends RefCounted

class ConsoleMessage:
	var text := ""
	var kind := "info"
	var source := "system"
	var timestamp := 0

	func _init(p_text: String = "", p_kind: String = "info", p_source: String = "system") -> void:
		text = p_text
		kind = p_kind
		source = p_source
		timestamp = Time.get_unix_time_from_system()

var messages: Array[ConsoleMessage] = []
var command_history: Array[String] = []
var max_messages := 1000
var max_command_history := 50
var _commands: Dictionary = {}

func _init() -> void:
	_register_default_commands()

func register_command(name: String, description: String, callback: Callable, args: Array[String] = []) -> void:
	_commands[name] = {"description": description, "callback": callback, "args": args}

func execute_command(input: String) -> String:
	var line := input.strip_edges()
	if line.is_empty():
		return ""
	command_history.append(line)
	while command_history.size() > max_command_history:
		command_history.pop_front()
	var parts := line.split(" ", false)
	var command_name := parts[0].to_lower()
	var args := parts.slice(1)
	add_message("> " + line, "command", "user")
	if not _commands.has(command_name):
		var unknown := "Unknown command '%s'. Type 'help' for available commands." % command_name
		add_message(unknown, "error")
		return unknown
	var result = _commands[command_name]["callback"].call(args)
	if result is String and not result.is_empty():
		add_message(result, "info")
		return result
	return ""

func add_message(text: String, kind: String = "info", source: String = "system") -> void:
	messages.append(ConsoleMessage.new(text, kind, source))
	while messages.size() > max_messages:
		messages.pop_front()
	GoGentSingleton.get_instance().console_message.emit(text, kind)

func clear_messages() -> void:
	messages.clear()

func get_filtered_messages(kind: String = "") -> Array[ConsoleMessage]:
	if kind.is_empty():
		return messages
	var result: Array[ConsoleMessage] = []
	for msg in messages:
		if msg.kind == kind:
			result.append(msg)
	return result

func _register_default_commands() -> void:
	register_command("help", "Show commands.", _cmd_help)
	register_command("clear", "Clear console output.", _cmd_clear)
	register_command("echo", "Print text.", _cmd_echo, ["text"])
	register_command("list_agents", "List configured agents.", _cmd_list_agents)
	register_command("list_models", "List model providers and models.", _cmd_list_models)
	register_command("select_model", "Select a model by provider/model index.", _cmd_select_model, ["supplier_index", "model_index"])
	register_command("ai_settings", "Show current AI request settings.", _cmd_ai_settings)
	register_command("set_ai_option", "Set an AI request option.", _cmd_set_ai_option, ["key", "value"])
	register_command("api_test", "Send a short API request.", _cmd_api_test)
	register_command("external_status", "Check Claude Code and Codex CLI availability.", _cmd_external_status)
	register_command("claude", "Send a prompt to Claude Code CLI.", _cmd_claude, ["prompt"])
	register_command("codex", "Send a prompt to Codex CLI.", _cmd_codex, ["prompt"])
	register_command("train", "Start simulated RL training.", _cmd_train, ["episodes"])
	register_command("stop_train", "Stop training.", _cmd_stop_train)
	register_command("feedback", "Record human training feedback.", _cmd_feedback, ["state_json", "action", "reward", "next_state_json", "done", "note"])
	register_command("editor_info", "Show current Godot editor scene information.", _cmd_editor_info)
	register_command("list_scene_nodes", "List nodes in current or specified scene.", _cmd_list_scene_nodes, ["scene_path"])
	register_command("create_scene", "Create a new scene.", _cmd_create_scene, ["scene_path", "root_node_class"])
	register_command("add_node", "Add a node to the edited scene.", _cmd_add_node, ["node_class", "parent_path", "node_name"])
	register_command("set_node_prop", "Set a node property with Godot str_to_var syntax.", _cmd_set_node_prop, ["node_path", "property", "value"])
	register_command("delete_node", "Delete a node from the edited scene.", _cmd_delete_node, ["node_path"])
	register_command("select_node", "Select a node in the editor.", _cmd_select_node, ["node_path"])
	register_command("attach_script", "Attach a script resource to a node.", _cmd_attach_script, ["node_path", "script_path"])
	register_command("run_test", "Run a scene in the editor.", _cmd_run_test, ["scene_path"])

func _cmd_help(_args: Array[String]) -> String:
	var names := _commands.keys()
	names.sort()
	var text := "Available commands:\n"
	for name in names:
		var command = _commands[name]
		text += "  %s %s - %s\n" % [name, " ".join(command["args"]), command["description"]]
	return text

func _cmd_clear(_args: Array[String]) -> String:
	clear_messages()
	return "Console cleared."

func _cmd_echo(args: Array[String]) -> String:
	return " ".join(args)

func _cmd_list_agents(_args: Array[String]) -> String:
	var manager = GoGentSingleton.get_instance().agent_manager
	if manager == null:
		return "Agent manager is not ready."
	if manager.agents.is_empty():
		return "No agents configured."
	var text := "Agents:\n"
	for i in range(manager.agents.size()):
		var agent = manager.agents[i]
		text += "  [%d] %s - %s (%s)\n" % [i, agent.name, agent.role, "enabled" if agent.enabled else "disabled"]
	return text

func _cmd_list_models(_args: Array[String]) -> String:
	var manager = GoGentSingleton.get_instance().model_manager
	if manager == null:
		return "Model manager is not ready."
	var text := "Models:\n"
	for i in range(manager.suppliers.size()):
		var supplier = manager.suppliers[i]
		text += "  [%d] %s <%s>\n" % [i, supplier.name, supplier.base_url]
		for j in range(supplier.models.size()):
			var model = supplier.models[j]
			var selected := "*" if supplier.id == manager.current_supplier_id and model.id == manager.current_model_id else " "
			text += "    %s[%d] %s (%s)\n" % [selected, j, model.name, model.model_name]
	return text

func _cmd_select_model(args: Array[String]) -> String:
	if args.size() < 2 or not args[0].is_valid_int() or not args[1].is_valid_int():
		return "Usage: select_model <supplier_index> <model_index>"
	var manager = GoGentSingleton.get_instance().model_manager
	if manager == null:
		return "Model manager is not ready."
	var si := args[0].to_int()
	var mi := args[1].to_int()
	if si < 0 or si >= manager.suppliers.size():
		return "Supplier index out of range."
	var supplier = manager.suppliers[si]
	if mi < 0 or mi >= supplier.models.size():
		return "Model index out of range."
	manager.set_current_model(supplier.id, supplier.models[mi].id)
	return "Selected %s / %s." % [supplier.name, supplier.models[mi].name]

func _cmd_ai_settings(_args: Array[String]) -> String:
	var singleton = GoGentSingleton.get_instance()
	var model_manager = singleton.model_manager
	var cfg = singleton.config_manager
	if model_manager == null or cfg == null:
		return "AI settings are not ready."
	var supplier = model_manager.get_current_supplier()
	var model = model_manager.get_current_model()
	return JSON.stringify({
		"supplier": supplier.to_dict() if supplier != null else {},
		"model": model.to_dict() if model != null else {},
		"request": {
			"temperature": cfg.get_setting("default_temperature", 0.7),
			"top_p": cfg.get_setting("default_top_p", 1.0),
			"max_tokens": cfg.get_setting("default_max_tokens", 8192),
			"presence_penalty": cfg.get_setting("default_presence_penalty", 0.0),
			"frequency_penalty": cfg.get_setting("default_frequency_penalty", 0.0),
			"reasoning_enabled": cfg.get_setting("default_reasoning_enabled", true),
			"tools_enabled": cfg.get_setting("default_tools_enabled", true),
			"json_mode": cfg.get_setting("default_json_mode", false),
			"request_timeout": cfg.get_setting("request_timeout", 120)
		}
	}, "\t")

func _cmd_set_ai_option(args: Array[String]) -> String:
	if args.size() < 2:
		return "Usage: set_ai_option <temperature|top_p|max_tokens|presence_penalty|frequency_penalty|reasoning_enabled|tools_enabled|json_mode|request_timeout> <value>"
	var cfg = GoGentSingleton.get_instance().config_manager
	if cfg == null:
		return "Config manager is not ready."
	var key_map := {
		"temperature": "default_temperature",
		"top_p": "default_top_p",
		"max_tokens": "default_max_tokens",
		"presence_penalty": "default_presence_penalty",
		"frequency_penalty": "default_frequency_penalty",
		"reasoning_enabled": "default_reasoning_enabled",
		"tools_enabled": "default_tools_enabled",
		"json_mode": "default_json_mode",
		"request_timeout": "request_timeout"
	}
	var key := args[0].to_lower()
	if not key_map.has(key):
		return "Unknown AI option: %s" % key
	var setting_key: String = key_map[key]
	var raw := " ".join(args.slice(1))
	var value = _parse_setting_value(setting_key, raw)
	cfg.set_setting(setting_key, value)
	return "AI option saved: %s = %s" % [setting_key, str(value)]

func _cmd_api_test(_args: Array[String]) -> String:
	var api = GoGentSingleton.get_instance().api_manager
	if api == null:
		return "API manager is not ready."
	api.send_chat_request([
		{"role": "system", "content": "Reply with exactly: Hello from GoGent"},
		{"role": "user", "content": "health check"}
	])
	return "API test request sent."

func _cmd_external_status(_args: Array[String]) -> String:
	var manager = GoGentSingleton.get_instance().external_tool_manager
	if manager == null:
		return "External tool manager is not ready."
	var status: Dictionary = manager.get_all_status()
	var text := "External tools:\n"
	for tool_id in status.keys():
		var item: Dictionary = status[tool_id]
		text += "  %s: %s\n" % [tool_id, item.get("message", "unknown")]
	return text

func _cmd_claude(args: Array[String]) -> String:
	return _run_external_prompt("claude", args)

func _cmd_codex(args: Array[String]) -> String:
	return _run_external_prompt("codex", args)

func _run_external_prompt(tool_id: String, args: Array[String]) -> String:
	if args.is_empty():
		return "Usage: %s <prompt>" % tool_id
	var manager = GoGentSingleton.get_instance().external_tool_manager
	if manager == null:
		return "External tool manager is not ready."
	var result: Dictionary = manager.run_prompt(tool_id, " ".join(args), "Godot project: %s" % ProjectSettings.globalize_path("res://"))
	return result.get("output", "")

func _cmd_train(args: Array[String]) -> String:
	var episodes := 100
	if not args.is_empty() and args[0].is_valid_int():
		episodes = max(1, args[0].to_int())
	var manager = GoGentSingleton.get_instance().training_manager
	if manager == null:
		return "Training manager is not ready."
	manager.start_training({"episodes": episodes})
	return "Training started for %d episodes." % episodes

func _cmd_stop_train(_args: Array[String]) -> String:
	var manager = GoGentSingleton.get_instance().training_manager
	if manager == null:
		return "Training manager is not ready."
	manager.stop_training()
	return "Training stopped."

func _cmd_feedback(args: Array[String]) -> String:
	if args.size() < 3:
		return "Usage: feedback <state_json> <action> <reward> [next_state_json] [done] [note]"
	var manager = GoGentSingleton.get_instance().training_manager
	if manager == null:
		return "Training manager is not ready."
	var state_vector := _parse_array_arg(args[0])
	if state_vector.is_empty():
		return "state_json must be a JSON array, for example [0.1,0.2,0.3,0.4]."
	if not args[1].is_valid_int() or not args[2].is_valid_float():
		return "action must be int and reward must be float."
	var next_state: Array = state_vector.duplicate()
	if args.size() >= 4:
		var parsed_next := _parse_array_arg(args[3])
		if not parsed_next.is_empty():
			next_state = parsed_next
	var done := false
	if args.size() >= 5:
		done = args[4].to_lower() in ["1", "true", "yes", "done"]
	var note := ""
	if args.size() >= 6:
		note = " ".join(args.slice(5))
	var feedback: Dictionary = manager.record_human_feedback(state_vector, args[1].to_int(), args[2].to_float(), next_state, done, note)
	return "Human feedback recorded: %s" % JSON.stringify(feedback)

func _cmd_editor_info(_args: Array[String]) -> String:
	var manager = GoGentSingleton.get_instance().node_editor_manager
	if manager == null:
		return "Node editor manager is not ready."
	return JSON.stringify(manager.get_editor_info(), "\t")

func _cmd_list_scene_nodes(args: Array[String]) -> String:
	var manager = GoGentSingleton.get_instance().node_editor_manager
	if manager == null:
		return "Node editor manager is not ready."
	var scene_path := args[0] if not args.is_empty() else ""
	var result: Dictionary = manager.list_scene_nodes(scene_path, false)
	if not result.get("success", false):
		return str(result.get("error", "Unable to list scene nodes."))
	var text := "Scene nodes: %s\n" % result.get("scene", "")
	for item in result.get("nodes", []):
		text += "  %s <%s> children=%d script=%s\n" % [item.get("path", "."), item.get("type", ""), int(item.get("child_count", 0)), item.get("script", "")]
	return text

func _cmd_create_scene(args: Array[String]) -> String:
	if args.is_empty():
		return "Usage: create_scene <res://path.tscn> [root_node_class]"
	var manager = GoGentSingleton.get_instance().node_editor_manager
	if manager == null:
		return "Node editor manager is not ready."
	var root_class := args[1] if args.size() >= 2 else "Node2D"
	return _format_tool_result(manager.create_scene(args[0], root_class))

func _cmd_add_node(args: Array[String]) -> String:
	if args.is_empty():
		return "Usage: add_node <node_class> [parent_path] [node_name]"
	var manager = GoGentSingleton.get_instance().node_editor_manager
	if manager == null:
		return "Node editor manager is not ready."
	var parent_path := args[1] if args.size() >= 2 else ""
	var node_name := args[2] if args.size() >= 3 else ""
	return _format_tool_result(manager.add_node(args[0], parent_path, node_name))

func _cmd_set_node_prop(args: Array[String]) -> String:
	if args.size() < 3:
		return "Usage: set_node_prop <node_path> <property> <value>"
	var manager = GoGentSingleton.get_instance().node_editor_manager
	if manager == null:
		return "Node editor manager is not ready."
	var value_text := " ".join(args.slice(2))
	return _format_tool_result(manager.set_node_property(args[0], args[1], value_text))

func _cmd_delete_node(args: Array[String]) -> String:
	if args.is_empty():
		return "Usage: delete_node <node_path>"
	var manager = GoGentSingleton.get_instance().node_editor_manager
	if manager == null:
		return "Node editor manager is not ready."
	return _format_tool_result(manager.delete_node(args[0]))

func _cmd_select_node(args: Array[String]) -> String:
	if args.is_empty():
		return "Usage: select_node <node_path>"
	var manager = GoGentSingleton.get_instance().node_editor_manager
	if manager == null:
		return "Node editor manager is not ready."
	return _format_tool_result(manager.select_node(args[0]))

func _cmd_attach_script(args: Array[String]) -> String:
	if args.size() < 2:
		return "Usage: attach_script <node_path> <script_path>"
	var manager = GoGentSingleton.get_instance().node_editor_manager
	if manager == null:
		return "Node editor manager is not ready."
	return _format_tool_result(manager.attach_script(args[0], args[1]))

func _cmd_run_test(args: Array[String]) -> String:
	if args.is_empty():
		return "Usage: run_test res://path/to/scene.tscn"
	var scene_path := args[0]
	if not ResourceLoader.exists(scene_path):
		return "Scene does not exist: %s" % scene_path
	var plugin := GoGentSingleton.get_instance().editor_plugin
	if plugin == null:
		return "Editor plugin is not available."
	plugin.get_editor_interface().play_custom_scene(scene_path)
	return "Running scene: %s" % scene_path

func _parse_array_arg(text: String) -> Array:
	var parsed = JSON.parse_string(text)
	if parsed is Array:
		return parsed
	return []

func _parse_setting_value(key: String, raw: String):
	match key:
		"default_reasoning_enabled", "default_tools_enabled", "default_json_mode":
			return raw.to_lower() in ["1", "true", "yes", "on", "enabled"]
		"default_max_tokens", "request_timeout":
			return max(1, int(raw))
		_:
			if raw.is_valid_float():
				return raw.to_float()
			return raw

func _format_tool_result(result: Dictionary) -> String:
	var color := "success" if result.get("success", false) else "error"
	return "[%s] %s" % [color, JSON.stringify(result, "\t")]
