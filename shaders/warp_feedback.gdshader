shader_type canvas_item;

uniform sampler2D prev_frame : filter_linear;

// Warp
uniform float warp_zoom : hint_range(0.9, 1.3) = 1.0;
uniform float warp_rotation : hint_range(-0.3, 0.3) = 0.0;
uniform float warp_dx : hint_range(-0.1, 0.1) = 0.0;
uniform float warp_dy : hint_range(-0.1, 0.1) = 0.0;
uniform float decay : hint_range(0.85, 1.0) = 0.97;
uniform float hue_shift : hint_range(0.0, 0.05) = 0.0;

// Noise
uniform sampler2D noise_tex : filter_linear;
uniform float noise_amount : hint_range(0.0, 0.15) = 0.0;

// Two-color injection: warm center, cool edge
uniform vec3 color_inner = vec3(1.0, 0.3, 0.1);
uniform vec3 color_outer = vec3(0.1, 0.4, 1.0);
uniform float audio_inject_amount : hint_range(0.0, 1.0) = 0.1;

uniform bool symmetry_enabled = false;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec2 uv = UV;

	if (symmetry_enabled) {
		vec2 centered = uv - 0.5;
		float angle = atan(centered.y, centered.x);
		float radius = length(centered);
		angle = mod(angle, PI / 2.0);
		uv = vec2(cos(angle), sin(angle)) * radius + 0.5;
	}

	// Asymmetric warp with drifting center
	vec2 warp_center = vec2(0.5) + vec2(warp_dx, warp_dy);
	vec2 delta = uv - warp_center;
	float r = length(delta);
	float a = atan(delta.y, delta.x);

	// Per-pixel variation from noise for organic flow
	vec2 n_uv = uv * 1.5 + vec2(TIME * 0.02, TIME * 0.015);
	vec2 ns = texture(noise_tex, n_uv).rg;
	float lz = warp_zoom + (ns.x - 0.5) * 0.025;
	float lr = warp_rotation + (ns.y - 0.5) * 0.04;

	r /= lz;
	a += lr;
	a += r * warp_rotation * 1.2;  // Strong spiral
	delta = vec2(cos(a), sin(a)) * r;
	vec2 warped_uv = clamp(delta + warp_center, vec2(0.002), vec2(0.998));

	vec4 prev = texture(prev_frame, warped_uv);
	prev.rgb *= decay;

	// Aggressive hue shift + saturation boost
	if (length(prev.rgb) > 0.01) {
		vec3 hsv = rgb2hsv(max(prev.rgb, vec3(0.0)));
		hsv.x = fract(hsv.x + hue_shift);
		hsv.y = min(hsv.y * 1.1, 1.0);
		prev.rgb = hsv2rgb(hsv);
	}

	// Two-color injection — warm blobs at center, cool blobs at edge
	float dist = length(UV - vec2(0.5));
	vec2 inj_uv = UV * 3.5 + vec2(TIME * 0.09, TIME * -0.07);
	float inj_noise = texture(noise_tex, inj_uv).r;

	// Inner injection: noise-shaped blobs near center
	float inner_mask = smoothstep(0.3, 0.02, dist) * smoothstep(0.25, 0.65, inj_noise);
	// Outer injection: scattered blobs further out
	float outer_mask = smoothstep(0.15, 0.4, dist) * smoothstep(0.5, 0.0, dist) * smoothstep(0.4, 0.75, inj_noise);

	prev.rgb = mix(prev.rgb, color_inner, inner_mask * audio_inject_amount);
	prev.rgb = mix(prev.rgb, color_outer, outer_mask * audio_inject_amount * 0.6);

	// Detail noise
	vec3 dn = texture(noise_tex, uv * 2.5 + vec2(TIME * 0.05)).rgb;
	prev.rgb += (dn - 0.5) * noise_amount * smoothstep(0.45, 0.1, dist);

	COLOR = vec4(clamp(prev.rgb, 0.0, 1.0), 1.0);
}
