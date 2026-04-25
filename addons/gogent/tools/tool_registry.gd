@tool
class_name GoGentToolRegistry
extends Node
## 工具注册器
##
## 自动扫描场景树中的 GoGentToolBase 子节点并注册。
## 提供统一的工具查询、执行和描述生成接口。
## 参考 AlphaAgent 的 tools.gd 设计。

signal tools_changed()

## 工具映射：tool_name -> GoGentToolBase
var _tool_map: Dictionary = {}
## 是否已初始化
var _initialized := false

func _ready() -> void:
	register_tools()

## 注册所有子节点中的工具
func register_tools() -> void:
	_tool_map.clear()
	var tools := get_children()
	for tool_node in tools:
		if tool_node is GoGentToolBase and tool_node.tool_enabled:
			var name := tool_node.tool_name
			if not name.is_empty():
				if _tool_map.has(name):
					push_warning("GoGentToolRegistry: 工具名重复 '%s'，后注册的将覆盖前一个" % name)
				_tool_map[name] = tool_node
	_initialized = true
	tools_changed.emit()

## 重新注册（在添加新工具后调用）
func reregister() -> void:
	register_tools()

## 获取所有已注册的工具名称
func get_tool_names() -> Array[String]:
	return _tool_map.keys()

## 获取所有已注册的工具
func get_all_tools() -> Array[GoGentToolBase]:
	return _tool_map.values()

## 根据名称获取工具
func get_tool(name: String) -> GoGentToolBase:
	return _tool_map.get(name, null)

## 检查工具是否存在
func has_tool(name: String) -> bool:
	return _tool_map.has(name)

## 执行工具
func execute_tool(tool_name: String, args: Dictionary) -> Dictionary:
	var tool := _tool_map.get(tool_name, null)
	if tool == null:
		return {"success": false, "error": "未知工具: %s" % tool_name}
	if not tool.tool_enabled:
		return {"success": false, "error": "工具已禁用: %s" % tool_name}
	tool.before_execute(args)
	var result := tool.execute_tool(args)
	tool.after_execute(args, result)
	return result

## 获取所有工具的 OpenAI 兼容函数定义列表
func get_tools_func_descriptions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for tool in _tool_map.values():
		result.append(tool.get_tool_func_description())
	return result

## 获取所有工具的文本描述（用于系统提示词）
func get_tools_text_descriptions(group_by: bool = true) -> String:
	if _tool_map.is_empty():
		return ""

	var lines: Array[String] = []

	if group_by:
		# 按分组输出
		var groups: Dictionary = {}
		for tool in _tool_map.values():
			var group_name := GoGentToolBase.ToolGroup.keys()[tool.tool_group]
			if not groups.has(group_name):
				groups[group_name] = []
			groups[group_name].append(tool)

		for group_name in groups.keys():
			lines.append("")
			lines.append("### %s" % _get_group_display_name(group_name))
			for tool in groups[group_name]:
				lines.append(tool.get_text_description())
	else:
		for tool in _tool_map.values():
			lines.append(tool.get_text_description())

	return "\n".join(lines)

## 获取指定分组的工具
func get_tools_by_group(group: GoGentToolBase.ToolGroup) -> Array[GoGentToolBase]:
	var result: Array[GoGentToolBase] = []
	for tool in _tool_map.values():
		if tool.tool_group == group:
			result.append(tool)
	return result

## 获取工具数量
func get_tool_count() -> int:
	return _tool_map.size()

## 检查是否已初始化
func is_initialized() -> bool:
	return _initialized

static func _get_group_display_name(group_name: String) -> String:
	match group_name:
		"FILE_OPERATION": return "项目文件工具"
		"SCENE_EDITING": return "场景节点编辑工具"
		"TRAINING_CONTROL": return "训练控制工具"
		"CODE_ANALYSIS": return "代码分析工具"
		"SYSTEM_CONTROL": return "系统控制工具"
		"COLLABORATION": return "协作工具"
		_: return "其他工具"
