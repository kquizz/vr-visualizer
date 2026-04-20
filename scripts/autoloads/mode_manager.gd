extends Node

signal mode_changed(mode_name: String)

## Registry of available modes: name -> scene path
var _modes: Dictionary = {}
## Currently active mode instance
var _active_mode: Node = null
## Container node where modes are placed (set by main.gd after scene tree ready)
var _container: Node3D = null
## Fade overlay for mode transitions
var _fade_overlay: ColorRect = null
## Prevents double-switches during fade
var _is_switching: bool = false

func _ready() -> void:
	call_deferred("_initialize")

func _initialize() -> void:
	register_mode("spectrum_bars", "res://scenes/modes/spectrum_bars.tscn")
	register_mode("warp", "res://scenes/modes/warp.tscn")

func register_mode(mode_name: String, scene_path: String) -> void:
	_modes[mode_name] = scene_path

func set_container(container: Node3D) -> void:
	_container = container

func get_mode_names() -> Array[String]:
	var names: Array[String] = []
	for key in _modes:
		names.append(key)
	return names

func switch_to(mode_name: String) -> void:
	if not _modes.has(mode_name):
		push_error("ModeManager: Unknown mode '%s'" % mode_name)
		return
	if _container == null:
		push_error("ModeManager: No container set")
		return
	if _is_switching:
		return

	_is_switching = true

	if _active_mode != null:
		# Fade transition for mode switch
		await _fade_switch(mode_name)
	else:
		# First load -- instant switch, no fade needed
		_do_switch(mode_name)
		_is_switching = false

func _fade_switch(mode_name: String) -> void:
	# Create full-screen fade overlay
	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 100
	get_tree().root.add_child(canvas_layer)

	_fade_overlay = ColorRect.new()
	_fade_overlay.color = Color.BLACK
	_fade_overlay.modulate.a = 0.0
	_fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(_fade_overlay)

	# Fade to black (0.25s)
	var tween := create_tween()
	tween.tween_property(_fade_overlay, "modulate:a", 1.0, 0.25)
	await tween.finished

	# Swap modes while screen is black
	_do_switch(mode_name)

	# Fade back in (0.25s)
	var tween_in := create_tween()
	tween_in.tween_property(_fade_overlay, "modulate:a", 0.0, 0.25)
	await tween_in.finished

	# Clean up overlay
	canvas_layer.queue_free()
	_fade_overlay = null
	_is_switching = false

func _do_switch(mode_name: String) -> void:
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
