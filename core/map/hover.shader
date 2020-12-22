shader_type canvas_item;

uniform bool flip_y = false;
uniform float alpha = 0.2;

void vertex() {
	if (flip_y)
		VERTEX.y = 96.0 - VERTEX.y;
}

void fragment() {
	COLOR = texture(TEXTURE, UV);
	if (COLOR.a < 0.5)
		COLOR = vec4(vec3(0.0), alpha);
}