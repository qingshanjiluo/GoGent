@tool
class_name GoGentAgentManager
extends RefCounted

const AGENTS_FILE := "res://addons/gogent/config/agents.json"

class AgentConfig:
	var id := ""
	var name := ""
	var role := ""
	var system_prompt := ""
	var model_id := ""
	var supplier_id := ""
	var temperature := 0.7
	var max_tokens := 8192
	var enabled := true
	var auto_respond := false
	var skills: Array[String] = []

	func _init(p_name: String = "", p_role: String = "") -> void:
		id = "agent_%d_%d" % [Time.get_unix_time_from_system(), randi()]
		name = p_name
		role = p_role

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"role": role,
			"system_prompt": system_prompt,
			"model_id": model_id,
			"supplier_id": supplier_id,
			"temperature": temperature,
			"max_tokens": max_tokens,
			"enabled": enabled,
			"auto_respond": auto_respond,
			"skills": skills
		}

	static func from_dict(data: Dictionary) -> AgentConfig:
		var agent := AgentConfig.new(data.get("name", ""), data.get("role", ""))
		agent.id = data.get("id", agent.id)
		agent.system_prompt = data.get("system_prompt", "")
		agent.model_id = data.get("model_id", "")
		agent.supplier_id = data.get("supplier_id", "")
		agent.temperature = float(data.get("temperature", 0.7))
		agent.max_tokens = int(data.get("max_tokens", 8192))
		agent.enabled = data.get("enabled", true)
		agent.auto_respond = data.get("auto_respond", false)
		agent.skills.clear()
		for skill in data.get("skills", []):
			agent.skills.append(str(skill))
		return agent

class AgentSession:
	var agent_id := ""
	var messages: Array[Dictionary] = []
	var created_at := 0
	var updated_at := 0

	func _init(p_agent_id: String = "") -> void:
		agent_id = p_agent_id
		created_at = Time.get_unix_time_from_system()
		updated_at = created_at

var agents: Array[AgentConfig] = []
var sessions: Dictionary = {}
var collaboration_enabled := true

func _init() -> void:
	_ensure_dir()
	load_agents()
	if agents.is_empty():
		_add_default_agents()
	else:
		_ensure_builtin_agents()

func _ensure_dir() -> void:
	var dir := AGENTS_FILE.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

func _add_default_agents() -> void:
	agents.clear()
	_add_default_agent("代码工程师", "Godot 4 开发专家", "你是资深 Godot 4 工程师。你负责 GDScript、编辑器插件、节点树结构、调试和可维护性，并且会优先给出能直接执行的修改步骤。", ["code_review"])
	_add_default_agent("场景编辑师", "Godot 场景与节点专家", "你负责创建场景、规划节点层级、设置节点属性、挂载脚本和整理编辑器工作流。回答时优先给出 GoGent Scene 面板或 Console 可执行的命令。", ["project_scaffold", "game_design"])
	_add_default_agent("游戏策划", "玩法和系统设计专家", "你负责机制、数值、关卡、反馈循环、玩家体验和内容节奏，并会把设计建议转化为 Godot 可实现的节点和脚本任务。", ["game_design"])
	_add_default_agent("测试工程师", "QA 与自动化测试专家", "你负责测试计划、边界条件、性能风险、Godot 无头测试和可复现 Bug 报告。", ["game_testing"])
	_add_default_agent("AI 训练师", "强化学习与人机训练专家", "你负责设计状态、动作、奖励、人工反馈、人机训练流程和评估指标，并会给出可记录到 GoGent Training 的反馈样本。", ["ai_training"])
	save_agents()

func _ensure_builtin_agents() -> void:
	var names := {}
	for agent in agents:
		names[agent.name] = true
	if not names.has("场景编辑师"):
		_add_default_agent("场景编辑师", "Godot 场景与节点专家", "你负责创建场景、规划节点层级、设置节点属性、挂载脚本和整理编辑器工作流。回答时优先给出 GoGent Scene 面板或 Console 可执行的命令。", ["project_scaffold", "game_design"])
	if not names.has("AI 训练师"):
		_add_default_agent("AI 训练师", "强化学习与人机训练专家", "你负责设计状态、动作、奖励、人工反馈、人机训练流程和评估指标，并会给出可记录到 GoGent Training 的反馈样本。", ["ai_training"])
	save_agents()

func _add_default_agent(name: String, role: String, prompt: String, default_skills: Array[String]) -> void:
	var agent := AgentConfig.new(name, role)
	agent.system_prompt = prompt
	agent.skills = default_skills
	agents.append(agent)

func load_agents() -> void:
	if not FileAccess.file_exists(AGENTS_FILE):
		return
	var text := FileAccess.get_file_as_string(AGENTS_FILE)
	if FileAccess.get_open_error() != OK:
		return
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return
	agents.clear()
	for item in parsed.get("agents", []):
		if item is Dictionary:
			agents.append(AgentConfig.from_dict(item))

