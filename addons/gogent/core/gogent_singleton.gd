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

const ConfigManagerScript := preload("res://addons/gogent/core/config_manager.gd")
const ModelManagerScript := preload("res://addons/gogent/core/model_manager.gd")
const AgentManagerScript := preload("res://addons/gogent/core/agent_manager.gd")
const ConsoleManagerScript := preload("res://addons/gogent/core/console_manager.gd")
const TrainingManagerScript := preload("res://addons/gogent/core/training_manager.gd")
const APIManagerScript := preload("res://addons/gogent/core/api_manager.gd")
const SkillManagerScript := preload("res://addons/gogent/core/skill_manager.gd")
const ExternalToolManagerScript := preload("res://addons/gogent/core/external_tool_manager.gd")

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
	print_gogent_console("All GoGent managers loaded.", "success")

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
