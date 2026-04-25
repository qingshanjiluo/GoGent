@tool
class_name GoGentModelManager
extends RefCounted

## 模型配置管理器
## 管理多个 AI 模型的配置（参考 AlphaAgent 的 ModelConfig）

const MODELS_FILE: String = "res://addons/gogent/config/models.json"

# 供应商信息
class SupplierInfo:
	var id: String = ""
	var name: String = ""
	var base_url: String = ""
	var api_key: String = ""
	var provider: String = "openai"  # openai, deepseek, gemini, ollama, claude
	var models: Array = []
	
	func _init(s_id: String = "", s_name: String = "", s_api_base: String = "", s_api_key: String = ""):
		id = s_id if s_id != "" else _generate_id()
		name = s_name
		base_url = s_api_base
		api_key = s_api_key
		models = []
	
	func _generate_id() -> String:
		return str(Time.get_unix_time_from_system()) + "_" + str(randi())
	
	func to_dict() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"base_url": base_url,
			"api_key": api_key,
			"provider": provider,
			"models": models.map(func(m): return m.to_dict())
		}
	
	static func from_dict(data: Dictionary) -> SupplierInfo:
		var info = SupplierInfo.new()
		info.id = data.get("id", "")
		info.name = data.get("name", "")
		info.base_url = data.get("base_url", "")
		info.api_key = data.get("api_key", "")
		info.provider = data.get("provider", "openai")
		info.models = data.get("models", []).map(func(m): return ModelInfo.from_dict(m))
		return info

# 模型信息
class ModelInfo:
	var id: String = ""
	var name: String = ""
	var model_name: String = ""
	var supports_thinking: bool = false
	var supports_tools: bool = true
	var supports_vision: bool = false
	var max_tokens: int = 8192
	var active: bool = false
	var supplier_id: String = ""
	
	func _init(p_id: String = "", p_name: String = "", p_model_name: String = "", p_active: bool = true):
		id = p_id if p_id != "" else _generate_id()
		name = p_name
		model_name = p_model_name
		active = p_active
	
	func _generate_id() -> String:
		return str(Time.get_unix_time_from_system()) + "_" + str(randi())
	
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
		var info = ModelInfo.new()
		info.id = data.get("id", "")
		info.name = data.get("name", "")
		info.model_name = data.get("model_name", "")
		info.supports_thinking = data.get("supports_thinking", false)
		info.supports_tools = data.get("supports_tools", true)
		info.supports_vision = data.get("supports_vision", false)
		info.max_tokens = data.get("max_tokens", 8192)
		info.active = data.get("active", false)
		info.supplier_id = data.get("supplier_id", "")
		return info

# 模型管理器
var suppliers: Array[SupplierInfo] = []
var current_supplier_id: String = ""
var current_model_id: String = ""

func _init() -> void:
	_ensure_config_dir()
	load_models()
	if suppliers.is_empty():
		add_default_suppliers()

func _ensure_config_dir() -> void:
	var dir_path = MODELS_FILE.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

