extends ImmediateGeometry


export(int) var count := 12 setget set_count
export(Color) var color := Color.whitesmoke

var vertices := []
var offset := 0
var alive_time := 0.0


func _ready() -> void:
	vertices.resize(count)
	for i in range(count):
		vertices[i] = to_global(Vector3.ZERO)


func _process(_delta: float) -> void:
	vertices[offset] = to_global(Vector3.ZERO)
	clear()
	begin(Mesh.PRIMITIVE_LINE_STRIP)
	set_color(color)
	for i in range(count):
		add_vertex(to_local(vertices[posmod(i + offset, count)]))
	end()
	offset -= 1
	if offset < 0:
		offset = count - 1


func _physics_process(delta):
	alive_time += delta
	if alive_time >= 5.0:
		queue_free()


func set_count(p_count: int) -> void:
	assert(p_count >= 0)
	vertices.resize(p_count)
	for i in range(count, p_count):
		vertices[i] = vertices[count - 1]
	count = p_count
