class_name AI

extends Reference

# AI Interface

var vehicle: Vehicle
var waypoints := []
# warning-ignore:unused_class_variable
var targets := []


func init(p_vehicle):
	vehicle = p_vehicle


func process(_delta):
	pass
		
	
func debug_draw(debug):
	var start_vertex = vehicle.translation + Vector3.UP * 0.1
	for waypoint in waypoints:
		waypoint += Vector3.UP * 0.1
		debug.draw_line(start_vertex, waypoint, Color.green)
		debug.draw_circle(waypoint, Color.green)
		start_vertex = waypoint
