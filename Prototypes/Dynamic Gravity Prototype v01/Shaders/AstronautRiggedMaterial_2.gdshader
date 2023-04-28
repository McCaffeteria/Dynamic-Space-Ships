shader_type spatial;
render_mode cull_back;

uniform float distortion_size = 0.4;
uniform sampler2D glass;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 d = texture(glass, UV).xy - vec2(0.5);
	ALBEDO = texture(SCREEN_TEXTURE, SCREEN_UV + d * distortion_size).rgb;
}