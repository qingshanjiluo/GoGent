@tool
class_name GoGentConfigManager
extends RefCounted

## GoGent 配置管理器
## 管理插件的全局配置

const CONFIG_FILE: String = "res://addons/gogent/config/gogent_settings.cfg"

var settings: Dictionary = {
	# 通用设置
	"auto_clear_console": true,
	"max_console_lines": 1000,
	"theme": "dark",
	
	# API 设置
	"default_api_type": "openai",
	"http_proxy_host": "",
	"http_proxy_port": "",
	
	# Agent 设置
	"agent_auto_decision_interval": 30.0,
	"agent_max_history": 100,
	
	# 训练设置
	"training_episodes": 1000,
	"training_save_interval": 100,
	"training_learning_rate": 0.001,
}

func _init() -> void:
	load_settings()

func load_settings() -> void:
	var file = FileAccess.open(CONFIG_FILE, FileAccess.READ)
	if FileAccess.get_open_error() != OK:
		GoGentPlugin.print_gogent("配置文件不存在，使用默认设置", "#ffb373")
		save_settings()
		return
	
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.parse_string(content)
	if json != null:
		for key in json.keys():
			if settings.has(key):
				settings[key] = json[key]
	
	GoGentPlugin.print_gogent("配置加载完成", "#42ffc2")

func save_settings() -> void:
	var dir = CONFIG_FILE.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	
	var file = FileAccess.open(CONFIG_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings, "\t"))
		file.close()

func get_setting(key: String, default_value = null):
	return settings.get(key, default_value)

func set_setting(key: String, value) -> void:
	settings[key] = value
	save_settings()
