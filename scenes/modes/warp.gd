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
	var img := Image.create(768, 768, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)
	_prev_frame_tex = ImageTexture.create_from_image(img)
	_shader_material.set_shader_parameter("prev_frame", _prev_frame_tex)

	# Wire dome to show viewport output
	call_deferred("_setup_dome")

	# Copy viewport output back to prev_frame after each render
	RenderingServer.frame_post_draw.connect(_copy_frame)
	print("[Warp] Feedback loop ready (CPU frame copy, 768x768)")


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
	# Seed: inject bright saturated colors to bootstrap the feedback loop
	_shader_material.set_shader_parameter("warp_zoom", 1.03)
	_shader_material.set_shader_parameter("warp_rotation", 0.03)
	_shader_material.set_shader_parameter("decay", 0.98)
	_shader_material.set_shader_parameter("audio_inject_amount", 0.25)
	_shader_material.set_shader_parameter("noise_amount", 0.04)
	_shader_material.set_shader_parameter("hue_shift", 0.008)
	_shader_material.set_shader_parameter("symmetry_enabled", false)
	var hue: float = fmod(_frame_count * 0.03, 1.0)
	var c := Color.from_hsv(hue, 0.9, 1.0)
	_shader_material.set_shader_parameter("color_inner", Vector3(c.r, c.g, c.b))
	var c2 := Color.from_hsv(fmod(hue + 0.45, 1.0), 0.9, 0.9)
	_shader_material.set_shader_parameter("color_outer", Vector3(c2.r, c2.g, c2.b))


func _update_warp_params(data: AudioData, _delta: float) -> void:
	var channels = data.grouped
	var bass: float = channels[0]
	var mids: float = (channels[1] + channels[2]) * 0.5
	var highs: float = channels[3]
	var energy: float = data.energy

	var t: float = Time.get_ticks_msec() / 1000.0

	# Bass -> zoom (dramatic tunnel pull on kicks)
	var zoom: float
	match bass_mode:
		0: zoom = 1.0 + bass * zoom_intensity * 1.5
		1: zoom = 1.0 + bass * zoom_intensity * 0.5
		2: zoom = 1.0 + bass * zoom_intensity * bass * 2.0
		_: zoom = 1.0
	zoom = maxf(zoom, 1.005)

	# Mids -> rotation (alternating direction for variety)
	var rot_dir: float = sign(sin(t * 0.2))
	var rotation_val: float = rot_dir * (0.01 + mids * 0.1)

	# Warp center drift — breaks circular symmetry, creates flowing motion
	var dx: float = sin(t * 0.3) * 0.03 + cos(t * 0.17) * 0.02
	var dy: float = cos(t * 0.23) * 0.03 + sin(t * 0.31) * 0.02
	# Bass hits push the center
	dx += bass * 0.02 * sin(t * 2.0)
	dy += bass * 0.02 * cos(t * 2.0)

	# Highs -> hue shift
	var hue_val: float = 0.003 + highs * 0.01

	# Decay
	var decay_val: float
	match decay_mode:
		0: decay_val = 0.97
		1: decay_val = 0.92
		2: decay_val = lerpf(0.97, 0.92, energy)
		_: decay_val = 0.97

	# Injection
	var inject: float = 0.08 + energy * 0.18

	# Inner color: bass-driven warm tones
	var inner_col: Vector3 = _audio_to_vivid_color(bass, mids, highs, energy)
	# Outer color: complementary/cool — offset hue by ~0.45
	var outer_hue: float = fmod(_get_hue(bass, mids, highs) + 0.45, 1.0)
	var oc := Color.from_hsv(outer_hue, 0.85, 0.8 + energy * 0.2)
	var outer_col := Vector3(oc.r, oc.g, oc.b)

	var noise_val: float = 0.02 + bass * 0.06

	var dome_brightness: float = 1.5 + energy * 1.2
	$WarpDome.material_override.set_shader_parameter("brightness", dome_brightness)

	_shader_material.set_shader_parameter("warp_zoom", zoom)
	_shader_material.set_shader_parameter("warp_rotation", rotation_val)
	_shader_material.set_shader_parameter("warp_dx", dx)
	_shader_material.set_shader_parameter("warp_dy", dy)
	_shader_material.set_shader_parameter("decay", decay_val)
	_shader_material.set_shader_parameter("hue_shift", hue_val)
	_shader_material.set_shader_parameter("audio_inject_amount", inject)
	_shader_material.set_shader_parameter("color_inner", inner_col)
	_shader_material.set_shader_parameter("color_outer", outer_col)
	_shader_material.set_shader_parameter("noise_amount", noise_val)
	_shader_material.set_shader_parameter("symmetry_enabled", symmetry_enabled)


func _get_hue(bass: float, mids: float, highs: float) -> float:
	var max_band := maxf(bass, maxf(mids, highs))
	if max_band < 0.01:
		return fmod(Time.get_ticks_msec() / 5000.0, 1.0)
	elif bass >= mids and bass >= highs:
		return lerpf(0.0, 0.1, mids / maxf(bass, 0.01))
	elif mids >= bass and mids >= highs:
		return lerpf(0.25, 0.5, highs / maxf(mids, 0.01))
	else:
		return lerpf(0.6, 0.85, bass / maxf(highs, 0.01))


func _audio_to_vivid_color(bass: float, mids: float, highs: float, energy: float) -> Vector3:
	var hue := _get_hue(bass, mids, highs)
	var c := Color.from_hsv(hue, 0.85 + energy * 0.15, 0.9 + energy * 0.1)
	return Vector3(c.r, c.g, c.b)


func _update_idle() -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	_shader_material.set_shader_parameter("warp_zoom", 1.01)
	_shader_material.set_shader_parameter("warp_rotation", 0.015 + 0.008 * sin(t * 0.3))
	_shader_material.set_shader_parameter("decay", 0.97)
	_shader_material.set_shader_parameter("audio_inject_amount", 0.06)
	_shader_material.set_shader_parameter("noise_amount", 0.02)
	_shader_material.set_shader_parameter("hue_shift", 0.003)
	_shader_material.set_shader_parameter("symmetry_enabled", symmetry_enabled)
	# Slow rainbow cycle when idle
	var hue: float = fmod(t * 0.05, 1.0)
	var c := Color.from_hsv(hue, 0.85, 0.9)
	_shader_material.set_shader_parameter("color_inner", Vector3(c.r, c.g, c.b))
	var c2 := Color.from_hsv(fmod(hue + 0.45, 1.0), 0.8, 0.8)
	_shader_material.set_shader_parameter("color_outer", Vector3(c2.r, c2.g, c2.b))
	$WarpDome.material_override.set_shader_parameter("brightness", 1.8)


func _on_reset_timer_timeout() -> void:
	if not stability_reset_enabled:
		return
	_shader_material.set_shader_parameter("noise_amount", 0.05)
	var tween := create_tween()
	tween.tween_method(
		func(val: float) -> void: _shader_material.set_shader_parameter("noise_amount", val),
		0.05, 0.0, 2.0
	)
