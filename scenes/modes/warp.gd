extends Node3D

var _shader_material: ShaderMaterial
var _prev_frame_tex: ImageTexture
var _viewport: SubViewport


func _ready() -> void:
	_viewport = $FeedbackViewport
	_shader_material = $FeedbackViewport/ColorRect.material

	# Black initial frame for feedback
	var img := Image.create(768, 768, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)
	_prev_frame_tex = ImageTexture.create_from_image(img)
	_shader_material.set_shader_parameter("prev_frame", _prev_frame_tex)

	call_deferred("_setup_dome")
	RenderingServer.frame_post_draw.connect(_copy_frame)
	print("[Warp] Audio-reactive tunnel ready (768x768)")


func _setup_dome() -> void:
	$WarpDome.material_override.set_shader_parameter("warp_texture", _viewport.get_texture())


func _copy_frame() -> void:
	var img := _viewport.get_texture().get_image()
	if img != null:
		_prev_frame_tex.set_image(img)


func _process(_delta: float) -> void:
	var data: AudioData = AudioManager.audio_data
	var bass: float = 0.0
	var mids: float = 0.0
	var highs: float = 0.0
	var energy_val: float = 0.0

	if data != null and AudioManager.has_signal:
		var ch = data.grouped
		bass = ch[0]
		mids = (ch[1] + ch[2]) * 0.5
		highs = ch[3]
		energy_val = data.energy

	_shader_material.set_shader_parameter("bass", bass)
	_shader_material.set_shader_parameter("mids", mids)
	_shader_material.set_shader_parameter("highs", highs)
	_shader_material.set_shader_parameter("energy", energy_val)

	# Display brightness scales with energy
	var dome_brightness: float = 1.5 + energy_val * 1.0
	$WarpDome.material_override.set_shader_parameter("brightness", dome_brightness)
