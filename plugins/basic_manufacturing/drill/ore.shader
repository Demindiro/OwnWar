shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;


uniform vec3 albedo_color;


void fragment () {
	ALBEDO = albedo_color;
	SPECULAR = 0.5;
}
