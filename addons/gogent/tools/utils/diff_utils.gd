@tool
class_name GoGentDiffUtils
extends RefCounted
## Myers Diff 算法实现
##
## 基于 Myers' O(ND) 差分算法，计算两个文本之间的最小编辑距离和编辑路径。
## 参考：https://neil.fraser.name/writing/diff/

class DiffResult:
	var added_lines: Array[String] = []
	var deleted_lines: Array[String] = []
	var unchanged_lines: Array[String] = []
	var edit_script: Array[DiffOp] = []

	func to_dict() -> Dictionary:
		return {
			"added_count": added_lines.size(),
			"deleted_count": deleted_lines.size(),
			"unchanged_count": unchanged_lines.size(),
			"edit_script": edit_script.map(func(op): return op.to_dict())
		}

class DiffOp:
	enum OpType { EQUAL, INSERT, DELETE }

	var op_type: OpType
	var text: String
	var old_line: int  # 在原文本中的行号（0-based）
	var new_line: int  # 在新文本中的行号（0-based）

	func _init(p_type: OpType, p_text: String, p_old: int = -1, p_new: int = -1) -> void:
		op_type = p_type
		text = p_text
		old_line = p_old
		new_line = p_new

	func to_dict() -> Dictionary:
		return {
			"type": OpType.keys()[op_type],
			"text": text,
			"old_line": old_line,
			"new_line": new_line
		}

## 计算两个字符串数组（行列表）之间的差异
static func compute(old_lines: Array[String], new_lines: Array[String]) -> DiffResult:
	var result := DiffResult.new()

	if old_lines.is_empty() and new_lines.is_empty():
		return result

	# 如果其中一个为空，直接返回全部插入或删除
	if old_lines.is_empty():
		for i in range(new_lines.size()):
			result.added_lines.append(new_lines[i])
			result.edit_script.append(DiffOp.new(DiffOp.OpType.INSERT, new_lines[i], -1, i))
		return result

	if new_lines.is_empty():
		for i in range(old_lines.size()):
			result.deleted_lines.append(old_lines[i])
			result.edit_script.append(DiffOp.new(DiffOp.OpType.DELETE, old_lines[i], i, -1))
		return result

	# 使用 Myers 算法计算最短编辑路径
	var n := old_lines.size()
	var m := new_lines.size()
	var max_d := n + m

	# V 数组：存储每个 k 线上到达的 x 坐标
	# k = x - y，范围从 -max_d 到 max_d
	var v: Dictionary = {}
	v[1] = 0

	var trace: Array[Dictionary] = []

	# Myers 主循环
	for d in range(0, max_d + 1):
		var snapshot: Dictionary = {}
		for k in range(-d, d + 1, 2):
			var x: int
			var y: int
			var from_down: bool

			if k == -d or (k != d and v.get(k - 1, -1) < v.get(k + 1, -1)):
				x = v.get(k + 1, 0)
				from_down = true
			else:
				x = v.get(k - 1, 0) + 1
				from_down = false

			y = x - k

			# 沿着对角线移动（匹配的行）
			while x < n and y < m and old_lines[x] == new_lines[y]:
				x += 1
				y += 1

			v[k] = x
			snapshot[k] = {"x": x, "y": y, "from_down": from_down}

			# 到达终点
			if x >= n and y >= m:
				trace.append(snapshot)
				# 回溯构建编辑脚本
				_backtrack(trace, old_lines, new_lines, result)
				return result

		trace.append(snapshot)

	# 不应该到达这里
	return result

