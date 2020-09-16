tool
extends ImmediateGeometry
# Draw debugging lines for the wheel class

const TIRE_VERTEX_COUNT = 16
var _warning: String = ""


func _onready():
	set_process(true)


func _get_configuration_warning():
	return _warning


func _process(_delta):
	var wheel = get_parent()
	if not wheel is Wheel:
		_warning = "Parent is not of type 'Wheel'"
		return
	clear()
	# Draw raycast
	begin(1, null)
	set_color(Color(1, 1, 1)) # TODO doesn't work
	add_vertex(Vector3.ZERO)
	add_vertex(Vector3(0, -wheel.suspension_max_length, 0))
	end()
	# Draw tire
	begin(Mesh.PRIMITIVE_LINE_STRIP, null)
	set_color(Color(1, 1, 1)) # TODO doesn't work
	for i in range(TIRE_VERTEX_COUNT):
		var angle = i * PI * 2 / TIRE_VERTEX_COUNT
		add_vertex(Vector3(0, cos(angle), sin(angle)))
	add_vertex(Vector3(0, 1, 0))
	end()
