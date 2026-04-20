shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D milkdrop_texture : filter_linear;
uniform float brightness : hint_range(0.5, 3.0) = 1.5;

void fragment() {
	vec3 color = texture(milkdrop_texture, UV).rgb;
	color *= brightness;
	ALBEDO = color;
	EMISSION = color;
}
