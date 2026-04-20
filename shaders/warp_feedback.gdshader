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

// Audio color injection
uniform vec3 audio_color = vec3(1.0, 0.3, 0.1);
uniform float audio_inject_amount : hint_range(0.0, 1.0) = 0.1;

// Symmetry
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

	// === ASYMMETRIC WARP ===
	// The warp center drifts over time (via warp_dx/dy from GDScript).
	// Per-pixel warp varies with noise so it's fluid, not uniform rings.
	vec2 warp_center = vec2(0.5) + vec2(warp_dx, warp_dy);
	vec2 delta = uv - warp_center;
	float r = length(delta);
	float a = atan(delta.y, delta.x);

	// Per-pixel warp variation from noise — creates organic fluid distortion
	vec2 noise_uv = uv * 1.5 + vec2(TIME * 0.02, TIME * 0.015);
	vec2 noise_sample = texture(noise_tex, noise_uv).rg;
	float local_zoom = warp_zoom + (noise_sample.x - 0.5) * 0.02;
	float local_rot = warp_rotation + (noise_sample.y - 0.5) * 0.03;

	// Apply warp with per-pixel variation
	r /= local_zoom;
	a += local_rot;
	// Spiral: rotation increases with distance
	a += r * warp_rotation * 0.8;
	delta = vec2(cos(a), sin(a)) * r;
	vec2 warped_uv = delta + warp_center;

	// Sample previous frame
	vec2 clamped_uv = clamp(warped_uv, vec2(0.002), vec2(0.998));
	vec4 prev = texture(prev_frame, clamped_uv);

	// Decay
	prev.rgb *= decay;

	// Hue shift — keep colors vivid through feedback
	if (hue_shift > 0.0001 && length(prev.rgb) > 0.01) {
		vec3 hsv = rgb2hsv(max(prev.rgb, vec3(0.0)));
		hsv.x = fract(hsv.x + hue_shift);
		hsv.y = min(hsv.y * 1.08, 1.0);  // Boost saturation to fight desaturation
		prev.rgb = hsv2rgb(hsv);
	}

	// === NOISE-SHAPED INJECTION ===
	// Instead of a static ring, use noise to create organic blobs of color.
	// The blobs move with time, creating constantly evolving shapes.
	float dist = length(UV - vec2(0.5));
	vec2 inject_noise_uv = UV * 3.0 + vec2(TIME * 0.08, TIME * -0.06);
	float inject_noise = texture(noise_tex, inject_noise_uv).r;
	// Blend center falloff with noise — organic shape that favors center
	float inject_mask = smoothstep(0.5, 0.05, dist) * smoothstep(0.3, 0.7, inject_noise);
	prev.rgb = mix(prev.rgb, audio_color, inject_mask * audio_inject_amount);

	// Noise texture injection for additional detail
	vec3 detail_noise = texture(noise_tex, uv * 2.0 + vec2(TIME * 0.04)).rgb;
	float detail_mask = smoothstep(0.4, 0.1, dist);
	prev.rgb += (detail_noise - 0.5) * noise_amount * detail_mask;

	COLOR = vec4(clamp(prev.rgb, 0.0, 1.0), 1.0);
}
