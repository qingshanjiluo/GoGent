@tool
class_name GoGentAgentEditorPanel
extends Control

## 自定义 Agent 创建 UI
## 提供可视化界面来创建、编辑和管理 AI Agent
## 支持自定义系统提示词、模型选择、技能分配等

# 信号
signal agent_created(agent_data: Dictionary)
signal agent_updated(agent_id: String, agent_data: Dictionary)
signal agent_deleted(agent_id: String)
signal agent_selected(agent_id: String)

# UI 节点
@onready var agent_list: ItemList = %AgentList
@onready var agent_name_input: LineEdit = %AgentNameInput
@onready var agent_role_input: LineEdit = %AgentRoleInput
@onready var system_prompt_edit: TextEdit = %SystemPromptEdit
@onready var model_option: OptionButton = %ModelOption
@onready var temperature_slider: HSlider = %TemperatureSlider
@onready var temperature_label: Label = %TemperatureLabel
@onready var max_tokens_spin: SpinBox = %MaxTokensSpin
@onready var auto_respond_toggle: CheckButton = %AutoRespondToggle
@onready var skill_list: VBoxContainer = %SkillList
@onready var save_button: Button = %SaveButton
@onready var delete_button: Button = %DeleteButton
@onready var new_button: Button = %NewButton
@onready var preview_text: RichTextLabel = %PreviewText
@onready var search_input: LineEdit = %SearchInput

# 预设模板
const AGENT_TEMPLATES = {
	"code_reviewer": {
		"name": "代码审查员",
		"role": "Godot GDScript 代码审查专家",
		"system_prompt": """你是一位资深的 Godot 4.x 代码审查专家。

## 核心职责
- 审查 GDScript 代码质量和性能
- 发现潜在的内存泄漏和性能瓶颈
- 确保代码符合 Godot 最佳实践
- 提供具体的优化建议和代码示例

## 审查重点
1. 节点引用和内存管理
2. 信号连接的生命周期
3. 场景树操作效率
4. 类型安全性和 null 检查
5. 内置类型（Vector2, Color 等）的正确使用

## 输出格式
- 问题严重性：[严重/重要/建议]
- 问题位置：文件:行号
- 问题描述
- 改进建议（附代码示例）""",
		"temperature": 0.3,
		"max_tokens": 4096,
		"auto_respond": false,
		"skills": ["代码审查"]
	},
	"game_designer": {
		"name": "游戏策划师",
		"role": "游戏策划与设计专家",
		"system_prompt": """你是一位富有创意的游戏策划专家。

## 核心能力
- 游戏机制设计与平衡
- 数值系统规划
- 关卡设计
- 用户体验优化
- 游戏经济系统设计

## 设计原则
1. 以玩家体验为中心
2. 渐进式难度曲线
3. 正反馈循环
4. 清晰的游戏目标
5. 有意义的玩家选择

## 输出格式
- 设计概念概述
- 核心机制说明
- 数值框架
- 实现建议""",
		"temperature": 0.8,
		"max_tokens": 8192,
		"auto_respond": false,
		"skills": ["游戏设计"]
	},
	"qa_tester": {
		"name": "QA 测试工程师",
		"role": "游戏质量保证专家",
		"system_prompt": """你是一位专业的 QA 测试工程师，擅长游戏测试和质量管理。

## 核心职责
- 设计全面的测试方案
- 发现和报告 Bug
- 性能分析和优化建议
- 自动化测试脚本编写

## 测试方法论
1. 功能测试：验证所有功能按预期工作
2. 边界测试：测试输入边界条件
3. 压力测试：测试极限情况下的表现
4. 兼容性测试：不同平台和配置
5. 回归测试：确保修复不引入新问题

## Bug 报告格式
- 严重性：Critical/Major/Minor
- 重现步骤
- 实际结果 vs 预期结果
- 环境信息
- 截图/日志（如适用）""",
		"temperature": 0.4,
		"max_tokens": 4096,
		"auto_respond": false,
		"skills": ["游戏测试"]
	},
	"ai_trainer": {
		"name": "AI 训练师",
		"role": "机器学习与 AI 训练专家",
		"system_prompt": """你是一位机器学习专家，专注于游戏 AI 训练。

## 核心能力
- 强化学习算法（DQN, PPO, A2C）
- 神经网络架构设计
- 训练策略优化
- 奖励函数设计

## 训练流程
1. 环境定义：状态空间、动作空间
2. 算法选择：根据问题特性选择
3. 超参数调优：学习率、折扣因子等
4. 训练监控：奖励曲线、损失曲线
5. 模型评估：泛化能力测试

## 输出格式
- 算法选择理由
- 网络架构说明
- 超参数配置
- 训练策略建议""",
		"temperature": 0.5,
		"max_tokens": 8192,
		"auto_respond": false,
		"skills": ["AI 训练"]
	},
	"architect": {
		"name": "架构师",
		"role": "Godot 项目架构专家",
		"system_prompt": """你是一位经验丰富的 Godot 项目架构师。

## 核心能力
- 项目结构设计
- 模块化架构规划
- 性能优化策略
- 代码复用和扩展性设计

## 架构原则
1. 单一职责原则
2. 开闭原则
3. 依赖倒置原则
4. 接口隔离原则
5. 组合优于继承

## 设计重点
- 场景树结构设计
- 信号系统设计
- 资源管理策略
- 自动加载（Autoload）规划
- 插件架构设计""",
		"temperature": 0.4,
		"max_tokens": 8192,
		"auto_respond": false,
		"skills": ["项目脚手架", "深度分析"]
	}
}

