@tool
class_name GoGentTrainingManager
extends RefCounted

## AI 训练管理器
## 管理强化学习训练、神经网络训练等
## 参考 MLGodotKit 的 RL 系统和 godot_rl_agents

# 训练状态
enum TrainingState {
	IDLE,
	RUNNING,
	PAUSED,
	COMPLETED,
	ERROR
}

# 训练配置
class TrainingConfig:
	var algorithm: String = "dqn"  # dqn, ppo, a2c
	var episodes: int = 1000
	var max_steps_per_episode: int = 1000
	var learning_rate: float = 0.001
	var discount_factor: float = 0.99
	var exploration_rate: float = 1.0
	var exploration_decay: float = 0.995
	var min_exploration_rate: float = 0.01
	var batch_size: int = 64
	var memory_size: int = 10000
	var save_interval: int = 100
	var model_path: String = "res://models/"
	var environment_scene: String = ""  # 训练场景路径
	
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
			"model_path": model_path,
			"environment_scene": environment_scene
		}
	
	static func from_dict(data: Dictionary) -> TrainingConfig:
		var config = TrainingConfig.new()
		config.algorithm = data.get("algorithm", "dqn")
		config.episodes = data.get("episodes", 1000)
		config.max_steps_per_episode = data.get("max_steps_per_episode", 1000)
		config.learning_rate = data.get("learning_rate", 0.001)
		config.discount_factor = data.get("discount_factor", 0.99)
		config.exploration_rate = data.get("exploration_rate", 1.0)
		config.exploration_decay = data.get("exploration_decay", 0.995)
		config.min_exploration_rate = data.get("min_exploration_rate", 0.01)
		config.batch_size = data.get("batch_size", 64)
		config.memory_size = data.get("memory_size", 10000)
		config.save_interval = data.get("save_interval", 100)
		config.model_path = data.get("model_path", "res://models/")
		config.environment_scene = data.get("environment_scene", "")
		return config

# 训练统计
class TrainingStats:
	var episode: int = 0
	var total_reward: float = 0.0
	var avg_reward: float = 0.0
	var max_reward: float = -INF
	var min_reward: float = INF
	var epsilon: float = 1.0
	var steps: int = 0
	var start_time: int = 0
	var elapsed_time: float = 0.0
	
	func reset() -> void:
		episode = 0
		total_reward = 0.0
		avg_reward = 0.0
		max_reward = -INF
		min_reward = INF
		epsilon = 1.0
		steps = 0
		start_time = Time.get_unix_time_from_system()
		elapsed_time = 0.0

# 经验回放
class ReplayBuffer:
	var buffer: Array[Dictionary] = []
	var max_size: int
	var position: int = 0
	
	func _init(size: int):
		max_size = size
		buffer.resize(size)
	
	func push(experience: Dictionary) -> void:
		buffer[position] = experience
		position = (position + 1) % max_size
	
	func sample(batch_size: int) -> Array[Dictionary]:
		var batch = []
		var size = min(buffer.size(), max_size)
		for i in range(batch_size):
			var idx = randi() % size
			batch.append(buffer[idx])
		return batch
	
	func size() -> int:
		return min(buffer.size(), max_size)

# 信号
signal training_started(config: Dictionary)
signal training_episode_completed(episode: int, reward: float, epsilon: float)
signal training_completed(stats: Dictionary)
signal training_error(error_msg: String)

var state: TrainingState = TrainingState.IDLE
var config: TrainingConfig = TrainingConfig.new()
var stats: TrainingStats = TrainingStats.new()
var replay_buffer: ReplayBuffer = null

# 训练可视化器
var visualizer: GoGentTrainingVisualizer = null

# DQN 网络参数
var _q_network: Dictionary = {}  # 简化的 Q 网络权重
var _target_network: Dictionary = {}
var _training_thread: Thread = null

func _init() -> void:
	# 初始化训练可视化器
	visualizer = GoGentTrainingVisualizer.new()

## 开始训练
func start_training(custom_config: Dictionary = {}) -> void:
	if state == TrainingState.RUNNING:
		push_warning("训练已在进行中")
		return
	
	# 应用自定义配置
	for key in custom_config.keys():
		if config.has(key):
			config.set(key, custom_config[key])
	
	state = TrainingState.RUNNING
	stats.reset()
	
	# 初始化经验回放
	replay_buffer = ReplayBuffer.new(config.memory_size)
	
	# 初始化 Q 网络
	_init_q_network()
	
	GoGentSingleton.print_gogent_console("训练开始 - 算法: {0}, 轮次: {1}".format([config.algorithm, config.episodes]), "info")
	training_started.emit(config.to_dict())
	
	# 开始训练循环
	_start_training_loop()

## 暂停训练
func pause_training() -> void:
	if state == TrainingState.RUNNING:
		state = TrainingState.PAUSED
		GoGentSingleton.print_gogent_console("训练已暂停", "warning")

## 恢复训练
func resume_training() -> void:
	if state == TrainingState.PAUSED:
		state = TrainingState.RUNNING
		GoGentSingleton.print_gogent_console("训练已恢复", "info")
		_start_training_loop()

