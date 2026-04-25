@tool
class_name GoGentTrainingVisualizer
extends RefCounted

## 训练可视化图表
## 管理训练数据，通过 ChartControl 节点进行渲染
## 兼容 Godot 4.2+ (包括 4.6.2)

# 图表类型
enum ChartType {
	REWARD,        # 奖励曲线
	LOSS,          # 损失曲线
	EPSILON,       # 探索率曲线
	ALL            # 全部
}

# 数据点
class DataPoint:
	var episode: int
	var value: float
	var timestamp: float
	
	func _init(p_episode: int, p_value: float):
		episode = p_episode
		value = p_value
		timestamp = Time.get_unix_time_from_system()

# 图表数据系列
class DataSeries:
	var name: String
	var color: Color
	var data: Array[DataPoint] = []
	var max_points: int = 1000
	
	func _init(p_name: String, p_color: Color):
		name = p_name
		color = p_color
	
	func add_point(episode: int, value: float) -> void:
		data.append(DataPoint.new(episode, value))
		if data.size() > max_points:
			data.pop_front()
	
	func get_values() -> Array:
		var values = []
		for p in data:
			values.append(p.value)
		return values
	
	func get_episodes() -> Array:
		var eps = []
		for p in data:
			eps.append(p.episode)
		return eps
	
	func get_min_value() -> float:
		if data.is_empty():
			return 0.0
		var min_val = INF
		for p in data:
			if p.value < min_val:
				min_val = p.value
		return min_val
	
	func get_max_value() -> float:
		if data.is_empty():
			return 0.0
		var max_val = -INF
		for p in data:
			if p.value > max_val:
				max_val = p.value
		return max_val
	
	func get_average() -> float:
		if data.is_empty():
			return 0.0
		var sum = 0.0
		for p in data:
			sum += p.value
		return sum / data.size()
	
	func get_latest() -> float:
		if data.is_empty():
			return 0.0
		return data[-1].value

# 信号
signal data_updated(series_name: String)
signal chart_cleared()

# 数据系列
var series_map: Dictionary = {}  # name -> DataSeries
var current_chart_type: int = ChartType.ALL

func _init() -> void:
	_add_default_series()

func _add_default_series() -> void:
	add_series("奖励", Color(0.26, 1.0, 0.76))
	add_series("平均奖励", Color(1.0, 0.7, 0.2))
	add_series("最大奖励", Color(0.4, 0.8, 1.0))
	add_series("探索率", Color(1.0, 0.4, 0.6))
	add_series("损失", Color(1.0, 0.3, 0.3))

## 添加数据系列
func add_series(name: String, color: Color) -> DataSeries:
	if series_map.has(name):
		return series_map[name]
	var series = DataSeries.new(name, color)
	series_map[name] = series
	return series

## 获取数据系列
func get_series(name: String) -> DataSeries:
	return series_map.get(name, null)

## 添加数据点
func add_data_point(series_name: String, episode: int, value: float) -> void:
	var series = series_map.get(series_name)
	if series == null:
		series = add_series(series_name, Color(randf(), randf(), randf()))
	series.add_point(episode, value)
	data_updated.emit(series_name)

## 记录训练奖励
func record_reward(episode: int, reward: float, avg_reward: float, max_reward: float) -> void:
	add_data_point("奖励", episode, reward)
	add_data_point("平均奖励", episode, avg_reward)
	add_data_point("最大奖励", episode, max_reward)

## 记录探索率
func record_epsilon(episode: int, epsilon: float) -> void:
	add_data_point("探索率", episode, epsilon)

## 记录损失
func record_loss(episode: int, loss: float) -> void:
	add_data_point("损失", episode, loss)

## 清除所有数据
func clear_all() -> void:
	for series in series_map.values():
		series.data.clear()
	chart_cleared.emit()

## 获取统计数据
func get_statistics() -> Dictionary:
	var stats = {}
	for name in series_map.keys():
		var series = series_map[name]
		if series.data.is_empty():
			continue
		stats[name] = {
			"min": series.get_min_value(),
			"max": series.get_max_value(),
			"avg": series.get_average(),
			"latest": series.get_latest(),
			"count": series.data.size()
		}
	return stats

## 创建图表控件并返回
func create_chart_control() -> Control:
	var chart = GoGentChartControl.new()
	chart.visualizer = self
	return chart

## 获取图表摘要文本
func get_summary_text() -> String:
	var text = "📊 训练统计摘要\n"
	text += "=" * 30 + "\n"
	
	for name in series_map.keys():
		var series = series_map[name]
		if series.data.is_empty():
			continue
		text += "\n{0}:\n".format([name])
		text += "  最新: {0:.4f}\n".format([series.get_latest()])
		text += "  平均: {0:.4f}\n".format([series.get_average()])
		text += "  最大: {0:.4f}\n".format([series.get_max_value()])
		text += "  最小: {0:.4f}\n".format([series.get_min_value()])
		text += "  数据点: {0}\n".format([series.data.size()])
	
	return text

## 导出数据为 CSV
func export_to_csv(path: String) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return false
	
	var headers = ["episode"]
	for name in series_map.keys():
		headers.append(name)
	file.store_line(",".join(headers))
	
	var max_points = 0
	for series in series_map.values():
		max_points = max(max_points, series.data.size())
	
	for i in range(max_points):
		var row = [str(i)]
		for name in series_map.keys():
			var series = series_map[name]
			if i < series.data.size():
				row.append(str(series.data[i].value))
			else:
				row.append("")
		file.store_line(",".join(row))
	
	file.close()
	return true


