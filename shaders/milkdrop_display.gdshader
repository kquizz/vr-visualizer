shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D milkdrop_texture : filter_linear, repeat_enable;
uniform float brightness : hint_range(0.5, 3.0) = 1.5;

void fragment() {
	vec3 color = texture(milkdrop_texture, UV).rgb;
	color *= brightness;
	ALBEDO = color;
	EMISSION = color;
}
