@tool
class_name GoGentConsoleManager
extends RefCounted

## 控制台管理器
## 提供游戏内控制台和调试功能

# 控制台消息
class ConsoleMessage:
	var text: String
	var type: String  # info, warning, error, success, system, command
	var timestamp: int
	var source: String  # 消息来源
	
	func _init(p_text: String, p_type: String = "info", p_source: String = "system"):
		text = p_text
		type = p_type
		timestamp = Time.get_unix_time_from_system()
		source = p_source

var messages: Array[ConsoleMessage] = []
var max_messages: int = 1000
var command_history: Array[String] = []
var max_command_history: int = 50

# 命令注册表
var _commands: Dictionary = {}

func _init() -> void:
	_register_default_commands()

func _register_default_commands() -> void:
	register_command("help", "显示帮助信息", _cmd_help)
	register_command("clear", "清除控制台", _cmd_clear)
	register_command("echo", "输出文本", _cmd_echo, ["text"])
	register_command("list_agents", "列出所有 Agent", _cmd_list_agents)
	register_command("list_models", "列出所有模型", _cmd_list_models)
	register_command("run_test", "运行游戏测试", _cmd_run_test, ["scene_path"])
	register_command("train", "启动 AI 训练", _cmd_train, ["episodes"])
	register_command("api_test", "测试 API 连接", _cmd_api_test)
	register_command("godot", "执行 Godot 命令", _cmd_godot, ["command"])

## 注册命令
func register_command(name: String, description: String, callback: Callable, args: Array[String] = []) -> void:
	_commands[name] = {
		"description": description,
		"callback": callback,
		"args": args
	}

## 执行命令
func execute_command(input: String) -> void:
	var parts = input.split(" ", false)
	if parts.is_empty():
		return
	
	var cmd_name = parts[0].to_lower()
	var cmd_args = parts.slice(1)
	
	# 添加到历史
	command_history.append(input)
	if command_history.size() > max_command_history:
		command_history.remove_at(0)
	
	if not _commands.has(cmd_name):
		add_message("未知命令: {0}，输入 'help' 查看可用命令".format([cmd_name]), "error")
		return
	
	var cmd = _commands[cmd_name]
	add_message("> {0}".format([input]), "command")
	
	# 调用回调
	var result = cmd.callback.call(cmd_args)
	if result is String:
		add_message(result, "info")

## 添加消息
func add_message(text: String, type: String = "info", source: String = "system") -> void:
	var msg = ConsoleMessage.new(text, type, source)
	messages.append(msg)
	
	if messages.size() > max_messages:
		messages.remove_at(0)
	
	# 通过单例发送信号
	var singleton = GoGentSingleton.get_instance()
	if singleton:
		singleton.emit_console_message(text, type)

## 清除消息
func clear_messages() -> void:
	messages.clear()
	add_message("控制台已清除", "system")

## 获取过滤后的消息
func get_filtered_messages(filter_type: String = "") -> Array[ConsoleMessage]:
	if filter_type.is_empty():
		return messages
	
	var filtered = []
	for msg in messages:
		if msg.type == filter_type:
			filtered.append(msg)
	return filtered

# ========== 默认命令实现 ==========

func _cmd_help(args: Array[String]) -> String:
	var help_text = "可用命令：\n"
	for cmd_name in _commands.keys():
		var cmd = _commands[cmd_name]
		help_text += "  {0} {1} - {2}\n".format([cmd_name, cmd.args.join(" "), cmd.description])
	return help_text

func _cmd_clear(args: Array[String]) -> String:
	clear_messages()
	return ""

func _cmd_echo(args: Array[String]) -> String:
	return args.join(" ")

func _cmd_list_agents(args: Array[String]) -> String:
	var singleton = GoGentSingleton.get_instance()
	if singleton.agent_manager == null:
		return "Agent 管理器未初始化"
	
	var agents = singleton.agent_manager.agents
	if agents.is_empty():
		return "没有配置 Agent"
	
	var text = "已配置的 Agent：\n"
	for agent in agents:
		var status = "启用" if agent.enabled else "禁用"
		text += "  - {0} ({1}) [{2}]\n".format([agent.name, agent.role, status])
	return text

func _cmd_list_models(args: Array[String]) -> String:
	var singleton = GoGentSingleton.get_instance()
	if singleton.model_manager == null:
		return "模型管理器未初始化"
	
	var suppliers = singleton.model_manager.suppliers
	if suppliers.is_empty():
		return "没有配置模型"
	
	var text = "已配置的模型供应商：\n"
	for supplier in suppliers:
		text += "  {0} ({1}):\n".format([supplier.name, supplier.provider])
		for model in supplier.models:
			var active = "✓" if model.active else " "
			text += "    [{0}] {1} ({2})\n".format([active, model.name, model.model_name])
	return text

func _cmd_run_test(args: Array[String]) -> String:
	if args.is_empty():
		return "请指定场景路径，例如: run_test res://test_scene.tscn"
	
	var scene_path = args[0]
	if not ResourceLoader.exists(scene_path):
		return "场景文件不存在: {0}".format([scene_path])
	
	# 在编辑器中运行场景
	var singleton = GoGentSingleton.get_instance()
	if singleton.editor_plugin:
		singleton.editor_plugin.get_editor_interface().play_custom_scene(scene_path)
		return "正在运行场景: {0}".format([scene_path])
	
	return "无法启动场景测试"

func _cmd_train(args: Array[String]) -> String:
	var episodes = 100
	if not args.is_empty() and args[0].is_valid_int():
		episodes = args[0].to_int()
	
	var singleton = GoGentSingleton.get_instance()
	if singleton.training_manager:
		singleton.training_manager.start_training(episodes)
		return "开始训练，共 {0} 轮次".format([episodes])
	
	return "训练管理器未初始化"

func _cmd_api_test(args: Array[String]) -> String:
	var singleton = GoGentSingleton.get_instance()
	if singleton.api_manager == null:
		return "API 管理器未初始化"
	
	var messages = [
		{"role": "system", "content": "你是一个助手，请回复 'Hello from GoGent!'"},
		{"role": "user", "content": "Say hello"}
	]
	
	singleton.api_manager.send_chat_request(messages)
	return "API 测试请求已发送"

func _cmd_godot(args: Array[String]) -> String:
	if args.is_empty():
		return "请指定 Godot 命令"
	
	var cmd = args.join(" ")
	# 执行 Godot 编辑器命令
	var editor = EditorInterface.get_editor_commands()
	if editor:
		editor.execute(cmd)
		return "执行命令: {0}".format([cmd])
	
	return "无法执行 Godot 命令"
