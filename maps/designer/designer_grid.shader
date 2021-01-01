shader_type spatial;

// This is a shader with less textures, in case the main one doesn't run on your GPU.
// It's mostly a big copy/paste, because Godot doesn't support #include or #ifdef...

uniform float u_ground_uv_scale = 20.0;
uniform sampler2D u_terrain_heightmap;
uniform sampler2D u_terrain_normalmap;
uniform mat4 u_terrain_inverse_transform;
uniform mat3 u_terrain_normal_basis;

varying vec3 v_ground_uv;


vec3 unpack_normal(vec4 rgba) {
        vec3 n = rgba.xzy * 2.0 - vec3(1.0);
        // Had to negate Z because it comes from Y in the normal map,
        // and OpenGL-style normal maps are Y-up.
        n.z *= -1.0;
        return n;
}


void vertex() {
	vec2 cell_coords = (u_terrain_inverse_transform * WORLD_MATRIX * vec4(VERTEX, 1)).xz;
	// Must add a half-offset so that we sample the center of pixels,
	// otherwise bilinear filtering of the textures will give us mixed results.
	cell_coords += vec2(0.5);

	// Normalized UV
	UV = cell_coords / vec2(textureSize(u_terrain_heightmap, 0));

	// Height displacement
	float h = texture(u_terrain_heightmap, UV).r;
	VERTEX.y = h;

	v_ground_uv = vec3(cell_coords.x, h * WORLD_MATRIX[1][1], cell_coords.y) / u_ground_uv_scale;

	// Putting this in vertex saves 2 fetches from the fragment shader,
	// which is good for performance at a negligible quality cost,
	// provided that geometry is a regular grid that decimates with LOD.
	// (downside is LOD will also decimate tint and splat, but it's not bad overall)

	// Need to use u_terrain_normal_basis to handle scaling.
	NORMAL = u_terrain_normal_basis * unpack_normal(texture(u_terrain_normalmap, UV));
}

void fragment() {

	vec2 ground_uv = v_ground_uv.xz;

	ALBEDO.xyz = vec3(1.0);

	ROUGHNESS = 1.0;

	vec3 terrain_normal_world = u_terrain_normal_basis *
		unpack_normal(texture(u_terrain_normalmap, UV));
	NORMAL = (INV_CAMERA_MATRIX * (vec4(terrain_normal_world, 0.0))).xyz;
}

