extends Spatial


class Text3D:
	var text: String
	var position: Vector3
	var color: Color

	func _init(p_position: Vector3, p_text: String, p_color: Color) -> void:
		text = p_text
		position = p_position
		color = p_color


var _assert_drawing := false
var _funcrefs := {}
var _cam: Camera = null
var _cam_far2: float
var _vp: Viewport = null
var _vp_rect: Rect2
var _im := ImmediateGeometry.new()
var _point_mesh: ArrayMesh
var _point_multimeshes := {}
var _canvas_item := Control.new()
var _canvas_item_text3d := []
onready var _default_font := Control.new().get_font("font")

var fps_only := false

var physics_step_time_samples := PoolIntArray()
const PHYSICS_STEP_TIME_SAMPLE_COUNT := 60


func _init():
	visible = OS.is_debug_build()
	var mat := SpatialMaterial.new()
	mat.flags_unshaded = true
	mat.vertex_color_use_as_albedo = true
	_im.material_override = mat
	_create_point_mesh()
	pause_mode = Node.PAUSE_MODE_PROCESS
	process_priority = 1000


func _enter_tree():
	_vp = get_tree().root
	add_child(_im)
	add_child(_canvas_item)
	_canvas_item.anchor_bottom = 1
	_canvas_item.anchor_right = 1
	_canvas_item.focus_mode = Control.FOCUS_NONE
	_canvas_item.focus_mode = Control.FOCUS_NONE
	_canvas_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tr := get_tree()
	var e := tr.connect("node_added", self, "_node_added")
	assert(e == OK)
	e = tr.connect("node_removed", self, "_node_removed")
	assert(e == OK)
	e = _canvas_item.connect("draw", self, "_draw_canvas_item")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		visible = not visible


func _physics_process(_d):
	if Engine.has_method("get_physics_step_time_usec"):
		if len(physics_step_time_samples) > PHYSICS_STEP_TIME_SAMPLE_COUNT:
			for i in len(physics_step_time_samples) - 1:
				physics_step_time_samples[i] = physics_step_time_samples[i + 1]
			physics_step_time_samples[PHYSICS_STEP_TIME_SAMPLE_COUNT - 1] = Engine.get_physics_step_time_usec()
		else:
			physics_step_time_samples.push_back(Engine.get_physics_step_time_usec())


func _process(_delta):
	if visible:
		# Clear visible stuff
		_im.clear()
		for v in _point_multimeshes.values():
			var mm: MultiMesh = v
			mm.visible_instance_count = 0
		_canvas_item_text3d.clear()
		# Get camera properties
		_cam = _vp.get_camera()
		if _cam == null:
			return
		_cam_far2 = _cam.far
		_cam_far2 *= _cam_far2
		_vp_rect = Rect2(Vector2.ZERO, _vp.size)
		_im.begin(Mesh.PRIMITIVE_LINES)
		_assert_drawing = true
		if not fps_only:
			for node in _funcrefs:
				_funcrefs[node].call_func()
		_assert_drawing = false
		_im.end()
		_canvas_item.update()
	_canvas_item.visible = visible


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


func draw_text(origin: Vector3, text: String, color := Color.white) -> void:
	assert(_assert_drawing)
	_canvas_item_text3d.append(Text3D.new(origin, text, color))


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


func _draw_canvas_item():
	for t3d in _canvas_item_text3d:
		var text3d: Text3D = t3d
		if _is_point_visible(text3d.position):
			var pos := _cam.unproject_position(text3d.position)
			var text := text3d.text.split('\n')
			for t in text:
				_canvas_item.draw_string(_default_font, pos, t, text3d.color)
				pos += Vector2(0, 16.0)
	_canvas_item.draw_string(
		_default_font,
		Vector2(_canvas_item.rect_size.x / 2.0, 20.0),
		"FPS: " + str(Engine.get_frames_per_second())
	)
	var draw_calls = get_tree() \
		.root \
		.get_render_info(Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	_canvas_item.draw_string(
		_default_font,
		Vector2(_canvas_item.rect_size.x / 2.0, 40.0),
		"Draw calls: " + str(draw_calls)
	)
	var vertices = get_tree() \
		.root \
		.get_render_info(Viewport.RENDER_INFO_VERTICES_IN_FRAME)
	_canvas_item.draw_string(
		_default_font,
		Vector2(_canvas_item.rect_size.x / 2.0, 60.0),
		"Vertices: " + str(vertices)
	)

	var avg := 0
	for n in physics_step_time_samples:
		avg += n
	if avg > 0:
		avg /= len(physics_step_time_samples)
		_canvas_item.draw_string(
			_default_font,
			Vector2(_canvas_item.rect_size.x / 2.0, 80.0),
			"Physics inverse step time (%d samples): %.3f" % [PHYSICS_STEP_TIME_SAMPLE_COUNT, (1000 * 1000.0 / avg)]
		)

