@tool
class_name GoGentModelManager
extends RefCounted

const MODELS_FILE := "res://addons/gogent/config/models.json"

class ModelInfo:
	var id := ""
	var name := ""
	var model_name := ""
	var supports_thinking := false
	var supports_tools := true
	var supports_vision := false
	var max_tokens := 8192
	var active := true
	var supplier_id := ""

	func _init(p_id: String = "", p_name: String = "", p_model_name: String = "") -> void:
		id = p_id if not p_id.is_empty() else _new_id("model")
		name = p_name
		model_name = p_model_name

	static func _new_id(prefix: String) -> String:
		return "%s_%d_%d" % [prefix, Time.get_unix_time_from_system(), randi()]

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"model_name": model_name,
			"supports_thinking": supports_thinking,
			"supports_tools": supports_tools,
			"supports_vision": supports_vision,
			"max_tokens": max_tokens,
			"active": active,
			"supplier_id": supplier_id
		}

	static func from_dict(data: Dictionary) -> ModelInfo:
		var model := ModelInfo.new(data.get("id", ""), data.get("name", ""), data.get("model_name", ""))
		model.supports_thinking = data.get("supports_thinking", false)
		model.supports_tools = data.get("supports_tools", true)
		model.supports_vision = data.get("supports_vision", false)
		model.max_tokens = int(data.get("max_tokens", 8192))
		model.active = data.get("active", true)
		model.supplier_id = data.get("supplier_id", "")
		return model

class SupplierInfo:
	var id := ""
	var name := ""
	var base_url := ""
	var api_key := ""
	var provider := "openai"
	var models: Array[ModelInfo] = []

	func _init(p_id: String = "", p_name: String = "", p_base_url: String = "", p_provider: String = "openai") -> void:
		id = p_id if not p_id.is_empty() else _new_id("supplier")
		name = p_name
		base_url = p_base_url
		provider = p_provider

	static func _new_id(prefix: String) -> String:
		return "%s_%d_%d" % [prefix, Time.get_unix_time_from_system(), randi()]

	func to_dict() -> Dictionary:
		var model_data: Array = []
		for model in models:
			model_data.append(model.to_dict())
		return {
			"id": id,
			"name": name,
			"base_url": base_url,
			"api_key": api_key,
			"provider": provider,
			"models": model_data
		}

	static func from_dict(data: Dictionary) -> SupplierInfo:
		var supplier := SupplierInfo.new(data.get("id", ""), data.get("name", ""), data.get("base_url", ""), data.get("provider", "openai"))
		supplier.api_key = data.get("api_key", "")
		for item in data.get("models", []):
			if item is Dictionary:
				var model := ModelInfo.from_dict(item)
				model.supplier_id = supplier.id
				supplier.models.append(model)
		return supplier

var suppliers: Array[SupplierInfo] = []
var current_supplier_id := ""
var current_model_id := ""

func _init() -> void:
	_ensure_dir()
	load_models()
	if suppliers.is_empty():
		add_default_suppliers()
	else:
		_ensure_builtin_suppliers()
	_validate_current_selection()

func _ensure_dir() -> void:
	var dir := MODELS_FILE.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

func add_default_suppliers() -> void:
	suppliers.clear()
	var deepseek := _make_supplier("deepseek", "DeepSeek", "https://api.deepseek.com", "deepseek")
	_add_model(deepseek, "deepseek-chat", "DeepSeek Chat", 65536, false, true, false)
	_add_model(deepseek, "deepseek-reasoner", "DeepSeek Reasoner", 65536, true, true, false)

	var openai := _make_supplier("openai", "OpenAI", "https://api.openai.com", "openai")
	_add_model(openai, "gpt-4o", "GPT-4o", 16384, false, true, true)
	_add_model(openai, "gpt-4o-mini", "GPT-4o Mini", 16384, false, true, true)

	var anthropic := _make_supplier("anthropic", "Anthropic Claude", "https://api.anthropic.com", "anthropic")
	_add_model(anthropic, "claude-3-5-sonnet-latest", "Claude 3.5 Sonnet", 8192, false, true, true)
	_add_model(anthropic, "claude-3-5-haiku-latest", "Claude 3.5 Haiku", 8192, false, true, true)

	var openrouter := _make_supplier("openrouter", "OpenRouter", "https://openrouter.ai/api", "openai")
	_add_model(openrouter, "anthropic/claude-sonnet-4.5", "Claude Sonnet 4.5", 65536, false, true, true)

	var ollama := _make_supplier("ollama", "Ollama", "http://localhost:11434", "ollama")
	_add_model(ollama, "llama3.1", "Llama 3.1", 8192, false, true, false)

	current_supplier_id = deepseek.id
	current_model_id = deepseek.models[0].id
	save_models()

func _make_supplier(id: String, name: String, base_url: String, provider: String) -> SupplierInfo:
	var supplier := SupplierInfo.new(id, name, base_url, provider)
	suppliers.append(supplier)
	return supplier

