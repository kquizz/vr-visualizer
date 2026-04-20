extends Node

# NOTE: Global shader uniforms are declared in project.godot [shader_globals].
# We do NOT call RenderingServer.global_shader_parameter_add() here.
# Godot Issue #77988: uniforms MUST be in project.godot for the editor to recognize them.
# ShaderBridge only SETS values at runtime.

func _process(_delta: float) -> void:
	var data: AudioData = AudioManager.audio_data
	if data == null:
		return

	RenderingServer.global_shader_parameter_set("audio_energy", data.energy)
	RenderingServer.global_shader_parameter_set("audio_peak_freq", data.peak_frequency)
	RenderingServer.global_shader_parameter_set("audio_bands_low",
		Vector4(data.bands[0], data.bands[1], data.bands[2], data.bands[3]))
	RenderingServer.global_shader_parameter_set("audio_bands_high",
		Vector4(data.bands[4], data.bands[5], data.bands[6], 0.0))
	RenderingServer.global_shader_parameter_set("audio_channels",
		Vector4(data.grouped[0], data.grouped[1], data.grouped[2], data.grouped[3]))
