@tool
class_name GoGentMessageItem
extends MarginContainer

var _user_panel: PanelContainer
var _assistant_box: VBoxContainer
var _user_content: RichTextLabel
var _assistant_content: RichTextLabel
var _thinking_content: RichTextLabel

func _ready() -> void:
	if get_child_count() == 0:
		_build_ui()
	hide_all()

func _build_ui() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(root)

	_user_panel = PanelContainer.new()
	_user_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_user_panel)
	_user_content = _make_text()
	_user_panel.add_child(_user_content)

	_assistant_box = VBoxContainer.new()
	_assistant_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_assistant_box)
	_thinking_content = _make_text()
	_thinking_content.add_theme_color_override("default_color", Color(0.68, 0.72, 0.78))
	_assistant_box.add_child(_thinking_content)
	_assistant_content = _make_text()
	_assistant_box.add_child(_assistant_content)

func _make_text() -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.selection_enabled = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func hide_all() -> void:
	if _user_panel:
		_user_panel.visible = false
	if _assistant_box:
		_assistant_box.visible = false
	if _thinking_content:
		_thinking_content.visible = false

func set_user_message(text: String) -> void:
	hide_all()
	_user_panel.visible = true
	_user_content.text = "[b]You[/b]\n%s" % _escape(text)

func set_assistant_message(text: String, thinking: String = "") -> void:
	hide_all()
	_assistant_box.visible = true
	_assistant_content.text = "[b]GoGent[/b]\n%s" % text
	if not thinking.strip_edges().is_empty():
		_thinking_content.visible = true
		_thinking_content.text = "[i]Thinking[/i]\n%s" % _escape(thinking)

func set_system_message(text: String) -> void:
	set_assistant_message("[color=#ffeda1]%s[/color]" % _escape(text))

func _escape(text: String) -> String:
	return text.replace("[", "\\[").replace("]", "\\]")
