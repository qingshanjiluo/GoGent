@tool
class_name GoGentNodeEditorManager
extends RefCounted

## GoGent 节点编辑管理器
## 这里复用 AlphaAgent 节点工具的核心思路：通过 EditorInterface 直接操作当前 Godot 编辑器场景。
## 这些能力会暴露给控制台、Agent 工具清单和面板按钮，让 AI 不只写代码，也能创建/编辑节点。

signal scene_changed(message: String)

# 错误检查历史记录（用于 get_recent_errors）
var _error_check_history: Array[Dictionary] = []

func get_editor_info() -> Dictionary:
	var root := _get_current_root()
	var selected: Array[String] = []
	if EditorInterface.get_selection() != null:
		for node in EditorInterface.get_selection().get_selected_nodes():
			if root != null and node != null:
				selected.append(str(root.get_path_to(node)))
	return {
		"opened_scenes": EditorInterface.get_open_scenes(),
		"current_scene": root.scene_file_path if root != null else "",
		"root_node": root.name if root != null else "",
		"selected_nodes": selected
	}

func list_scene_nodes(scene_path: String = "", include_properties: bool = false) -> Dictionary:
	var open_result := _open_scene_if_needed(scene_path)
	if not open_result.get("success", false):
		return open_result
	var root := _get_current_root()
	if root == null:
		return {"success": false, "error": "当前没有已编辑的场景。"}
	var result: Array[Dictionary] = []
	var queue: Array[Node] = [root]
	while not queue.is_empty():
		var node: Node = queue.pop_front()
		var script := node.get_script()
		var item := {
			"path": str(root.get_path_to(node)),
			"name": node.name,
			"type": node.get_class(),
			"script": script.resource_path if script != null else "",
			"child_count": node.get_child_count()
		}
		if include_properties:
			item["edited_properties"] = _list_edited_properties(node)
		result.append(item)
		for child in node.get_children():
			queue.append(child)
	return {"success": true, "scene": root.scene_file_path, "nodes": result}

func create_scene(scene_path: String, root_node_class: String = "Node2D") -> Dictionary:
	if not _is_res_path(scene_path):
		return {"success": false, "error": "场景路径必须以 res:// 开头。"}
	if ResourceLoader.exists(scene_path):
		return {"success": false, "error": "目标场景已存在，不会覆盖: %s" % scene_path}
	if not ClassDB.class_exists(root_node_class):
		return {"success": false, "error": "根节点类型不存在: %s" % root_node_class}
	var object = ClassDB.instantiate(root_node_class)
	if object == null or not (object is Node):
		return {"success": false, "error": "根节点类型不是可实例化 Node: %s" % root_node_class}
	var root := object as Node
	root.name = root_node_class
	var scene := PackedScene.new()
	var pack_error := scene.pack(root)
	root.free()
	if pack_error != OK:
		return {"success": false, "error": "场景打包失败: %s" % error_string(pack_error)}
	_ensure_parent_dir(scene_path)
	var save_error := ResourceSaver.save(scene, scene_path)
	if save_error != OK:
		return {"success": false, "error": "场景保存失败: %s" % error_string(save_error)}
	EditorInterface.get_resource_filesystem().scan()
	EditorInterface.open_scene_from_path(scene_path)
	scene_changed.emit("已创建场景: %s" % scene_path)
	return {"success": true, "path": scene_path, "root": root_node_class}

func add_node(node_class: String, parent_path: String = "", node_name: String = "", scene_path: String = "") -> Dictionary:
	var open_result := _open_scene_if_needed(scene_path)
	if not open_result.get("success", false):
		return open_result
	var root := _get_current_root()
	if root == null:
		return {"success": false, "error": "当前没有已编辑的场景。"}
	if not ClassDB.class_exists(node_class):
		return {"success": false, "error": "节点类型不存在: %s" % node_class}
	var object = ClassDB.instantiate(node_class)
	if object == null or not (object is Node):
		return {"success": false, "error": "节点类型不是可实例化 Node: %s" % node_class}
	var parent := _find_node(root, parent_path)
	if parent == null:
		object.free()
		return {"success": false, "error": "父节点不存在: %s" % parent_path}
	var node := object as Node
	node.name = _unique_child_name(parent, node_name if not node_name.is_empty() else node_class)
	parent.add_child(node)
	node.owner = root
	_select_node(node)
	_mark_owned(root)
	_mark_scene_dirty()
	scene_changed.emit("已添加节点: %s" % root.get_path_to(node))
	return {"success": true, "path": str(root.get_path_to(node)), "name": node.name, "type": node.get_class()}

