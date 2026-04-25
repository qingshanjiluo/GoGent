@tool
class_name GoGentExternalToolManager
extends RefCounted

signal tool_completed(tool_name: String, success: bool, output: String)

const DEFAULT_TIMEOUT_MSEC := 120000

class ToolConfig:
	var id := ""
	var name := ""
	var command := ""
	var version_args: Array[String] = []
	var prompt_args: Array[String] = []
	var enabled := true

	func _init(p_id: String = "", p_name: String = "", p_command: String = "", p_prompt_args: Array[String] = []) -> void:
		id = p_id
		name = p_name
		command = p_command
		prompt_args = p_prompt_args

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"command": command,
			"version_args": version_args,
			"prompt_args": prompt_args,
			"enabled": enabled
		}

	static func from_dict(data: Dictionary) -> ToolConfig:
		var tool := ToolConfig.new(data.get("id", ""), data.get("name", ""), data.get("command", ""), [])
		tool.version_args.clear()
		for item in data.get("version_args", []):
			tool.version_args.append(str(item))
		tool.prompt_args.clear()
		for item in data.get("prompt_args", []):
			tool.prompt_args.append(str(item))
		tool.enabled = data.get("enabled", true)
		return tool

var tools: Dictionary = {}

func _init() -> void:
	_load_defaults()
	load_from_settings()

func _load_defaults() -> void:
	var claude := ToolConfig.new("claude", "Claude Code", "claude", ["-p", "{prompt}"])
	claude.version_args = ["--version"]
	tools[claude.id] = claude

	var codex := ToolConfig.new("codex", "Codex CLI", "codex", ["exec", "{prompt}"])
	codex.version_args = ["--version"]
	tools[codex.id] = codex

func load_from_settings() -> void:
	var config = GoGentSingleton.get_instance().config_manager
	if config == null:
		return
	for tool_id in tools.keys():
		var tool: ToolConfig = tools[tool_id]
		tool.command = str(config.get_setting("%s_command" % tool_id, tool.command)).strip_edges()
		tool.enabled = bool(config.get_setting("%s_enabled" % tool_id, tool.enabled))
		var prompt_value = config.get_setting("%s_prompt_args" % tool_id, tool.prompt_args)
		if prompt_value is Array:
			tool.prompt_args.clear()
			for item in prompt_value:
				tool.prompt_args.append(str(item))

func save_tool(tool_id: String, command: String, enabled: bool, prompt_args: Array[String] = []) -> bool:
	if not tools.has(tool_id):
		return false
	var tool: ToolConfig = tools[tool_id]
	tool.command = command.strip_edges()
	tool.enabled = enabled
	if not prompt_args.is_empty():
		tool.prompt_args = prompt_args
	var config = GoGentSingleton.get_instance().config_manager
	if config != null:
		config.set_many({
			"%s_command" % tool_id: tool.command,
			"%s_enabled" % tool_id: tool.enabled,
			"%s_prompt_args" % tool_id: tool.prompt_args
		})
	return true

func get_tool(tool_id: String) -> ToolConfig:
	return tools.get(tool_id, null)

func get_status(tool_id: String) -> Dictionary:
	var tool := get_tool(tool_id)
	if tool == null:
		return {"available": false, "message": "Unknown tool: %s" % tool_id}
	if not tool.enabled:
		return {"available": false, "message": "%s is disabled." % tool.name}
	if tool.command.is_empty():
		return {"available": false, "message": "%s command is empty." % tool.name}
	if not _command_available(tool.command):
		return {"available": false, "message": "%s command '%s' was not found on PATH. Set the command path in Settings." % [tool.name, tool.command]}
	var output: Array = []
	var code := _execute_tool(tool.command, tool.version_args, output)
	var text := "\n".join(output).strip_edges()
	if code == 0:
		return {"available": true, "message": "%s available: %s" % [tool.name, text if not text.is_empty() else "ok"]}
	return {"available": false, "message": "%s not available. Command '%s' returned %d. %s" % [tool.name, tool.command, code, text]}

func get_all_status() -> Dictionary:
	var result := {}
	for tool_id in tools.keys():
		result[tool_id] = get_status(tool_id)
	return result

func run_prompt(tool_id: String, prompt: String, extra_context: String = "") -> Dictionary:
	var tool := get_tool(tool_id)
	if tool == null:
		var missing := "Unknown tool: %s" % tool_id
		tool_completed.emit(tool_id, false, missing)
		return {"success": false, "output": missing, "exit_code": -1}
	if not tool.enabled:
		var disabled := "%s is disabled." % tool.name
		tool_completed.emit(tool_id, false, disabled)
		return {"success": false, "output": disabled, "exit_code": -1}
	if not _command_available(tool.command):
		var unavailable := "%s command '%s' was not found on PATH. Set the command path in Settings." % [tool.name, tool.command]
		tool_completed.emit(tool_id, false, unavailable)
		return {"success": false, "output": unavailable, "exit_code": -1}
	var final_prompt := prompt.strip_edges()
	if not extra_context.strip_edges().is_empty():
		final_prompt += "\n\nContext:\n" + extra_context.strip_edges()
	var args := _render_args(tool.prompt_args, final_prompt)
	var output: Array = []
	var code := _execute_tool(tool.command, args, output)
	var text := "\n".join(output).strip_edges()
	var success := code == 0
	if text.is_empty():
		text = "%s exited with code %d." % [tool.name, code]
	tool_completed.emit(tool_id, success, text)
	return {"success": success, "output": text, "exit_code": code}

func run_claude(prompt: String, extra_context: String = "") -> Dictionary:
	return run_prompt("claude", prompt, extra_context)

func run_codex(prompt: String, extra_context: String = "") -> Dictionary:
	return run_prompt("codex", prompt, extra_context)

func _render_args(template_args: Array[String], prompt: String) -> Array[String]:
	var rendered: Array[String] = []
	for item in template_args:
		rendered.append(item.replace("{prompt}", prompt).replace("{project}", ProjectSettings.globalize_path("res://")))
	return rendered

func _command_available(command: String) -> bool:
	if command.is_absolute_path() and FileAccess.file_exists(command):
		return true
	var output: Array = []
	if OS.get_name() == "Windows":
		return OS.execute("where", [command], output, true, false) == 0
	return OS.execute("which", [command], output, true, false) == 0

func _execute_tool(command: String, args: Array[String], output: Array) -> int:
	if command.is_absolute_path():
		return OS.execute(command, args, output, true, false)
	if OS.get_name() == "Windows":
		var shell_args: Array[String] = ["/C", command]
		shell_args.append_array(args)
		return OS.execute("cmd.exe", shell_args, output, true, false)
	return OS.execute(command, args, output, true, false)
