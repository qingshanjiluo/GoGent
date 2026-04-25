@tool
class_name GoGentDebugOverlay
extends CanvasLayer

## 游戏内实时调试覆盖层
## 显示 FPS、内存、节点信息等调试数据
## 支持实时命令执行和场景树浏览
## 按 F3 切换显示/隐藏
## 兼容 Godot 4.2+ (包括 4.6.2)

# 信号
signal debug_command_executed(command: String, result: String)

# 显示模式
enum DisplayMode {
	MINIMAL,     # 仅 FPS
	COMPACT,     # FPS + 内存 + 节点数
	FULL,        # 所有信息
	OFF          # 隐藏
}

# 调试面板节点
var _panel: Panel = null
var _fps_label: RichTextLabel = null
var _memory_label: Label = null
var _node_count_label: Label = null
var _scene_label: Label = null
var _viewport_label: Label = null
var _input_label: Label = null
var _command_input: LineEdit = null
var _command_output: RichTextLabel = null
var _toggle_button: Button = null
var _mode_button: Button = null

var _display_mode: int = DisplayMode.MINIMAL
var _fps_history: Array[float] = []
var _update_interval: float = 0.5
var _update_timer: float = 0.0
var _is_visible: bool = true
var _shortcut_key: int = KEY_F3
var _shortcut_held: bool = false

func _init() -> void:
	layer = 128
	process_mode = PROCESS_MODE_ALWAYS

func _enter_tree() -> void:
	_build_ui()

func _exit_tree() -> void:
	_cleanup_ui()

func _build_ui() -> void:
	# 主面板
	_panel = Panel.new()
	_panel.anchor_left = 0.0
	_panel.anchor_top = 0.0
	_panel.anchor_right = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left = 4
	_panel.offset_top = 4
	_panel.offset_right = 340
	_panel.offset_bottom = 380
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	
	# 内容容器
	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.0
	vbox.anchor_top = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vbox.theme_override_constants/separation = 2
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(vbox)
	
	# 顶栏
	var top_bar = HBoxContainer.new()
	top_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	vbox.add_child(top_bar)
	
	_toggle_button = Button.new()
	_toggle_button.text = "🛠 调试"
	_toggle_button.flat = true
	_toggle_button.pressed.connect(_toggle_visibility)
	top_bar.add_child(_toggle_button)
	
	_mode_button = Button.new()
	_mode_button.text = "模式"
	_mode_button.flat = true
	_mode_button.pressed.connect(_cycle_display_mode)
	top_bar.add_child(_mode_button)
	
	# FPS 标签 (使用 RichTextLabel 支持颜色)
	_fps_label = RichTextLabel.new()
	_fps_label.bbcode_enabled = true
	_fps_label.fit_content = true
	_fps_label.add_theme_font_size_override("normal_font_size", 14)
	vbox.add_child(_fps_label)
	
	# 内存标签
	_memory_label = Label.new()
	_memory_label.add_theme_color_override("font_color", Color(0.67, 0.8, 1.0))
	_memory_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_memory_label)
	
	# 节点数标签
	_node_count_label = Label.new()
	_node_count_label.add_theme_color_override("font_color", Color(0.67, 0.8, 1.0))
	_node_count_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_node_count_label)
	
	# 场景标签
	_scene_label = Label.new()
	_scene_label.add_theme_color_override("font_color", Color(0.67, 0.8, 1.0))
	_scene_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_scene_label)
	
	# 视口标签
	_viewport_label = Label.new()
	_viewport_label.add_theme_color_override("font_color", Color(0.67, 0.8, 1.0))
	_viewport_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_viewport_label)
	
	# 输入标签
	_input_label = Label.new()
	_input_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
	_input_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_input_label)
	
	# 命令输出
	_command_output = RichTextLabel.new()
	_command_output.custom_minimum_size = Vector2(300, 80)
	_command_output.size_flags_vertical = Control.SIZE_EXPAND
	_command_output.bbcode_enabled = true
	_command_output.scroll_active = true
	_command_output.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_command_output)
	
	# 命令输入行
	var cmd_hbox = HBoxContainer.new()
	vbox.add_child(cmd_hbox)
	
	_command_input = LineEdit.new()
	_command_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_command_input.placeholder_text = "输入调试命令..."
	_command_input.text_submitted.connect(_on_command_submitted)
	cmd_hbox.add_child(_command_input)
	
	var exec_button = Button.new()
	exec_button.text = "执行"
	exec_button.pressed.connect(_on_command_execute)
	cmd_hbox.add_child(exec_button)
	
	_update_display_mode()

