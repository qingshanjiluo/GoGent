@tool
class_name GoGentPlugin
extends EditorPlugin

## GoGent 主插件入口
## 整合了 Agent 协作、AI 训练、API 链接、控制台调试等功能

const PLUGIN_DIR: String = "res://addons/gogent/"
const CONFIG_DIR: String = "res://addons/gogent/config/"

# 预加载主面板
const MAIN_PANEL = preload("res://addons/gogent/ui/main_panel.tscn")

func _enable_plugin() -> void:
	pass

func _disable_plugin() -> void:
	pass

func _enter_tree() -> void:
	print_rich("[color='#42ffc2']=== GoGent 插件初始化中... ===[/color]")
	
	# 初始化配置目录
	_init_config_dir()
	
	# 创建主面板并添加到编辑器
	var main_panel = MAIN_PANEL.instantiate()
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, main_panel)
	
	# 初始化单例
	var singleton = GoGentSingleton.get_instance()
	singleton.set_main_panel(main_panel)
	singleton.set_editor_plugin(self)
	
	# 加载配置
	await _load_configs()
	
	print_rich("[color='#42ffc2']=== GoGent 插件初始化完成！ ===[/color]")
	print_rich("[color='#abc9ff']GoGent - 让 Godot 开发更智能[/color]")

func _exit_tree() -> void:
	var singleton = GoGentSingleton.get_instance()
	var main_panel = singleton.main_panel
	
	if main_panel != null:
		remove_control_from_docks(main_panel)
		main_panel.queue_free()
	
	singleton.set_main_panel(null)
	singleton.set_editor_plugin(null)

func _init_config_dir() -> void:
	if not DirAccess.dir_exists_absolute(CONFIG_DIR):
		DirAccess.make_dir_recursive_absolute(CONFIG_DIR)

func _load_configs() -> void:
	# 延迟加载各模块
	GoGentSingleton.get_instance().load_all_configs()

# ========== 工具函数 ==========

static func get_plugin_dir() -> String:
	return PLUGIN_DIR

static func print_gogent(msg: String, color: String = "#abc9ff") -> void:
	print_rich("[color='{0}']{1}[/color]".format([color, msg]))