func save_agents() -> bool:
	_ensure_dir()
	var data := {"agents": []}
	for agent in agents:
		data["agents"].append(agent.to_dict())
	var file := FileAccess.open(AGENTS_FILE, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

func add_agent(agent: AgentConfig) -> void:
	agents.append(agent)
	save_agents()
	GoGentSingleton.get_instance().agents_changed.emit()

func update_agent(agent_id: String, values: Dictionary) -> bool:
	var agent := get_agent(agent_id)
	if agent == null:
		return false
	for key in values.keys():
		match key:
			"name":
				agent.name = values[key]
			"role":
				agent.role = values[key]
			"system_prompt":
				agent.system_prompt = values[key]
			"temperature":
				agent.temperature = float(values[key])
			"max_tokens":
				agent.max_tokens = int(values[key])
			"enabled":
				agent.enabled = values[key]
			"auto_respond":
				agent.auto_respond = values[key]
			"skills":
				agent.skills.clear()
				for skill in values[key]:
					agent.skills.append(str(skill))
	save_agents()
	GoGentSingleton.get_instance().agents_changed.emit()
	return true

func remove_agent(agent_id: String) -> void:
	for i in range(agents.size()):
		if agents[i].id == agent_id:
			agents.remove_at(i)
			sessions.erase(agent_id)
			break
	save_agents()
	GoGentSingleton.get_instance().agents_changed.emit()

func get_agent(agent_id: String) -> AgentConfig:
	for agent in agents:
		if agent.id == agent_id:
			return agent
	return null

func get_or_create_session(agent_id: String) -> AgentSession:
	if not sessions.has(agent_id):
		sessions[agent_id] = AgentSession.new(agent_id)
	return sessions[agent_id]

func add_message_to_session(agent_id: String, role: String, content: String) -> void:
	var session: AgentSession = get_or_create_session(agent_id)
	session.messages.append({"role": role, "content": content})
	session.updated_at = Time.get_unix_time_from_system()
	while session.messages.size() > 100:
		session.messages.pop_front()

func build_messages_for_agent(agent: AgentConfig, user_text: String) -> Array[Dictionary]:
	var session: AgentSession = get_or_create_session(agent.id)
	var result: Array[Dictionary] = []
	if not agent.system_prompt.is_empty():
		result.append({"role": "system", "content": agent.system_prompt + _build_editor_tool_prompt()})
	var start := max(0, session.messages.size() - 10)
	for i in range(start, session.messages.size()):
		result.append(session.messages[i])
	result.append({"role": "user", "content": user_text})
	return result

func _build_editor_tool_prompt() -> String:
	var node_editor = GoGentSingleton.get_instance().node_editor_manager
	var workspace_tools = GoGentSingleton.get_instance().workspace_tool_manager
	if node_editor == null and workspace_tools == null:
		return ""
	var tools: Array[Dictionary] = []
	if node_editor != null:
		tools.append_array(node_editor.get_agent_tool_manifest())
	if workspace_tools != null:
		tools.append_array(workspace_tools.get_tool_manifest())
	if tools.is_empty():
		return ""
	var lines := PackedStringArray()
	lines.append("")
	lines.append("可用 GoGent 工具：你可以读取/写入项目文件、搜索代码、执行控制台命令、创建和编辑 Godot 节点。需要真实修改项目时，使用 <gogent_tool>{\"tool\":\"write_file\",\"args\":{\"path\":\"res://...\",\"content\":\"...\"}}</gogent_tool> 这类工具调用。")
	for tool in tools:
		lines.append("- %s：%s" % [tool.get("name", ""), tool.get("description", "")])
	lines.append("常用命令包括 editor_info、list_scene_nodes、create_scene、add_node、set_node_prop、delete_node、select_node、attach_script。")
	lines.append("项目文件工具包括 list_files、read_file、write_file、append_file、search_text、console。")
	lines.append("AI 设置命令包括 ai_settings 和 set_ai_option，可调整 temperature、top_p、max_tokens、json_mode、request_timeout 等参数。")
	lines.append("人机训练命令包括 train、stop_train、feedback，feedback 格式为 feedback <state_json> <action> <reward> [next_state_json] [done] [note]。")
	return "\n".join(lines)

func collaborate(problem: String, agent_ids: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for agent_id in agent_ids:
		var agent := get_agent(agent_id)
		if agent == null or not agent.enabled:
			continue
		result.append({
			"agent_id": agent.id,
			"agent_name": agent.name,
			"messages": build_messages_for_agent(agent, problem),
			"options": {
				"temperature": agent.temperature,
				"max_tokens": agent.max_tokens
			}
		})
	return result
