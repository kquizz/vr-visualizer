extends Node

signal mode_changed(mode_name: String)

## Registry of available modes: name -> scene path
var _modes: Dictionary = {}
## Currently active mode instance
var _active_mode: Node = null
## Container node where modes are placed (set by main.gd after scene tree ready)
var _container: Node3D = null

func _ready() -> void:
	call_deferred("_initialize")

func _initialize() -> void:
	register_mode("spectrum_bars", "res://scenes/modes/spectrum_bars.tscn")

func register_mode(mode_name: String, scene_path: String) -> void:
	_modes[mode_name] = scene_path

func set_container(container: Node3D) -> void:
	_container = container

func switch_to(mode_name: String) -> void:
	if not _modes.has(mode_name):
		push_error("ModeManager: Unknown mode '%s'" % mode_name)
		return
	if _container == null:
		push_error("ModeManager: No container set")
		return

	# Remove current mode
	if _active_mode != null:
		_container.remove_child(_active_mode)
		_active_mode.queue_free()
		_active_mode = null

	# Load and instantiate new mode
	var scene: PackedScene = load(_modes[mode_name])
	_active_mode = scene.instantiate()
	_container.add_child(_active_mode)
	mode_changed.emit(mode_name)
	print("ModeManager: switched to %s" % mode_name)

func get_active_mode_name() -> String:
	if _active_mode == null:
		return ""
	for key in _modes:
		if _active_mode.scene_file_path == _modes[key]:
			return key
	return ""