var _current_agent_id: String = ""
var _is_editing: bool = false
var _all_skills: Array = []

func _ready() -> void:
	_connect_signals()
	_load_skills()
	_load_agents()
	_update_preview()

func _connect_signals() -> void:
	save_button.pressed.connect(_on_save)
	delete_button.pressed.connect(_on_delete)
	new_button.pressed.connect(_on_new)
	agent_list.item_selected.connect(_on_agent_selected)
	agent_name_input.text_changed.connect(_update_preview)
	agent_role_input.text_changed.connect(_update_preview)
	system_prompt_edit.text_changed.connect(_update_preview)
	temperature_slider.value_changed.connect(func(v):
		temperature_label.text = "{0:.2f}".format([v])
		_update_preview()
	)
	search_input.text_changed.connect(_on_search)
	
	# 连接模板按钮
	var template_buttons = {
		"code_reviewer": find_child("TemplateCodeReview", true, false),
		"game_designer": find_child("TemplateGameDesign", true, false),
		"qa_tester": find_child("TemplateQATest", true, false),
		"ai_trainer": find_child("TemplateAITrain", true, false),
		"architect": find_child("TemplateArchitect", true, false)
	}
	for template_name in template_buttons.keys():
		var btn = template_buttons[template_name]
		if btn:
			btn.pressed.connect(func(): apply_template(template_name))
	
	# 连接导出/导入按钮
	var export_btn = find_child("ExportButton", true, false)
	var import_btn = find_child("ImportButton", true, false)
	if export_btn:
		export_btn.pressed.connect(_on_export)
	if import_btn:
		import_btn.pressed.connect(_on_import)

func _load_skills() -> void:
	var singleton = GoGentSingleton.get_instance()
	if singleton.skill_manager:
		_all_skills = singleton.skill_manager.skills
		_populate_skill_checkboxes()

func _populate_skill_checkboxes() -> void:
	# 清空现有技能列表
	for child in skill_list.get_children():
		child.queue_free()
	
	for skill in _all_skills:
		var hbox = HBoxContainer.new()
		var check = CheckButton.new()
		check.text = skill.name
		check.set_meta("skill_id", skill.id)
		check.toggled.connect(_on_skill_toggled.bind(skill.id))
		hbox.add_child(check)
		skill_list.add_child(hbox)

func _load_agents() -> void:
	agent_list.clear()
	var singleton = GoGentSingleton.get_instance()
	if singleton.agent_manager:
		for agent in singleton.agent_manager.agents:
			agent_list.add_item("{0} ({1})".format([agent.name, agent.role]))

func _on_agent_selected(index: int) -> void:
	var singleton = GoGentSingleton.get_instance()
	if singleton.agent_manager and index >= 0 and index < singleton.agent_manager.agents.size():
		var agent = singleton.agent_manager.agents[index]
		_current_agent_id = agent.id
		_is_editing = true
		_populate_form(agent)
		agent_selected.emit(agent.id)

