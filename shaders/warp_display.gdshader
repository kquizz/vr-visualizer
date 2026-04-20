shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D warp_texture : filter_linear;

void fragment() {
	vec3 color = texture(warp_texture, UV).rgb;
	ALBEDO = color;
	EMISSION = color * 2.0;
}