func _add_model(supplier: SupplierInfo, model_name: String, display_name: String, max_tokens: int, thinking: bool, tools: bool, vision: bool) -> void:
	var model := ModelInfo.new("%s_%s" % [supplier.id, model_name.replace("/", "_").replace(".", "_")], display_name, model_name)
	model.supplier_id = supplier.id
	model.max_tokens = max_tokens
	model.supports_thinking = thinking
	model.supports_tools = tools
	model.supports_vision = vision
	supplier.models.append(model)

func _ensure_builtin_suppliers() -> void:
	var changed := false
	if get_supplier("anthropic") == null:
		var anthropic := _make_supplier("anthropic", "Anthropic Claude", "https://api.anthropic.com", "anthropic")
		_add_model(anthropic, "claude-3-5-sonnet-latest", "Claude 3.5 Sonnet", 8192, false, true, true)
		_add_model(anthropic, "claude-3-5-haiku-latest", "Claude 3.5 Haiku", 8192, false, true, true)
		changed = true
	if get_supplier("openrouter") == null:
		var openrouter := _make_supplier("openrouter", "OpenRouter", "https://openrouter.ai/api", "openai")
		_add_model(openrouter, "anthropic/claude-sonnet-4.5", "Claude Sonnet 4.5", 65536, false, true, true)
		changed = true
	if changed:
		save_models()

func load_models() -> void:
	if not FileAccess.file_exists(MODELS_FILE):
		return
	var text := FileAccess.get_file_as_string(MODELS_FILE)
	if FileAccess.get_open_error() != OK:
		return
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return
	suppliers.clear()
	current_supplier_id = parsed.get("current_supplier_id", "")
	current_model_id = parsed.get("current_model_id", "")
	for supplier_data in parsed.get("suppliers", parsed.get("supplier", [])):
		if supplier_data is Dictionary:
			suppliers.append(SupplierInfo.from_dict(supplier_data))

func save_models() -> bool:
	_ensure_dir()
	var data := {
		"current_supplier_id": current_supplier_id,
		"current_model_id": current_model_id,
		"suppliers": []
	}
	for supplier in suppliers:
		data["suppliers"].append(supplier.to_dict())
	var file := FileAccess.open(MODELS_FILE, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

func get_current_supplier() -> SupplierInfo:
	_validate_current_selection()
	return get_supplier(current_supplier_id)

func get_current_model() -> ModelInfo:
	_validate_current_selection()
	var supplier := get_supplier(current_supplier_id)
	if supplier == null:
		return null
	for model in supplier.models:
		if model.id == current_model_id:
			return model
	return null

func get_supplier(supplier_id: String) -> SupplierInfo:
	for supplier in suppliers:
		if supplier.id == supplier_id:
			return supplier
	return null

func set_current_model(supplier_id: String, model_id: String) -> bool:
	var supplier := get_supplier(supplier_id)
	if supplier == null:
		return false
	for model in supplier.models:
		if model.id == model_id:
			current_supplier_id = supplier_id
			current_model_id = model_id
			save_models()
			GoGentSingleton.get_instance().models_changed.emit()
			return true
	return false

func set_current_credentials(api_key: String, base_url: String = "") -> void:
	var supplier := get_current_supplier()
	if supplier == null:
		return
	supplier.api_key = api_key
	if not base_url.strip_edges().is_empty():
		supplier.base_url = base_url.strip_edges()
	save_models()

func add_supplier(supplier: SupplierInfo) -> void:
	suppliers.append(supplier)
	_validate_current_selection()
	save_models()
	GoGentSingleton.get_instance().models_changed.emit()

func remove_supplier(supplier_id: String) -> void:
	for i in range(suppliers.size()):
		if suppliers[i].id == supplier_id:
			suppliers.remove_at(i)
			break
	_validate_current_selection()
	save_models()
	GoGentSingleton.get_instance().models_changed.emit()

func add_model(supplier_id: String, model: ModelInfo) -> bool:
	var supplier := get_supplier(supplier_id)
	if supplier == null:
		return false
	model.supplier_id = supplier_id
	supplier.models.append(model)
	_validate_current_selection()
	save_models()
	GoGentSingleton.get_instance().models_changed.emit()
	return true

func remove_model(supplier_id: String, model_id: String) -> void:
	var supplier := get_supplier(supplier_id)
	if supplier == null:
		return
	for i in range(supplier.models.size()):
		if supplier.models[i].id == model_id:
			supplier.models.remove_at(i)
			break
	_validate_current_selection()
	save_models()
	GoGentSingleton.get_instance().models_changed.emit()

func _validate_current_selection() -> void:
	if suppliers.is_empty():
		current_supplier_id = ""
		current_model_id = ""
		return
	var supplier := get_supplier(current_supplier_id)
	if supplier == null:
		supplier = suppliers[0]
		current_supplier_id = supplier.id
	if supplier.models.is_empty():
		current_model_id = ""
		return
	var found := false
	for model in supplier.models:
		if model.id == current_model_id:
			found = true
			break
	if not found:
		current_model_id = supplier.models[0].id
