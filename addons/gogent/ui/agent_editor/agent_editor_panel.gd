@tool
class_name GoGentAgentEditorPanel
extends HSplitContainer

signal agent_created(agent_data: Dictionary)
signal agent_updated(agent_id: String, agent_data: Dictionary)
signal agent_deleted(agent_id: String)
signal agent_selected(agent_id: String)

var agent_list: ItemList
var search_input: LineEdit
var name_input: LineEdit
var role_input: LineEdit
var prompt_edit: TextEdit
var temperature_slider: HSlider
var temperature_label: Label
var max_tokens_spin: SpinBox
var enabled_toggle: CheckButton
var auto_toggle: CheckButton
var skill_list: VBoxContainer
var preview: RichTextLabel
var delete_button: Button

var _current_agent_id := ""

func _ready() -> void:
	if get_child_count() == 0:
		_build_ui()
	_connect_singleton_signals()
	refresh()

func _build_ui() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(180, 0)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(left)

	search_input = LineEdit.new()
	search_input.placeholder_text = "Search agents"
	search_input.text_changed.connect(_filter_agents)
	left.add_child(search_input)

	agent_list = ItemList.new()
	agent_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	agent_list.item_selected.connect(_select_agent)
	left.add_child(agent_list)

	var left_actions := HBoxContainer.new()
	left.add_child(left_actions)
	var new_button := Button.new()
	new_button.text = "New"
	new_button.pressed.connect(_new_agent)
	left_actions.add_child(new_button)
	delete_button = Button.new()
	delete_button.text = "Delete"
	delete_button.disabled = true
	delete_button.pressed.connect(_delete_agent)
	left_actions.add_child(delete_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(form)

	name_input = _line(form, "Name")
	role_input = _line(form, "Role")
	prompt_edit = TextEdit.new()
	prompt_edit.custom_minimum_size = Vector2(0, 150)
	prompt_edit.placeholder_text = "System prompt"
	prompt_edit.text_changed.connect(_update_preview)
	form.add_child(_label("System Prompt"))
	form.add_child(prompt_edit)

	var temp_row := HBoxContainer.new()
	form.add_child(temp_row)
	temp_row.add_child(_label("Temperature"))
	temperature_slider = HSlider.new()
	temperature_slider.min_value = 0.0
	temperature_slider.max_value = 2.0
	temperature_slider.step = 0.01
	temperature_slider.value = 0.7
	temperature_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	temperature_slider.value_changed.connect(func(value: float):
		temperature_label.text = "%.2f" % value
		_update_preview()
	)
	temp_row.add_child(temperature_slider)
	temperature_label = _label("0.70")
	temp_row.add_child(temperature_label)

	var tokens_row := HBoxContainer.new()
	form.add_child(tokens_row)
	tokens_row.add_child(_label("Max Tokens"))
	max_tokens_spin = SpinBox.new()
	max_tokens_spin.min_value = 256
	max_tokens_spin.max_value = 131072
	max_tokens_spin.step = 256
	max_tokens_spin.value = 8192
	max_tokens_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	max_tokens_spin.value_changed.connect(func(_value: float): _update_preview())
	tokens_row.add_child(max_tokens_spin)

	enabled_toggle = CheckButton.new()
	enabled_toggle.text = "Enabled"
	enabled_toggle.button_pressed = true
	enabled_toggle.toggled.connect(func(_v: bool): _update_preview())
	form.add_child(enabled_toggle)
	auto_toggle = CheckButton.new()
	auto_toggle.text = "Auto respond"
	auto_toggle.toggled.connect(func(_v: bool): _update_preview())
	form.add_child(auto_toggle)

	form.add_child(_label("Skills"))
	skill_list = VBoxContainer.new()
	form.add_child(skill_list)

	var templates := HBoxContainer.new()
	form.add_child(templates)
	for item in [
		["Code", "Code Assistant", "Godot development expert", "You are a senior Godot 4 engineer. Help write, debug, review, and improve GDScript."],
		["Design", "Game Designer", "Gameplay designer", "You are a game designer. Help design mechanics, progression, and player experience."],
		["QA", "QA Tester", "QA engineer", "You are a QA engineer. Create test plans and bug reports for Godot projects."],
		["AI", "AI Trainer", "RL advisor", "You are an AI training specialist. Help design states, rewards, and training strategy."]
	]:
		var btn := Button.new()
		btn.text = item[0]
		btn.pressed.connect(func(template = item): _apply_template(template))
		templates.add_child(btn)

	var actions := HBoxContainer.new()
	form.add_child(actions)
	var save_button := Button.new()
	save_button.text = "Save Agent"
	save_button.pressed.connect(_save_agent)
	actions.add_child(save_button)
	var export_button := Button.new()
	export_button.text = "Export"
	export_button.pressed.connect(_export_agent)
	actions.add_child(export_button)
	var import_button := Button.new()
	import_button.text = "Import"
	import_button.pressed.connect(_import_agent)
	actions.add_child(import_button)

	preview = RichTextLabel.new()
	preview.bbcode_enabled = true
	preview.fit_content = true
	preview.custom_minimum_size = Vector2(0, 120)
	form.add_child(preview)

func _connect_singleton_signals() -> void:
	var singleton = GoGentSingleton.get_instance()
	if not singleton.agents_changed.is_connected(refresh):
		singleton.agents_changed.connect(refresh)

func refresh() -> void:
	_populate_skills()
	_populate_agents()
	_update_preview()

func _line(parent: Control, label_text: String) -> LineEdit:
	var row := HBoxContainer.new()
	parent.add_child(row)
	row.add_child(_label(label_text))
	var line := LineEdit.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.text_changed.connect(func(_text: String): _update_preview())
	row.add_child(line)
	return line

func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(92, 0)
	return label

func _populate_agents() -> void:
	agent_list.clear()
	var manager = GoGentSingleton.get_instance().agent_manager
	if manager == null:
		return
	for agent in manager.agents:
		agent_list.add_item("%s - %s" % [agent.name, agent.role])
		agent_list.set_item_metadata(agent_list.get_item_count() - 1, agent.id)

func _populate_skills() -> void:
	for child in skill_list.get_children():
		child.queue_free()
	var skill_manager = GoGentSingleton.get_instance().skill_manager
	if skill_manager == null:
		return
	for skill in skill_manager.skills:
		var check := CheckButton.new()
		check.text = skill.name
		check.set_meta("skill_id", skill.id)
		check.toggled.connect(func(_v: bool): _update_preview())
		skill_list.add_child(check)

func _filter_agents(text: String) -> void:
	for i in range(agent_list.get_item_count()):
		var visible := text.is_empty() or agent_list.get_item_text(i).to_lower().contains(text.to_lower())
		agent_list.set_item_disabled(i, not visible)

func _select_agent(index: int) -> void:
	var manager = GoGentSingleton.get_instance().agent_manager
	if manager == null:
		return
	var agent_id := str(agent_list.get_item_metadata(index))
	var agent = manager.get_agent(agent_id)
	if agent == null:
		return
	_current_agent_id = agent.id
	name_input.text = agent.name
	role_input.text = agent.role
	prompt_edit.text = agent.system_prompt
	temperature_slider.value = agent.temperature
	temperature_label.text = "%.2f" % agent.temperature
	max_tokens_spin.value = agent.max_tokens
	enabled_toggle.button_pressed = agent.enabled
	auto_toggle.button_pressed = agent.auto_respond
	for child in skill_list.get_children():
		var skill_id := str(child.get_meta("skill_id", ""))
		child.button_pressed = skill_id in agent.skills
	delete_button.disabled = false
	_update_preview()
	agent_selected.emit(agent.id)

func _new_agent() -> void:
	_current_agent_id = ""
	name_input.text = ""
	role_input.text = ""
	prompt_edit.text = ""
	temperature_slider.value = 0.7
	max_tokens_spin.value = 8192
	enabled_toggle.button_pressed = true
	auto_toggle.button_pressed = false
	for child in skill_list.get_children():
		child.button_pressed = false
	delete_button.disabled = true
	_update_preview()

func _save_agent() -> void:
	var data := _collect_form()
	if data["name"].is_empty() or data["role"].is_empty() or data["system_prompt"].is_empty():
		GoGentSingleton.print_gogent_console("Agent name, role, and system prompt are required.", "error")
		return
	var manager = GoGentSingleton.get_instance().agent_manager
	if manager == null:
		return
	if _current_agent_id.is_empty():
		var agent = GoGentAgentManager.AgentConfig.new(data["name"], data["role"])
		manager.add_agent(agent)
		_current_agent_id = agent.id
		manager.update_agent(agent.id, data)
		agent_created.emit(data)
	else:
		manager.update_agent(_current_agent_id, data)
		agent_updated.emit(_current_agent_id, data)
	GoGentSingleton.print_gogent_console("Agent saved.", "success")
	refresh()

func _delete_agent() -> void:
	if _current_agent_id.is_empty():
		return
	GoGentSingleton.get_instance().agent_manager.remove_agent(_current_agent_id)
	agent_deleted.emit(_current_agent_id)
	_new_agent()
	refresh()

func _collect_form() -> Dictionary:
	var selected_skills: Array[String] = []
	for child in skill_list.get_children():
		if child is CheckButton and child.button_pressed:
			selected_skills.append(str(child.get_meta("skill_id", "")))
	return {
		"name": name_input.text.strip_edges(),
		"role": role_input.text.strip_edges(),
		"system_prompt": prompt_edit.text.strip_edges(),
		"temperature": temperature_slider.value,
		"max_tokens": int(max_tokens_spin.value),
		"enabled": enabled_toggle.button_pressed,
		"auto_respond": auto_toggle.button_pressed,
		"skills": selected_skills
	}

func _update_preview() -> void:
	if preview == null:
		return
	var data := _collect_form() if name_input != null else {}
	preview.text = "[b]Preview[/b]\nName: %s\nRole: %s\nTemperature: %.2f\nMax tokens: %d\nSkills: %s" % [
		data.get("name", "<unset>"),
		data.get("role", "<unset>"),
		float(data.get("temperature", 0.7)),
		int(data.get("max_tokens", 8192)),
		", ".join(data.get("skills", []))
	]

func _apply_template(template: Array) -> void:
	name_input.text = template[1]
	role_input.text = template[2]
	prompt_edit.text = template[3]
	_update_preview()

func _export_agent() -> void:
	if _current_agent_id.is_empty():
		GoGentSingleton.print_gogent_console("Select an agent before exporting.", "warning")
		return
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.add_filter("*.json", "JSON")
	dialog.file_selected.connect(func(path: String):
		var agent = GoGentSingleton.get_instance().agent_manager.get_agent(_current_agent_id)
		if agent != null:
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify(agent.to_dict(), "\t"))
				file.close()
	)
	add_child(dialog)
	dialog.popup_centered(Vector2i(640, 420))

func _import_agent() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.add_filter("*.json", "JSON")
	dialog.file_selected.connect(func(path: String):
		var text := FileAccess.get_file_as_string(path)
		if FileAccess.get_open_error() == OK:
			var parsed = JSON.parse_string(text)
			if parsed is Dictionary:
				GoGentSingleton.get_instance().agent_manager.add_agent(GoGentAgentManager.AgentConfig.from_dict(parsed))
	)
	add_child(dialog)
	dialog.popup_centered(Vector2i(640, 420))
