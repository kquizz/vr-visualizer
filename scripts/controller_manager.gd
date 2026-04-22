extends Node3D

## ControllerManager — handles XR controller input for the preset browser and favorites cycling
## Lives in VRScene. Spawns PresetBrowser, routes input.

const BROWSER_SCENE := "res://scenes/preset_browser.gd"

var _browser: Node3D
var _left_controller: XRController3D
var _right_controller: XRController3D
var _camera: XRCamera3D
var _fallback_camera: Camera3D

## Favorite cycling state
var _fav_index: int = 0

func _ready() -> void:
	call_deferred("_setup")

func _setup() -> void:
	# Find XR nodes
	var origin := get_node_or_null("../XROrigin3D")
	if origin:
		_camera = origin.get_node_or_null("XRCamera3D")
		_left_controller = origin.get_node_or_null("LeftController")
		_right_controller = origin.get_node_or_null("RightController")

		if _left_controller:
			_left_controller.button_pressed.connect(_on_button_pressed.bind("left"))
			_left_controller.button_released.connect(_on_button_released.bind("left"))
		if _right_controller:
			_right_controller.button_pressed.connect(_on_button_pressed.bind("right"))
			_right_controller.button_released.connect(_on_button_released.bind("right"))

	_fallback_camera = get_node_or_null("../FallbackCamera3D")

	# Spawn preset browser
	_browser = load("res://scenes/preset_browser.gd").new()
	get_parent().add_child(_browser)
	_browser.preset_selected.connect(_on_preset_selected)

	print("[ControllerManager] Ready. Browser spawned.")

func _get_camera_transform() -> Transform3D:
	if _camera and _camera.is_inside_tree():
		return _camera.global_transform
	if _fallback_camera and _fallback_camera.is_inside_tree():
		return _fallback_camera.global_transform
	return Transform3D.IDENTITY

## --- XR Button Handling ---

func _on_button_pressed(button_name: String, hand: String) -> void:
	match button_name:
		"menu_button":
			_toggle_browser()
		"ax_button":
			# A (right) or X (left) → toggle favorite in browser
			if _browser.is_open():
				var preset_name := _browser.current_preset_name()
				_browser.toggle_favorite_current()
				if preset_name != "":
					_browser.show_toast("★ " + preset_name)
		"by_button":
			# B (right) or Y (left) → cycle favorites when browser closed
			if not _browser.is_open():
				_cycle_favorite(1)
		"trigger_click":
			if _browser.is_open():
				_browser.select_current()

func _on_button_released(_button_name: String, _hand: String) -> void:
	pass

func _toggle_browser() -> void:
	if _browser.is_open():
		_browser.close()
	else:
		_browser.open(_get_camera_transform())

## --- Favorite Cycling ---

func _cycle_favorite(dir: int) -> void:
	var favs := PresetLibrary.get_favorites_category()
	if favs.is_empty():
		return
	_fav_index = (_fav_index + dir) % favs.size()
	var path := favs[_fav_index]
	_load_preset(path)
	_show_cycling_toast(path)

func _show_cycling_toast(path: String) -> void:
	var name := PresetLibrary.preset_display_name(path)
	var favs := PresetLibrary.get_favorites_category()
	_browser.show_toast("♪ %d/%d  %s" % [_fav_index + 1, favs.size(), name])

## --- Preset Loading ---

func _on_preset_selected(path: String) -> void:
	_load_preset(path)
	var name := PresetLibrary.preset_display_name(path)
	_browser.show_toast("Loading: " + name)
	_browser.close()

func _load_preset(path: String) -> void:
	var mode_scene := ModeManager.get_active_scene()
	if mode_scene == null:
		push_warning("[ControllerManager] No active scene to load preset into")
		return
	if mode_scene.has_method("load_preset"):
		mode_scene.load_preset(path)
	else:
		push_warning("[ControllerManager] Active mode has no load_preset method")

## --- Stick Input (polled each frame) ---

func _process(delta: float) -> void:
	if not _browser.is_open():
		return

	var stick := Vector2.ZERO
	if _right_controller:
		stick = Vector2(
			_right_controller.get_float("primary/x"),
			_right_controller.get_float("primary/y")
		)
	elif _left_controller:
		stick = Vector2(
			_left_controller.get_float("primary/x"),
			_left_controller.get_float("primary/y")
		)

	if stick.length() > 0.2:
		_browser.handle_stick(stick, delta)

## --- Keyboard Fallback (macOS / testing) ---

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_P:
			_toggle_browser()
		KEY_ENTER:
			if _browser.is_open():
				_browser.select_current()
		KEY_F:
			if _browser.is_open():
				var preset_name := _browser.current_preset_name()
				_browser.toggle_favorite_current()
				if preset_name != "":
					_browser.show_toast("★ " + preset_name)
		KEY_N:
			if not _browser.is_open():
				_cycle_favorite(1)
		KEY_B:
			if not _browser.is_open():
				_cycle_favorite(-1)
		KEY_UP:
			if _browser.is_open():
				_browser.handle_stick(Vector2(0, 1), 0.2)
		KEY_DOWN:
			if _browser.is_open():
				_browser.handle_stick(Vector2(0, -1), 0.2)
		KEY_LEFT:
			if _browser.is_open():
				_browser.handle_stick(Vector2(-1, 0), 0.2)
		KEY_RIGHT:
			if _browser.is_open():
				_browser.handle_stick(Vector2(1, 0), 0.2)
