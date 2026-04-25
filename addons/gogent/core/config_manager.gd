@tool
class_name GoGentConfigManager
extends RefCounted

const CONFIG_FILE := "res://addons/gogent/config/gogent_settings.json"

var settings: Dictionary = {
	"auto_clear_console": true,
	"max_console_lines": 1000,
	"theme": "dark",
	"language": "zh_CN",
	"tutorial_seen": false,
	"conversation_history_enabled": true,
	"auto_apply_tool_calls": true,
	"auto_continue_tool_calls": true,
	"max_auto_tool_rounds": 4,
	"http_proxy_host": "",
	"http_proxy_port": 0,
	"default_temperature": 0.7,
	"default_top_p": 1.0,
	"default_max_tokens": 8192,
	"default_presence_penalty": 0.0,
	"default_frequency_penalty": 0.0,
	"default_reasoning_enabled": true,
	"default_tools_enabled": true,
	"default_json_mode": false,
	"stream_by_default": true,
	"request_timeout": 120,
	# API 请求频率限制（毫秒，0=不限制）
	"api_request_delay_ms": 500,
	# 工具调用间隔延迟（毫秒，0=不延迟）
	"tool_call_delay_ms": 200,
	# 每次 API 请求的最大重试次数
	"api_max_retries": 3,
	"training_episodes": 100,
	"training_save_interval": 100,
	"claude_enabled": true,
	"claude_command": "claude",
	"claude_prompt_args": ["-p", "{prompt}"],
	"codex_enabled": true,
	"codex_command": "codex",
	"codex_prompt_args": ["exec", "{prompt}"]
}

func _init() -> void:
	_ensure_dir()
	load_settings()

func _ensure_dir() -> void:
	var dir := CONFIG_FILE.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

func load_settings() -> void:
	if not FileAccess.file_exists(CONFIG_FILE):
		save_settings()
		return
	var text := FileAccess.get_file_as_string(CONFIG_FILE)
	if FileAccess.get_open_error() != OK:
		return
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		for key in parsed.keys():
			settings[key] = parsed[key]

func save_settings() -> bool:
	_ensure_dir()
	var file := FileAccess.open(CONFIG_FILE, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(settings, "\t"))
	file.close()
	return true

func get_setting(key: String, default_value = null):
	return settings.get(key, default_value)

func set_setting(key: String, value) -> void:
	settings[key] = value
	save_settings()

func set_many(values: Dictionary) -> void:
	for key in values.keys():
		settings[key] = values[key]
	save_settings()
