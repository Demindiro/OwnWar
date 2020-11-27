extends Spatial


var _assert_drawing := false
var _funcrefs := {}
var _cam: Camera = null
var _cam_far2: float
var _vp: Viewport = null
var _vp_rect: Rect2
var _im := ImmediateGeometry.new()
var _point_mesh: ArrayMesh
var _point_multimeshes := {}


func _init():
	var mat := SpatialMaterial.new()
	mat.flags_unshaded = true
	mat.vertex_color_use_as_albedo = true
	_im.material_override = mat
	_create_point_mesh()


func _enter_tree():
	_vp = get_tree().root
	add_child(_im)
	var tr := get_tree()
	var e := tr.connect("node_added", self, "_node_added")
	assert(e == OK)
	e = tr.connect("node_removed", self, "_node_removed")
	assert(e == OK)


func _process(_delta):
	if visible:
		# Clear visible stuff
		_im.clear()
		for v in _point_multimeshes.values():
			var mm: MultiMesh = v
			mm.visible_instance_count = 0
		# Get camera properties
		_cam = _vp.get_camera()
		_cam_far2 = _cam.far
		_cam_far2 *= _cam_far2
		_vp_rect = Rect2(Vector2.ZERO, _vp.size)
		_im.begin(Mesh.PRIMITIVE_LINES)
		_assert_drawing = true
		for node in _funcrefs:
			_funcrefs[node].call_func()
		_assert_drawing = false
		_im.end()


func draw_point(origin: Vector3, color := Color.white, radius := 1.0):
	assert(_assert_drawing)
	var mm: MultiMesh = _point_multimeshes.get(color)
	if mm == null:
		mm = MultiMesh.new()
		mm.mesh = _point_mesh
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.instance_count = 1
		mm.visible_instance_count = 0
		var mat := SpatialMaterial.new()
		mat.flags_unshaded = true
		mat.albedo_color = color
		var mmi := MultiMeshInstance.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		add_child(mmi)
		_point_multimeshes[color] = mm
	if _is_point_visible(origin):
		var vic := mm.visible_instance_count
		if mm.instance_count <= vic:
			# warning-ignore:integer_division
			mm.instance_count = (vic + 1) * 3 / 2
		var tr := Transform(Basis.IDENTITY.scaled(Vector3.ONE * radius), origin)
		mm.set_instance_transform(vic, tr)
		mm.visible_instance_count = vic + 1


func draw_circle(origin: Vector3, color := Color.white, radius := 1.0):
	assert(_assert_drawing)
	if _is_point_visible(origin):
		_im.set_color(color)
		for i in range(16):
			var ra := (i - 1) * PI / 8
			var rb := i * PI / 8
			_im.add_vertex(Vector3(cos(ra) * radius, 0, sin(ra) * radius) + origin)
			_im.add_vertex(Vector3(cos(rb) * radius, 0, sin(rb) * radius) + origin)


func draw_line(start: Vector3, end: Vector3, color := Color.white):
	assert(_assert_drawing)
	if _is_point_visible(start) or _is_point_visible(end):
		_im.set_color(color)
		_im.add_vertex(start)
		_im.add_vertex(end)


func draw_normal(origin: Vector3, direction: Vector3, color := Color.white):
	assert(_assert_drawing)
	draw_line(origin, origin + direction, color)


func draw_graph(points: PoolVector3Array, color := Color.white):
	assert(_assert_drawing)
	_im.set_color(color)
	var v_prev := points[0]
	var v_prev_vis := _is_point_visible(v_prev)
	for i in range(1, len(points)):
		var v := points[i]
		var v_vis := _is_point_visible(v)
		if v_prev_vis or v_vis:
			_im.add_vertex(v_prev)
			_im.add_vertex(v)
		v_prev = v
		v_prev_vis = v_vis


func _node_added(node: Node) -> void:
	assert(not node in _funcrefs)
	if node.has_method("debug_draw"):
		_funcrefs[node] = funcref(node, "debug_draw")


func _node_removed(node: Node) -> void:
	if node.has_method("debug_draw"):
		assert(node in _funcrefs)
		var existed := _funcrefs.erase(node)
		assert(existed)


func _is_point_visible(point: Vector3) -> bool:
	return not _cam.is_position_behind(point) and \
			_cam_far2 > _cam.global_transform.origin.distance_squared_to(
					point) and \
			_vp_rect.has_point(_cam.unproject_position(point))


func _create_point_mesh():
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	var verts := PoolVector3Array()
	for axis in [[Vector3.UP, Vector3.RIGHT], [Vector3.FORWARD, Vector3.UP],
			[Vector3.RIGHT, Vector3.FORWARD]]:
		for i in range(16):
			verts.append(axis[0].rotated(axis[1], (i - 1) * PI / 8))
			verts.append(axis[0].rotated(axis[1], i * PI / 8))
	arr[Mesh.ARRAY_VERTEX] = verts
	_point_mesh = ArrayMesh.new()
	_point_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
