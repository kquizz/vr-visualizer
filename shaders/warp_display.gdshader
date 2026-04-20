shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D warp_texture : filter_linear;
uniform float brightness : hint_range(0.5, 3.0) = 1.5;

void fragment() {
	vec3 color = texture(warp_texture, UV).rgb;
	// Brightness boost applied here (outside feedback loop) so it can't cause saturation
	color *= brightness;
	ALBEDO = color;
	EMISSION = color;
}