func _populate_form(agent) -> void:
	agent_name_input.text = agent.name
	agent_role_input.text = agent.role
	system_prompt_edit.text = agent.system_prompt
	temperature_slider.value = agent.temperature
	temperature_label.text = "{0:.2f}".format([agent.temperature])
	max_tokens_spin.value = agent.max_tokens
	auto_respond_toggle.button_pressed = agent.auto_respond
	
	# 更新技能勾选
	for child in skill_list.get_children():
		if child is HBoxContainer:
			var check = child.get_child(0) if child.get_child_count() > 0 else null
			if check and check is CheckButton:
				var skill_id = check.get_meta("skill_id", "")
				check.button_pressed = skill_id in agent.skills
	
	_update_preview()

func _on_save() -> void:
	var name = agent_name_input.text.strip_edges()
	if name.is_empty():
		_show_error("请输入 Agent 名称")
		return
	
	var role = agent_role_input.text.strip_edges()
	if role.is_empty():
		_show_error("请输入 Agent 角色")
		return
	
	var system_prompt = system_prompt_edit.text.strip_edges()
	if system_prompt.is_empty():
		_show_error("请输入系统提示词")
		return
	
	# 收集选中的技能
	var selected_skills = []
	for child in skill_list.get_children():
		if child is HBoxContainer:
			var check = child.get_child(0) if child.get_child_count() > 0 else null
			if check and check is CheckButton and check.button_pressed:
				selected_skills.append(check.get_meta("skill_id", ""))
	
	var agent_data = {
		"name": name,
		"role": role,
		"system_prompt": system_prompt,
		"temperature": temperature_slider.value,
		"max_tokens": int(max_tokens_spin.value),
		"auto_respond": auto_respond_toggle.button_pressed,
		"skills": selected_skills
	}
	
	var singleton = GoGentSingleton.get_instance()
	if singleton.agent_manager:
		if _is_editing and not _current_agent_id.is_empty():
			# 更新现有 Agent
			var existing = singleton.agent_manager.get_agent(_current_agent_id)
			if existing:
				existing.name = agent_data.name
				existing.role = agent_data.role
				existing.system_prompt = agent_data.system_prompt
				existing.temperature = agent_data.temperature
				existing.max_tokens = agent_data.max_tokens
				existing.auto_respond = agent_data.auto_respond
				existing.skills = agent_data.skills
				singleton.agent_manager.save_agents()
				agent_updated.emit(_current_agent_id, agent_data)
				_show_success("Agent 已更新")
		else:
			# 创建新 Agent
			var new_agent = GoGentAgentManager.AgentConfig.new(name, role)
			new_agent.system_prompt = agent_data.system_prompt
			new_agent.temperature = agent_data.temperature
			new_agent.max_tokens = agent_data.max_tokens
			new_agent.auto_respond = agent_data.auto_respond
			new_agent.skills = agent_data.skills
			singleton.agent_manager.add_agent(new_agent)
			agent_created.emit(agent_data)
			_show_success("Agent 已创建")
		
		_load_agents()
		_is_editing = false
		_current_agent_id = ""

func _on_delete() -> void:
	if _current_agent_id.is_empty():
		return
	
	var singleton = GoGentSingleton.get_instance()
	if singleton.agent_manager:
		singleton.agent_manager.remove_agent(_current_agent_id)
		agent_deleted.emit(_current_agent_id)
		_load_agents()
		_clear_form()
		_show_success("Agent 已删除")

func _on_new() -> void:
	_clear_form()
	_is_editing = false
	_current_agent_id = ""

func _clear_form() -> void:
	agent_name_input.text = ""
	agent_role_input.text = ""
	system_prompt_edit.text = ""
	temperature_slider.value = 0.7
	temperature_label.text = "0.70"
	max_tokens_spin.value = 8192
	auto_respond_toggle.button_pressed = false
	
	for child in skill_list.get_children():
		if child is HBoxContainer:
			var check = child.get_child(0) if child.get_child_count() > 0 else null
			if check and check is CheckButton:
				check.button_pressed = false
	
	_update_preview()

func _on_search(text: String) -> void:
	# 在 Agent 列表中搜索
	for i in range(agent_list.get_item_count()):
		var item_text = agent_list.get_item_text(i)
		var visible = text.is_empty() or text.to_lower() in item_text.to_lower()
		agent_list.set_item_disabled(i, not visible)
		if not visible:
			agent_list.deselect(i)

