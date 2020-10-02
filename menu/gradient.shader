shader_type canvas_item;

uniform sampler2D albedo_texture;


float f(vec2 crd) {
	crd = crd * 2.0 - vec2(1.0);
	float z = -(crd.x * 0.5 + crd.y);
	return (clamp(z, -1.0, 1.0)) / 2.0;
}


void fragment() {
	COLOR = texture(albedo_texture, UV);
	COLOR.rgb = COLOR.rgb + vec3(f(UV) * 0.2);
}