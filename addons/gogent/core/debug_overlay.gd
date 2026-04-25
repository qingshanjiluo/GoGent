@tool
class_name GoGentDebugOverlay
extends CanvasLayer

signal debug_command_executed(command: String, result: String)

enum DisplayMode { MINIMAL, COMPACT, FULL, OFF }

var _panel: PanelContainer
var _fps_label: RichTextLabel
var _memory_label: Label
var _node_label: Label
var _scene_label: Label
var _command_output: RichTextLabel
var _command_input: LineEdit
var _mode_button: Button
var _display_mode: DisplayMode = DisplayMode.MINIMAL
var _shortcut_held := false
var _update_timer := 0.0
var _fps_history: Array[float] = []

func _init() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	if not Engine.is_editor_hint():
		_build_ui()
	else:
		_build_ui()
		visible = false

func _process(delta: float) -> void:
	if _display_mode == DisplayMode.OFF:
		visible = false
		return
	if Input.is_key_pressed(KEY_F3):
		if not _shortcut_held:
			_shortcut_held = true
			visible = not visible
	else:
		_shortcut_held = false
	if not visible:
		return
	_update_timer += delta
	if _update_timer >= 0.5:
		_update_timer = 0.0
		_update_stats()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.offset_left = 8
	_panel.offset_top = 8
	_panel.offset_right = 360
	_panel.offset_bottom = 330
	add_child(_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	_panel.add_child(root)

	var top := HBoxContainer.new()
	root.add_child(top)

	var title := Label.new()
	title.text = "GoGent Debug"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)

	_mode_button = Button.new()
	_mode_button.text = "Mode"
	_mode_button.pressed.connect(_cycle_mode)
	top.add_child(_mode_button)

	_fps_label = RichTextLabel.new()
	_fps_label.bbcode_enabled = true
	_fps_label.fit_content = true
	root.add_child(_fps_label)

	_memory_label = Label.new()
	root.add_child(_memory_label)
	_node_label = Label.new()
	root.add_child(_node_label)
	_scene_label = Label.new()
	root.add_child(_scene_label)

	_command_output = RichTextLabel.new()
	_command_output.bbcode_enabled = true
	_command_output.custom_minimum_size = Vector2(320, 90)
	root.add_child(_command_output)

	var command_row := HBoxContainer.new()
	root.add_child(command_row)
	_command_input = LineEdit.new()
	_command_input.placeholder_text = "debug command"
	_command_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_command_input.text_submitted.connect(func(text: String): _execute_command(text))
	command_row.add_child(_command_input)
	var run_button := Button.new()
	run_button.text = "Run"
	run_button.pressed.connect(func(): _execute_command(_command_input.text))
	command_row.add_child(run_button)
	_update_mode_visibility()
	_update_stats()

func _update_stats() -> void:
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	_fps_history.append(fps)
	while _fps_history.size() > 60:
		_fps_history.pop_front()
	var avg := 0.0
	for item in _fps_history:
		avg += item
	avg = avg / max(1, _fps_history.size())
	var color := "#42ffc2" if fps >= 55 else ("#ffb373" if fps >= 30 else "#ff7085")
	_fps_label.text = "[color=%s]FPS: %.0f avg %.0f[/color]" % [color, fps, avg]
	_memory_label.text = "Memory: %s" % _format_bytes(int(Performance.get_monitor(Performance.MEMORY_STATIC)))
	_node_label.text = "Nodes: %d  Orphans: %d" % [Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)]
	var scene := get_tree().current_scene if get_tree() else null
	_scene_label.text = "Scene: %s" % (scene.scene_file_path if scene != null and not scene.scene_file_path.is_empty() else (scene.name if scene != null else "<none>"))

func _cycle_mode() -> void:
	_display_mode = (_display_mode + 1) % 4
	_update_mode_visibility()

func _update_mode_visibility() -> void:
	var full := _display_mode == DisplayMode.FULL
	var compact := _display_mode == DisplayMode.COMPACT or full
	_memory_label.visible = compact
	_node_label.visible = compact
	_scene_label.visible = full
	_command_output.visible = full
	_command_input.visible = full
	if _mode_button:
		_mode_button.text = ["Minimal", "Compact", "Full", "Off"][_display_mode]

func _execute_command(command: String) -> void:
	var line := command.strip_edges()
	if line.is_empty():
		return
	var result := _internal_command(line)
	if result.is_empty():
		var console = GoGentSingleton.get_instance().console_manager
		result = console.execute_command(line) if console != null else "Console manager is not ready."
	_command_output.append_text("[color=#abc9ff]> %s[/color]\n%s\n" % [line, result])
	_command_output.scroll_to_line(max(0, _command_output.get_line_count() - 1))
	_command_input.text = ""
	debug_command_executed.emit(line, result)

func _internal_command(command: String) -> String:
	match command.to_lower():
		"/fps":
			_display_mode = DisplayMode.MINIMAL
			_update_mode_visibility()
			return "Mode set to minimal."
		"/full":
			_display_mode = DisplayMode.FULL
			_update_mode_visibility()
			return "Mode set to full."
		"/hide":
			visible = false
			return "Overlay hidden."
		"/clear":
			_command_output.text = ""
			return "Output cleared."
		"/mem":
			return _memory_label.text
		"/nodes":
			return _node_label.text
	return ""

static func _format_bytes(value: int) -> String:
	if value < 1024:
		return "%d B" % value
	if value < 1024 * 1024:
		return "%.1f KB" % (value / 1024.0)
	if value < 1024 * 1024 * 1024:
		return "%.1f MB" % (value / 1048576.0)
	return "%.2f GB" % (value / 1073741824.0)
