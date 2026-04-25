@tool
class_name GoGentConversationManager
extends RefCounted

const HISTORY_DIR := "res://addons/gogent/config/conversations/"

var current_id := ""
var current_title := ""
var messages: Array[Dictionary] = []

func _init() -> void:
	_ensure_dir()
	new_conversation()

func new_conversation(title: String = "") -> String:
	current_id = "chat_%d_%d" % [Time.get_unix_time_from_system(), randi()]
	current_title = title if not title.is_empty() else "GoGent 对话 %s" % Time.get_datetime_string_from_system(false, true)
	messages.clear()
	return current_id

func add_message(role: String, content: String, meta: Dictionary = {}) -> void:
	messages.append({
		"role": role,
		"content": content,
		"meta": meta,
		"created_at": Time.get_unix_time_from_system()
	})
	if bool(GoGentSingleton.get_instance().config_manager.get_setting("conversation_history_enabled", true)):
		save_current()

func set_messages(source: Array[Dictionary]) -> void:
	messages.clear()
	for item in source:
		messages.append(item.duplicate(true))
	if bool(GoGentSingleton.get_instance().config_manager.get_setting("conversation_history_enabled", true)):
		save_current()

func save_current() -> bool:
	_ensure_dir()
	var path := HISTORY_DIR + current_id + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({
		"id": current_id,
		"title": current_title,
		"messages": messages,
		"updated_at": Time.get_unix_time_from_system()
	}, "\t"))
	file.close()
	return true

func list_conversations() -> Array[Dictionary]:
	_ensure_dir()
	var result: Array[Dictionary] = []
	var dir := DirAccess.open(HISTORY_DIR)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var data := _read_conversation(HISTORY_DIR + file_name)
			if not data.is_empty():
				result.append({
					"id": data.get("id", file_name.get_basename()),
					"title": data.get("title", file_name),
					"message_count": data.get("messages", []).size(),
					"updated_at": data.get("updated_at", 0)
				})
		file_name = dir.get_next()
	dir.list_dir_end()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("updated_at", 0)) > int(b.get("updated_at", 0)))
	return result

func load_conversation(conversation_id: String) -> bool:
	var clean_id := conversation_id.get_file().get_basename()
	var data := _read_conversation(HISTORY_DIR + clean_id + ".json")
	if data.is_empty():
		return false
	current_id = data.get("id", clean_id)
	current_title = data.get("title", current_id)
	messages.clear()
	for item in data.get("messages", []):
		if item is Dictionary:
			messages.append(item)
	return true

func delete_conversation(conversation_id: String) -> bool:
	var path := HISTORY_DIR + conversation_id.get_file().get_basename() + ".json"
	if not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK

func _read_conversation(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	if FileAccess.get_open_error() != OK:
		return {}
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}

func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(HISTORY_DIR):
		DirAccess.make_dir_recursive_absolute(HISTORY_DIR)
