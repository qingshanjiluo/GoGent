@tool
class_name GoGentTrainingManager
extends RefCounted

signal training_started(config: Dictionary)
signal training_episode_completed(episode: int, reward: float, epsilon: float)
signal training_completed(stats: Dictionary)
signal training_error(error_msg: String)
signal human_feedback_recorded(action: int, reward: float, note: String)

enum TrainingState { IDLE, RUNNING, PAUSED, COMPLETED, ERROR }

class TrainingConfig:
	var algorithm := "dqn"
	var episodes := 100
	var max_steps_per_episode := 128
	var learning_rate := 0.001
	var discount_factor := 0.99
	var exploration_rate := 1.0
	var exploration_decay := 0.995
	var min_exploration_rate := 0.02
	var batch_size := 32
	var memory_size := 2000
	var save_interval := 0
	var model_path := "res://addons/gogent/config/trained_models/"

	func to_dict() -> Dictionary:
		return {
			"algorithm": algorithm,
			"episodes": episodes,
			"max_steps_per_episode": max_steps_per_episode,
			"learning_rate": learning_rate,
			"discount_factor": discount_factor,
			"exploration_rate": exploration_rate,
			"exploration_decay": exploration_decay,
			"min_exploration_rate": min_exploration_rate,
			"batch_size": batch_size,
			"memory_size": memory_size,
			"save_interval": save_interval,
			"model_path": model_path
		}

class TrainingStats:
	var episode := 0
	var total_reward := 0.0
	var avg_reward := 0.0
	var max_reward := -INF
	var min_reward := INF
	var epsilon := 1.0
	var elapsed_time := 0.0
	var start_time := 0.0

	func reset(initial_epsilon: float) -> void:
		episode = 0
		total_reward = 0.0
		avg_reward = 0.0
		max_reward = -INF
		min_reward = INF
		epsilon = initial_epsilon
		elapsed_time = 0.0
		start_time = Time.get_unix_time_from_system()

class ReplayBuffer:
	var buffer: Array[Dictionary] = []
	var max_size := 1000

	func _init(p_max_size: int = 1000) -> void:
		max_size = max(1, p_max_size)

	func push(experience: Dictionary) -> void:
		buffer.append(experience)
		while buffer.size() > max_size:
			buffer.pop_front()

	func sample(batch_size: int) -> Array[Dictionary]:
		var result: Array[Dictionary] = []
		if buffer.is_empty():
			return result
		for _i in range(min(batch_size, buffer.size())):
			result.append(buffer[randi() % buffer.size()])
		return result

	func size() -> int:
		return buffer.size()

var state: TrainingState = TrainingState.IDLE
var config := TrainingConfig.new()
var stats := TrainingStats.new()
var replay_buffer := ReplayBuffer.new()
var visualizer := GoGentTrainingVisualizer.new()
var human_feedback: Array[Dictionary] = []
var _q_table: Dictionary = {}
var _run_token := 0

func start_training(custom_config = null) -> void:
	if state == TrainingState.RUNNING:
		return
	if custom_config is int:
		config.episodes = max(1, custom_config)
	elif custom_config is Dictionary:
		_apply_config(custom_config)
	state = TrainingState.RUNNING
	_run_token += 1
	config.exploration_rate = clamp(config.exploration_rate, config.min_exploration_rate, 1.0)
	stats.reset(config.exploration_rate)
	replay_buffer = ReplayBuffer.new(config.memory_size)
	human_feedback.clear()
	_q_table.clear()
	visualizer.clear_all()
	training_started.emit(config.to_dict())
	_run_training_loop.call_deferred(_run_token)

func pause_training() -> void:
	if state == TrainingState.RUNNING:
		state = TrainingState.PAUSED

func resume_training() -> void:
	if state == TrainingState.PAUSED:
		state = TrainingState.RUNNING
		_run_token += 1
		_run_training_loop.call_deferred(_run_token)

func stop_training() -> void:
	state = TrainingState.IDLE
	_run_token += 1

func save_model(path: String = "") -> bool:
	if path.is_empty():
		path = config.model_path + "q_table_%d.json" % stats.episode
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"q_table": _q_table, "stats": get_stats_dict()}, "\t"))
	file.close()
	return true

func load_model(path: String) -> bool:
	var text := FileAccess.get_file_as_string(path)
	if FileAccess.get_open_error() != OK:
		return false
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return false
	_q_table = parsed.get("q_table", {})
	return true

func get_stats_dict() -> Dictionary:
	return {
		"episodes": stats.episode,
		"total_reward": stats.total_reward,
		"avg_reward": stats.avg_reward,
		"max_reward": stats.max_reward,
		"min_reward": stats.min_reward,
		"epsilon": stats.epsilon,
		"elapsed_time": stats.elapsed_time,
		"human_feedback_count": human_feedback.size(),
		"replay_buffer_size": replay_buffer.size()
	}

func get_action(state_vector: Array) -> int:
	if randf() < config.exploration_rate:
		return randi() % 4
	return _best_action(_state_key(state_vector))

