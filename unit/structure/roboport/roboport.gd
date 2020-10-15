extends Unit


var _radius2 := 100.0 * 100.0
var _immediate_geometry: ImmediateGeometry


func _physics_process(_delta):
	pass


func get_actions() -> Array:
	var actions := .get_actions()
	actions += [
			["Set Coverage", Action.INPUT_COORDINATE, "set_coverage_radius", []]
		]
	return actions


func show_action_feedback(function: String, viewport: Viewport, arguments: Array) -> void:
	match function:
		"set_coverage_radius":
			if _immediate_geometry == null:
				_immediate_geometry = ImmediateGeometry.new()
				_immediate_geometry.material_override = SpatialMaterial.new()
				_immediate_geometry.material_override.vertex_color_use_as_albedo = true
			var position := arguments[0] as Vector3
			var radius = translation.distance_to(position)
			_immediate_geometry.clear()
			_immediate_geometry.begin(Mesh.PRIMITIVE_LINE_LOOP)
			_immediate_geometry.set_color(Color.orange)
			for i in range(256):
				var r := i * PI / 180.0
				var v := Vector3(cos(r) * radius, 0.0, sin(r) * radius)
			_immediate_geometry.end()
		_:
			.show_action_feedback(function, viewport, arguments)


func hide_action_feedback() -> void:
	.hide_action_feedback()
	if _immediate_geometry != null:
		_immediate_geometry.queue_free()
		_immediate_geometry = null


func set_coverage_radius(flags: int, position: Vector3) -> void:
	_radius2 = translation.distance_squared_to(position)
