@tool
class_name GoGentTempFileManager
extends RefCounted
## 临时文件回滚管理器
##
## 在 AI 编辑文件前自动创建备份，支持回滚操作。
## 参考 AlphaAgent 的 AgentTempFileManager 设计。

class EditedFile:
	var target_path: String      # 原始文件路径（res://）
	var origin_exist: bool       # 原始文件是否存在
	var origin_content: String   # 原始文件内容
	var temp_path: String        # 临时备份文件路径
	var timestamp: int           # 创建时间戳

	func _init(p_path: String, p_exist: bool, p_content: String, p_temp: String) -> void:
		target_path = p_path
		origin_exist = p_exist
		origin_content = p_content
		temp_path = p_temp
		timestamp = Time.get_unix_time_from_system()

	func to_dict() -> Dictionary:
		return {
			"target_path": target_path,
			"origin_exist": origin_exist,
			"origin_content": origin_content.left(200),
			"temp_path": temp_path,
			"timestamp": timestamp
		}

const TEMP_DIR_PREFIX := "gogent_temp_"

var _edited_files: Array[EditedFile] = []
var _temp_dir: String = ""
var _initialized := false

func _init() -> void:
	_init_temp_dir()

func _init_temp_dir() -> void:
	var user_dir := OS.get_user_data_dir()
	if user_dir.is_empty():
		user_dir = ProjectSettings.globalize_path("res://")
	_temp_dir = user_dir.path_join(".gogent").path_join("temp")
	_ensure_dir(_temp_dir)
	_initialized = true

func _ensure_dir(path: String) -> void:
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())

## 在编辑文件前创建临时备份
## 返回 EditedFile 对象，如果文件不存在也记录
func create_temp_file(target_path: String) -> EditedFile:
	if not _initialized:
		_init_temp_dir()

	var global_path := _resolve_path(target_path)
	var exist := FileAccess.file_exists(global_path)
	var content := ""

	if exist:
		content = FileAccess.get_file_as_string(global_path)
		if FileAccess.get_open_error() != OK:
			content = ""

	# 生成临时文件名
	var safe_name := target_path.replace("res://", "").replace("/", "_").replace("\\", "_")
	var temp_filename := "%s_%d_%d.bak" % [safe_name, Time.get_unix_time_from_system(), randi()]
	var temp_path := _temp_dir.path_join(temp_filename)

	# 写入备份
	if exist and not content.is_empty():
		var file := FileAccess.open(temp_path, FileAccess.WRITE)
		if file != null:
			file.store_string(content)
			file.close()

	var edited := EditedFile.new(target_path, exist, content, temp_path)
	_edited_files.append(edited)
	return edited

## 回滚指定文件的修改
## 返回是否成功
func rollback_file(target_path: String) -> bool:
	for i in range(_edited_files.size() - 1, -1, -1):
		var edited := _edited_files[i]
		if edited.target_path == target_path:
			return _do_rollback(edited)

	return false

## 回滚所有文件的修改
func rollback_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for edited in _edited_files:
		var success := _do_rollback(edited)
		results.append({"path": edited.target_path, "success": success})
	_edited_files.clear()
	return results

## 接受所有修改（删除临时文件）
func accept_all() -> void:
	_cleanup_temp_files()
	_edited_files.clear()

## 获取所有已编辑的文件列表
func get_edited_files() -> Array[EditedFile]:
	return _edited_files.duplicate()

## 获取指定文件的编辑记录
func get_edited_file(target_path: String) -> EditedFile:
	for edited in _edited_files:
		if edited.target_path == target_path:
			return edited
	return null

## 检查是否有未决定的修改
func has_pending_changes() -> bool:
	return not _edited_files.is_empty()

## 获取临时目录路径
func get_temp_dir() -> String:
	return _temp_dir

func _do_rollback(edited: EditedFile) -> bool:
	var global_path := _resolve_path(edited.target_path)

	if edited.origin_exist:
		# 恢复原始内容
		var file := FileAccess.open(global_path, FileAccess.WRITE)
		if file == null:
			return false
		file.store_string(edited.origin_content)
		file.close()
	else:
		# 文件原本不存在，删除
		if FileAccess.file_exists(global_path):
			var dir := DirAccess.open(global_path.get_base_dir())
			if dir != null:
				dir.remove(global_path.get_file())

	# 删除临时文件
	if FileAccess.file_exists(edited.temp_path):
		var dir := DirAccess.open(edited.temp_path.get_base_dir())
		if dir != null:
			dir.remove(edited.temp_path.get_file())

	_edited_files.erase(edited)
	return true

func _cleanup_temp_files() -> void:
	for edited in _edited_files:
		if FileAccess.file_exists(edited.temp_path):
			var dir := DirAccess.open(edited.temp_path.get_base_dir())
			if dir != null:
				dir.remove(edited.temp_path.get_file())

func _resolve_path(path: String) -> String:
	if path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)
	return path

## 清理所有临时文件（启动时调用）
static func cleanup_old_temp_files() -> void:
	var user_dir := OS.get_user_data_dir()
	if user_dir.is_empty():
		return
	var gogent_dir := user_dir.path_join(".gogent").path_join("temp")
	if not DirAccess.dir_exists_absolute(gogent_dir):
		return
	var dir := DirAccess.open(gogent_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if file_name.ends_with(".bak"):
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
