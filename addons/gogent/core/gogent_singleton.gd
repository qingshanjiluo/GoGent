@tool
class_name GoGentSingleton
extends RefCounted

## GoGent 全局单例
## 管理所有模块的状态和引用

static var instance: GoGentSingleton = null

# 信号
signal models_changed
signal agents_changed
signal console_message(msg: String, type: String)

# 主面板引用
var main_panel: Control = null
var editor_plugin: EditorPlugin = null

# 配置管理器
var config_manager = null
var model_manager = null
var agent_manager = null
var console_manager = null
var training_manager = null
var api_manager = null
var skill_manager = null

# 查找标志
var _has_tried_find_main_panel: bool = false

static func get_instance() -> GoGentSingleton:
	if instance == null:
		instance = GoGentSingleton.new()
		instance._try_find_main_panel_in_scene_tree()
	return instance

func _try_find_main_panel_in_scene_tree() -> void:
	if main_panel != null:
		return
	if _has_tried_find_main_panel:
		return
	_has_tried_find_main_panel = true
	
	var scene_tree = get_scene_tree()
	if scene_tree == null:
		return
	var root = scene_tree.root
	if root == null:
		return
	var found_panel = _find_main_panel_recursive(root)
	if found_panel != null:
		main_panel = found_panel

func _find_main_panel_recursive(node: Node) -> Control:
	if node is Control and node.has_method("is_gogent_main_panel"):
		return node as Control
	for child in node.get_children():
		var result = _find_main_panel_recursive(child)
		if result != null:
			return result
	return null

func set_main_panel(panel: Control) -> void:
	main_panel = panel
	if panel != null:
		_has_tried_find_main_panel = true

func set_editor_plugin(plugin: EditorPlugin) -> void:
	editor_plugin = plugin

func get_scene_tree() -> SceneTree:
	if main_panel != null:
		var tree = main_panel.get_tree()
		if tree != null:
			return tree
	var main_loop = Engine.get_main_loop()
	if main_loop != null:
		return main_loop as SceneTree
	return null

func wait_for_scene_tree_frame() -> void:
	if main_panel != null:
		var tree = main_panel.get_tree()
		if tree != null:
			await tree.process_frame
			return
	var main_loop = Engine.get_main_loop()
	if main_loop == null:
		return
	var scene_tree = main_loop as SceneTree
	if scene_tree != null:
		await scene_tree.process_frame
		return

func load_all_configs() -> void:
	# 延迟加载各模块
	await wait_for_scene_tree_frame()
	
	# 初始化配置管理器
	config_manager = GoGentConfigManager.new()
	
	# 初始化模型管理器
	model_manager = GoGentModelManager.new()
	
	# 初始化 Agent 管理器
	agent_manager = GoGentAgentManager.new()
	
	# 初始化控制台管理器
	console_manager = GoGentConsoleManager.new()
	
	# 初始化训练管理器
	training_manager = GoGentTrainingManager.new()
	
	# 初始化 API 管理器
	api_manager = GoGentAPIManager.new()
	
	# 初始化技能管理器
	skill_manager = GoGentSkillManager.new()
	
	GoGentPlugin.print_gogent("所有模块加载完成", "#42ffc2")

func emit_console_message(msg: String, type: String = "info") -> void:
	console_message.emit(msg, type)
	print_gogent_console(msg, type)

static func print_gogent_console(msg: String, type: String = "info") -> void:
	var color = "#abc9ff"
	match type:
		"info": color = "#abc9ff"
		"success": color = "#42ffc2"
		"warning": color = "#ffb373"
		"error": color = "#ff7085"
		"system": color = "#ffeda1"
	print_rich("[color='{0}'][GoGent] {1}[/color]".format([color, msg]))
