extends Node3D

## projectM rendering resolution (start at 1024, can increase to 2048 if perf allows)
const PM_WIDTH := 1024
const PM_HEIGHT := 1024

## PCM samples to feed projectM per frame (512 is projectM's typical expectation)
const PCM_FRAMES := 512

var _pm: ProjectMWrapper
var _dome_material: ShaderMaterial
var _initialized: bool = false
var _current_preset_path: String = ""
func _ready() -> void:
	call_deferred("_initialize")

func _initialize() -> void:
	_pm = ProjectMWrapper.new()
	add_child(_pm)

	if not _pm.initialize(PM_WIDTH, PM_HEIGHT):
		push_error("[Milkdrop] Failed to initialize projectM")
		return

	_initialized = true
	print("[Milkdrop] projectM initialized at %dx%d" % [PM_WIDTH, PM_HEIGHT])

	# Set up dome display
	_dome_material = $MilkdropDome.material_override
	# Load default preset if available
	_load_default_preset()

func _load_default_preset() -> void:
	# Prefer spectacular presets with per-pixel shaders over basic test presets
	var preferred := [
		"Geiss - Cosmic Dust 2.milk",
		"Flexi - smashing fractals 2-0.milk",
		"Aderrasi - Bow To Gravity.milk",
	]
	for preset_name in preferred:
		var preset_path: String = "res://presets/" + preset_name
		if FileAccess.file_exists(preset_path):
			load_preset(preset_path)
			return
	# Fallback: first .milk file found
	var dir := DirAccess.open("res://presets")
	if dir == null:
		push_warning("[Milkdrop] No presets/ directory found")
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".milk"):
			var fallback_path: String = "res://presets/" + file_name
			load_preset(fallback_path)
			break
		file_name = dir.get_next()

func load_preset(path: String) -> void:
	if not _initialized:
		return
	if _pm.load_preset(path):
		_current_preset_path = path
		print("[Milkdrop] Loaded preset: %s" % path)
	else:
		push_warning("[Milkdrop] Failed to load preset: %s" % path)

func _process(_delta: float) -> void:
	if not _initialized:
		return

	# Feed audio PCM to projectM
	var pcm := AudioManager.get_pcm_buffer(PCM_FRAMES)
	if pcm.size() > 0:
		_pm.feed_audio(pcm)
		# Debug: log audio level every 60 frames
		if Engine.get_frames_drawn() % 60 == 0:
			var peak := 0.0
			for i in range(min(pcm.size(), 100)):
				peak = max(peak, abs(pcm[i]))
			print("[Milkdrop] Audio: %d samples, peak=%.4f" % [pcm.size(), peak])

	# Render frame and update dome texture
	_pm.render_frame()
	var tex := _pm.get_texture()
	if tex != null:
		_dome_material.set_shader_parameter("milkdrop_texture", tex)

	# Brightness scales with audio energy (same pattern as Phase 4)
	var energy_val: float = 0.0
	if AudioManager.audio_data != null and AudioManager.has_signal:
		energy_val = AudioManager.audio_data.energy
	_dome_material.set_shader_parameter("brightness", 1.5 + energy_val * 1.0)

func _exit_tree() -> void:
	if _pm != null and _initialized:
		_pm.shutdown()
