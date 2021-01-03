shader_type spatial;


uniform bool enable_mirror = false;
uniform int grid_size = 8;
uniform float edge_size : hint_range(0.0, 1.0) = 0.2;
uniform vec4 cell_color : hint_color = vec4(vec3(0.0), 1.0); 
uniform vec4 edge_color : hint_color = vec4(vec3(1.0), 1.0);
uniform vec4 mirror_color : hint_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float mirror_offset : hint_range(0.0, 1.0) = 0.1;
uniform sampler2D albedo_texture : hint_albedo;


void vertex() {
	VERTEX.xz += vec2(0.5);
	VERTEX.xz *= float(grid_size) + edge_size;
	VERTEX.xz -= edge_size / 2.0;
	UV.xy = UV.yx;
}


void fragment() {
	float mirror_offt = 0.5 - edge_size * 0.5 - mirror_offset;
	mirror_offt /= float(grid_size);
	float mirror_min = 0.5 - mirror_offt;
	float mirror_max = 0.5 + mirror_offt;
	if (enable_mirror && mirror_min < UV.y && UV.y < mirror_max) {
		ALBEDO = mirror_color.rgb;
	} else {
		vec2 uv = fract(UV * (float(grid_size) + edge_size));
		if (uv.x < edge_size || uv.y < edge_size) {
			ALBEDO = edge_color.rgb;
		} else {
			vec4 tex = texture(albedo_texture, UV);
			ALBEDO = cell_color.rgb * (1.0 - tex.a) + tex.rgb * tex.a;
		}
	}
	METALLIC = 0.0;
	SPECULAR = 1.0;
	ROUGHNESS = 0.5;
}