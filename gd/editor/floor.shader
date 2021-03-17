shader_type spatial;


uniform bool enable_mirror = false;
uniform int grid_size = 8;
uniform float edge_size : hint_range(0.0, 1.0) = 0.2;
uniform float edge_glow: hint_range(0.0, 10.0) = 2.0;
uniform vec4 cell_color : hint_color = vec4(vec3(0.0), 1.0); 
uniform vec4 edge_color : hint_color = vec4(vec3(1.0), 1.0);
uniform vec4 mirror_color : hint_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float mirror_offset : hint_range(0.0, 1.0) = 0.1;
uniform float mirror_glow : hint_range(0.0, 10.0) = 2.0;
uniform float sample_radius: hint_range(0.0, 1.0) = 0.01;
uniform int samples: hint_range(1, 10) = 5;


void vertex() {
	VERTEX.xz += vec2(0.5);
	VERTEX.xz *= float(grid_size) + edge_size;
	VERTEX.xz -= edge_size / 2.0;
	UV.xy = UV.yx;
}


bool draw_mirror(vec2 uv) {
	float mirror_offt = 0.5 - edge_size * 0.5 - mirror_offset;
	mirror_offt /= float(grid_size);
	float mirror_min = 0.5 - mirror_offt;
	float mirror_max = 0.5 + mirror_offt;
	return enable_mirror && mirror_min < uv.y && uv.y < mirror_max;
}

bool draw_edge(vec2 uv) {
	uv = fract(uv * (float(grid_size) + edge_size));
	return uv.x < edge_size || uv.y < edge_size;
}

vec3 albedo(vec2 uv) {
	if (draw_mirror(uv)) {
		return mirror_color.rgb;
	} else if (draw_edge(uv)) {
		return edge_color.rgb;
	} else {
		return cell_color.rgb;
	}
}

vec3 emission(vec2 uv) {
	if (draw_mirror(uv)) {
		return mirror_color.rgb * mirror_glow;
	} else if (draw_edge(uv)) {
		return edge_color.rgb * edge_glow;
	} else {
		return vec3(0.0);
	}
}

mat3 ms(vec2 uv, float f) {
	float sr = sample_radius / float(grid_size) / f;
	int c = 0;
	vec3 alb = vec3(0.0);
	vec3 ems = vec3(0.0);
	for (float x = -sr; x <= sr; x += sr / float(samples)) {
		for (float y = -sr; y <= sr; y += sr / float(samples)) {
			vec2 pos = vec2(x, y);
			if (length(pos) > sr)
				continue;
			alb += albedo(uv + pos * normalize(pos));
			ems += emission(uv + pos * normalize(pos));
			c += 1;
		}
	}
	alb /= float(c);
	ems /= float(c);
	return mat3(alb, ems, vec3(0.0));
}

void fragment() {
	if (draw_mirror(UV)) {
		METALLIC = 0.3;
	} else if (draw_edge(UV)) {
		METALLIC = 0.5;
	} else {
		METALLIC = 1.0;
	}
	float s = FRAGCOORD.z * FRAGCOORD.w;
	s *= max(abs(NORMAL.z), 0.5);
	mat3 res = ms(UV, s);
	ALBEDO = res[0];
	EMISSION = res[1];
	SPECULAR = 1.0;
	ROUGHNESS = 0.5;
}