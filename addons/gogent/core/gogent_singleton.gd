@tool
class_name GoGentSingleton
extends RefCounted

signal models_changed
signal agents_changed
signal console_message(message: String, kind: String)

static var _instance: GoGentSingleton

var main_panel: Control
var editor_plugin: EditorPlugin
var config_manager
var model_manager
var agent_manager
var console_manager
var training_manager
var api_manager
var skill_manager
var stream_manager
var external_tool_manager
var node_editor_manager
var conversation_manager
var workspace_tool_manager

# 新组件
var tool_registry: GoGentToolRegistry          # 工具注册器（场景树自动注册）
var temp_file_manager: GoGentTempFileManager    # 临时文件回滚管理器
var plan_list: GoGentPlanList                   # 计划列表 UI

const ConfigManagerScript := preload("res://addons/gogent/core/config_manager.gd")
const ModelManagerScript := preload("res://addons/gogent/core/model_manager.gd")
const AgentManagerScript := preload("res://addons/gogent/core/agent_manager.gd")
const ConsoleManagerScript := preload("res://addons/gogent/core/console_manager.gd")
const TrainingManagerScript := preload("res://addons/gogent/core/training_manager.gd")
const APIManagerScript := preload("res://addons/gogent/core/api_manager.gd")
const SkillManagerScript := preload("res://addons/gogent/core/skill_manager.gd")
const ExternalToolManagerScript := preload("res://addons/gogent/core/external_tool_manager.gd")
const NodeEditorManagerScript := preload("res://addons/gogent/core/node_editor_manager.gd")
const ConversationManagerScript := preload("res://addons/gogent/core/conversation_manager.gd")
const WorkspaceToolManagerScript := preload("res://addons/gogent/core/workspace_tool_manager.gd")

static func get_instance() -> GoGentSingleton:
	if _instance == null:
		_instance = GoGentSingleton.new()
	return _instance

func set_main_panel(panel: Control) -> void:
	main_panel = panel

func set_editor_plugin(plugin: EditorPlugin) -> void:
	editor_plugin = plugin

func load_all_configs() -> void:
	config_manager = ConfigManagerScript.new()
	model_manager = ModelManagerScript.new()
	agent_manager = AgentManagerScript.new()
	console_manager = ConsoleManagerScript.new()
	training_manager = TrainingManagerScript.new()
	api_manager = APIManagerScript.new()
	stream_manager = api_manager.stream_manager
	skill_manager = SkillManagerScript.new()
	external_tool_manager = ExternalToolManagerScript.new()
	node_editor_manager = NodeEditorManagerScript.new()
	conversation_manager = ConversationManagerScript.new()
	workspace_tool_manager = WorkspaceToolManagerScript.new()

	# 初始化新组件
	temp_file_manager = GoGentTempFileManager.new()
	GoGentTempFileManager.cleanup_old_temp_files()

	print_gogent_console("All GoGent managers loaded.", "success")

## 初始化工具注册器（需要在场景树就绪后调用）
func init_tool_registry(parent_node: Node) -> void:
	if tool_registry != null:
		return
	# 加载 tools.tscn 场景
	var tools_scene = preload("res://addons/gogent/tools/tools.tscn")
	var tools_instance = tools_scene.instantiate()
	parent_node.add_child(tools_instance)
	tool_registry = tools_instance as GoGentToolRegistry
	print_gogent_console("Tool registry initialized with %d tools." % tool_registry.get_tool_count(), "success")

## 初始化计划列表（需要在场景树就绪后调用）
func init_plan_list(parent_node: Node) -> GoGentPlanList:
	if plan_list != null:
		return plan_list
	var plan_scene = preload("res://addons/gogent/ui/plan_list/plan_list.tscn")
	plan_list = plan_scene.instantiate()
	parent_node.add_child(plan_list)
	return plan_list

func get_scene_tree() -> SceneTree:
	if main_panel != null:
		return main_panel.get_tree()
	var loop := Engine.get_main_loop()
	return loop as SceneTree

func emit_console_message(message: String, kind: String = "info") -> void:
	console_message.emit(message, kind)
	print_gogent_console(message, kind)

static func print_gogent_console(message: String, kind: String = "info") -> void:
	var color := "#abc9ff"
	match kind:
		"success":
			color = "#42ffc2"
		"warning":
			color = "#ffb373"
		"error":
			color = "#ff7085"
		"system":
			color = "#ffeda1"
	print_rich("[color=%s][GoGent] %s[/color]" % [color, message])
