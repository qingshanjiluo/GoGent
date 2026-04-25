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
	register_command("api_test", "Send a short API request.", _cmd_api_test)
	register_command("train", "Start simulated RL training.", _cmd_train, ["episodes"])
	register_command("stop_train", "Stop training.", _cmd_stop_train)
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

func _cmd_api_test(_args: Array[String]) -> String:
	var api = GoGentSingleton.get_instance().api_manager
	if api == null:
		return "API manager is not ready."
	api.send_chat_request([
		{"role": "system", "content": "Reply with exactly: Hello from GoGent"},
		{"role": "user", "content": "health check"}
	])
	return "API test request sent."

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