func add_experience(state_vector: Array, action: int, reward: float, next_state: Array, done: bool) -> void:
	replay_buffer.push({"state": state_vector, "action": action, "reward": reward, "next_state": next_state, "done": done})

func record_human_feedback(state_vector: Array, action: int, reward: float, next_state: Array = [], done: bool = false, note: String = "") -> Dictionary:
	if next_state.is_empty():
		next_state = state_vector.duplicate()
	var feedback := {
		"state": state_vector,
		"action": action,
		"reward": reward,
		"next_state": next_state,
		"done": done,
		"note": note,
		"created_at": Time.get_unix_time_from_system()
	}
	human_feedback.append(feedback)
	add_experience(state_vector, action, reward, next_state, done)
	var visual_episode := max(1, stats.episode + human_feedback.size())
	stats.max_reward = max(stats.max_reward, reward)
	stats.min_reward = min(stats.min_reward, reward)
	visualizer.record_reward(visual_episode, reward, stats.avg_reward, stats.max_reward)
	human_feedback_recorded.emit(action, reward, note)
	return feedback

func _apply_config(values: Dictionary) -> void:
	for key in values.keys():
		match key:
			"episodes":
				config.episodes = max(1, int(values[key]))
			"max_steps_per_episode":
				config.max_steps_per_episode = max(1, int(values[key]))
			"learning_rate":
				config.learning_rate = max(0.000001, float(values[key]))
			"discount_factor":
				config.discount_factor = clamp(float(values[key]), 0.0, 1.0)
			"exploration_rate":
				config.exploration_rate = clamp(float(values[key]), 0.0, 1.0)
			"exploration_decay":
				config.exploration_decay = clamp(float(values[key]), 0.0, 1.0)
			"min_exploration_rate":
				config.min_exploration_rate = clamp(float(values[key]), 0.0, 1.0)
			"batch_size":
				config.batch_size = max(1, int(values[key]))
			"memory_size":
				config.memory_size = max(1, int(values[key]))
			"save_interval":
				config.save_interval = max(0, int(values[key]))

func _run_training_loop(token: int) -> void:
	while token == _run_token and state == TrainingState.RUNNING and stats.episode < config.episodes:
		var reward := _run_episode()
		_update_stats(reward)
		_train_from_replay()
		visualizer.record_reward(stats.episode, reward, stats.avg_reward, stats.max_reward)
		visualizer.record_epsilon(stats.episode, stats.epsilon)
		training_episode_completed.emit(stats.episode, reward, stats.epsilon)
		if config.save_interval > 0 and stats.episode % config.save_interval == 0:
			save_model()
		var tree = GoGentSingleton.get_instance().get_scene_tree()
		if tree != null:
			await tree.process_frame
		else:
			break
	if token == _run_token and state == TrainingState.RUNNING:
		state = TrainingState.COMPLETED
		training_completed.emit(get_stats_dict())

func _run_episode() -> float:
	var total := 0.0
	var current := [randf(), randf(), randf(), randf()]
	for step in range(config.max_steps_per_episode):
		var action := get_action(current)
		var target_action := int(round(current[0] * 3.0))
		var reward := 1.0 if action == target_action else -0.25
		reward += randf_range(-0.05, 0.05)
		var next := [randf(), randf(), randf(), randf()]
		var done := step == config.max_steps_per_episode - 1
		add_experience(current, action, reward, next, done)
		total += reward
		current = next
	return total

func _update_stats(reward: float) -> void:
	stats.episode += 1
	stats.total_reward += reward
	stats.avg_reward = stats.total_reward / max(1, stats.episode)
	stats.max_reward = max(stats.max_reward, reward)
	stats.min_reward = min(stats.min_reward, reward)
	config.exploration_rate = max(config.min_exploration_rate, config.exploration_rate * config.exploration_decay)
	stats.epsilon = config.exploration_rate
	stats.elapsed_time = Time.get_unix_time_from_system() - stats.start_time

func _train_from_replay() -> void:
	for item in replay_buffer.sample(config.batch_size):
		var key := _state_key(item["state"])
		var action := int(item["action"])
		var reward := float(item["reward"])
		var next_key := _state_key(item["next_state"])
		var done := bool(item["done"])
		_ensure_state(key)
		_ensure_state(next_key)
		var next_best: float = 0.0 if done else float(_q_table[next_key][_best_action(next_key)])
		var old: float = float(_q_table[key][action])
		_q_table[key][action] = old + config.learning_rate * (reward + config.discount_factor * next_best - old)

func _state_key(state_vector: Array) -> String:
	var parts := PackedStringArray()
	for value in state_vector:
		parts.append(str(int(clamp(float(value), 0.0, 0.999) * 10.0)))
	return ":".join(parts)

func _ensure_state(key: String) -> void:
	if not _q_table.has(key):
		_q_table[key] = [0.0, 0.0, 0.0, 0.0]

func _best_action(key: String) -> int:
	_ensure_state(key)
	var values: Array = _q_table[key]
	var best := 0
	for i in range(1, values.size()):
		if values[i] > values[best]:
			best = i
	return best