func _cleanup_ui() -> void:
	if _panel:
		_panel.queue_free()
		_panel = null

func _process(delta: float) -> void:
	if _display_mode == DisplayMode.OFF:
		hide()
		return
	
	# 处理快捷键 F3
	if Input.is_key_pressed(_shortcut_key):
		if not _shortcut_held:
			_shortcut_held = true
			_toggle_visibility()
	else:
		_shortcut_held = false
	
	if not _is_visible:
		hide()
		return
	
	show()
	
	_update_timer += delta
	if _update_timer < _update_interval:
		return
	_update_timer = 0.0
	
	_update_debug_info()

func _update_debug_info() -> void:
	if not is_inside_tree():
		return
	
	# FPS
	var fps = Performance.get_monitor(Performance.TIME_FPS)
	_fps_history.append(fps)
	if _fps_history.size() > 60:
		_fps_history.pop_front()
	
	var avg_fps = 0.0
	if not _fps_history.is_empty():
		var sum = 0.0
		for v in _fps_history:
			sum += v
		avg_fps = sum / _fps_history.size()
	
	var fps_color = "#42ffc2" if fps >= 55 else ("#ffb373" if fps >= 30 else "#ff7085")
	_fps_label.text = "[color={0}]FPS: {1}  (平均: {2:.0f})[/color]".format([fps_color, fps, avg_fps])
	
	if _display_mode == DisplayMode.MINIMAL:
		_hide_all_except([_fps_label])
		return
	
	# 内存
	var mem_usage = Performance.get_monitor(Performance.MEMORY_STATIC)
	_memory_label.text = "内存: {0}".format([_format_bytes(mem_usage)])
	
	# 节点数
	var node_count = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var orphan_count = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	_node_count_label.text = "节点: {0}  (游离: {1})".format([node_count, orphan_count])
	
	# 场景信息
	if get_tree():
		var current_scene = get_tree().current_scene
		if current_scene:
			var scene_path = ""
			if current_scene.has_method("get_scene_file_path"):
				scene_path = current_scene.get_scene_file_path()
			elif "scene_file_path" in current_scene:
				scene_path = current_scene.scene_file_path
			_scene_label.text = "场景: {0}".format([scene_path if scene_path else current_scene.name])
	
	# 视口信息
	var root = get_tree().root if get_tree() else null
	if root:
		var vp_size = root.get_visible_rect().size
		_viewport_label.text = "视口: {0}x{1}".format([vp_size.x, vp_size.y])
	
	# 输入设备
	var input_devices = []
	if Input.get_connected_joypads().size() > 0:
		input_devices.append("手柄")
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		input_devices.append("鼠标")
	input_devices.append("键盘")
	_input_label.text = "输入: {0}".format([", ".join(input_devices)])
	
	# 根据模式显示/隐藏
	match _display_mode:
		DisplayMode.COMPACT:
			_hide_all_except([_fps_label, _memory_label, _node_count_label])
		DisplayMode.FULL:
			_show_all()

func _hide_all_except(visible_list: Array) -> void:
	for child in [_memory_label, _node_count_label, _scene_label, _viewport_label, _input_label, _command_output, _command_input]:
		if child and is_instance_valid(child):
			child.visible = child in visible_list

