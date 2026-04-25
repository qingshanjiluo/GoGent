@tool
class_name GoGentDiffViewer
extends Control
## 差异查看器 UI 组件
##
## 显示文件修改前后的差异对比，支持接受/回滚操作。

signal accepted(path: String)
signal rolled_back(path: String)
signal all_accepted()
signal all_rolled_back()

const PADDING := 4
const LINE_HEIGHT := 22

var _file_path: String
var _old_lines: Array[String] = []
var _new_lines: Array[String] = []
var _diff_result: GoGentDiffUtils.DiffResult
var _line_widgets: Array[Control] = []

@onready var _header := $Header as HBoxContainer
@onready var _file_label := $Header/FileLabel as Label
@onready var _accept_btn := $Header/AcceptBtn as Button
@onready var _rollback_btn := $Header/RollbackBtn as Button
@onready var _line_container := $LineContainer as VBoxContainer
@onready var _stats_label := $StatsLabel as Label

func _ready() -> void:
	if _accept_btn:
		_accept_btn.pressed.connect(_on_accept)
	if _rollback_btn:
		_rollback_btn.pressed.connect(_on_rollback)

## 设置要显示的差异
func set_diff(file_path: String, old_content: String, new_content: String) -> void:
	_file_path = file_path
	_old_lines = GoGentDiffUtils.split_lines(old_content)
	_new_lines = GoGentDiffUtils.split_lines(new_content)
	_diff_result = GoGentDiffUtils.compute(_old_lines, _new_lines)
	_render()

## 直接从 DiffResult 设置
func set_diff_result(file_path: String, old_lines: Array[String], new_lines: Array[String], result: GoGentDiffUtils.DiffResult) -> void:
	_file_path = file_path
	_old_lines = old_lines
	_new_lines = new_lines
	_diff_result = result
	_render()

func _render() -> void:
	if _file_label:
		_file_label.text = _file_path

	# 清空旧内容
	for child in _line_container.get_children():
		child.queue_free()
	_line_widgets.clear()

	if _diff_result == null or _diff_result.edit_script.is_empty():
		var label := Label.new()
		label.text = "  文件无变化"
		label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_line_container.add_child(label)
		return

	# 渲染编辑脚本
	for op in _diff_result.edit_script:
		var line := _create_line_widget(op)
		_line_container.add_child(line)
		_line_widgets.append(line)

	# 更新统计信息
	if _stats_label:
		var added := _diff_result.added_lines.size()
		var deleted := _diff_result.deleted_lines.size()
		_stats_label.text = "+%d  -%d  %d 行不变" % [added, deleted, _diff_result.unchanged_lines.size()]
		var color := "#42ffc2" if added > 0 else "#abc9ff"
		_stats_label.add_theme_color_override("font_color", Color(color))

func _create_line_widget(op: GoGentDiffUtils.DiffOp) -> Control:
	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size.y = LINE_HEIGHT
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 行号标签
	var line_num := Label.new()
	line_num.custom_minimum_size.x = 40
	line_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line_num.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	line_num.add_theme_font_size_override("font_size", 11)

	match op.op_type:
		GoGentDiffUtils.DiffOp.OpType.EQUAL:
			line_num.text = "%d" % (op.old_line + 1)
			hbox.modulate = Color(1, 1, 1, 0.6)
		GoGentDiffUtils.DiffOp.OpType.INSERT:
			line_num.text = "  +"
			hbox.modulate = Color(0.26, 1, 0.76, 0.15)
		GoGentDiffUtils.DiffOp.OpType.DELETE:
			line_num.text = "  -"
			hbox.modulate = Color(1, 0.44, 0.52, 0.15)

	hbox.add_child(line_num)

	# 操作标记
	var marker := Label.new()
	marker.custom_minimum_size.x = 16
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.add_theme_font_size_override("font_size", 11)
	match op.op_type:
		GoGentDiffUtils.DiffOp.OpType.EQUAL:
			marker.text = " "
			marker.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		GoGentDiffUtils.DiffOp.OpType.INSERT:
			marker.text = "+"
			marker.add_theme_color_override("font_color", Color(0.26, 1, 0.76))
		GoGentDiffUtils.DiffOp.OpType.DELETE:
			marker.text = "-"
			marker.add_theme_color_override("font_color", Color(1, 0.44, 0.52))
	hbox.add_child(marker)

	# 文本内容
	var text := Label.new()
	text.text = op.text
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.autowrap_mode = TextServer.AUTOWRAP_OFF
	text.add_theme_font_size_override("font_size", 12)
	# 防止过长文本撑开
	text.clip_text = true
	hbox.add_child(text)

	return hbox

func _on_accept() -> void:
	accepted.emit(_file_path)

func _on_rollback() -> void:
	rolled_back.emit(_file_path)

## 获取文件路径
func get_file_path() -> String:
	return _file_path
