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
	ok = _test_openai_compatible_options() and ok
	ok = _test_agents() and ok
	ok = _test_skills() and ok
	ok = _test_workspace_tools() and ok
	ok = _test_conversation_history() and ok
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
		and _assert(singleton.external_tool_manager != null, "external tool manager") \
		and _assert(singleton.node_editor_manager != null, "node editor manager") \
		and _assert(singleton.conversation_manager != null, "conversation manager") \
		and _assert(singleton.workspace_tool_manager != null, "workspace tool manager") \
		and _assert(singleton.node_editor_manager.get_agent_tool_manifest().size() >= 8, "node editor tool manifest")

func _test_models() -> bool:
	var manager = SingletonScript.get_instance().get("model_manager")
	return _assert(manager.suppliers.size() >= 1, "default suppliers") \
		and _assert(manager.get_current_supplier() != null, "current supplier") \
		and _assert(manager.get_current_model() != null, "current model") \
		and _assert(manager.get_supplier("deepseek") != null, "deepseek supplier") \
		and _assert(manager.get_supplier("openai") != null, "openai supplier") \
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

func _test_openai_compatible_options() -> bool:
	var singleton = SingletonScript.get_instance()
	var model_manager = singleton.get("model_manager")
	var cfg = singleton.get("config_manager")
	var api = singleton.get("api_manager")
	var original_supplier = model_manager.current_supplier_id
	var original_model = model_manager.current_model_id
	var deepseek = model_manager.get_supplier("deepseek")
	if not _assert(deepseek != null and not deepseek.models.is_empty(), "deepseek models"):
		return false
	cfg.set_many({
		"default_temperature": 0.2,
		"default_top_p": 0.8,
		"default_max_tokens": 1024,
		"default_presence_penalty": 0.1,
		"default_frequency_penalty": 0.2,
		"default_json_mode": true
	})
	model_manager.set_current_model(deepseek.id, deepseek.models[0].id)
	var messages: Array[Dictionary] = [{"role": "user", "content": "hello"}]
	var context: Dictionary = api._build_request_context(messages, {}, false)
	model_manager.set_current_model(original_supplier, original_model)
	var body = JSON.parse_string(context.get("body", "{}"))
	return _assert(context.get("url", "").ends_with("/v1/chat/completions"), "openai compatible endpoint") \
		and _assert(body is Dictionary and body.get("temperature", 0.0) == 0.2, "temperature option") \
		and _assert(body.get("top_p", 0.0) == 0.8, "top_p option") \
		and _assert(body.get("response_format", {}).get("type", "") == "json_object", "json mode option")

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
	var import_result: Dictionary = manager.import_skill_zip("res://missing_skill.zip")
	return _assert(manager.skills.size() >= 1, "default skills") \
		and _assert(prompt.contains("extends Node"), "skill prompt render") \
		and _assert(not import_result.get("success", true), "missing skill zip reports failure")

func _test_workspace_tools() -> bool:
	var manager = SingletonScript.get_instance().get("workspace_tool_manager")
	var write_result: Dictionary = manager.write_file("res://addons/gogent/config/workspace_tool_test.tmp", "hello workspace")
	var read_result: Dictionary = manager.read_file("res://addons/gogent/config/workspace_tool_test.tmp")
	var search_result: Dictionary = manager.search_text("hello workspace", "res://addons/gogent/config", 10)
	return _assert(write_result.get("success", false), "workspace write file") \
		and _assert(read_result.get("content", "") == "hello workspace", "workspace read file") \
		and _assert(search_result.get("matches", []).size() >= 1, "workspace search text")

func _test_conversation_history() -> bool:
	var manager = SingletonScript.get_instance().get("conversation_manager")
	var id: String = manager.new_conversation("测试对话")
	manager.add_message("user", "hello")
	manager.add_message("assistant", "world")
	var listed := false
	for item in manager.list_conversations():
		if item.get("id", "") == id:
			listed = true
			break
	var loaded: bool = manager.load_conversation(id)
	return _assert(listed, "conversation listed") \
		and _assert(loaded, "conversation loaded") \
		and _assert(manager.messages.size() == 2, "conversation messages")

func _test_training() -> bool:
	var manager = SingletonScript.get_instance().get("training_manager")
	manager.record_human_feedback([0.0, 0.0, 0.0, 0.0], 1, 2.5, [0.1, 0.0, 0.0, 0.0], false, "test")
	manager.start_training({"episodes": 3, "max_steps_per_episode": 4, "save_interval": 0})
	while manager.state == TrainingManagerScript.TrainingState.RUNNING:
		await process_frame
	manager.record_human_feedback([0.0, 0.0, 0.0, 0.0], 2, 1.5, [0.2, 0.0, 0.0, 0.0], true, "post train")
	return _assert(manager.stats.episode == 3, "training episodes") \
		and _assert(manager.visualizer.get_statistics().has("Reward"), "training chart data") \
		and _assert(manager.human_feedback.size() == 1, "human feedback recorded") \
		and _assert(manager.get_stats_dict().get("human_feedback_count", 0) == 1, "human feedback stats")

func _test_console() -> bool:
	var console = SingletonScript.get_instance().get("console_manager")
	var text = console.execute_command("list_models")
	var external_status = console.execute_command("external_status")
	var feedback_status = console.execute_command("feedback [0,0,0,0] 1 1.25 [0,0,0,1] true console_test")
	var ai_settings = console.execute_command("ai_settings")
	var set_ai_option = console.execute_command("set_ai_option temperature 0.55")
	var list_files = console.execute_command("list_files res://addons/gogent/core")
	var read_file = console.execute_command("read_file res://project.godot")
	return _assert(text.contains("Models:"), "console list_models") \
		and _assert(external_status.contains("External tools:"), "console external_status") \
		and _assert(feedback_status.contains("Human feedback recorded"), "console feedback") \
		and _assert(ai_settings.contains("temperature"), "console ai_settings") \
		and _assert(set_ai_option.contains("default_temperature"), "console set_ai_option") \
		and _assert(list_files.contains("files"), "console list_files") \
		and _assert(read_file.contains("config/name"), "console read_file")

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
