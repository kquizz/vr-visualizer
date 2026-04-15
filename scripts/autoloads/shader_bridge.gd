extends Node

## Stem prefixes matching AudioManager.STEM_NAMES order
const STEM_PREFIXES: PackedStringArray = ["drums", "bass", "vocals", "other"]

# NOTE: Global shader uniforms are already declared in project.godot [shader_globals].
# We do NOT call RenderingServer.global_shader_parameter_add() here.
# Godot Issue #77988: uniforms MUST be in project.godot for the editor to recognize them.
# ShaderBridge only SETS values at runtime.

func _process(_delta: float) -> void:
	var data: Array[AudioData] = AudioManager.stem_data
	for i in range(min(data.size(), STEM_PREFIXES.size())):
		var prefix: String = STEM_PREFIXES[i]
		RenderingServer.global_shader_parameter_set(
			prefix + "_energy", data[i].energy
		)
		RenderingServer.global_shader_parameter_set(
			prefix + "_peak_freq", data[i].peak_frequency
		)
		RenderingServer.global_shader_parameter_set(
			prefix + "_bands_low",
			Vector4(
				data[i].bands[0], data[i].bands[1],
				data[i].bands[2], data[i].bands[3]
			)
		)
		RenderingServer.global_shader_parameter_set(
			prefix + "_bands_high",
			Vector4(
				data[i].bands[4], data[i].bands[5],
				data[i].bands[6], 0.0
			)
		)
