shader_type canvas_item;

uniform sampler2D prev_frame : filter_linear;
uniform sampler2D noise_tex : filter_linear;

// Audio data (set from GDScript each frame)
uniform float bass = 0.0;
uniform float mids = 0.0;
uniform float highs = 0.0;
uniform float energy = 0.0;

// Warp params
uniform float decay : hint_range(0.85, 1.0) = 0.96;
uniform float hue_shift : hint_range(0.0, 0.05) = 0.005;

void fragment() {
	vec2 uv = UV;
	vec2 center = vec2(0.5);
	vec2 delta = uv - center;
	float dist = length(delta);
	float angle = atan(delta.y, delta.x);

	// === GENERATE NEW CONTENT EACH FRAME (not just feedback) ===

	// Tunnel rings — concentric rings that pulse with bass
	float ring_freq = 8.0 + bass * 12.0;
	float ring_phase = TIME * (1.0 + energy * 2.0);
	float rings = sin(dist * ring_freq - ring_phase) * 0.5 + 0.5;
	rings = pow(rings, 3.0);  // Sharpen the rings

	// Radial spokes — rotate with time, modulated by mids
	float spoke_count = 6.0 + mids * 10.0;
	float spoke_rotation = TIME * 0.5 + mids * 0.3;
	float spokes = sin(angle * spoke_count + spoke_rotation) * 0.5 + 0.5;
	spokes = pow(spokes, 4.0);

	// Combine: rings × spokes creates a web/grid that warps
	float pattern = rings * 0.7 + spokes * 0.3 * rings;

	// Color: map angle + time to hue for rainbow tunnel effect
	float hue = fract(angle / TAU + TIME * 0.1 + dist * 0.5);
	// Shift hue with audio — bass pushes warm, highs push cool
	hue = fract(hue + bass * 0.15 - highs * 0.1);
	float sat = 0.7 + energy * 0.3;
	float val = pattern * (0.6 + energy * 0.4);

	// HSV to RGB
	vec3 K = vec3(1.0, 2.0 / 3.0, 1.0 / 3.0);
	vec3 p = abs(fract(vec3(hue) + K) * 6.0 - vec3(3.0));
	vec3 new_color = val * mix(vec3(1.0), clamp(p - vec3(1.0), 0.0, 1.0), sat);

	// Noise texture adds organic detail
	vec2 n_uv = uv * 3.0 + vec2(TIME * 0.05, TIME * -0.03);
	float noise = texture(noise_tex, n_uv).r;
	new_color *= 0.8 + noise * 0.4;

	// === BLEND WITH FEEDBACK for trails ===
	// Warp the previous frame (gentle zoom + rotation for trail smearing)
	float fb_zoom = 1.01 + bass * 0.02;
	float fb_rot = 0.01 + mids * 0.02;
	float fb_r = dist / fb_zoom;
	float fb_a = angle + fb_rot;
	vec2 fb_uv = vec2(cos(fb_a), sin(fb_a)) * fb_r + center;
	fb_uv = clamp(fb_uv, vec2(0.002), vec2(0.998));
	vec3 prev = texture(prev_frame, fb_uv).rgb * decay;

	// Hue-shift the trails
	// Simple hue rotation via matrix
	float cs = cos(hue_shift * TAU);
	float sn = sin(hue_shift * TAU);
	mat3 hue_mat = mat3(
		vec3(0.299 + 0.701*cs + 0.168*sn, 0.299 - 0.299*cs - 0.328*sn, 0.299 - 0.300*cs + 1.25*sn),
		vec3(0.587 - 0.587*cs + 0.330*sn, 0.587 + 0.413*cs + 0.035*sn, 0.587 - 0.588*cs - 1.05*sn),
		vec3(0.114 - 0.114*cs - 0.497*sn, 0.114 - 0.114*cs + 0.292*sn, 0.114 + 0.886*cs - 0.203*sn)
	);
	prev = hue_mat * prev;

	// Final: blend new pattern with feedback trails
	// New content is additive so it glows on top of trails
	float trail_strength = 0.5 + energy * 0.2;
	vec3 result = prev * trail_strength + new_color * (0.6 + energy * 0.4);

	// Center glow — bright hot spot at the tunnel origin
	float glow = exp(-dist * 4.0) * energy * 0.5;
	result += vec3(1.0, 0.9, 0.7) * glow;

	COLOR = vec4(clamp(result, 0.0, 1.0), 1.0);
}