func set_node_property(node_path: String, property_name: String, property_value_text: String, scene_path: String = "") -> Dictionary:
	var open_result := _open_scene_if_needed(scene_path)
	if not open_result.get("success", false):
		return open_result
	var root := _get_current_root()
	if root == null:
		return {"success": false, "error": "当前没有已编辑的场景。"}
	var node := _find_node(root, node_path)
	if node == null:
		return {"success": false, "error": "节点不存在: %s" % node_path}
	var parsed = str_to_var(property_value_text)
	if parsed == null and property_value_text.strip_edges() != "null":
		parsed = property_value_text
	node.set(property_name, parsed)
	_select_node(node)
	_mark_scene_dirty()
	scene_changed.emit("已设置节点属性: %s.%s" % [node_path, property_name])
	return {"success": true, "path": node_path, "property": property_name, "value": var_to_str(parsed)}

func delete_node(node_path: String, scene_path: String = "") -> Dictionary:
	var open_result := _open_scene_if_needed(scene_path)
	if not open_result.get("success", false):
		return open_result
	var root := _get_current_root()
	if root == null:
		return {"success": false, "error": "当前没有已编辑的场景。"}
	var node := _find_node(root, node_path)
	if node == null:
		return {"success": false, "error": "节点不存在: %s" % node_path}
	if node == root:
		return {"success": false, "error": "不允许删除场景根节点。"}
	var removed_name := node.name
	node.get_parent().remove_child(node)
	node.free()
	_mark_scene_dirty()
	scene_changed.emit("已删除节点: %s" % node_path)
	return {"success": true, "deleted": removed_name, "path": node_path}

func select_node(node_path: String, scene_path: String = "") -> Dictionary:
	var open_result := _open_scene_if_needed(scene_path)
	if not open_result.get("success", false):
		return open_result
	var root := _get_current_root()
	var node := _find_node(root, node_path) if root != null else null
	if node == null:
		return {"success": false, "error": "节点不存在: %s" % node_path}
	_select_node(node)
	return {"success": true, "selected": node_path}

func attach_script(node_path: String, script_path: String, scene_path: String = "") -> Dictionary:
	var open_result := _open_scene_if_needed(scene_path)
	if not open_result.get("success", false):
		return open_result
	var root := _get_current_root()
	var node := _find_node(root, node_path) if root != null else null
	if node == null:
		return {"success": false, "error": "节点不存在: %s" % node_path}
	if not ResourceLoader.exists(script_path):
		return {"success": false, "error": "脚本不存在: %s" % script_path}
	var script := ResourceLoader.load(script_path)
	if script == null or not (script is Script):
		return {"success": false, "error": "目标资源不是脚本: %s" % script_path}
	node.set_script(script)
	_select_node(node)
	_mark_scene_dirty()
	scene_changed.emit("已挂载脚本: %s -> %s" % [node_path, script_path])
	return {"success": true, "path": node_path, "script": script_path}

## 扫描项目中的所有 GDScript 文件，检查语法错误和解析错误
## 返回错误列表，包含文件路径、行号和错误描述
func check_errors(scan_path: String = "res://") -> Dictionary:
	var errors: Array[Dictionary] = []
	var scanned: int = 0
	var failed: int = 0
	# 递归扫描所有 .gd 文件
	var gd_files := _find_gd_files(scan_path)
	for file_path in gd_files:
		scanned += 1
		var file_error := _check_single_script(file_path)
		if not file_error.is_empty():
			errors.append_array(file_error)
			failed += 1
	var result := {
		"success": true,
		"scanned": scanned,
		"failed_scripts": failed,
		"total_errors": errors.size(),
		"errors": errors,
		"summary": "扫描了 %d 个脚本，发现 %d 个文件有 %d 个错误。" % [scanned, failed, errors.size()]
	}
	# 记录到历史
	_error_check_history.append({
		"timestamp": Time.get_datetime_string_from_system(),
		"scan_path": scan_path,
		"scanned": scanned,
		"failed_scripts": failed,
		"total_errors": errors.size(),
		"summary": result["summary"]
	})
	# 最多保留 50 条历史
	if _error_check_history.size() > 50:
		_error_check_history = _error_check_history.slice(_error_check_history.size() - 50)
	return result

