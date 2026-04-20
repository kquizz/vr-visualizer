shader_type spatial;
render_mode unshaded;

global uniform float audio_energy;
global uniform vec4 audio_bands_low;
global uniform vec4 audio_channels;

void fragment() {
	// Color driven by grouped channels:
	// Red = LOW (bass), Green = MID_LOW (melody), Blue = HIGH (sparkle)
	vec3 color = vec3(audio_channels.x, audio_channels.y, audio_channels.w);

	// Sub-bass pulse from raw bands
	float pulse = audio_bands_low.x * 0.5;

	ALBEDO = color + vec3(pulse);
	EMISSION = color * 2.0 + vec3(pulse) * 3.0;
}

void vertex() {
	// Scale mesh based on overall energy
	float scale_factor = 1.0 + audio_energy * 0.3;
	VERTEX *= scale_factor;
}
