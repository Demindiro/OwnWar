extends ImmediateGeometry


var _assert_drawing := false
var _funcrefs := {}


func _init():
	var mat := SpatialMaterial.new()
	mat.flags_unshaded = true
	mat.vertex_color_use_as_albedo = true
	material_override = mat


func _enter_tree():
	var e := get_tree().connect("node_added", self, "_node_added")
	assert(e == OK)
	e = get_tree().connect("node_removed", self, "_node_removed")
	assert(e == OK)


func _process(_delta):
	if visible:
		clear()
		_assert_drawing = true
		for node in _funcrefs:
			_funcrefs[node].call_func()
		_assert_drawing = false


func draw_point(origin: Vector3, color := Color.white, radius := 1.0):
	assert(_assert_drawing)
	for axis in [[Vector3.UP, Vector3.RIGHT], [Vector3.FORWARD, Vector3.UP],
			[Vector3.RIGHT, Vector3.FORWARD]]:
		begin(Mesh.PRIMITIVE_LINE_LOOP)
		set_color(color)
		for i in range(16):
			add_vertex(radius * axis[0].rotated(axis[1], PI / 8 * i) + origin)
		end()


func draw_circle(origin: Vector3, color := Color.white, radius := 1.0):
	assert(_assert_drawing)
	begin(Mesh.PRIMITIVE_LINE_LOOP)
	set_color(color)
	for i in range(16):
		var r = i * PI / 8
		add_vertex(Vector3(cos(r) * radius, 0, sin(r) * radius) + origin)
	end()


func draw_line(start: Vector3, end: Vector3, color := Color.white):
	assert(_assert_drawing)
	begin(Mesh.PRIMITIVE_LINES)
	set_color(color)
	add_vertex(start)
	add_vertex(end)
	end()


func draw_normal(origin: Vector3, direction: Vector3, color := Color.white):
	assert(_assert_drawing)
	begin(Mesh.PRIMITIVE_LINES)
	set_color(color)
	add_vertex(origin)
	add_vertex(origin + direction)
	end()


func _node_added(node: Node) -> void:
	assert(not node in _funcrefs)
	if node.has_method("debug_draw"):
		_funcrefs[node] = funcref(node, "debug_draw")


func _node_removed(node: Node) -> void:
	if node.has_method("debug_draw"):
		assert(node in _funcrefs)
		var existed := _funcrefs.erase(node)
		assert(existed)
