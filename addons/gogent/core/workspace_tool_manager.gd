@tool
class_name GoGentWorkspaceToolManager
extends RefCounted

const MAX_READ_BYTES := 256000
const MAX_READ_LINES := 200

func get_tool_manifest() -> Array[Dictionary]:
	return [
		{"name": "list_files", "description": "列出 res:// 项目目录中的文件。参数：path, recursive, max_results。"},
		{"name": "read_file", "description": "读取 res:// 项目文本文件。参数：path（文件路径）, offset（可选，起始行号，从1开始，默认1）, limit（可选，最多读取行数，默认50，最大200）。AI 应优先使用 offset+limit 按行读取，避免一次性读取大文件。"},
		{"name": "read_file_lines", "description": "精确读取文件的指定行范围。参数：path（文件路径）, start_line（起始行号，从1开始）, end_line（结束行号，包含该行）。最多返回50行。适合 AI 需要查看文件特定区域时使用。"},
		{"name": "replace_lines", "description": "替换文件中指定行范围的内容。参数：path（文件路径）, start_line（起始行号，从1开始）, end_line（结束行号，包含该行）, content（替换后的文本内容）。注意：end_line 必须 >= start_line，替换后文件总行数可能变化。"},
		{"name": "write_file", "description": "完整重写 res:// 项目文本文件，会真实修改项目。参数：path, content。注意：这会覆盖整个文件，如果只需要修改部分内容，请使用 replace_lines。"},
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
			return read_file(str(args.get("path", "")), int(args.get("offset", 1)), int(args.get("limit", 50)))
		"read_file_lines":
			return read_file_lines(str(args.get("path", "")), int(args.get("start_line", 1)), int(args.get("end_line", 50)))
		"replace_lines":
			return replace_lines(str(args.get("path", "")), int(args.get("start_line", 1)), int(args.get("end_line", 1)), str(args.get("content", "")))
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

func read_file(path: String, offset: int = 0, limit: int = 0) -> Dictionary:
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
	var lines := content.split("\n")
	var total_lines := lines.size()
	# 如果指定了 offset/limit，返回指定范围的行
	if offset > 0 or limit > 0:
		var start_line := max(0, offset - 1)  # offset 从 1 开始
		var end_line := total_lines
		if limit > 0:
			end_line = min(total_lines, start_line + limit)
		var selected := lines.slice(start_line, end_line)
		return {
			"success": true,
			"path": clean,
			"total_lines": total_lines,
			"offset": start_line + 1,
			"limit": limit if limit > 0 else total_lines,
			"content": "\n".join(selected)
		}
	# 超过最大行数时返回摘要，让 AI 可以分段读取
	if total_lines > MAX_READ_LINES:
		return {
			"success": true,
			"path": clean,
			"total_lines": total_lines,
			"truncated": true,
			"message": "文件共 %d 行，超过 %d 行限制。请使用 offset 和 limit 参数分段读取。例如：read_file(path=\"%s\", offset=1, limit=200) 读取前200行。" % [total_lines, MAX_READ_LINES, clean],
			"content": "\n".join(lines.slice(0, MAX_READ_LINES)),
			"showing_lines": "1-%d" % MAX_READ_LINES
		}
	return {"success": true, "path": clean, "total_lines": total_lines, "content": content}

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

# ---- 新增精确行操作工具 ----

const MAX_LINE_READ := 50

# 精确读取文件的指定行范围（start_line 到 end_line，包含两端）
func read_file_lines(path: String, start_line: int = 1, end_line: int = 50) -> Dictionary:
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
	var lines := content.split("\n")
	var total_lines := lines.size()
	# 参数校验
	start_line = max(1, start_line)
	end_line = min(total_lines, max(start_line, end_line))
	var line_count := end_line - start_line + 1
	if line_count > MAX_LINE_READ:
		return {
			"success": false,
			"error": "请求的行数 %d 超过最大限制 %d。请缩小范围后重试。" % [line_count, MAX_LINE_READ],
			"total_lines": total_lines,
			"max_allowed": MAX_LINE_READ
		}
	var selected := lines.slice(start_line - 1, end_line)
	return {
		"success": true,
		"path": clean,
		"total_lines": total_lines,
		"start_line": start_line,
		"end_line": end_line,
		"line_count": line_count,
		"content": "\n".join(selected)
	}

# 替换文件中指定行范围的内容
func replace_lines(path: String, start_line: int, end_line: int, content: String) -> Dictionary:
	var clean := _normalize_res_path(path)
	if clean.is_empty():
		return {"success": false, "error": "只能操作 res:// 项目路径。"}
	if not FileAccess.file_exists(clean):
		return {"success": false, "error": "文件不存在: %s" % clean}
	if start_line < 1:
		return {"success": false, "error": "start_line 必须 >= 1。"}
	if end_line < start_line:
		return {"success": false, "error": "end_line 必须 >= start_line。"}
	
	var file := FileAccess.open(clean, FileAccess.READ)
	if file == null:
		return {"success": false, "error": "无法打开文件: %s" % clean}
	var full_content := file.get_as_text()
	file.close()
	
	var lines := full_content.split("\n")
	var total_lines := lines.size()
	
	if start_line > total_lines:
		return {"success": false, "error": "start_line (%d) 超出文件总行数 (%d)。" % [start_line, total_lines]}
	
	# 确保 end_line 不超出范围
	end_line = min(end_line, total_lines)
	
	# 替换内容：保留 start_line 之前的部分 + 新内容 + end_line 之后的部分
	var before := lines.slice(0, start_line - 1)
	var after := lines.slice(end_line)  # end_line 之后（含 end_line 的下一行）
	
	var new_lines := []
	new_lines.append_array(before)
	# 将新内容按行拆分加入
	var replacement_lines := content.split("\n")
	new_lines.append_array(replacement_lines)
	new_lines.append_array(after)
	
	var new_content := "\n".join(new_lines)
	
	var write_file := FileAccess.open(clean, FileAccess.WRITE)
	if write_file == null:
		return {"success": false, "error": "无法写入文件: %s" % clean}
	write_file.store_string(new_content)
	write_file.close()
	
	_scan_filesystem()
	
	return {
		"success": true,
		"path": clean,
		"total_lines_before": total_lines,
		"total_lines_after": new_lines.size(),
		"replaced_lines": "第 %d-%d 行" % [start_line, end_line],
		"message": "已替换第 %d-%d 行（共 %d 行）。" % [start_line, end_line, end_line - start_line + 1]
	}
