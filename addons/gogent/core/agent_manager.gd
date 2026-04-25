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

func _ensure_dir() -> void:
	var dir := AGENTS_FILE.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

func _add_default_agents() -> void:
	agents.clear()
	_add_default_agent("Code Assistant", "Godot development expert", "You are a senior Godot 4 engineer. Help write, debug, review, and improve GDScript and editor workflows.", ["code_review"])
	_add_default_agent("Game Designer", "Gameplay and systems designer", "You are a game designer. Help design mechanics, progression, economy, levels, and player experience for Godot games.", ["game_design"])
	_add_default_agent("QA Tester", "Game QA engineer", "You are a QA engineer. Create test plans, edge cases, bug reports, and automated Godot testing ideas.", ["game_testing"])
	_add_default_agent("AI Trainer", "Reinforcement learning advisor", "You are an AI training specialist. Help design RL states, actions, rewards, evaluation, and training strategy.", ["ai_training"])
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
		result.append({"role": "system", "content": agent.system_prompt})
	var start := max(0, session.messages.size() - 10)
	for i in range(start, session.messages.size()):
		result.append(session.messages[i])
	result.append({"role": "user", "content": user_text})
	return result

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
