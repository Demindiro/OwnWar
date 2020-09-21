extends Spatial


func _ready():
	$Vehicle.load_from_file("user://vehicles/apc.json")


func _input(event):
	if event is InputEventMouseButton and event.button_index == 1 and event.pressed:
		var position = get_viewport().get_mouse_position()
#		var origin = $Camera.project_ray_origin(event.global_position)
#		var normal = $Camera.project_ray_normal(event.global_position)
		var origin = $Camera.project_ray_origin(position)
		var normal = $Camera.project_ray_normal(position)
		var space_state := get_world().direct_space_state
		var result = space_state.intersect_ray(origin, origin + normal * 1000)
		if len(result) == 0:
			print("Waypoint ray did not hit an object")
		else:
			print("Setting waypoint to " + str(result.position))
			$Vehicle.ai.waypoint = result.position