## 停止训练
func stop_training() -> void:
	state = TrainingState.IDLE
	GoGentSingleton.print_gogent_console("训练已停止", "warning")

## 保存模型
func save_model(path: String = "") -> void:
	if path.is_empty():
		path = config.model_path + "model_{0}.tres".format([stats.episode])
	
	var dir = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	
	# 保存模型权重
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_q_network))
		file.close()
		GoGentSingleton.print_gogent_console("模型已保存: {0}".format([path]), "success")

## 加载模型
func load_model(path: String) -> bool:
	var file = FileAccess.open(path, FileAccess.READ)
	if FileAccess.get_open_error() != OK:
		push_error("无法加载模型: " + path)
		return false
	
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.parse_string(content)
	if json == null:
		return false
	
	_q_network = json
	GoGentSingleton.print_gogent_console("模型已加载: {0}".format([path]), "success")
	return true

## 获取动作（基于当前状态）
func get_action(state_vector: Array) -> int:
	if config.exploration_rate > randf():
		# 探索：随机动作
		return randi() % 4  # 假设 4 个动作
	else:
		# 利用：选择最佳动作
		return _get_best_action(state_vector)

## 添加经验到回放缓冲区
func add_experience(state: Array, action: int, reward: float, next_state: Array, done: bool) -> void:
	if replay_buffer:
		replay_buffer.push({
			"state": state,
			"action": action,
			"reward": reward,
			"next_state": next_state,
			"done": done
		})

## 更新训练统计
func update_stats(episode_reward: float) -> void:
	stats.episode += 1
	stats.total_reward += episode_reward
	stats.avg_reward = stats.total_reward / stats.episode
	stats.max_reward = max(stats.max_reward, episode_reward)
	stats.min_reward = min(stats.min_reward, episode_reward)
	stats.epsilon = max(config.min_exploration_rate, config.exploration_rate)
	stats.elapsed_time = Time.get_unix_time_from_system() - stats.start_time
	
	# 衰减探索率
	config.exploration_rate *= config.exploration_decay
	config.exploration_rate = max(config.min_exploration_rate, config.exploration_rate)

# ========== 内部方法 ==========

func _init_q_network() -> void:
	# 简化的 Q 网络初始化
	_q_network = {
		"layer1_weight": [],
		"layer1_bias": [],
		"layer2_weight": [],
		"layer2_bias": [],
		"output_weight": [],
		"output_bias": []
	}
	_target_network = _q_network.duplicate(true)

func _start_training_loop() -> void:
	# 使用协程进行训练循环，避免阻塞编辑器
	while state == TrainingState.RUNNING and stats.episode < config.episodes:
		var episode_reward = _run_episode()
		update_stats(episode_reward)
		
		# 训练网络
		if replay_buffer and replay_buffer.size() >= config.batch_size:
			_train_network()
		
		# 记录训练数据到可视化器
		if visualizer:
			visualizer.record_reward(stats.episode, episode_reward, stats.avg_reward, stats.max_reward)
			visualizer.record_epsilon(stats.episode, stats.epsilon)
		
		# 定期保存
		if stats.episode % config.save_interval == 0:
			save_model()
		
		training_episode_completed.emit(stats.episode, episode_reward, stats.epsilon)
		
		# 让出控制权
		await Engine.get_main_loop().process_frame
		
		if state == TrainingState.PAUSED:
			return
	
	if state == TrainingState.RUNNING:
		state = TrainingState.COMPLETED
		var final_stats = {
			"episodes": stats.episode,
			"total_reward": stats.total_reward,
			"avg_reward": stats.avg_reward,
			"max_reward": stats.max_reward,
			"min_reward": stats.min_reward,
			"final_epsilon": stats.epsilon,
			"elapsed_time": stats.elapsed_time
		}
		training_completed.emit(final_stats)
		GoGentSingleton.print_gogent_console("训练完成！平均奖励: {0}".format([stats.avg_reward]), "success")
		
		# 输出训练统计摘要
		if visualizer:
			GoGentSingleton.print_gogent_console(visualizer.get_summary_text(), "info")

func _run_episode() -> float:
	# 模拟一个 episode 的运行
	# 实际使用时需要连接到游戏环境
	var total_reward = 0.0
	var state = [randf(), randf(), randf(), randf()]  # 示例状态
	
	for step in range(config.max_steps_per_episode):
		var action = get_action(state)
		# 模拟环境反馈
		var reward = randf() * 2 - 1  # -1 到 1 的随机奖励
		var next_state = [randf(), randf(), randf(), randf()]
		var done = step >= config.max_steps_per_episode - 1
		
		add_experience(state, action, reward, next_state, done)
		total_reward += reward
		state = next_state
		
		if done:
			break
	
	return total_reward

func _train_network() -> void:
	# 简化的 DQN 训练
	var batch = replay_buffer.sample(config.batch_size)
	# 实际训练逻辑需要矩阵运算库
	# 这里使用 MLGodotKit 的 Matrix 类进行运算
	pass

func _get_best_action(state: Array) -> int:
	# 简化的最佳动作选择
	return randi() % 4
