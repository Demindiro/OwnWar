class_name AI

extends Reference

# AI Interface

var waypoints := []
# warning-ignore:unused_class_variable
var targets := []


func init(_mainframe):
	pass


func process(_mainframe, _delta):
	pass
		
	
func debug_draw(mainframe, debug):
	var start_vertex = mainframe.vehicle.translation + Vector3.UP * 0.1
	for waypoint in waypoints:
		waypoint += Vector3.UP * 0.1
		debug.draw_line(start_vertex, waypoint, Color.green)
		debug.draw_circle(waypoint, Color.green)
		start_vertex = waypoint
