@tool
class_name GoGentWorkspaceToolManager
extends RefCounted

const MAX_READ_BYTES := 256000

func get_tool_manifest() -> Array[Dictionary]:
	return [
		{"name": "list_files", "description": "列出 res:// 项目目录中的文件。参数：path, recursive, max_results。"},
		{"name": "read_file", "description": "读取 res:// 项目文本文件。参数：path。"},
		{"name": "write_file", "description": "写入 res:// 项目文本文件，会真实修改项目。参数：path, content。"},
		{"name": "append_file", "description": "追加文本到 res:// 项目文件。参数：path, content。"},
		{"name": "search_text", "description": "在项目文本文件中搜索内容。参数：query, path, max_results。"},
		{"name": "console", "description": "执行 GoGent 控制台命令，可间接调用场景、训练、外部 Agent 等工具。参数：command。"}
	]

func execute_tool_call(call: Dictionary) -> Dictionary:
	var tool := str(call.get("tool", call.get("name", ""))).strip_edges()
	var args: Dictionary = call.get("args", call.get("arguments", {}))
	match tool:
		"list_files":
			return list_files(str(args.get("path", "res://")), bool(args.get("recursive", true)), int(args.get("max_results", 200)))
		"read_file":
			return read_file(str(args.get("path", "")))
		"write_file":
			return write_file(str(args.get("path", "")), str(args.get("content", "")))
		"append_file":
			return append_file(str(args.get("path", "")), str(args.get("content", "")))
		"search_text":
			return search_text(str(args.get("query", "")), str(args.get("path", "res://")), int(args.get("max_results", 100)))
		"console":
			var console = GoGentSingleton.get_instance().console_manager
			if console == null:
				return {"success": false, "error": "控制台管理器未就绪。"}
			return {"success": true, "output": console.execute_command(str(args.get("command", "")))}
		_:
			return {"success": false, "error": "未知工具: %s" % tool}

func list_files(path: String = "res://", recursive: bool = true, max_results: int = 200) -> Dictionary:
	var root := _normalize_res_path(path)
	if root.is_empty():
		return {"success": false, "error": "只能访问 res:// 项目路径。"}
	var result: Array[String] = []
	_collect_files(root, recursive, max(1, max_results), result)
	return {"success": true, "path": root, "files": result}

func read_file(path: String) -> Dictionary:
	var clean := _normalize_res_path(path)
	if clean.is_empty():
		return {"success": false, "error": "只能读取 res:// 项目路径。"}
	if not FileAccess.file_exists(clean):
		return {"success": false, "error": "文件不存在: %s" % clean}
	var file := FileAccess.open(clean, FileAccess.READ)
	if file == null:
		return {"success": false, "error": "无法打开文件: %s" % clean}
	var size := file.get_length()
	if size > MAX_READ_BYTES:
		file.close()
		return {"success": false, "error": "文件过大，超过 %d bytes: %s" % [MAX_READ_BYTES, clean]}
	var content := file.get_as_text()
	file.close()
	return {"success": true, "path": clean, "content": content}

func write_file(path: String, content: String) -> Dictionary:
	var clean := _normalize_res_path(path)
	if clean.is_empty():
		return {"success": false, "error": "只能写入 res:// 项目路径。"}
	_ensure_parent_dir(clean)
	var file := FileAccess.open(clean, FileAccess.WRITE)
	if file == null:
		return {"success": false, "error": "无法写入文件: %s" % clean}
	file.store_string(content)
	file.close()
	_scan_filesystem()
	return {"success": true, "path": clean, "bytes": content.to_utf8_buffer().size()}

func append_file(path: String, content: String) -> Dictionary:
	var current := ""
	if FileAccess.file_exists(path):
		var read_result := read_file(path)
		if not read_result.get("success", false):
			return read_result
		current = str(read_result.get("content", ""))
	return write_file(path, current + content)

func search_text(query: String, path: String = "res://", max_results: int = 100) -> Dictionary:
	if query.is_empty():
		return {"success": false, "error": "搜索内容不能为空。"}
	var files_result := list_files(path, true, 1000)
	if not files_result.get("success", false):
		return files_result
	var matches: Array[Dictionary] = []
	for file_path in files_result.get("files", []):
		if matches.size() >= max_results:
			break
		if not _is_text_file(file_path):
			continue
		var read_result := read_file(file_path)
		if not read_result.get("success", false):
			continue
		var lines := str(read_result.get("content", "")).split("\n")
		for i in range(lines.size()):
			if lines[i].find(query) >= 0:
				matches.append({"path": file_path, "line": i + 1, "text": lines[i]})
				if matches.size() >= max_results:
					break
	return {"success": true, "query": query, "matches": matches}

func _collect_files(path: String, recursive: bool, max_results: int, result: Array[String]) -> void:
	if result.size() >= max_results:
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var item := dir.get_next()
	while not item.is_empty() and result.size() < max_results:
		if item.begins_with("."):
			item = dir.get_next()
			continue
		var child := path.path_join(item)
		if dir.current_is_dir():
			if recursive:
				_collect_files(child, recursive, max_results, result)
		else:
			result.append(child)
		item = dir.get_next()
	dir.list_dir_end()

func _normalize_res_path(path: String) -> String:
	var clean := path.strip_edges().replace("\\", "/")
	if clean.is_empty():
		clean = "res://"
	if not clean.begins_with("res://"):
		return ""
	if clean.find("..") >= 0:
		return ""
	return clean

func _ensure_parent_dir(path: String) -> void:
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

func _scan_filesystem() -> void:
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()

func _is_text_file(path: String) -> bool:
	var ext := path.get_extension().to_lower()
	return ext in ["gd", "tscn", "tres", "json", "md", "txt", "tmp", "cfg", "shader", "cs", "xml", "yml", "yaml"]
