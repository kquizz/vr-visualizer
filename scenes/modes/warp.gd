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
@export var symmetry_enabled: bool = true

var _shader_material: ShaderMaterial


func _ready() -> void:
	_shader_material = $PingPongSystem/SubViewportA/ColorRect.material
	$ResetTimer.timeout.connect(_on_reset_timer_timeout)
	$ResetTimer.wait_time = reset_interval
	call_deferred("_setup_viewport_textures")


func _setup_viewport_textures() -> void:
	# ViewportTexture for prev_frame: SubViewportB -> ColorRect shader
	var vt_b := ViewportTexture.new()
	vt_b.viewport_path = get_node("PingPongSystem/SubViewportB").get_path()
	_shader_material.set_shader_parameter("prev_frame", vt_b)

	# ViewportTexture for CopySprite: SubViewportA -> Sprite2D in SubViewportB
	var vt_a_copy := ViewportTexture.new()
	vt_a_copy.viewport_path = get_node("PingPongSystem/SubViewportA").get_path()
	$PingPongSystem/SubViewportB/CopySprite.texture = vt_a_copy

	# ViewportTexture for WarpDome: SubViewportA -> dome material
	var vt_a_dome := ViewportTexture.new()
	vt_a_dome.viewport_path = get_node("PingPongSystem/SubViewportA").get_path()
	$WarpDome.material_override.set_shader_parameter("warp_texture", vt_a_dome)


func _process(delta: float) -> void:
	var data: AudioData = AudioManager.audio_data
	if data == null:
		return

	if not AudioManager.has_signal:
		_update_idle()
		return

	_update_warp_params(data, delta)


func _update_warp_params(data: AudioData, delta: float) -> void:
	var channels = data.grouped
	var bass: float = channels[0]
	var mids: float = (channels[1] + channels[2]) * 0.5
	var highs: float = channels[3]
	var energy: float = data.energy

	# Bass -> zoom
	var zoom: float
	match bass_mode:
		0:  # Punchy
			zoom = 1.0 + bass * zoom_intensity
		1:  # Smooth
			zoom = 1.0 + bass * zoom_intensity * 0.3
		2:  # Intensity-Scaled
			zoom = 1.0 + bass * zoom_intensity * bass
		_:
			zoom = 1.0

	# Mids -> rotation (consistent direction)
	var rotation: float = mids * 0.03

	# Highs -> hue shift + brightness
	var hue_shift: float = highs * 0.005
	var brightness: float = 1.0 + highs * 0.3

	# Decay mode
	var decay_val: float
	match decay_mode:
		0: decay_val = 0.975  # Long trails
		1: decay_val = 0.85   # Quick dissolve
		2: decay_val = lerpf(0.98, 0.85, energy)  # Audio-driven
		_: decay_val = 0.975

	# Master intensity (never fully zero)
	var master: float = 0.3 + energy * 0.7

	# Audio color: map dominant band to hue
	var audio_color: Vector3 = _frequency_to_color(bass, mids, highs)

	_shader_material.set_shader_parameter("warp_zoom", zoom)
	_shader_material.set_shader_parameter("warp_rotation", rotation)
	_shader_material.set_shader_parameter("decay", decay_val)
	_shader_material.set_shader_parameter("hue_shift", hue_shift)
	_shader_material.set_shader_parameter("brightness", brightness)
	_shader_material.set_shader_parameter("master_intensity", master)
	_shader_material.set_shader_parameter("audio_inject_amount", energy * 0.15)
	_shader_material.set_shader_parameter("audio_color", audio_color)
	_shader_material.set_shader_parameter("symmetry_enabled", symmetry_enabled)


func _frequency_to_color(bass: float, mids: float, highs: float) -> Vector3:
	# Bass = warm (red/orange), Mids = green/yellow, Highs = cool (blue/purple)
	var r: float = bass * 0.8 + mids * 0.2
	var g: float = mids * 0.5 + bass * 0.3
	var b: float = highs * 0.8 + mids * 0.2
	var color := Vector3(r, g, b)
	if color.length() > 0.001:
		color = color.normalized() * 0.8
	else:
		color = Vector3(0.5, 0.3, 0.2)
	return color


func _update_idle() -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	_shader_material.set_shader_parameter("warp_zoom", 1.0)
	_shader_material.set_shader_parameter("warp_rotation", 0.005)
	_shader_material.set_shader_parameter("decay", 0.975)
	_shader_material.set_shader_parameter("master_intensity", 0.3)
	_shader_material.set_shader_parameter("audio_inject_amount", 0.02)
	_shader_material.set_shader_parameter("hue_shift", 0.001)
	_shader_material.set_shader_parameter("brightness", 1.0)
	_shader_material.set_shader_parameter("symmetry_enabled", symmetry_enabled)
	# Slowly cycling idle color based on time
	var idle_color := Vector3(
		0.5 + 0.3 * sin(t * 0.1),
		0.3 + 0.2 * sin(t * 0.13 + 1.0),
		0.4 + 0.3 * sin(t * 0.17 + 2.0)
	)
	_shader_material.set_shader_parameter("audio_color", idle_color)


func _on_reset_timer_timeout() -> void:
	if not stability_reset_enabled:
		return
	_shader_material.set_shader_parameter("noise_amount", 0.05)
	# Tween noise back to 0 over 2 seconds
	var tween := create_tween()
	tween.tween_method(
		func(val: float) -> void: _shader_material.set_shader_parameter("noise_amount", val),
		0.05, 0.0, 2.0
	)
