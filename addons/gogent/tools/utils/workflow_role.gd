@tool
class_name GoGentWorkflowRole
extends RefCounted
## 三阶段工作流角色
##
## 提供分析问题 → 制定方案 → 执行方案 的三阶段工作流提示词。
## 参考 AlphaAgent 的 role_config.gd 中的 WORKFLOW_PROMPT 设计。

## 工作流系统提示词
const WORKFLOW_PROMPT := """
## 工作流程

你采用三阶段工作流来完成任务。每次回复时，请先说明当前阶段。

### 阶段一：分析问题 🔍

理解用户的需求，分析项目结构和现有代码。在此阶段：
- 使用 list_files、read_file 等工具了解项目
- 使用 editor_info、list_scene_nodes 了解当前场景
- 使用 check_errors 了解现有错误
- 输出分析结果和问题理解

### 阶段二：制定方案 📋

基于分析结果，制定详细的执行计划。在此阶段：
- 列出具体的修改步骤
- 使用 <plan_list> 标签输出计划项，格式：
  <plan_list>
  - 步骤1：具体描述
  - 步骤2：具体描述
  - 步骤3：具体描述
  </plan_list>
- 每个计划项应该是一个可独立执行的操作
- 计划应该按执行顺序排列

### 阶段三：执行方案 🛠️

按计划逐步执行。在此阶段：
- 每完成一步，在回复中标记该步骤已完成
- 使用工具进行实际修改
- 每步执行后检查结果
- 全部完成后总结修改内容

## 计划列表格式说明

使用 <plan_list> 标签输出计划列表，系统会自动解析并显示在计划面板中：

<plan_list>
- 使用 list_files 查看项目结构
- 使用 read_file 读取 main.gd
- 修改 main.gd 添加新功能
- 使用 check_errors 检查错误
</plan_list>

系统会自动将每个 "- " 开头的行作为一个计划项。
"""

## 获取工作流提示词
static func get_workflow_prompt() -> String:
	return WORKFLOW_PROMPT

## 从回复文本中解析计划列表
## 返回 Array[String] 或空数组
static func parse_plan_list(text: String) -> Array[String]:
	var result: Array[String] = []
	var start := text.find("<plan_list>")
	if start < 0:
		return result
	var content_start := start + "<plan_list>".length()
	var end := text.find("</plan_list>", content_start)
	if end < 0:
		return result
	var content := text.substr(content_start, end - content_start)
	for line in content.split("\n", false):
		var trimmed := line.strip_edges()
		if trimmed.begins_with("- "):
			result.append(trimmed.substr(2).strip_edges())
		elif trimmed.begins_with("* "):
			result.append(trimmed.substr(2).strip_edges())
	return result

## 检查回复中是否包含计划列表
static func has_plan_list(text: String) -> bool:
	return text.contains("<plan_list>") and text.contains("</plan_list>")

## 获取三阶段角色配置
static func create_workflow_agent(name: String = "工作流助手", role_desc: String = "三阶段工作流专家") -> Dictionary:
	return {
		"name": name,
		"role": role_desc,
		"system_prompt": WORKFLOW_PROMPT,
		"temperature": 0.7,
		"max_tokens": 8192,
		"enabled": true,
		"auto_respond": false,
		"skills": []
	}
