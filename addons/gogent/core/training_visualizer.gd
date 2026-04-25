@tool
class_name GoGentTrainingVisualizer
extends RefCounted

signal data_updated(series_name: String)
signal chart_cleared

class DataPoint:
	var episode := 0
	var value := 0.0

	func _init(p_episode: int = 0, p_value: float = 0.0) -> void:
		episode = p_episode
		value = p_value

class DataSeries:
	var name := ""
	var color := Color.WHITE
	var data: Array[DataPoint] = []
	var max_points := 1000

	func _init(p_name: String = "", p_color: Color = Color.WHITE) -> void:
		name = p_name
		color = p_color

	func add_point(episode: int, value: float) -> void:
		data.append(DataPoint.new(episode, value))
		while data.size() > max_points:
			data.pop_front()

	func get_min_value() -> float:
		if data.is_empty():
			return 0.0
		var value := INF
		for point in data:
			value = min(value, point.value)
		return value

	func get_max_value() -> float:
		if data.is_empty():
			return 0.0
		var value := -INF
		for point in data:
			value = max(value, point.value)
		return value

	func get_average() -> float:
		if data.is_empty():
			return 0.0
		var total := 0.0
		for point in data:
			total += point.value
		return total / data.size()

	func get_latest() -> float:
		return 0.0 if data.is_empty() else data[-1].value

var series_map: Dictionary = {}

func _init() -> void:
	add_series("Reward", Color(0.26, 1.0, 0.76))
	add_series("Average", Color(1.0, 0.68, 0.25))
	add_series("Max", Color(0.4, 0.8, 1.0))
	add_series("Epsilon", Color(1.0, 0.4, 0.6))
	add_series("Loss", Color(1.0, 0.32, 0.32))

func add_series(name: String, color: Color) -> DataSeries:
	if series_map.has(name):
		return series_map[name]
	var series := DataSeries.new(name, color)
	series_map[name] = series
	return series

func add_data_point(series_name: String, episode: int, value: float) -> void:
	var series: DataSeries = series_map.get(series_name)
	if series == null:
		series = add_series(series_name, Color(randf(), randf(), randf()))
	series.add_point(episode, value)
	data_updated.emit(series_name)

func record_reward(episode: int, reward: float, average: float, max_reward: float) -> void:
	add_data_point("Reward", episode, reward)
	add_data_point("Average", episode, average)
	add_data_point("Max", episode, max_reward)

func record_epsilon(episode: int, epsilon: float) -> void:
	add_data_point("Epsilon", episode, epsilon)

func record_loss(episode: int, loss: float) -> void:
	add_data_point("Loss", episode, loss)

func clear_all() -> void:
	for series in series_map.values():
		series.data.clear()
	chart_cleared.emit()

func get_statistics() -> Dictionary:
	var stats := {}
	for name in series_map.keys():
		var series: DataSeries = series_map[name]
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

func create_chart_control() -> Control:
	var chart := GoGentChartControl.new()
	chart.visualizer = self
	return chart

func get_summary_text() -> String:
	var lines := PackedStringArray(["Training summary"])
	for name in series_map.keys():
		var series: DataSeries = series_map[name]
		if series.data.is_empty():
			continue
		lines.append("%s latest=%.3f avg=%.3f min=%.3f max=%.3f count=%d" % [name, series.get_latest(), series.get_average(), series.get_min_value(), series.get_max_value(), series.data.size()])
	return "\n".join(lines)

func export_to_csv(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_line("series,episode,value")
	for name in series_map.keys():
		var series: DataSeries = series_map[name]
		for point in series.data:
			file.store_line("%s,%d,%s" % [name, point.episode, point.value])
	file.close()
	return true

class GoGentChartControl:
	extends Control

	var visualizer: GoGentTrainingVisualizer
	var bg_color := Color(0.08, 0.09, 0.12, 1.0)
	var grid_color := Color(0.24, 0.27, 0.34, 0.65)
	var text_color := Color(0.86, 0.9, 0.96, 1.0)
	var margin := Vector4(52, 18, 18, 32)

	func _ready() -> void:
		custom_minimum_size = Vector2(260, 180)

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, bg_color, true)
		if visualizer == null:
			return
		var plot := Rect2(Vector2(margin.x, margin.y), Vector2(max(1.0, size.x - margin.x - margin.z), max(1.0, size.y - margin.y - margin.w)))
		_draw_grid(plot)
		var bounds := _bounds()
		for name in visualizer.series_map.keys():
			var series: DataSeries = visualizer.series_map[name]
			if series.data.size() < 2:
				continue
			_draw_series(series, plot, bounds)
		_draw_legend()

	func _draw_grid(plot: Rect2) -> void:
		for i in range(6):
			var t := i / 5.0
			draw_line(Vector2(plot.position.x, plot.position.y + plot.size.y * t), Vector2(plot.end.x, plot.position.y + plot.size.y * t), grid_color)
			draw_line(Vector2(plot.position.x + plot.size.x * t, plot.position.y), Vector2(plot.position.x + plot.size.x * t, plot.end.y), grid_color)

	func _bounds() -> Dictionary:
		var min_v := INF
		var max_v := -INF
		var max_count := 1
		for series in visualizer.series_map.values():
			for point in series.data:
				min_v = min(min_v, point.value)
				max_v = max(max_v, point.value)
			max_count = max(max_count, series.data.size())
		if min_v == INF:
			min_v = 0.0
			max_v = 1.0
		if is_equal_approx(min_v, max_v):
			min_v -= 1.0
			max_v += 1.0
		return {"min": min_v, "max": max_v, "count": max_count}

	func _draw_series(series: DataSeries, plot: Rect2, bounds: Dictionary) -> void:
		var points := PackedVector2Array()
		for i in range(series.data.size()):
			var value := series.data[i].value
			var x: float = plot.position.x + plot.size.x * (float(i) / max(1.0, float(bounds["count"] - 1)))
			var y: float = plot.end.y - plot.size.y * ((value - bounds["min"]) / max(0.001, bounds["max"] - bounds["min"]))
			points.append(Vector2(x, y))
		for i in range(points.size() - 1):
			draw_line(points[i], points[i + 1], series.color, 2.0)

	func _draw_legend() -> void:
		var y := 14.0
		for name in visualizer.series_map.keys():
			var series: DataSeries = visualizer.series_map[name]
			if series.data.is_empty():
				continue
			draw_rect(Rect2(10, y - 9, 10, 10), series.color, true)
			draw_string(get_theme_default_font(), Vector2(24, y), "%s %.2f" % [name, series.get_latest()], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, text_color)
			y += 15.0
