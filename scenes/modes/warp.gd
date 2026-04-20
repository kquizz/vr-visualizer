extends Node3D

@export_group("Bass Response")
@export_enum("Punchy", "Smooth", "Intensity-Scaled") var bass_mode: int = 0
@export var zoom_intensity: float = 0.15

@export_group("Decay")
@export_enum("Long Trails", "Quick Dissolve", "Audio-Driven") var decay_mode: int = 0

@export_group("Stability")
@export var stability_reset_enabled: bool = true
@export var reset_interval: float = 45.0

@export_group("Symmetry")
@export var symmetry_enabled: bool = false

var _shader_material: ShaderMaterial
var _prev_frame_tex: ImageTexture
var _viewport: SubViewport
## Frames since startup
var _frame_count: int = 0
var _seeded: bool = false


func _ready() -> void:
	_viewport = $FeedbackViewport
	_shader_material = $FeedbackViewport/ColorRect.material
	$ResetTimer.timeout.connect(_on_reset_timer_timeout)
	$ResetTimer.wait_time = reset_interval

	# Create a black ImageTexture as the initial prev_frame
	var img := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)
	_prev_frame_tex = ImageTexture.create_from_image(img)
	_shader_material.set_shader_parameter("prev_frame", _prev_frame_tex)

	# Wire dome to show viewport output
	call_deferred("_setup_dome")

	# Copy viewport output back to prev_frame after each render
	RenderingServer.frame_post_draw.connect(_copy_frame)
	print("[Warp] Feedback loop ready (CPU frame copy, 512x512)")


func _setup_dome() -> void:
	$WarpDome.material_override.set_shader_parameter("warp_texture", _viewport.get_texture())


func _copy_frame() -> void:
	# Grab the viewport's rendered output and feed it back as prev_frame
	var img := _viewport.get_texture().get_image()
	if img != null:
		_prev_frame_tex.set_image(img)


func _process(delta: float) -> void:
	_frame_count += 1

	if not _seeded:
		_seed_feedback_loop()
		if _frame_count >= 30:
			_seeded = true
		return

	var data: AudioData = AudioManager.audio_data
	if data == null:
		_update_idle()
		return

	if not AudioManager.has_signal:
		_update_idle()
		return

	_update_warp_params(data, delta)


func _seed_feedback_loop() -> void:
	# Seed phase: inject vivid colors at the center to bootstrap the feedback loop.
	# Warp spreads the center injection outward over subsequent frames.
	_shader_material.set_shader_parameter("warp_zoom", 1.02)
	_shader_material.set_shader_parameter("warp_rotation", 0.02)
	_shader_material.set_shader_parameter("decay", 0.98)
	_shader_material.set_shader_parameter("audio_inject_amount", 0.3)
	_shader_material.set_shader_parameter("noise_amount", 0.03)
	_shader_material.set_shader_parameter("hue_shift", 0.005)
	_shader_material.set_shader_parameter("symmetry_enabled", false)
	var t: float = _frame_count * 0.1
	var seed_color := Vector3(
		0.6 + 0.4 * sin(t),
		0.4 + 0.4 * sin(t * 1.3 + 1.0),
		0.5 + 0.4 * sin(t * 0.7 + 2.0)
	)
	_shader_material.set_shader_parameter("audio_color", seed_color)


func _update_warp_params(data: AudioData, _delta: float) -> void:
	var channels = data.grouped
	var bass: float = channels[0]
	var mids: float = (channels[1] + channels[2]) * 0.5
	var highs: float = channels[3]
	var energy: float = data.energy

	# Bass -> zoom
	var zoom: float
	match bass_mode:
		0: zoom = 1.0 + bass * zoom_intensity
		1: zoom = 1.0 + bass * zoom_intensity * 0.3
		2: zoom = 1.0 + bass * zoom_intensity * bass
		_: zoom = 1.0
	zoom = maxf(zoom, 1.003)

	# Mids -> rotation
	var rotation_val: float = 0.003 + mids * 0.04

	# Highs -> hue shift (small values — this runs every frame in the loop)
	var hue_val: float = 0.001 + highs * 0.005

	# Decay: controls how fast trails fade. Must dominate over injection.
	var decay_val: float
	match decay_mode:
		0: decay_val = 0.97   # Long trails
		1: decay_val = 0.90   # Quick dissolve
		2: decay_val = lerpf(0.97, 0.90, energy)  # Audio-driven
		_: decay_val = 0.97

	# Injection: center-weighted blend toward audio_color.
	# Keep low — steady-state brightness ≈ inject / (1 - decay).
	# At inject=0.08, decay=0.97: steady state ≈ 0.08/0.03 ≈ 2.7 → clamps but only at center
	var inject: float = 0.03 + energy * 0.08

	var audio_col: Vector3 = _frequency_to_color(bass, mids, highs)

	# Display brightness (on dome, outside feedback loop)
	var dome_brightness: float = 1.2 + energy * 0.8
	$WarpDome.material_override.set_shader_parameter("brightness", dome_brightness)

	_shader_material.set_shader_parameter("warp_zoom", zoom)
	_shader_material.set_shader_parameter("warp_rotation", rotation_val)
	_shader_material.set_shader_parameter("decay", decay_val)
	_shader_material.set_shader_parameter("hue_shift", hue_val)
	_shader_material.set_shader_parameter("audio_inject_amount", inject)
	_shader_material.set_shader_parameter("audio_color", audio_col)
	_shader_material.set_shader_parameter("symmetry_enabled", symmetry_enabled)


func _frequency_to_color(bass: float, mids: float, highs: float) -> Vector3:
	var r: float = bass * 0.8 + mids * 0.2
	var g: float = mids * 0.5 + bass * 0.3
	var b: float = highs * 0.8 + mids * 0.2
	var color := Vector3(r, g, b)
	if color.length() > 0.001:
		color = color.normalized()
	else:
		color = Vector3(0.6, 0.3, 0.2)
	return color


func _update_idle() -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	_shader_material.set_shader_parameter("warp_zoom", 1.008)
	_shader_material.set_shader_parameter("warp_rotation", 0.008 + 0.004 * sin(t * 0.3))
	_shader_material.set_shader_parameter("decay", 0.97)
	_shader_material.set_shader_parameter("audio_inject_amount", 0.04)
	_shader_material.set_shader_parameter("hue_shift", 0.002)
	_shader_material.set_shader_parameter("symmetry_enabled", symmetry_enabled)
	var idle_color := Vector3(
		0.5 + 0.3 * sin(t * 0.2),
		0.3 + 0.2 * sin(t * 0.26 + 1.0),
		0.4 + 0.3 * sin(t * 0.34 + 2.0)
	)
	_shader_material.set_shader_parameter("audio_color", idle_color)
	$WarpDome.material_override.set_shader_parameter("brightness", 1.5)


func _on_reset_timer_timeout() -> void:
	if not stability_reset_enabled:
		return
	_shader_material.set_shader_parameter("noise_amount", 0.05)
	var tween := create_tween()
	tween.tween_method(
		func(val: float) -> void: _shader_material.set_shader_parameter("noise_amount", val),
		0.05, 0.0, 2.0
	)
