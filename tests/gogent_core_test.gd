extends SceneTree

const SingletonScript := preload("res://addons/gogent/core/gogent_singleton.gd")
const AgentManagerScript := preload("res://addons/gogent/core/agent_manager.gd")
const TrainingManagerScript := preload("res://addons/gogent/core/training_manager.gd")
const MainPanelScene := preload("res://addons/gogent/ui/main_panel.tscn")

func _initialize() -> void:
	var ok := true
	ok = _test_managers() and ok
	ok = _test_models() and ok
	ok = _test_anthropic_request_context() and ok
	ok = _test_agents() and ok
	ok = _test_skills() and ok
	ok = _test_console() and ok
	ok = await _test_ui() and ok
	ok = await _test_training() and ok
	if ok:
		print("GoGent core tests passed.")
		quit(0)
	else:
		push_error("GoGent core tests failed.")
		quit(1)

func _test_managers() -> bool:
	var singleton = SingletonScript.get_instance()
	singleton.load_all_configs()
	return _assert(singleton.model_manager != null, "model manager") \
		and _assert(singleton.agent_manager != null, "agent manager") \
		and _assert(singleton.api_manager != null, "api manager") \
		and _assert(singleton.skill_manager != null, "skill manager") \
		and _assert(singleton.training_manager != null, "training manager") \
		and _assert(singleton.external_tool_manager != null, "external tool manager")

func _test_models() -> bool:
	var manager = SingletonScript.get_instance().get("model_manager")
	return _assert(manager.suppliers.size() >= 1, "default suppliers") \
		and _assert(manager.get_current_supplier() != null, "current supplier") \
		and _assert(manager.get_current_model() != null, "current model") \
		and _assert(manager.get_supplier("anthropic") != null, "anthropic claude supplier")

func _test_anthropic_request_context() -> bool:
	var singleton = SingletonScript.get_instance()
	var model_manager = singleton.get("model_manager")
	var api = singleton.get("api_manager")
	var original_supplier = model_manager.current_supplier_id
	var original_model = model_manager.current_model_id
	var anthropic = model_manager.get_supplier("anthropic")
	if not _assert(anthropic != null and not anthropic.models.is_empty(), "anthropic models"):
		return false
	model_manager.set_current_model(anthropic.id, anthropic.models[0].id)
	var messages: Array[Dictionary] = [
		{"role": "system", "content": "system text"},
		{"role": "user", "content": "hello"}
	]
	var context: Dictionary = api._build_request_context(messages, {}, false)
	model_manager.set_current_model(original_supplier, original_model)
	var body = JSON.parse_string(context.get("body", "{}"))
	return _assert(context.get("url", "").ends_with("/v1/messages"), "anthropic endpoint") \
		and _assert(body is Dictionary and body.get("system", "") == "system text", "anthropic system field")

func _test_agents() -> bool:
	var manager = SingletonScript.get_instance().get("agent_manager")
	var count = manager.agents.size()
	var agent = AgentManagerScript.AgentConfig.new("Test Agent", "Test Role")
	agent.system_prompt = "You test things."
	manager.add_agent(agent)
	var found = manager.get_agent(agent.id) != null
	manager.remove_agent(agent.id)
	return _assert(count >= 1, "default agents") and _assert(found, "agent add/remove")

func _test_skills() -> bool:
	var manager = SingletonScript.get_instance().get("skill_manager")
	var prompt = manager.render_skill_prompt("code_review", {"code_content": "extends Node"})
	return _assert(manager.skills.size() >= 1, "default skills") and _assert(prompt.contains("extends Node"), "skill prompt render")

func _test_training() -> bool:
	var manager = SingletonScript.get_instance().get("training_manager")
	manager.start_training({"episodes": 3, "max_steps_per_episode": 4, "save_interval": 0})
	while manager.state == TrainingManagerScript.TrainingState.RUNNING:
		await process_frame
	return _assert(manager.stats.episode == 3, "training episodes") and _assert(manager.visualizer.get_statistics().has("Reward"), "training chart data")

func _test_console() -> bool:
	var console = SingletonScript.get_instance().get("console_manager")
	var text = console.execute_command("list_models")
	var external_status = console.execute_command("external_status")
	return _assert(text.contains("Models:"), "console list_models") and _assert(external_status.contains("External tools:"), "console external_status")

func _test_ui() -> bool:
	var singleton = SingletonScript.get_instance()
	var panel = MainPanelScene.instantiate()
	root.add_child(panel)
	singleton.set_main_panel(panel)
	await process_frame
	var ok = _assert(panel.has_method("is_gogent_main_panel"), "main panel marker") and _assert(panel.is_gogent_main_panel(), "main panel ready")
	panel.queue_free()
	await process_frame
	singleton.set_main_panel(null)
	return ok

func _assert(condition: bool, label: String) -> bool:
	if not condition:
		push_error("Assertion failed: " + label)
	return condition