# ============================================================
# 图表渲染控件 - 使用 Godot 的 _draw() 回调进行绘制
# ============================================================
class GoGentChartControl extends Control:
	## 图表渲染控件
	## 通过 _draw() 回调绘制训练曲线
	## 兼容 Godot 4.2+ (包括 4.6.2)
	
	var visualizer: GoGentTrainingVisualizer = null
	
	# 外观设置
	var background_color: Color = Color(0.1, 0.1, 0.15, 0.9)
	var grid_color: Color = Color(0.2, 0.2, 0.3, 0.5)
	var text_color: Color = Color(0.8, 0.8, 0.9, 1.0)
	var line_width: float = 2.0
	var show_grid: bool = true
	var show_legend: bool = true
	var smooth_curve: bool = true
	var margin_left: float = 50.0
	var margin_top: float = 20.0
	var margin_right: float = 20.0
	var margin_bottom: float = 30.0
	
	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		# 不需要设置 process_mode，因为 _draw() 由引擎自动调用
	
	func _draw() -> void:
		if visualizer == null:
			return
		
		var rect = get_rect()
		var draw_w = rect.size.x - margin_left - margin_right
		var draw_h = rect.size.y - margin_top - margin_bottom
		var draw_x = margin_left
		var draw_y = margin_top
		
		if draw_w <= 0 or draw_h <= 0:
			return
		
		# 绘制背景
		draw_rect(Rect2(0, 0, rect.size.x, rect.size.y), background_color)
		
		# 绘制网格
		if show_grid:
			_draw_grid(draw_x, draw_y, draw_w, draw_h)
		
		# 绘制数据
		_draw_all_series(draw_x, draw_y, draw_w, draw_h)
		
		# 绘制图例
		if show_legend:
			_draw_legend()
	
	func _draw_grid(x: float, y: float, w: float, h: float) -> void:
		var num_h_lines = 5
		var num_v_lines = 5
		
		for i in range(num_h_lines + 1):
			var line_y = y + h * i / num_h_lines
			draw_line(Vector2(x, line_y), Vector2(x + w, line_y), grid_color, 0.5)
		
		for i in range(num_v_lines + 1):
			var line_x = x + w * i / num_v_lines
			draw_line(Vector2(line_x, y), Vector2(line_x, y + h), grid_color, 0.5)
	
	func _draw_all_series(x: float, y: float, w: float, h: float) -> void:
		if visualizer == null:
			return
		
		for name in visualizer.series_map.keys():
			var series = visualizer.series_map[name]
			if series.data.is_empty():
				continue
			
			var values = series.get_values()
			var min_val = series.get_min_value()
			var max_val = series.get_max_value()
			var value_range = max_val - min_val
			if value_range == 0:
				value_range = 1.0
			
			var points = []
			for i in range(values.size()):
				var px = x + w * i / max(values.size() - 1, 1)
				var py = y + h * (1.0 - (values[i] - min_val) / value_range)
				points.append(Vector2(px, py))
			
			# 绘制折线
			if smooth_curve and points.size() >= 3:
				_draw_smooth_curve(points, series.color, line_width)
			else:
				for i in range(points.size() - 1):
					draw_line(points[i], points[i + 1], series.color, line_width)
	
	func _draw_smooth_curve(points: Array, color: Color, width: float) -> void:
		if points.size() < 2:
			return
		
		var segments = 10
		for i in range(points.size() - 1):
			var p0 = points[max(0, i - 1)]
			var p1 = points[i]
			var p2 = points[min(i + 1, points.size() - 1)]
			var p3 = points[min(i + 2, points.size() - 1)]
			
			var prev_point = p1
			for j in range(1, segments + 1):
				var t = j / float(segments)
				var tt = t * t
				var ttt = tt * t
				
				var qx = 0.5 * (
					(2.0 * p1.x) +
					(-p0.x + p2.x) * t +
					(2.0 * p0.x - 5.0 * p1.x + 4.0 * p2.x - p3.x) * tt +
					(-p0.x + 3.0 * p1.x - 3.0 * p2.x + p3.x) * ttt
				)
				var qy = 0.5 * (
					(2.0 * p1.y) +
					(-p0.y + p2.y) * t +
					(2.0 * p0.y - 5.0 * p1.y + 4.0 * p2.y - p3.y) * tt +
					(-p0.y + 3.0 * p1.y - 3.0 * p2.y + p3.y) * ttt
				)
				
				draw_line(prev_point, Vector2(qx, qy), color, width)
				prev_point = Vector2(qx, qy)
	
	func _draw_legend() -> void:
		if visualizer == null:
			return
		
		var legend_x = 10.0
		var legend_y = 10.0
		var item_height = 16.0
		
		for name in visualizer.series_map.keys():
			var series = visualizer.series_map[name]
			if series.data.is_empty():
				continue
			
			# 颜色方块
			draw_rect(Rect2(legend_x, legend_y, 12, 12), series.color)
			
			# 标签
			var label = "{0}: {1:.2f}".format([name, series.get_latest()])
			draw_string(get_theme_default_font(), Vector2(legend_x + 16, legend_y + 10), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, text_color)
			
			legend_y += item_height
	
	## 刷新图表
	func refresh() -> void:
		queue_redraw()
