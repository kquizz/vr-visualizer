extends Node3D

## PresetBrowser — floating VR panel for browsing and loading presets
## Attach to a Node3D that has:
##   - SubViewport (child)
##   - MeshInstance3D with QuadMesh (child, for display)
##   - PanelContainer > HBoxContainer > (CategoryList VBoxContainer, PresetList VBoxContainer)

signal preset_selected(path: String)

const ITEM_HEIGHT := 48
const VISIBLE_ROWS := 14
const SCROLL_ACCEL_THRESHOLD := 0.5  # stick magnitude for fast scroll

## Panel dimensions in world units
const PANEL_WIDTH := 1.6
const PANEL_HEIGHT := 1.0

## Colors
const COLOR_SELECTED := Color(0.3, 0.6, 1.0, 1.0)
const COLOR_NORMAL := Color(0.9, 0.9, 0.9, 1.0)
const COLOR_FAVORITE := Color(1.0, 0.85, 0.2, 1.0)
const COLOR_BG := Color(0.05, 0.05, 0.12, 0.95)

## Focus: 0 = left (categories), 1 = right (presets)
var _focus_col: int = 0
var _cat_index: int = 0
var _preset_index: int = 0
var _cat_scroll: int = 0
var _preset_scroll: int = 0

var _category_items: Array = []
var _preset_items: Array = []

var _stick_cooldown: float = 0.0
const STICK_REPEAT_DELAY := 0.18

# Node references (set up in _ready)
var _viewport: SubViewport
var _quad: MeshInstance3D
var _cat_container: VBoxContainer
var _preset_container: VBoxContainer
var _header_label: Label
var _toast_label: Label
var _toast_timer: float = 0.0

func _ready() -> void:
	visible = false
	_build_ui()
	PresetLibrary.scan_complete.connect(_on_scan_complete)
	PresetLibrary.favorites_changed.connect(_refresh_preset_list)
	if PresetLibrary.category_names.size() > 0:
		_on_scan_complete()

func _build_ui() -> void:
	# SubViewport
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1024, 640)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	# Root panel
	var root := PanelContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_stylebox_override("panel", _make_panel_style())
	_viewport.add_child(root)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(vbox)

	# Header
	_header_label = Label.new()
	_header_label.text = "PRESET BROWSER"
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	_header_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(_header_label)

	# Divider
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.3, 0.3, 0.5))
	vbox.add_child(sep)

	# Columns
	var hbox := HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	# Category column
	var cat_panel := PanelContainer.new()
	cat_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cat_panel.custom_minimum_size = Vector2(300, 0)
	cat_panel.add_theme_stylebox_override("panel", _make_column_style())
	hbox.add_child(cat_panel)
	var cat_scroll := ScrollContainer.new()
	cat_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	cat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cat_panel.add_child(cat_scroll)
	_cat_container = VBoxContainer.new()
	_cat_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cat_scroll.add_child(_cat_container)

	# Vertical separator
	var vsep := VSeparator.new()
	vsep.add_theme_color_override("color", Color(0.3, 0.3, 0.5))
	hbox.add_child(vsep)

	# Preset column
	var preset_panel := PanelContainer.new()
	preset_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_panel.add_theme_stylebox_override("panel", _make_column_style())
	hbox.add_child(preset_panel)
	var preset_scroll := ScrollContainer.new()
	preset_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	preset_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	preset_panel.add_child(preset_scroll)
	_preset_container = VBoxContainer.new()
	_preset_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_scroll.add_child(_preset_container)

	# Toast (bottom bar)
	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_toast_label.add_theme_font_size_override("font_size", 16)
	_toast_label.text = "A=Favorite  Trigger=Load  Stick=Navigate  Menu=Close"
	vbox.add_child(_toast_label)

	# 3D quad for displaying the viewport
	_quad = MeshInstance3D.new()
	var quad_mesh := QuadMesh.new()
	quad_mesh.size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	_quad.mesh = quad_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _viewport.get_texture()
	mat.flags_unshaded = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_quad.material_override = mat
	add_child(_quad)

func _make_panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = COLOR_BG
	s.border_color = Color(0.3, 0.4, 0.7)
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	return s

func _make_column_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	return s

func _on_scan_complete() -> void:
	_rebuild_category_list()
	_rebuild_preset_list()

func _rebuild_category_list() -> void:
	for child in _cat_container.get_children():
		child.queue_free()
	_category_items.clear()

	# "Favorites" always first
	var all_cats := ["★ Favorites"] + PresetLibrary.category_names
	for i in range(all_cats.size()):
		var cat := all_cats[i]
		var lbl := _make_list_item(cat, i == _cat_index and _focus_col == 0)
		_cat_container.add_child(lbl)
		_category_items.append(lbl)

