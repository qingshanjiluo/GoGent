@tool
class_name GoGentSkillManager
extends RefCounted

const SKILLS_FILE := "res://addons/gogent/config/skills.json"
const SKILLS_DIR := "res://addons/gogent/skills/"

class SkillDefinition:
	var id := ""
	var name := ""
	var description := ""
	var prompt_template := ""
	var api_type := "openai"
	var model_name := ""
	var parameters := {}
	var enabled := true
	var category := "general"

	func _init(p_id: String = "", p_name: String = "", p_description: String = "") -> void:
		id = p_id if not p_id.is_empty() else "skill_%d_%d" % [Time.get_unix_time_from_system(), randi()]
		name = p_name
		description = p_description

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"description": description,
			"prompt_template": prompt_template,
			"api_type": api_type,
			"model_name": model_name,
			"parameters": parameters,
			"enabled": enabled,
			"category": category
		}

	static func from_dict(data: Dictionary) -> SkillDefinition:
		var skill := SkillDefinition.new(data.get("id", ""), data.get("name", ""), data.get("description", ""))
		skill.prompt_template = data.get("prompt_template", "")
		skill.api_type = data.get("api_type", "openai")
		skill.model_name = data.get("model_name", "")
		skill.parameters = data.get("parameters", {})
		skill.enabled = data.get("enabled", true)
		skill.category = data.get("category", "general")
		return skill

var skills: Array[SkillDefinition] = []

func _init() -> void:
	_ensure_dirs()
	load_skills()
	if skills.is_empty():
		_add_default_skills()

func _ensure_dirs() -> void:
	for dir in [SKILLS_FILE.get_base_dir(), SKILLS_DIR]:
		if not DirAccess.dir_exists_absolute(dir):
			DirAccess.make_dir_recursive_absolute(dir)

func _add_default_skills() -> void:
	skills.clear()
	_add_skill("code_review", "Code Review", "Review GDScript quality.", "coding", "You are a Godot 4 code reviewer. Review this code and report correctness, performance, maintainability, and Godot API issues:\n\n{code_content}")
	_add_skill("game_testing", "Game Testing", "Create test plans.", "testing", "Create a practical test plan for this Godot feature:\n\n{feature_description}")
	_add_skill("ai_training", "AI Training", "Design RL training.", "training", "Design states, actions, rewards, algorithm choice, and evaluation for this game AI training task:\n\n{training_task}")
	_add_skill("game_design", "Game Design", "Design game systems.", "design", "Give concrete gameplay, balance, progression, and UX recommendations for:\n\n{design_requirements}")
	_add_skill("deep_analysis", "Deep Analysis", "Analyze architecture and risk.", "general", "Analyze this Godot project information from architecture, risk, testing, and implementation angles:\n\n{content}")
	_add_skill("project_scaffold", "Project Scaffold", "Generate project structure.", "coding", "Create a Godot project structure and starter GDScript plan for:\n\n{requirements}")
	save_skills()

func _add_skill(id: String, name: String, description: String, category: String, template: String) -> void:
	var skill := SkillDefinition.new(id, name, description)
	skill.category = category
	skill.prompt_template = template
	skills.append(skill)

func load_skills() -> void:
	if not FileAccess.file_exists(SKILLS_FILE):
		return
	var text := FileAccess.get_file_as_string(SKILLS_FILE)
	if FileAccess.get_open_error() != OK:
		return
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return
	skills.clear()
	for item in parsed.get("skills", []):
		if item is Dictionary:
			skills.append(SkillDefinition.from_dict(item))

func save_skills() -> bool:
	_ensure_dirs()
	var data := {"skills": []}
	for skill in skills:
		data["skills"].append(skill.to_dict())
	var file := FileAccess.open(SKILLS_FILE, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

func add_skill(skill: SkillDefinition) -> void:
	skills.append(skill)
	save_skills()

func remove_skill(skill_id: String) -> void:
	for i in range(skills.size()):
		if skills[i].id == skill_id:
			skills.remove_at(i)
			break
	save_skills()

func get_skill(skill_id: String) -> SkillDefinition:
	for skill in skills:
		if skill.id == skill_id:
			return skill
	return null

func get_skills_by_category(category: String) -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = []
	for skill in skills:
		if skill.category == category and skill.enabled:
			result.append(skill)
	return result

func render_skill_prompt(skill_id: String, params: Dictionary) -> String:
	var skill := get_skill(skill_id)
	if skill == null:
		return ""
	var prompt := skill.prompt_template
	for key in params.keys():
		prompt = prompt.replace("{%s}" % key, str(params[key]))
	return prompt

func execute_skill(skill_id: String, params: Dictionary) -> Dictionary:
	var skill := get_skill(skill_id)
	if skill == null:
		return {"success": false, "error": "Skill not found."}
	if not skill.enabled:
		return {"success": false, "error": "Skill is disabled."}
	var prompt := render_skill_prompt(skill_id, params)
	var api = GoGentSingleton.get_instance().api_manager
	if api == null:
		return {"success": false, "error": "API manager is not ready."}
	var options := {}
	if not skill.model_name.is_empty():
		options["model"] = skill.model_name
	api.send_chat_request([{"role": "user", "content": prompt}], options)
	return {"success": true, "skill_name": skill.name, "prompt": prompt}
