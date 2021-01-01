shader_type canvas_item;


void vertex() {
	VERTEX.y = 96.0 - VERTEX.y;
}