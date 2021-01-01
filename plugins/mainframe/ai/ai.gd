extends Reference

# AI Interface

var waypoints := []
# warning-ignore:unused_class_variable
var targets := []


func init(_mainframe):
	pass


func process(_mainframe, _delta):
	pass


func debug_draw(mainframe):
	var start_vertex = mainframe.vehicle.translation + Vector3.UP * 0.1
	for waypoint in waypoints:
		waypoint += Vector3.UP * 0.1
		Debug.draw_line(start_vertex, waypoint, Color.green)
		Debug.draw_circle(waypoint, Color.green)
		start_vertex = waypoint


func serialize_json(_game_master) -> Dictionary:
	var w_list := []
	for w in waypoints:
		w_list.append(var2str(w))
	var t_list := []
	for t in targets:
		t_list.append(t.uid)
	return {
			"waypoints": w_list,
			"targets": t_list,
		}


func deserialize_json(game_master, data: Dictionary) -> void:
	waypoints = []
	targets = []
	for w in data["waypoints"]:
		waypoints.append(str2var(w))
	for t in data["targets"]:
		targets.append(game_master.get_unit_by_uid(t))