## 递归查找所有 .gd 文件
func _find_gd_files(path: String) -> PackedStringArray:
	var result: PackedStringArray = []
	var dir := DirAccess.open(path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue
		var full_path := path.path_join(file_name)
		if dir.current_is_dir():
			# 跳过 addons 目录（除非是 gogent 自身）
			if file_name == "addons":
				file_name = dir.get_next()
				continue
			result.append_array(_find_gd_files(full_path))
		elif file_name.ends_with(".gd"):
			result.append(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result

## 检查单个脚本文件的解析错误
func _check_single_script(file_path: String) -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	# 尝试加载脚本资源
	var script := ResourceLoader.load(file_path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
	if script == null:
		errors.append({
			"file": file_path,
			"line": 0,
			"message": "无法加载脚本文件（可能文件不存在或格式错误）"
		})
		return errors
	if not (script is Script):
		errors.append({
			"file": file_path,
			"line": 0,
			"message": "资源不是有效的 Script 类型"
		})
		return errors
	# 检查脚本是否存在解析错误
	# Godot 4 中，Script 有 get_script_property_list() 等方法
	# 但解析错误需要通过尝试获取 source_code 并重新编译来检测
	var source := ""
	if script.has_method("get_source_code"):
		source = script.get_source_code()
	if source.is_empty():
		# 尝试通过文件系统读取源码
		var file := FileAccess.open(file_path, FileAccess.READ)
		if file != null:
			source = file.get_as_text()
			file.close()
	if source.is_empty():
		errors.append({
			"file": file_path,
			"line": 0,
			"message": "无法读取脚本源码"
		})
		return errors
	# 尝试用 GDScript 重新编译来检测错误
	var gdscript := GDScript.new()
	gdscript.source_code = source
	# 通过 try_reload 或直接设置 source_code 触发编译
	var reload_err := gdscript.reload()
	if reload_err != OK:
		# 尝试从错误信息中提取行号
		var err_msg := error_string(reload_err)
		errors.append({
			"file": file_path,
			"line": 0,
			"message": "编译错误: %s (code: %d)" % [err_msg, reload_err]
		})
	# 额外检查：逐行扫描常见语法问题
	errors.append_array(_check_common_syntax_issues(file_path, source))
	return errors

## 检查常见语法问题（缩进、关键字拼写等）
func _check_common_syntax_issues(file_path: String, source: String) -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	var lines := source.split("\n")
	for i in range(lines.size()):
		var line := lines[i]
		var line_num := i + 1
		var stripped := line.strip_edges()
		if stripped.is_empty() or stripped.begins_with("#"):
			continue
		# 检查混用 tab 和空格
		if line.begins_with("\t") and line.find("    ") != -1:
			errors.append({
				"file": file_path,
				"line": line_num,
				"message": "行 %d: 混用了 Tab 和空格缩进" % line_num
			})
		# 检查明显的关键字拼写错误
		if stripped.begins_with("funciton ") or stripped.begins_with("fucntion "):
			errors.append({
				"file": file_path,
				"line": line_num,
				"message": "行 %d: 疑似 'function' 拼写错误，应为 'func'" % line_num
			})
		if stripped.begins_with("ver ") or stripped.begins_with("varible "):
			errors.append({
				"file": file_path,
				"line": line_num,
				"message": "行 %d: 疑似变量声明拼写错误" % line_num
			})
		if stripped.begins_with("cont ") or stripped.begins_with("const "):
			# const 是合法的，cont 不是
			if stripped.begins_with("cont "):
				errors.append({
					"file": file_path,
					"line": line_num,
					"message": "行 %d: 疑似 'const' 拼写错误" % line_num
				})
		# 检查 if/for/while 后缺少冒号
		if not stripped.ends_with(":") and not stripped.ends_with(": "):
			for keyword in ["if ", "elif ", "else", "for ", "while ", "match ", "func "]:
				if stripped.begins_with(keyword) and not stripped.ends_with(":") and not line.contains(":"):
					# 排除单行 if 语句
					if not (stripped.begins_with("if ") and stripped.contains(":")):
						errors.append({
							"file": file_path,
							"line": line_num,
							"message": "行 %d: '%s' 语句后缺少冒号 ':'" % [line_num, keyword.strip_edges()]
						})
					break
	return errors

func get_agent_tool_manifest() -> Array[Dictionary]:
	return [
		{"name": "editor_info", "description": "获取当前编辑器场景和选中节点。"},
		{"name": "list_scene_nodes", "description": "列出当前或指定场景中的节点。参数：scene_path（可选），include_properties（可选，是否包含属性）。"},
		{"name": "create_scene", "description": "创建一个新场景并指定根节点类型。参数：scene_path（场景路径），root_node_class（根节点类型，默认Node2D）。"},
		{"name": "add_node", "description": "在场景中添加节点。参数：node_class（节点类型，如Sprite2D、Node2D、Button等），parent_path（父节点路径），node_name（可选节点名），scene_path（可选场景路径）。"},
		{"name": "set_node_property", "description": "设置节点属性，属性值使用 Godot str_to_var 格式。参数：node_path，property_name，property_value，scene_path（可选）。"},
		{"name": "delete_node", "description": "删除场景中的节点。参数：node_path，scene_path（可选）。"},
		{"name": "select_node", "description": "在编辑器中选中节点。参数：node_path，scene_path（可选）。"},
		{"name": "rename_node", "description": "重命名场景中的节点。参数：node_path（节点路径），new_name（新名称），scene_path（可选场景路径）。"},
		{"name": "duplicate_node", "description": "复制场景中的节点。参数：node_path（要复制的节点路径），new_name（可选新名称），scene_path（可选场景路径）。"},
		{"name": "move_node", "description": "移动节点到新的父节点下。参数：node_path（要移动的节点路径），new_parent_path（目标父节点路径），scene_path（可选场景路径）。"},
		{"name": "attach_script", "description": "给节点挂载脚本。参数：node_path，script_path，scene_path（可选）。"},
		{"name": "check_errors", "description": "扫描项目中的所有 GDScript 文件，检查语法错误和解析错误，返回错误列表。参数：scan_path（可选，默认res://）。"},
		{"name": "get_recent_errors", "description": "获取最近X次错误检查的结果记录。参数：count（可选，要获取的记录条数，默认5）。"}
	]

func _open_scene_if_needed(scene_path: String) -> Dictionary:
	if scene_path.strip_edges().is_empty():
		return {"success": true}
	if not _is_res_path(scene_path):
		return {"success": false, "error": "场景路径必须以 res:// 开头。"}
	if not ResourceLoader.exists(scene_path):
		return {"success": false, "error": "场景不存在: %s" % scene_path}
	var root := _get_current_root()
	if root == null or root.scene_file_path != scene_path:
		EditorInterface.open_scene_from_path(scene_path)
	return {"success": true}

func _get_current_root() -> Node:
	return EditorInterface.get_edited_scene_root()

func _find_node(root: Node, node_path: String) -> Node:
	if root == null:
		return null
	if node_path.strip_edges().is_empty() or node_path == "." or node_path == root.name:
		return root
	return root.get_node_or_null(NodePath(node_path))

func _select_node(node: Node) -> void:
	var selection := EditorInterface.get_selection()
	if selection != null:
		selection.clear()
		selection.add_node(node)

func _mark_owned(root: Node) -> void:
	var queue: Array[Node] = [root]
	while not queue.is_empty():
		var node: Node = queue.pop_front()
		for child in node.get_children():
			if child.owner == null:
				child.owner = root
			queue.append(child)

func _mark_scene_dirty() -> void:
	if EditorInterface.has_method("mark_scene_as_unsaved"):
		EditorInterface.mark_scene_as_unsaved()

func _unique_child_name(parent: Node, base_name: String) -> String:
	var candidate := base_name
	var index := 1
	while parent.get_node_or_null(NodePath(candidate)) != null:
		candidate = "%s%d" % [base_name, index]
		index += 1
	return candidate

func _list_edited_properties(node: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for property in node.get_property_list():
		var name := str(property.get("name", ""))
		if name.is_empty():
			continue
		if node.is_property_pinned(name):
			result.append({"name": name, "value": var_to_str(node.get(name))})
	return result

func _is_res_path(path: String) -> bool:
	return path.begins_with("res://")

func _ensure_parent_dir(path: String) -> void:
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

# ---- 新增节点操作工具 ----

func rename_node(node_path: String, new_name: String, scene_path: String = "") -> Dictionary:
	var open_result := _open_scene_if_needed(scene_path)
	if not open_result.get("success", false):
		return open_result
	var root := _get_current_root()
	if root == null:
		return {"success": false, "error": "当前没有已编辑的场景。"}
	var node := _find_node(root, node_path)
	if node == null:
		return {"success": false, "error": "节点不存在: %s" % node_path}
	if new_name.strip_edges().is_empty():
		return {"success": false, "error": "新名称不能为空。"}
	var old_name := node.name
	node.name = _unique_child_name(node.get_parent(), new_name)
	_select_node(node)
	_mark_scene_dirty()
	scene_changed.emit("已重命名节点: %s -> %s" % [old_name, node.name])
	return {"success": true, "old_name": old_name, "new_name": node.name, "path": node_path}

func duplicate_node(node_path: String, new_name: String = "", scene_path: String = "") -> Dictionary:
	var open_result := _open_scene_if_needed(scene_path)
	if not open_result.get("success", false):
		return open_result
	var root := _get_current_root()
	if root == null:
		return {"success": false, "error": "当前没有已编辑的场景。"}
	var node := _find_node(root, node_path)
	if node == null:
		return {"success": false, "error": "节点不存在: %s" % node_path}
	if node == root:
		return {"success": false, "error": "不允许复制场景根节点。"}
	var parent := node.get_parent()
	if parent == null:
		return {"success": false, "error": "节点没有父节点。"}
	# 复制节点
	var duplicate := node.duplicate()
	if duplicate == null:
		return {"success": false, "error": "节点复制失败。"}
	# 设置名称
	var base_name := new_name if not new_name.is_empty() else (node.name + "Copy")
	duplicate.name = _unique_child_name(parent, base_name)
	parent.add_child(duplicate)
	duplicate.owner = root
	_select_node(duplicate)
	_mark_owned(root)
	_mark_scene_dirty()
	scene_changed.emit("已复制节点: %s -> %s" % [node_path, duplicate.name])
	return {"success": true, "original": node_path, "new_node": str(root.get_path_to(duplicate)), "name": duplicate.name}

func move_node(node_path: String, new_parent_path: String, scene_path: String = "") -> Dictionary:
	var open_result := _open_scene_if_needed(scene_path)
	if not open_result.get("success", false):
		return open_result
	var root := _get_current_root()
	if root == null:
		return {"success": false, "error": "当前没有已编辑的场景。"}
	var node := _find_node(root, node_path)
	if node == null:
		return {"success": false, "error": "节点不存在: %s" % node_path}
	if node == root:
		return {"success": false, "error": "不允许移动场景根节点。"}
	var new_parent := _find_node(root, new_parent_path)
	if new_parent == null:
		return {"success": false, "error": "目标父节点不存在: %s" % new_parent_path}
	if new_parent == node:
		return {"success": false, "error": "不能将节点移动到自己下面。"}
	if _is_descendant(node, new_parent):
		return {"success": false, "error": "不能将节点移动到自己的子节点下面。"}
	var old_parent := node.get_parent()
	old_parent.remove_child(node)
	new_parent.add_child(node)
	node.owner = root
	_select_node(node)
	_mark_owned(root)
	_mark_scene_dirty()
	scene_changed.emit("已移动节点: %s -> %s" % [node_path, new_parent_path])
	return {"success": true, "node": node_path, "from": str(root.get_path_to(old_parent)), "to": new_parent_path}

# 检查 node 是否是 potential_ancestor 的后代
func _is_descendant(node: Node, potential_ancestor: Node) -> bool:
	var current := potential_ancestor.get_parent()
	while current != null:
		if current == node:
			return true
		current = current.get_parent()
	return false

# 获取最近X次错误检查记录
func get_recent_errors(count: int = 5) -> Dictionary:
	if _error_check_history.is_empty():
		return {"success": true, "records": [], "message": "暂无错误检查记录。"}
	var recent := _error_check_history.slice(max(0, _error_check_history.size() - count), _error_check_history.size())
	recent.reverse()
	return {"success": true, "records": recent, "total_records": _error_check_history.size(), "showing": recent.size()}