## 回溯编辑路径，构建编辑脚本
static func _backtrack(trace: Array[Dictionary], old_lines: Array[String], new_lines: Array[String], result: DiffResult) -> void:
	var ops: Array[DiffOp] = []

	var x := old_lines.size()
	var y := new_lines.size()

	# 从最后一步开始回溯
	for d in range(trace.size() - 1, -1, -1):
		var snapshot: Dictionary = trace[d]
		var k := x - y

		# 确定这一步是从哪里来的
		var prev_k: int
		var from_down: bool

		if snapshot.has(k) and snapshot[k] is Dictionary:
			var entry: Dictionary = snapshot[k]
			from_down = entry.get("from_down", false)
		else:
			from_down = false

		if from_down:
			prev_k = k + 1
		else:
			prev_k = k - 1

		# 获取前一步的位置
		var prev_entry: Dictionary = {}
		if d > 0 and trace[d - 1].has(prev_k):
			prev_entry = trace[d - 1][prev_k]
		else:
			prev_entry = {"x": 0, "y": 0}

		var prev_x: int = prev_entry.get("x", 0)
		var prev_y: int = prev_entry.get("y", 0)

		# 处理对角线移动（匹配的行）- 从后往前
		while x > prev_x and y > prev_y:
			x -= 1
			y -= 1
			var op := DiffOp.new(DiffOp.OpType.EQUAL, old_lines[x], x, y)
			ops.push_front(op)
			result.unchanged_lines.push_front(old_lines[x])

		# 处理非对角线移动
		if d > 0:
			if x == prev_x:
				# 垂直移动：插入新行
				y -= 1
				var op := DiffOp.new(DiffOp.OpType.INSERT, new_lines[y], -1, y)
				ops.push_front(op)
				result.added_lines.push_front(new_lines[y])
			elif y == prev_y:
				# 水平移动：删除旧行
				x -= 1
				var op := DiffOp.new(DiffOp.OpType.DELETE, old_lines[x], x, -1)
				ops.push_front(op)
				result.deleted_lines.push_front(old_lines[x])

	# 处理第一段对角线
	while x > 0 and y > 0:
		x -= 1
		y -= 1
		var op := DiffOp.new(DiffOp.OpType.EQUAL, old_lines[x], x, y)
		ops.push_front(op)
		result.unchanged_lines.push_front(old_lines[x])

	result.edit_script = ops

## 生成统一的差异文本（类似 unified diff 格式）
static func generate_unified_diff(old_lines: Array[String], new_lines: Array[String], context_lines: int = 3) -> String:
	var result := compute(old_lines, new_lines)
	if result.edit_script.is_empty():
		return ""

	var lines: Array[String] = []
	var i := 0
	var script := result.edit_script

	while i < script.size():
		# 跳过连续的 EQUAL 块，只保留上下文行
		if script[i].op_type == DiffOp.OpType.EQUAL:
			i += 1
			continue

		# 找到变更块的起始和结束
		var start := max(0, i - context_lines)
		var end := min(script.size(), i + context_lines + 1)

		# 扩展以包含所有相邻的变更
		var block_start := i
		var block_end := i
		while block_start > 0 and script[block_start - 1].op_type != DiffOp.OpType.EQUAL:
			block_start -= 1
		while block_end < script.size() - 1 and script[block_end + 1].op_type != DiffOp.OpType.EQUAL:
			block_end += 1

		# 计算块的范围
		var old_start := 1
		var new_start := 1
		if block_start > 0 and script[block_start - 1].op_type == DiffOp.OpType.EQUAL:
			old_start = script[block_start - 1].old_line + 2
			new_start = script[block_start - 1].new_line + 2
		else:
			old_start = 1
			new_start = 1

		var old_count := 0
		var new_count := 0
		for j in range(block_start, block_end + 1):
			match script[j].op_type:
				DiffOp.OpType.DELETE:
					old_count += 1
				DiffOp.OpType.INSERT:
					new_count += 1
				DiffOp.OpType.EQUAL:
					old_count += 1
					new_count += 1

		lines.append("@@ -%d,%d +%d,%d @@" % [old_start, old_count, new_start, new_count])

		for j in range(block_start, block_end + 1):
			match script[j].op_type:
				DiffOp.OpType.EQUAL:
					lines.append(" " + script[j].text)
				DiffOp.OpType.DELETE:
					lines.append("-" + script[j].text)
				DiffOp.OpType.INSERT:
					lines.append("+" + script[j].text)

		i = block_end + 1

	return "\n".join(lines)

## 将文本按行分割
static func split_lines(text: String) -> Array[String]:
	if text.is_empty():
		return []
	return text.split("\n", false)

## 计算两个文本的差异（字符串版本）
static func diff_text(old_text: String, new_text: String) -> DiffResult:
	return compute(split_lines(old_text), split_lines(new_text))