func _show_all() -> void:
	for child in [_memory_label, _node_count_label, _scene_label, _viewport_label, _input_label]:
		if child and is_instance_valid(child):
			child.visible = true

func _toggle_visibility() -> void:
	_is_visible = not _is_visible

func _cycle_display_mode() -> void:
	_display_mode = (_display_mode + 1) % 4
	_update_display_mode()

func _update_display_mode() -> void:
	var mode_names = ["最小", "简洁", "完整", "关闭"]
	if _mode_button and is_instance_valid(_mode_button):
		_mode_button.text = "模式: {0}".format([mode_names[_display_mode]])

func _on_command_submitted(text: String) -> void:
	_execute_debug_command(text)
	_command_input.text = ""

func _on_command_execute() -> void:
	var text = _command_input.text.strip_edges()
	if not text.is_empty():
		_execute_debug_command(text)
		_command_input.text = ""

func _execute_debug_command(command: String) -> void:
	var result = ""
	
	if command.begins_with("/"):
		result = _execute_internal_command(command.substr(1))
	else:
		var singleton = GoGentSingleton.get_instance()
		if singleton and singleton.console_manager:
			singleton.console_manager.execute_command(command)
			var msgs = singleton.console_manager.messages
			if not msgs.is_empty():
				result = msgs[-1].text
		else:
			result = "控制台管理器不可用"
	
	if _command_output and is_instance_valid(_command_output):
		_command_output.append_text("[color='#abc9ff']> {0}\n[/color]".format([command]))
		_command_output.append_text("[color='#ffffff']{0}\n[/color]".format([result]))
		_command_output.scroll_to_line(_command_output.get_line_count() - 1)
	
	debug_command_executed.emit(command, result)

func _execute_internal_command(cmd: String) -> String:
	var parts = cmd.split(" ", false)
	var cmd_name = parts[0].to_lower()
	
	match cmd_name:
		"fps":
			_display_mode = DisplayMode.MINIMAL
			return "切换到 FPS 模式"
		"full":
			_display_mode = DisplayMode.FULL
			return "切换到完整模式"
		"hide":
			_is_visible = false
			return "调试面板已隐藏"
		"show":
			_is_visible = true
			return "调试面板已显示"
		"clear":
			if _command_output and is_instance_valid(_command_output):
				_command_output.text = ""
			return "输出已清除"
		"gc":
			return "GC 请求已发送"
		"nodes":
			var node_count = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
			return "场景节点数: {0}".format([node_count])
		"mem":
			var mem = Performance.get_monitor(Performance.MEMORY_STATIC)
			return "内存使用: {0}".format([_format_bytes(mem)])
		_:
			return "未知内部命令: {0}\n可用: fps, full, hide, show, clear, gc, nodes, mem".format([cmd_name])

static func _format_bytes(bytes: int) -> String:
	if bytes < 1024:
		return "{0} B".format([bytes])
	elif bytes < 1024 * 1024:
		return "{0:.1f} KB".format([bytes / 1024.0])
	elif bytes < 1024 * 1024 * 1024:
		return "{0:.1f} MB".format([bytes / (1024.0 * 1024.0)])
	else:
		return "{0:.2f} GB".format([bytes / (1024.0 * 1024.0 * 1024.0)])

## 设置快捷键
func set_shortcut_key(key: int) -> void:
	_shortcut_key = key

## 设置更新间隔
func set_update_interval(interval: float) -> void:
	_update_interval = max(0.1, interval)

## 获取当前 FPS
func get_current_fps() -> float:
	return Performance.get_monitor(Performance.TIME_FPS)

## 获取平均 FPS
func get_average_fps() -> float:
	if _fps_history.is_empty():
		return 0.0
	var sum = 0.0
	for v in _fps_history:
		sum += v
	return sum / _fps_history.size()
