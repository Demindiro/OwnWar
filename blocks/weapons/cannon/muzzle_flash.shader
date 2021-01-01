shader_type spatial;
render_mode cull_disabled,unshaded,depth_draw_alpha_prepass;
uniform vec4 albedo : hint_color;
uniform sampler2D texture_albedo : hint_albedo;


void vertex() {
}


void fragment() {
	ALBEDO = texture(texture_albedo, UV).rgb;
	ALPHA = ALBEDO.r * ALBEDO.g * ALBEDO.b;
	ALBEDO = albedo.rgb;
}
