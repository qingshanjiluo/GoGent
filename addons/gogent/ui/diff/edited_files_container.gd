@tool
class_name GoGentEditedFilesContainer
extends VBoxContainer
## 已编辑文件列表容器
##
## 显示所有被 AI 修改过的文件，支持逐个接受/回滚和批量操作。
## 参考 AlphaAgent 的 EditedFilesContainer 设计。

signal all_accepted()
signal all_rolled_back()

var _temp_manager: GoGentTempFileManager
var _diff_viewers: Array[GoGentDiffViewer] = []
var _is_collapsed := false

@onready var _header := $Header as HBoxContainer
@onready var _title_label := $Header/TitleLabel as Label
@onready var _collapse_btn := $Header/CollapseBtn as Button
@onready var _accept_all_btn := $Header/AcceptAllBtn as Button
@onready var _rollback_all_btn := $Header/RollbackAllBtn as Button
@onready var _file_list := $FileList as VBoxContainer
@onready var _empty_label := $EmptyLabel as Label

func _ready() -> void:
	if _accept_all_btn:
		_accept_all_btn.pressed.connect(_on_accept_all)
	if _rollback_all_btn:
		_rollback_all_btn.pressed.connect(_on_rollback_all)
	if _collapse_btn:
		_collapse_btn.pressed.connect(_toggle_collapse)

## 设置临时文件管理器
func set_temp_manager(manager: GoGentTempFileManager) -> void:
	_temp_manager = manager
	refresh()

## 刷新显示
func refresh() -> void:
	if _temp_manager == null:
		return

	# 清空旧内容
	for child in _file_list.get_children():
		child.queue_free()
	_diff_viewers.clear()

	var edited_files := _temp_manager.get_edited_files()
	if edited_files.is_empty():
		_file_list.visible = false
		if _empty_label:
			_empty_label.visible = true
		if _title_label:
			_title_label.text = "已编辑文件 (0)"
		return

	_file_list.visible = true
	if _empty_label:
		_empty_label.visible = false
	if _title_label:
		_title_label.text = "已编辑文件 (%d)" % edited_files.size()

	for edited in edited_files:
		var viewer := _create_diff_viewer(edited)
		_file_list.add_child(viewer)
		_diff_viewers.append(viewer)

func _create_diff_viewer(edited: GoGentTempFileManager.EditedFile) -> GoGentDiffViewer:
	var viewer := GoGentDiffViewer.new()
	viewer.set_diff(edited.target_path, edited.origin_content, _read_current_content(edited.target_path))
	viewer.accepted.connect(_on_file_accepted)
	viewer.rolled_back.connect(_on_file_rolled_back)
	return viewer

func _read_current_content(path: String) -> String:
	var global_path := path
	if path.begins_with("res://"):
		global_path = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global_path):
		return FileAccess.get_file_as_string(global_path)
	return ""

func _on_file_accepted(path: String) -> void:
	if _temp_manager:
		# 从管理器中移除记录（保留文件不变）
		var edited := _temp_manager.get_edited_file(path)
		if edited:
			# 删除临时备份
			if FileAccess.file_exists(edited.temp_path):
				var dir := DirAccess.open(edited.temp_path.get_base_dir())
				if dir:
					dir.remove(edited.temp_path.get_file())
	refresh()

func _on_file_rolled_back(path: String) -> void:
	if _temp_manager:
		_temp_manager.rollback_file(path)
	refresh()

func _on_accept_all() -> void:
	if _temp_manager:
		_temp_manager.accept_all()
	refresh()
	all_accepted.emit()

func _on_rollback_all() -> void:
	if _temp_manager:
		_temp_manager.rollback_all()
	refresh()
	all_rolled_back.emit()

func _toggle_collapse() -> void:
	_is_collapsed = not _is_collapsed
	_file_list.visible = not _is_collapsed
	if _collapse_btn:
		_collapse_btn.text = "▶" if _is_collapsed else "▼"

## 获取当前差异查看器列表
func get_diff_viewers() -> Array[GoGentDiffViewer]:
	return _diff_viewers.duplicate()

## 检查是否有待处理的文件
func has_pending() -> bool:
	return _temp_manager != null and _temp_manager.has_pending_changes()
