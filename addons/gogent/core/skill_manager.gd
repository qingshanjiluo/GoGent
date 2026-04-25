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

func import_skill_zip(zip_path: String) -> Dictionary:
	var path := zip_path.strip_edges()
	if path.is_empty():
		return {"success": false, "error": "ZIP 路径不能为空。"}
	var reader := ZIPReader.new()
	var open_error := reader.open(path)
	if open_error != OK:
		open_error = reader.open(ProjectSettings.globalize_path(path))
	if open_error != OK:
		return {"success": false, "error": "无法打开 Skill ZIP: %s" % error_string(open_error)}
	var imported := 0
	var errors: Array[String] = []
	for file_path in reader.get_files():
		if file_path.ends_with("/") or file_path.find("..") >= 0:
			continue
		var lower := file_path.to_lower()
		if lower.ends_with(".json"):
			var bytes := reader.read_file(file_path)
			var parsed = JSON.parse_string(bytes.get_string_from_utf8())
			if parsed is Dictionary:
				imported += _import_skill_data(parsed)
			else:
				errors.append("JSON 无效: %s" % file_path)
		elif lower.ends_with(".md") or lower.ends_with(".txt"):
			var bytes := reader.read_file(file_path)
			var skill := SkillDefinition.new(file_path.get_file().get_basename(), file_path.get_file().get_basename(), "从 ZIP 导入的文本 Skill")
			skill.category = "imported"
			skill.prompt_template = bytes.get_string_from_utf8()
			_upsert_skill(skill)
			imported += 1
	reader.close()
	save_skills()
	return {"success": imported > 0, "imported": imported, "errors": errors}

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

func _import_skill_data(data: Dictionary) -> int:
	var count := 0
	if data.has("skills") and data["skills"] is Array:
		for item in data["skills"]:
			if item is Dictionary:
				_upsert_skill(SkillDefinition.from_dict(item))
				count += 1
	else:
		_upsert_skill(SkillDefinition.from_dict(data))
		count += 1
	return count

func _upsert_skill(skill: SkillDefinition) -> void:
	for i in range(skills.size()):
		if skills[i].id == skill.id:
			skills[i] = skill
			return
	skills.append(skill)
