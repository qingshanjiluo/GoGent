@tool
class_name GoGentAgentManager
extends RefCounted

## Agent 管理器
## 管理多个 AI Agent 的创建、配置和协作
## 参考 AlphaAgent 的 Agent 系统和 Microverse 的多角色 AI

# Agent 配置
class AgentConfig:
	var id: String = ""
	var name: String = ""
	var role: String = ""        # 角色描述
	var system_prompt: String = ""
	var model_id: String = ""
	var supplier_id: String = ""
	var temperature: float = 1.0
	var max_tokens: int = 8192
	var enabled: bool = true
	var auto_respond: bool = false  # 是否自动响应
	var skills: Array[String] = []  # 技能列表
	
	func _init(p_name: String = "", p_role: String = ""):
		id = str(Time.get_unix_time_from_system()) + "_" + str(randi())
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
		var config = AgentConfig.new()
		config.id = data.get("id", config.id)
		config.name = data.get("name", "")
		config.role = data.get("role", "")
		config.system_prompt = data.get("system_prompt", "")
		config.model_id = data.get("model_id", "")
		config.supplier_id = data.get("supplier_id", "")
		config.temperature = data.get("temperature", 1.0)
		config.max_tokens = data.get("max_tokens", 8192)
		config.enabled = data.get("enabled", true)
		config.auto_respond = data.get("auto_respond", false)
		config.skills = data.get("skills", [])
		return config

# Agent 会话
class AgentSession:
	var agent_id: String = ""
	var messages: Array[Dictionary] = []
	var context: Dictionary = {}
	var created_at: int = 0
	var updated_at: int = 0
	
	func _init(p_agent_id: String):
		agent_id = p_agent_id
		created_at = Time.get_unix_time_from_system()
		updated_at = created_at

const AGENTS_FILE: String = "res://addons/gogent/config/agents.json"

var agents: Array[AgentConfig] = []
var sessions: Dictionary = {}  # agent_id -> AgentSession
var collaboration_enabled: bool = true

func _init() -> void:
	load_agents()
	if agents.is_empty():
		_add_default_agents()

func _add_default_agents() -> void:
	# 代码助手 Agent
	var coder = AgentConfig.new("代码助手", "Godot 开发专家")
	coder.system_prompt = "你是一个 Godot 4.x 开发专家，精通 GDScript 和 Godot 引擎 API。帮助用户编写、优化和调试代码。"
	coder.auto_respond = false
	agents.append(coder)
	
	# 策划助手 Agent
	var designer = AgentConfig.new("策划助手", "游戏策划专家")
	designer.system_prompt = "你是一个游戏策划专家，擅长游戏设计、数值平衡、关卡设计。帮助用户规划游戏功能和设计文档。"
	designer.auto_respond = false
	agents.append(designer)
	
	# 测试助手 Agent
	var tester = AgentConfig.new("测试助手", "QA 测试专家")
	tester.system_prompt = "你是一个 QA 测试专家，擅长游戏测试、性能分析、Bug 追踪。帮助用户发现和修复问题。"
	tester.auto_respond = false
	agents.append(tester)
	
	# AI 训练师 Agent
	var trainer = AgentConfig.new("AI 训练师", "机器学习专家")
	trainer.system_prompt = "你是一个机器学习专家，擅长强化学习、神经网络训练。帮助用户训练游戏 AI。"
	trainer.auto_respond = false
	agents.append(trainer)
	
	save_agents()
	GoGentPlugin.print_gogent("已创建 {0} 个默认 Agent".format([agents.size()]), "#42ffc2")

func load_agents() -> void:
	var file_content = FileAccess.get_file_as_string(AGENTS_FILE)
	if FileAccess.get_open_error() != OK:
		return
	
	var json = JSON.parse_string(file_content)
	if json == null:
		return
	
	var agents_data = json.get("agents", [])
	agents.clear()
	for data in agents_data:
		agents.append(AgentConfig.from_dict(data))

func save_agents() -> void:
	var data = {
		"agents": agents.map(func(a): return a.to_dict())
	}
	
	var file = FileAccess.open(AGENTS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func add_agent(config: AgentConfig) -> void:
	agents.append(config)
	save_agents()

func remove_agent(agent_id: String) -> void:
	for i in range(agents.size()):
		if agents[i].id == agent_id:
			agents.remove_at(i)
			sessions.erase(agent_id)
			break
	save_agents()

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
	var session = get_or_create_session(agent_id)
	session.messages.append({"role": role, "content": content})
	session.updated_at = Time.get_unix_time_from_system()
	
	# 限制消息数量
	var max_history = 100
	if session.messages.size() > max_history:
		session.messages = session.messages.slice(-max_history)

## Agent 协作：让多个 Agent 共同讨论一个问题
func collaborate(problem: String, agent_ids: Array[String]) -> Array[Dictionary]:
	var results = []
	
	for agent_id in agent_ids:
		var agent = get_agent(agent_id)
		if agent == null or not agent.enabled:
			continue
		
		var session = get_or_create_session(agent_id)
		var messages = []
		
		# 系统提示
		messages.append({"role": "system", "content": agent.system_prompt})
		
		# 历史消息
		messages.append_array(session.messages.slice(-10))
		
		# 当前问题
		messages.append({"role": "user", "content": problem})
		
		results.append({
			"agent_id": agent_id,
			"agent_name": agent.name,
			"messages": messages
		})
	
	return results
