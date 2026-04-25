@tool
class_name GoGentNodeEditorManager
extends RefCounted

## GoGent 节点编辑管理器
## 这里复用 AlphaAgent 节点工具的核心思路：通过 EditorInterface 直接操作当前 Godot 编辑器场景。
## 这些能力会暴露给控制台、Agent 工具清单和面板按钮，让 AI 不只写代码，也能创建/编辑节点。

signal scene_changed(message: String)

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

func get_agent_tool_manifest() -> Array[Dictionary]:
	return [
		{"name": "editor_info", "description": "获取当前编辑器场景和选中节点。"},
		{"name": "list_scene_nodes", "description": "列出当前或指定场景中的节点。"},
		{"name": "create_scene", "description": "创建一个新场景并指定根节点类型。"},
		{"name": "add_node", "description": "在场景中添加节点。"},
		{"name": "set_node_property", "description": "设置节点属性，属性值使用 Godot str_to_var 格式。"},
		{"name": "delete_node", "description": "删除场景中的节点。"},
		{"name": "select_node", "description": "在编辑器中选中节点。"},
		{"name": "attach_script", "description": "给节点挂载脚本。"}
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
