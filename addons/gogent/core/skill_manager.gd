@tool
class_name GoGentSkillManager
extends RefCounted

## 技能管理器
## 管理 AI 技能的定义、加载和执行
## 技能是预定义的提示模板，用于与 Claude/GPT 等 AI 进行特定任务的交互

# 技能定义
class SkillDefinition:
	var id: String = ""
	var name: String = ""
	var description: String = ""
	var prompt_template: String = ""  # 提示模板
	var api_type: String = "openai"   # openai, claude, gemini
	var model_name: String = ""       # 推荐使用的模型
	var parameters: Dictionary = {}   # 额外参数
	var enabled: bool = true
	var category: String = "general"  # general, coding, testing, training, design
	
	func _init(p_name: String = "", p_desc: String = ""):
		id = str(Time.get_unix_time_from_system()) + "_" + str(randi())
		name = p_name
		description = p_desc
	
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
		var skill = SkillDefinition.new()
		skill.id = data.get("id", skill.id)
		skill.name = data.get("name", "")
		skill.description = data.get("description", "")
		skill.prompt_template = data.get("prompt_template", "")
		skill.api_type = data.get("api_type", "openai")
		skill.model_name = data.get("model_name", "")
		skill.parameters = data.get("parameters", {})
		skill.enabled = data.get("enabled", true)
		skill.category = data.get("category", "general")
		return skill

const SKILLS_FILE: String = "res://addons/gogent/config/skills.json"
const SKILLS_DIR: String = "res://addons/gogent/skills/"

var skills: Array[SkillDefinition] = []

func _init() -> void:
	_ensure_dirs()
	load_skills()
	if skills.is_empty():
		_add_default_skills()

func _ensure_dirs() -> void:
	var dirs = [SKILLS_FILE.get_base_dir(), SKILLS_DIR]
	for dir in dirs:
		if not DirAccess.dir_exists_absolute(dir):
			DirAccess.make_dir_recursive_absolute(dir)

func _add_default_skills() -> void:
	# 1. 代码审查技能
	var code_review = SkillDefinition.new("代码审查", "审查 Godot GDScript 代码质量")
	code_review.prompt_template = """你是一个 Godot 4.x 代码审查专家。请审查以下代码：

{code_content}

请检查：
1. 代码风格和命名规范
2. 性能问题
3. 内存泄漏风险
4. 类型安全性
5. Godot 最佳实践
6. 潜在的 Bug

请给出改进建议。"""
	code_review.category = "coding"
	code_review.api_type = "openai"
	skills.append(code_review)
	
	# 2. 游戏测试技能
	var game_test = SkillDefinition.new("游戏测试", "生成游戏测试方案")
	game_test.prompt_template = """你是一个 QA 测试专家。请为以下游戏功能设计测试方案：

{feature_description}

请提供：
1. 测试用例列表
2. 边界条件测试
3. 性能测试建议
4. 自动化测试脚本模板（GDScript）"""
	game_test.category = "testing"
	skills.append(game_test)
	
	# 3. AI 训练技能
	var ai_training = SkillDefinition.new("AI 训练", "配置和优化 AI 训练参数")
	ai_training.prompt_template = """你是一个机器学习专家。请为以下训练任务提供配置建议：

{training_task}

请提供：
1. 推荐的算法（DQN/PPO/A2C）
2. 超参数设置建议
3. 奖励函数设计
4. 状态空间和动作空间设计
5. 训练策略优化建议"""
	ai_training.category = "training"
	skills.append(ai_training)
	
	# 4. 游戏设计技能
	var game_design = SkillDefinition.new("游戏设计", "游戏策划和设计建议")
	game_design.prompt_template = """你是一个资深游戏策划。请为以下游戏设计需求提供建议：

{design_requirements}

请提供：
1. 核心玩法设计
2. 数值平衡建议
3. 关卡设计思路
4. 用户体验优化
5. 游戏经济系统设计（如适用）"""
	game_design.category = "design"
	skills.append(game_design)
	
	# 5. Claude 专用分析技能
	var claude_analysis = SkillDefinition.new("深度分析", "使用 Claude 进行深度代码分析（通过 OpenRouter）")
	claude_analysis.prompt_template = """请对以下内容进行深度分析：

{content}

请从多个角度进行分析，包括技术实现、架构设计、潜在风险和优化方向。"""
	claude_analysis.api_type = "openai"  # 通过 OpenRouter 调用 Claude
	claude_analysis.model_name = "anthropic/claude-sonnet-4.5"
	claude_analysis.category = "general"
	skills.append(claude_analysis)
	
	# 6. 项目脚手架技能
	var scaffold = SkillDefinition.new("项目脚手架", "生成 Godot 项目结构和代码模板")
	scaffold.prompt_template = """你是一个 Godot 项目架构师。请根据以下需求生成项目脚手架：

{requirements}

请提供：
1. 项目目录结构建议
2. 核心脚本模板
3. 场景结构设计
4. 自动加载（Autoload）设计
5. 信号和事件系统设计"""
	scaffold.category = "coding"
	skills.append(scaffold)
	
	save_skills()
	GoGentPlugin.print_gogent("已创建 {0} 个默认技能".format([skills.size()]), "#42ffc2")

func load_skills() -> void:
	var file_content = FileAccess.get_file_as_string(SKILLS_FILE)
	if FileAccess.get_open_error() != OK:
		return
	
	var json = JSON.parse_string(file_content)
	if json == null:
		return
	
	var skills_data = json.get("skills", [])
	skills.clear()
	for data in skills_data:
		skills.append(SkillDefinition.from_dict(data))

func save_skills() -> void:
	var data = {
		"skills": skills.map(func(s): return s.to_dict())
	}
	
	var file = FileAccess.open(SKILLS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func add_skill(skill: SkillDefinition) -> void:
	skills.append(skill)
	save_skills()

func remove_skill(skill_id: String) -> void:
	for i in range(skills.size()):
		if skills[i].id == skill_id:
			skills.remove_at(i)
			save_skills()
			return

func get_skill(skill_id: String) -> SkillDefinition:
	for skill in skills:
		if skill.id == skill_id:
			return skill
	return null

func get_skills_by_category(category: String) -> Array[SkillDefinition]:
	return skills.filter(func(s): return s.category == category and s.enabled)

## 执行技能：填充模板并发送到 API
func execute_skill(skill_id: String, params: Dictionary) -> Dictionary:
	var skill = get_skill(skill_id)
	if skill == null:
		return {"success": false, "error": "技能不存在"}
	
	if not skill.enabled:
		return {"success": false, "error": "技能已禁用"}
	
	# 填充模板
	var prompt = skill.prompt_template
	for key in params.keys():
		prompt = prompt.replace("{" + key + "}", str(params[key]))
	
	# 发送到 API
	var singleton = GoGentSingleton.get_instance()
	if singleton.api_manager == null:
		return {"success": false, "error": "API 管理器未初始化"}
	
	var messages = [
		{"role": "system", "content": "你是一个 Godot 开发专家助手。"},
		{"role": "user", "content": prompt}
	]
	
	var options = {}
	if not skill.model_name.is_empty():
		options["model"] = skill.model_name
	
	singleton.api_manager.send_chat_request(messages, options)
	
	return {"success": true, "skill_name": skill.name, "prompt": prompt}
