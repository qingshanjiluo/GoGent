@tool
class_name GoGentPlugin
extends EditorPlugin

const PLUGIN_DIR := "res://addons/gogent/"
const CONFIG_DIR := "res://addons/gogent/config/"
const MAIN_PANEL_SCENE := preload("res://addons/gogent/ui/main_panel.tscn")

var _main_panel: Control
var _debug_overlay: GoGentDebugOverlay

func _enter_tree() -> void:
	print_rich("[color=#42ffc2]=== GoGent loading ===[/color]")
	_ensure_config_dir()
	var singleton := GoGentSingleton.get_instance()
	singleton.set_editor_plugin(self)
	singleton.load_all_configs()
	_main_panel = MAIN_PANEL_SCENE.instantiate()
	_main_panel.name = "GoGent"
	singleton.set_main_panel(_main_panel)
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, _main_panel)
	if _main_panel.has_method("refresh_from_managers"):
		_main_panel.call_deferred("refresh_from_managers")
	_init_debug_overlay()
	print_rich("[color=#42ffc2]=== GoGent ready ===[/color]")

func _exit_tree() -> void:
	var singleton := GoGentSingleton.get_instance()
	_remove_debug_overlay()
	if _main_panel != null:
		remove_control_from_docks(_main_panel)
		_main_panel.queue_free()
		_main_panel = null
	singleton.set_main_panel(null)
	singleton.set_editor_plugin(null)

func _ensure_config_dir() -> void:
	if not DirAccess.dir_exists_absolute(CONFIG_DIR):
		DirAccess.make_dir_recursive_absolute(CONFIG_DIR)

func _init_debug_overlay() -> void:
	if _debug_overlay != null and is_instance_valid(_debug_overlay):
		return
	_debug_overlay = GoGentDebugOverlay.new()
	_debug_overlay.name = "GoGentDebugOverlay"
	var root := get_tree().root if get_tree() else null
	if root != null:
		root.add_child.call_deferred(_debug_overlay)

func _remove_debug_overlay() -> void:
	if _debug_overlay != null and is_instance_valid(_debug_overlay):
		_debug_overlay.queue_free()
	_debug_overlay = null

static func get_plugin_dir() -> String:
	return PLUGIN_DIR

static func print_gogent(message: String, color: String = "#abc9ff") -> void:
	print_rich("[color=%s]%s[/color]" % [color, message])
