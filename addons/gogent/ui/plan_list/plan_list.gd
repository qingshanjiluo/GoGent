@tool
class_name GoGentPlanList
extends VBoxContainer
## 计划列表 UI 组件
##
## 显示 AI 的任务计划列表，支持三种状态：计划中、进行中、已完成。
## 参考 AlphaAgent 的 PlanList + PlanItem 设计。

## 计划项状态
enum PlanState {
	PLAN,   # 计划中（待执行）
	ACTIVE, # 进行中
	FINISH  # 已完成
}

## 计划项数据类
class PlanItem:
	var id: String
	var content: String
	var state: PlanState
	var order: int

	func _init(p_content: String, p_order: int, p_state: PlanState = PlanState.PLAN) -> void:
		id = "plan_%d_%d" % [Time.get_unix_time_from_system(), randi()]
		content = p_content
		state = p_state
		order = p_order

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"content": content,
			"state": PlanState.keys()[state],
			"order": order
		}

	func to_bbcode() -> String:
		match state:
			PlanState.PLAN:
				return "[color=#abc9ff]⏳[/color] %s" % content
			PlanState.ACTIVE:
				return "[color=#ffb373]▶[/color] [b]%s[/b]" % content
			PlanState.FINISH:
				return "[color=#42ffc2]✅[/color] %s" % content
		return content

## 信号
signal plan_item_added(item: PlanItem)
signal plan_item_removed(item: PlanItem)
signal plan_item_state_changed(item: PlanItem)
signal plan_cleared()
signal all_completed()

## 计划项列表
var _items: Array[PlanItem] = []

@onready var _header := $Header as HBoxContainer
@onready var _title_label := $Header/TitleLabel as Label
@onready var _clear_btn := $Header/ClearBtn as Button
@onready var _list_container := $ListContainer as VBoxContainer
@onready var _empty_label := $EmptyLabel as Label

func _ready() -> void:
	if _clear_btn:
		_clear_btn.pressed.connect(_on_clear)
	refresh()

## 添加计划项
func add_item(content: String) -> PlanItem:
	var item := PlanItem.new(content, _items.size())
	_items.append(item)
	_refresh_ui()
	plan_item_added.emit(item)
	return item

## 批量添加计划项
func add_items(contents: Array[String]) -> Array[PlanItem]:
	var result: Array[PlanItem] = []
	for content in contents:
		var item := PlanItem.new(content, _items.size())
		_items.append(item)
		result.append(item)
	_refresh_ui()
	for item in result:
		plan_item_added.emit(item)
	return result

## 设置计划项状态
func set_item_state(item_id: String, state: PlanState) -> bool:
	for item in _items:
		if item.id == item_id:
			item.state = state
			_refresh_ui()
			plan_item_state_changed.emit(item)
			_check_all_completed()
			return true
	return false

## 通过索引设置状态
func set_item_state_by_index(index: int, state: PlanState) -> bool:
	if index < 0 or index >= _items.size():
		return false
	_items[index].state = state
	_refresh_ui()
	plan_item_state_changed.emit(_items[index])
	_check_all_completed()
	return true

## 标记下一个计划项为进行中
func activate_next() -> PlanItem:
	for item in _items:
		if item.state == PlanState.PLAN:
			item.state = PlanState.ACTIVE
			_refresh_ui()
			plan_item_state_changed.emit(item)
			return item
	return null

## 标记当前进行中的项为已完成
func complete_active() -> PlanItem:
	for item in _items:
		if item.state == PlanState.ACTIVE:
			item.state = PlanState.FINISH
			_refresh_ui()
			plan_item_state_changed.emit(item)
			_check_all_completed()
			return item
	return null

## 移除计划项
func remove_item(item_id: String) -> bool:
	for i in range(_items.size()):
		if _items[i].id == item_id:
			var item := _items[i]
			_items.remove_at(i)
			_refresh_ui()
			plan_item_removed.emit(item)
			return true
	return false

## 清空所有计划项
func clear() -> void:
	_items.clear()
	_refresh_ui()
	plan_cleared.emit()

## 获取所有计划项
func get_items() -> Array[PlanItem]:
	return _items.duplicate()

## 获取指定状态的计划项
func get_items_by_state(state: PlanState) -> Array[PlanItem]:
	var result: Array[PlanItem] = []
	for item in _items:
		if item.state == state:
			result.append(item)
	return result

## 获取计划项数量
func get_item_count() -> int:
	return _items.size()

## 获取已完成数量
func get_completed_count() -> int:
	var count := 0
	for item in _items:
		if item.state == PlanState.FINISH:
			count += 1
	return count

## 检查是否全部完成
func is_all_completed() -> bool:
	return _items.size() > 0 and get_completed_count() == _items.size()

## 转换为 BBCode 文本（用于显示在聊天中）
func to_bbcode() -> String:
	if _items.is_empty():
		return ""
	var parts: Array[String] = []
	parts.append("[b]📋 执行计划[/b]")
	for item in _items:
		parts.append(item.to_bbcode())
	return "\n".join(parts)

## 转换为纯文本
func to_text() -> String:
	if _items.is_empty():
		return ""
	var parts: Array[String] = []
	parts.append("执行计划：")
	for item in _items:
		var prefix := ""
		match item.state:
			PlanState.PLAN: prefix = "[待执行]"
			PlanState.ACTIVE: prefix = "[进行中]"
			PlanState.FINISH: prefix = "[已完成]"
		parts.append("  %d. %s %s" % [item.order + 1, prefix, item.content])
	return "\n".join(parts)

func refresh() -> void:
	_refresh_ui()

func _refresh_ui() -> void:
	if not is_node_ready():
		return

	# 清空列表
	for child in _list_container.get_children():
		child.queue_free()

	if _items.is_empty():
		_list_container.visible = false
		if _empty_label:
			_empty_label.visible = true
		if _title_label:
			_title_label.text = "📋 计划 (0)"
		return

	_list_container.visible = true
	if _empty_label:
		_empty_label.visible = false
	if _title_label:
		_title_label.text = "📋 计划 (%d/%d)" % [get_completed_count(), _items.size()]

	for item in _items:
		var row := _create_item_row(item)
		_list_container.add_child(row)

func _create_item_row(item: PlanItem) -> Control:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.custom_minimum_size.y = 24

	# 状态图标
	var icon := Label.new()
	icon.custom_minimum_size.x = 24
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	match item.state:
		PlanState.PLAN:
			icon.text = "⏳"
			icon.add_theme_color_override("font_color", Color(0.67, 0.8, 1.0))
		PlanState.ACTIVE:
			icon.text = "▶"
			icon.add_theme_color_override("font_color", Color(1.0, 0.7, 0.45))
		PlanState.FINISH:
			icon.text = "✅"
			icon.add_theme_color_override("font_color", Color(0.26, 1.0, 0.76))
	hbox.add_child(icon)

	# 序号
	var order_label := Label.new()
	order_label.custom_minimum_size.x = 24
	order_label.text = "%d." % (item.order + 1)
	order_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	order_label.add_theme_font_size_override("font_size", 11)
	hbox.add_child(order_label)

	# 内容
	var content := Label.new()
	content.text = item.content
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_theme_font_size_override("font_size", 12)
	if item.state == PlanState.FINISH:
		content.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hbox.add_child(content)

	return hbox

func _check_all_completed() -> void:
	if is_all_completed():
		all_completed.emit()

func _on_clear() -> void:
	clear()
