extends Node

## PresetLibrary — scans preset directories and manages favorites
## Autoload singleton: PresetLibrary

const PRESETS_DIR := "res://presets"
const CREAM_DIR := "res://presets/cream-of-the-crop"
const FAVORITES_PATH := "user://favorites.json"

## category_name -> Array[String] of absolute file paths
var categories: Dictionary = {}
## Ordered list of category names for the browser
var category_names: Array[String] = []
## Set of favorited preset paths
var favorites: Array[String] = []

signal scan_complete
signal favorites_changed

func _ready() -> void:
	call_deferred("_scan_and_load")

func _scan_and_load() -> void:
	_scan_presets()
	_load_favorites()
	emit_signal("scan_complete")
	print("[PresetLibrary] Scan complete. %d categories, %d favorites" % [categories.size(), favorites.size()])

## Scan both the root presets/ dir and cream-of-the-crop subfolders
func _scan_presets() -> void:
	categories.clear()
	category_names.clear()

	# Root presets dir (flat .milk files) → "Local" category
	var local_presets: Array[String] = _scan_flat_dir(PRESETS_DIR)
	if local_presets.size() > 0:
		categories["Local"] = local_presets
		category_names.append("Local")

	# Cream-of-the-crop subfolders
	var cream_dir := DirAccess.open(CREAM_DIR)
	if cream_dir == null:
		push_warning("[PresetLibrary] cream-of-the-crop not found at %s" % CREAM_DIR)
		return

	cream_dir.list_dir_begin()
	var entry := cream_dir.get_next()
	var folder_names: Array[String] = []
	while entry != "":
		if cream_dir.current_is_dir() and not entry.begins_with("."):
			folder_names.append(entry)
		entry = cream_dir.get_next()
	cream_dir.list_dir_end()

	folder_names.sort()
	for folder in folder_names:
		var folder_path := CREAM_DIR + "/" + folder
		var presets := _scan_flat_dir(folder_path)
		if presets.size() > 0:
			categories[folder] = presets
			category_names.append(folder)

func _scan_flat_dir(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".milk"):
			result.append(dir_path + "/" + entry)
		entry = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result

func get_presets_in_category(category: String) -> Array[String]:
	if categories.has(category):
		return categories[category]
	return []

func get_favorites_category() -> Array[String]:
	return favorites.duplicate()

## Returns a display name for a preset path (filename without extension)
func preset_display_name(path: String) -> String:
	var base := path.get_file()
	if base.ends_with(".milk"):
		base = base.left(base.length() - 5)
	return base

## --- Favorites ---

func is_favorite(path: String) -> bool:
	return favorites.has(path)

func toggle_favorite(path: String) -> void:
	if favorites.has(path):
		favorites.erase(path)
	else:
		favorites.append(path)
	_save_favorites()
	emit_signal("favorites_changed")

func _save_favorites() -> void:
	var file := FileAccess.open(FAVORITES_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[PresetLibrary] Could not write favorites")
		return
	file.store_string(JSON.stringify(favorites))
	file.close()

func _load_favorites() -> void:
	if not FileAccess.file_exists(FAVORITES_PATH):
		return
	var file := FileAccess.open(FAVORITES_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed is Array:
		favorites.clear()
		for item in parsed:
			if item is String:
				favorites.append(item)
