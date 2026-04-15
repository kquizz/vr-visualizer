shader_type spatial;
render_mode unshaded;

global uniform float drums_energy;
global uniform float bass_energy;
global uniform float vocals_energy;
global uniform float other_energy;
global uniform vec4 drums_bands_low;

void fragment() {
	// Color channels driven by stem energy:
	// Red = drums, Green = bass, Blue = vocals
	vec3 color = vec3(drums_energy, bass_energy, vocals_energy);

	// Add some variation from drum sub-bass band
	float pulse = drums_bands_low.x * 0.5;

	ALBEDO = color + vec3(pulse);
	EMISSION = color * 2.0 + vec3(pulse) * 3.0;
}

void vertex() {
	// Scale mesh based on combined energy
	float scale_factor = 1.0 + (drums_energy + bass_energy) * 0.3;
	VERTEX *= scale_factor;
}
