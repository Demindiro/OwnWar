class_name AI

extends Reference

# AI Interface

var vehicle #: Vehicle
var waypoint: Vector3
var target #: Vehicle


func init(p_vehicle):
	vehicle = p_vehicle
	waypoint = vehicle.translation


func process(_delta):
	pass
		
	
func debug_draw(debug):
	debug.global_transform = Transform.IDENTITY
	debug.begin(Mesh.PRIMITIVE_LINE_LOOP)
	debug.set_color(Color.green)
	for i in range(16):
		var r = i * PI / 8
		debug.add_vertex(Vector3(cos(r), 1, sin(r)) + waypoint)
	debug.end()
	debug.begin(Mesh.PRIMITIVE_LINES)
	debug.set_color(Color.green)
	debug.add_vertex(vehicle.translation)
	debug.add_vertex(waypoint)
	debug.end()
