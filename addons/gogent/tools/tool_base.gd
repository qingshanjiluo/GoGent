@tool
class_name GoGentToolBase
extends Node
## 工具抽象基类
##
## 所有 GoGent 工具都应继承此类，实现抽象方法。
## 工具通过场景树自动注册，无需手动维护工具列表。
## 参考 AlphaAgent 的 AgentToolBase 设计。

## 工具分组枚举
enum ToolGroup {
	FILE_OPERATION,     # 文件操作类
	SCENE_EDITING,      # 场景编辑类
	TRAINING_CONTROL,   # 训练控制类
	CODE_ANALYSIS,      # 代码分析类
	SYSTEM_CONTROL,     # 系统控制类
	COLLABORATION,      # 协作类
	OTHER               # 其他
}

## 工具名称（唯一标识符）
@export var tool_name: String = ""
## 工具显示名称
@export var tool_display_name: String = ""
## 工具分组
@export var tool_group: ToolGroup = ToolGroup.OTHER
## 是否启用
@export var tool_enabled: bool = true

func _init() -> void:
	# 自动设置工具名称
	if tool_name.is_empty():
		tool_name = _generate_tool_name()

## 获取工具描述（子类必须实现）
func _get_tool_description() -> String:
	push_error("GoGentToolBase: _get_tool_description() not implemented for %s" % tool_name)
	return ""

## 获取工具参数定义（子类必须实现）
## 返回 Dictionary，格式为 JSON Schema
## 例如：{"type": "object", "properties": {"path": {"type": "string"}}, "required": ["path"]}
func _get_tool_parameters() -> Dictionary:
	push_error("GoGentToolBase: _get_tool_parameters() not implemented for %s" % tool_name)
	return {}

## 执行工具（子类必须实现）
## 参数 args: Dictionary，包含工具参数
## 返回 Dictionary，包含执行结果
func execute_tool(args: Dictionary) -> Dictionary:
	push_error("GoGentToolBase: execute_tool() not implemented for %s" % tool_name)
	return {"success": false, "error": "Tool not implemented: %s" % tool_name}

## 获取 OpenAI 兼容的函数定义
func get_tool_func_description() -> Dictionary:
	return {
		"type": "function",
		"function": {
			"name": tool_name,
			"description": _get_tool_description(),
			"parameters": _get_tool_parameters()
		}
	}

## 获取文本格式的工具描述（用于系统提示词）
func get_text_description() -> String:
	var params := _get_tool_parameters()
	var props := params.get("properties", {})
	var required := params.get("required", [])

	var parts: Array[String] = []
	parts.append("  - **%s**：%s" % [tool_name, _get_tool_description()])

	if not props.is_empty():
		var param_parts: Array[String] = []
		for key in props.keys():
			var prop := props[key] as Dictionary
			var ptype := prop.get("type", "string")
			var pdesc := prop.get("description", "")
			var req := "（必填）" if key in required else "（可选）"
			param_parts.append("    - `%s` (%s)%s：%s" % [key, ptype, req, pdesc])
		if not param_parts.is_empty():
			parts.append("    参数：")
			parts.append_array(param_parts)

	return "\n".join(parts)

## 生成默认工具名称（基于类名）
func _generate_tool_name() -> String:
	var name := get_script().get_global_name() if get_script() else get_class()
	# 移除 "GoGent" 前缀和 "Tool" 后缀
	name = name.replace("GoGent", "").replace("Tool", "")
	# 转换为 snake_case
	var result := ""
	for i in range(name.length()):
		var ch := name[i]
		if ch >= 'A' and ch <= 'Z':
			if not result.is_empty():
				result += "_"
			result += ch.to_lower()
		else:
			result += ch
	return result

## 工具执行前的钩子（可选重写）
func before_execute(args: Dictionary) -> void:
	pass

## 工具执行后的钩子（可选重写）
func after_execute(args: Dictionary, result: Dictionary) -> void:
	pass
