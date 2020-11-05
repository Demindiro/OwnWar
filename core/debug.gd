extends ImmediateGeometry


func _init():
	material_override = SpatialMaterial.new()
	material_override.flags_unshaded = true
	material_override.vertex_color_use_as_albedo = true


func _process(_delta):
	clear()


func draw_point(origin: Vector3, color := Color.white, radius := 1.0):
	if visible:
		for axis in [[Vector3.UP, Vector3.RIGHT], [Vector3.FORWARD, Vector3.UP],
				[Vector3.RIGHT, Vector3.FORWARD]]:
			begin(Mesh.PRIMITIVE_LINE_LOOP)
			set_color(color)
			for i in range(16):
				add_vertex(radius * axis[0].rotated(axis[1], PI / 8 * i) + origin)
			end()


func draw_circle(origin: Vector3, color := Color.white, radius := 1.0):
	if visible:
		begin(Mesh.PRIMITIVE_LINE_LOOP)
		set_color(color)
		for i in range(16):
			var r = i * PI / 8
			add_vertex(Vector3(cos(r) * radius, 0, sin(r) * radius) + origin)
		end()


func draw_line(start: Vector3, end: Vector3, color := Color.white):
	if visible:
		begin(Mesh.PRIMITIVE_LINES)
		set_color(color)
		add_vertex(start)
		add_vertex(end)
		end()


func draw_normal(origin: Vector3, direction: Vector3, color := Color.white):
	if visible:
		begin(Mesh.PRIMITIVE_LINES)
		set_color(color)
		add_vertex(origin)
		add_vertex(origin + direction)
		end()