func _rebuild_preset_list() -> void:
	for child in _preset_container.get_children():
		child.queue_free()
	_preset_items.clear()

	var presets := _get_current_presets()
	_preset_index = clamp(_preset_index, 0, max(0, presets.size() - 1))

	for i in range(presets.size()):
		var path := presets[i]
		var name := PresetLibrary.preset_display_name(path)
		var is_fav := PresetLibrary.is_favorite(path)
		var text := ("★ " if is_fav else "  ") + name
		var selected := (i == _preset_index and _focus_col == 1)
		var lbl := _make_list_item(text, selected)
		if is_fav:
			lbl.add_theme_color_override("font_color", COLOR_FAVORITE)
		_preset_container.add_child(lbl)
		_preset_items.append(lbl)

func _make_list_item(text: String, selected: bool) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.clip_text = true
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.custom_minimum_size = Vector2(0, ITEM_HEIGHT)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 15)
	if selected:
		lbl.add_theme_color_override("font_color", COLOR_SELECTED)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.15, 0.25, 0.5, 0.8)
		bg.set_corner_radius_all(4)
		lbl.add_theme_stylebox_override("normal", bg)
	else:
		lbl.add_theme_color_override("font_color", COLOR_NORMAL)
	return lbl

func _get_current_presets() -> Array[String]:
	var all_cats := ["★ Favorites"] + PresetLibrary.category_names
	if _cat_index >= all_cats.size():
		return []
	var cat := all_cats[_cat_index]
	if cat == "★ Favorites":
		return PresetLibrary.get_favorites_category()
	return PresetLibrary.get_presets_in_category(cat)

## --- Public API ---

func open(camera_transform: Transform3D) -> void:
	visible = true
	# Float 1.5m in front of camera, at eye height
	var forward := -camera_transform.basis.z
	var pos := camera_transform.origin + forward * 1.5
	pos.y = camera_transform.origin.y  # same height as eyes
	global_transform.origin = pos
	# Face the camera
	look_at(camera_transform.origin, Vector3.UP)
	# Flip 180 so panel faces camera (look_at makes -Z point at target)
	rotate_object_local(Vector3.UP, PI)

func close() -> void:
	visible = false

func is_open() -> bool:
	return visible

## Called by controller manager each frame when browser is open
func handle_stick(stick: Vector2, delta: float) -> void:
	_stick_cooldown -= delta
	if _stick_cooldown > 0.0:
		return

	var threshold := 0.4
	var moved := false

	if abs(stick.x) > threshold:
		# Horizontal: switch columns
		var new_col := 1 if stick.x > 0.0 else 0
		if new_col != _focus_col:
			_focus_col = new_col
			moved = true
			_refresh_lists()
	elif abs(stick.y) > threshold:
		# Vertical: scroll current column
		var dir := -1 if stick.y > 0.0 else 1
		if _focus_col == 0:
			_move_cat(dir)
		else:
			_move_preset(dir)
		moved = true

	if moved:
		var speed_factor := 2.0 if abs(stick.y) > SCROLL_ACCEL_THRESHOLD or abs(stick.x) > SCROLL_ACCEL_THRESHOLD else 1.0
		_stick_cooldown = STICK_REPEAT_DELAY / speed_factor

func _move_cat(dir: int) -> void:
	var all_cats := ["★ Favorites"] + PresetLibrary.category_names
	_cat_index = clamp(_cat_index + dir, 0, all_cats.size() - 1)
	_preset_index = 0
	_refresh_lists()

func _move_preset(dir: int) -> void:
	var presets := _get_current_presets()
	_preset_index = clamp(_preset_index + dir, 0, max(0, presets.size() - 1))
	_refresh_preset_list()

func _refresh_lists() -> void:
	_rebuild_category_list()
	_rebuild_preset_list()

func _refresh_preset_list() -> void:
	_rebuild_preset_list()

## Trigger pressed — load the selected preset
func select_current() -> void:
	var presets := _get_current_presets()
	if _preset_index < presets.size():
		emit_signal("preset_selected", presets[_preset_index])

## A button — toggle favorite on selected preset
func toggle_favorite_current() -> void:
	var presets := _get_current_presets()
	if _preset_index < presets.size():
		PresetLibrary.toggle_favorite(presets[_preset_index])
		_refresh_preset_list()

## Returns name of currently highlighted preset
func current_preset_name() -> String:
	var presets := _get_current_presets()
	if _preset_index < presets.size():
		return PresetLibrary.preset_display_name(presets[_preset_index])
	return ""

func show_toast(text: String, duration: float = 2.0) -> void:
	_toast_label.text = text
	_toast_timer = duration

func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_toast_label.text = "A=Favorite  Trigger=Load  Stick=Navigate  Menu=Close"