func add_default_suppliers() -> void:
	# OpenAI
	var openai = SupplierInfo.new()
	openai.name = "OpenAI"
	openai.base_url = "https://api.openai.com"
	openai.provider = "openai"
	suppliers.append(openai)
	
	var gpt4o = ModelInfo.new()
	gpt4o.name = "GPT-4o"
	gpt4o.model_name = "gpt-4o"
	gpt4o.supports_vision = true
	gpt4o.supports_tools = true
	gpt4o.max_tokens = 16384
	gpt4o.supplier_id = openai.id
	openai.models.append(gpt4o)
	
	# DeepSeek
	var deepseek = SupplierInfo.new()
	deepseek.name = "DeepSeek"
	deepseek.base_url = "https://api.deepseek.com"
	deepseek.provider = "deepseek"
	suppliers.append(deepseek)
	
	var ds_chat = ModelInfo.new()
	ds_chat.name = "DeepSeek Chat"
	ds_chat.model_name = "deepseek-chat"
	ds_chat.supports_tools = true
	ds_chat.max_tokens = 65536
	ds_chat.supplier_id = deepseek.id
	deepseek.models.append(ds_chat)
	
	var ds_reasoner = ModelInfo.new()
	ds_reasoner.name = "DeepSeek Reasoner"
	ds_reasoner.model_name = "deepseek-reasoner"
	ds_reasoner.supports_thinking = true
	ds_reasoner.supports_tools = true
	ds_reasoner.max_tokens = 65536
	ds_reasoner.supplier_id = deepseek.id
	deepseek.models.append(ds_reasoner)
	
	# Claude (通过 OpenRouter)
	var openrouter = SupplierInfo.new()
	openrouter.name = "OpenRouter"
	openrouter.base_url = "https://openrouter.ai/api"
	openrouter.provider = "openai"
	suppliers.append(openrouter)
	
	var claude = ModelInfo.new()
	claude.name = "Claude Sonnet 4.5"
	claude.model_name = "anthropic/claude-sonnet-4.5"
	claude.supports_tools = true
	claude.max_tokens = 65536
	claude.supplier_id = openrouter.id
	openrouter.models.append(claude)
	
	# Ollama (本地)
	var ollama = SupplierInfo.new()
	ollama.name = "Ollama"
	ollama.base_url = "http://localhost:11434"
	ollama.provider = "ollama"
	suppliers.append(ollama)
	
	# 设置默认
	current_supplier_id = deepseek.id
	current_model_id = ds_chat.id
	
	save_models()
	GoGentPlugin.print_gogent("已添加 {0} 个默认供应商".format([suppliers.size()]), "#42ffc2")

func load_models() -> void:
	var file_content = FileAccess.get_file_as_string(MODELS_FILE)
	if FileAccess.get_open_error() != OK:
		return
	
	var json = JSON.parse_string(file_content)
	if json == null:
		return
	
	current_model_id = json.get("current_model_id", "")
	current_supplier_id = json.get("current_supplier_id", "")
	var suppliers_data = json.get("supplier", [])
	
	suppliers.clear()
	for supplier_data in suppliers_data:
		suppliers.append(SupplierInfo.from_dict(supplier_data))

func save_models() -> void:
	var data = {
		"current_supplier_id": current_supplier_id,
		"current_model_id": current_model_id,
		"supplier": suppliers.map(func(m): return m.to_dict())
	}
	
	var file = FileAccess.open(MODELS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func get_current_supplier() -> SupplierInfo:
	for supplier in suppliers:
		if supplier.id == current_supplier_id:
			return supplier
	return null

func get_current_model() -> ModelInfo:
	var supplier = get_current_supplier()
	if supplier != null:
		for model in supplier.models:
			if model.id == current_model_id:
				return model
		if not supplier.models.is_empty():
			current_model_id = supplier.models[0].id
			return supplier.models[0]
	elif not suppliers.is_empty():
		current_supplier_id = suppliers[0].id
		if not suppliers[0].models.is_empty():
			current_model_id = suppliers[0].models[0].id
			return suppliers[0].models[0]
	return null

func set_current_model(supplier_id: String, model_id: String) -> void:
	current_supplier_id = supplier_id
	current_model_id = model_id
	save_models()

func add_supplier(supplier: SupplierInfo) -> void:
	suppliers.append(supplier)
	save_models()

func remove_supplier(supplier_id: String) -> void:
	for i in range(suppliers.size()):
		if suppliers[i].id == supplier_id:
			suppliers.remove_at(i)
			break
	save_models()

func add_model(supplier_id: String, model: ModelInfo) -> void:
	var supplier = _get_supplier_by_id(supplier_id)
	if supplier:
		supplier.models.append(model)
		save_models()

func remove_model(supplier_id: String, model_id: String) -> void:
	var supplier = _get_supplier_by_id(supplier_id)
	if supplier:
		for i in range(supplier.models.size()):
			if supplier.models[i].id == model_id:
				supplier.models.remove_at(i)
				if current_model_id == model_id and not supplier.models.is_empty():
					current_model_id = supplier.models[0].id
				save_models()
				return

func _get_supplier_by_id(supplier_id: String) -> SupplierInfo:
	for supplier in suppliers:
		if supplier.id == supplier_id:
			return supplier
	return null
