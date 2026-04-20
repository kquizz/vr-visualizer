shader_type canvas_item;

// Previous frame (CPU-copied ImageTexture from GDScript)
uniform sampler2D prev_frame : filter_linear;

// Audio-driven warp parameters (set from GDScript)
uniform float warp_zoom : hint_range(0.9, 1.2) = 1.0;
uniform float warp_rotation : hint_range(-0.1, 0.1) = 0.0;
uniform float warp_dx : hint_range(-0.02, 0.02) = 0.0;
uniform float warp_dy : hint_range(-0.02, 0.02) = 0.0;
uniform float decay : hint_range(0.8, 1.0) = 0.97;
uniform float hue_shift : hint_range(0.0, 0.05) = 0.0;

// Noise injection
uniform sampler2D noise_tex : filter_linear;
uniform float noise_amount : hint_range(0.0, 0.1) = 0.0;

// Audio color injection (center-weighted, not uniform)
uniform vec3 audio_color = vec3(1.0, 0.3, 0.1);
uniform float audio_inject_amount : hint_range(0.0, 0.5) = 0.1;

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

	// Optional symmetry (kaleidoscope fold)
	if (symmetry_enabled) {
		vec2 centered = uv - 0.5;
		float angle = atan(centered.y, centered.x);
		float radius = length(centered);
		angle = mod(angle, PI / 2.0);
		uv = vec2(cos(angle), sin(angle)) * radius + 0.5;
	}

	// UV warp: polar coordinate transform
	vec2 center = vec2(0.5);
	vec2 delta = uv - center;
	float r = length(delta);
	float a = atan(delta.y, delta.x);

	// Apply warp
	r /= warp_zoom;
	a += warp_rotation;
	delta = vec2(cos(a), sin(a)) * r;
	vec2 warped_uv = delta + center + vec2(warp_dx, warp_dy);

	// Sample previous frame (clamp to avoid edge bleed)
	vec2 clamped_uv = clamp(warped_uv, vec2(0.002), vec2(0.998));
	vec4 prev = texture(prev_frame, clamped_uv);

	// Decay — energy-conserving, always removes some each frame
	prev.rgb *= decay;

	// Hue shift only (NO brightness multiply — that would amplify inside the loop)
	if (hue_shift > 0.0001) {
		vec3 hsv = rgb2hsv(max(prev.rgb, vec3(0.0)));
		hsv.x = fract(hsv.x + hue_shift);
		prev.rgb = hsv2rgb(hsv);
	}

	// Audio color injection — CENTER-WEIGHTED like Milkdrop
	// Inject color at the center; warp spreads it outward over frames.
	// Edges only get decayed/warped content from previous frames.
	float dist = length(UV - vec2(0.5));
	float inject_mask = smoothstep(0.35, 0.0, dist);
	prev.rgb = mix(prev.rgb, audio_color, inject_mask * audio_inject_amount);

	// Noise injection (periodic bursts, controlled by GDScript)
	vec3 noise_val = texture(noise_tex, uv + vec2(TIME * 0.01)).rgb;
	float noise_mask = smoothstep(0.4, 0.1, dist);
	prev.rgb += noise_val * noise_amount * noise_mask;

	COLOR = vec4(clamp(prev.rgb, 0.0, 1.0), 1.0);
}