func _on_skill_toggled(pressed: bool, skill_id: String) -> void:
	_update_preview()

func _update_preview() -> void:
	var name = agent_name_input.text
	var role = agent_role_input.text
	var prompt = system_prompt_edit.text
	var temp = temperature_slider.value
	var tokens = int(max_tokens_spin.value)
	
	var preview = "[b]Agent 预览[/b]\n\n"
	preview += "[color='#42ffc2']名称:[/color] {0}\n".format([name if name else "(未设置)"])
	preview += "[color='#42ffc2']角色:[/color] {0}\n".format([role if role else "(未设置)"])
	preview += "[color='#42ffc2']温度:[/color] {0:.2f}\n".format([temp])
	preview += "[color='#42ffc2']最大 Token:[/color] {0}\n".format([tokens])
	
	# 显示技能
	var selected_skills = []
	for child in skill_list.get_children():
		if child is HBoxContainer:
			var check = child.get_child(0) if child.get_child_count() > 0 else null
			if check and check is CheckButton and check.button_pressed:
				selected_skills.append(check.text)
	
	if not selected_skills.is_empty():
		preview += "[color='#42ffc2']技能:[/color] {0}\n".format([", ".join(selected_skills)])
	
	# 显示提示词预览（截取前200字符）
	if not prompt.is_empty():
		var preview_prompt = prompt.substr(0, 200)
		if prompt.length() > 200:
			preview_prompt += "..."
		preview += "\n[color='#ffb373']系统提示词预览:[/color]\n{0}".format([preview_prompt])
	
	preview_text.text = preview

func _show_error(msg: String) -> void:
	GoGentSingleton.print_gogent_console(msg, "error")

func _show_success(msg: String) -> void:
	GoGentSingleton.print_gogent_console(msg, "success")

func _on_export() -> void:
	"""导出当前 Agent 配置"""
	if _current_agent_id.is_empty():
		_show_error("请先选择一个 Agent")
		return
	
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.add_filter("*.json", "Agent 配置文件")
	file_dialog.file_selected.connect(func(path):
		if export_agent_config(path):
			_show_success("Agent 配置已导出")
		else:
			_show_error("导出失败")
	)
	add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(600, 400))

func _on_import() -> void:
	"""导入 Agent 配置"""
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.add_filter("*.json", "Agent 配置文件")
	file_dialog.file_selected.connect(func(path):
		if import_agent_config(path):
			_show_success("Agent 配置已导入")
		else:
			_show_error("导入失败")
	)
	add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(600, 400))

## 应用预设模板
func apply_template(template_name: String) -> void:
	if not AGENT_TEMPLATES.has(template_name):
		return
	
	var template = AGENT_TEMPLATES[template_name]
	agent_name_input.text = template.name
	agent_role_input.text = template.role
	system_prompt_edit.text = template.system_prompt
	temperature_slider.value = template.temperature
	temperature_label.text = "{0:.2f}".format([template.temperature])
	max_tokens_spin.value = template.max_tokens
	auto_respond_toggle.button_pressed = template.auto_respond
	
	# 勾选技能
	for child in skill_list.get_children():
		if child is HBoxContainer:
			var check = child.get_child(0) if child.get_child_count() > 0 else null
			if check and check is CheckButton:
				check.button_pressed = check.text in template.skills
	
	_update_preview()
	_show_success("已应用模板: {0}".format([template.name]))

## 导出 Agent 配置
func export_agent_config(file_path: String) -> bool:
	if _current_agent_id.is_empty():
		return false
	
	var singleton = GoGentSingleton.get_instance()
	if not singleton.agent_manager:
		return false
	
	var agent = singleton.agent_manager.get_agent(_current_agent_id)
	if agent == null:
		return false
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return false
	
	file.store_string(JSON.stringify(agent.to_dict(), "\t"))
	file.close()
	return true

## 导入 Agent 配置
func import_agent_config(file_path: String) -> bool:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if FileAccess.get_open_error() != OK:
		return false
	
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.parse_string(content)
	if json == null:
		return false
	
	var singleton = GoGentSingleton.get_instance()
	if not singleton.agent_manager:
		return false
	
	var agent = GoGentAgentManager.AgentConfig.from_dict(json)
	singleton.agent_manager.add_agent(agent)
	_load_agents()
	_show_success("Agent 配置已导入")
	return true
