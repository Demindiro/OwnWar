shader_type spatial;
render_mode world_vertex_coords;


uniform vec2 amplitude = vec2(0.2, 0.1);
uniform vec2 frequency = vec2(3.0, 2.5);
uniform vec2 time_factor = vec2(0.5, 1.0);
uniform sampler2D texturemap : hint_albedo;
uniform sampler2D normalmap : hint_normal;
uniform vec2 uv_offset = vec2(0.0, 0.0);
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform vec2 uv_time_offset = vec2(1.0, 1.0);
uniform float refraction = 0.03;


float rand(vec2 co){
	return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}


float height(vec2 position, float time) {
	vec2 position_random = vec2(sin(position.x * 0.01), cos(position.y * 0.01));
	float height_random = rand(position) * 0.5;
	vec2 result = amplitude * sin(position * frequency + vec2(0.5, 1.0) * time + position_random );
	return result.x + result.y + height_random;
}


void vertex() {
	VERTEX.y += height(VERTEX.xz, TIME);
	float dx = height(VERTEX.xz + vec2(0.02, 0), TIME) - height(VERTEX.xz - vec2(0.02, 0), TIME);
	float dz = height(VERTEX.xz + vec2(0, 0.02), TIME) - height(VERTEX.xz - vec2(0, 0.02), TIME);
	BINORMAL = normalize(vec3(0.04, dx, 0.0));
	TANGENT = normalize(vec3(0.0, dz, 0.04));
	NORMAL = cross(BINORMAL, TANGENT);
	UV = UV * uv_scale + uv_offset + time_factor * TIME;
}


void fragment() {
	vec2 uv_distortion = texture(normalmap, UV).rg;
	vec2 uv = UV + uv_distortion + uv_time_offset * TIME;
	ALBEDO.rgb = texture(texturemap, uv).rgb;
	ALPHA = clamp((ALBEDO.r + ALBEDO.g + ALBEDO.b) * 0.1 + 0.3, 0.0, 1.0);
	NORMALMAP = texture(normalmap, uv).rgb;
	METALLIC = 0.4;
	ROUGHNESS = 0.2;

	// This effect is cool, but it causes physically incorrect "reflections",
	// so beware

//	// I'm not going to pretend I know what I'm doing
//	vec3 ref_normal = normalize(mix(NORMAL, TANGENT * NORMALMAP.x + BINORMAL * NORMALMAP.y + NORMAL * NORMALMAP.z, NORMALMAP_DEPTH));
//	vec2 ref_offset = SCREEN_UV - ref_normal.xy * refraction;
//	EMISSION += textureLod(SCREEN_TEXTURE, ref_offset, ROUGHNESS * 8.0).rgb * (1.0 - ALPHA);
//	ALBEDO *= ALPHA;
//	ALPHA = 1.0;
}