extends Spatial


var selected_units = []

var _selecting_units = false
var _mouse_position_start
var _last_mouse_position


func _ready():
	$Vehicle.load_from_file("user://vehicles/apc.json")


func _process(_delta):
	if len(selected_units) > 0:
		$HUD.update()


func _input(event):
	if event.is_action_type():
		if event.is_action("campaign_select_units"):
			if event.pressed:
				_selecting_units = true
				_mouse_position_start = _last_mouse_position
			else:
				_selecting_units = false
				selected_units = []
				var start = _last_mouse_position
				var end = _mouse_position_start
				if start.x > end.x:
					var s = start.x
					start.x = end.x
					end.x = s
				if start.y > end.y:
					var s = start.y
					start.y = end.y
					end.y = s
				var rect = Rect2(start, end - start)
				for child in get_children():
					if child is Vehicle and rect.has_point(
							$Camera.unproject_position(child.translation)):
						selected_units.append(child) # Birds live here
				print("Selected %d units" % len(selected_units))
			$HUD.update()
		elif event.is_action_pressed("campaign_set_waypoint"):
			var origin = $Camera.project_ray_origin(event.position)
			var normal = $Camera.project_ray_normal(event.position)
			var space_state := get_world().direct_space_state
			var result = space_state.intersect_ray(origin, origin + normal * 1000)
			if len(result) == 0:
				print("Waypoint ray did not hit an object")
			else:
				print("Setting waypoint to " + str(result.position))
				for unit in selected_units:
					unit.ai.waypoint = result.position
	elif event is InputEventMouseMotion:
		_last_mouse_position = event.position
		if _selecting_units:
			$HUD.update()


func _on_HUD_draw():
	if _selecting_units:
		var rect = Rect2(_mouse_position_start, _last_mouse_position - _mouse_position_start)
		$HUD.draw_rect(rect, Color.purple, false, 2)
	for unit in selected_units:
		if (unit.translation - $Camera.translation).dot(-$Camera.transform.basis.z) > 0:
			var position = $Camera.unproject_position(unit.translation)
			var rect = Rect2(position - Vector2.ONE * 25, Vector2.ONE * 50)
			$HUD.draw_rect(rect, Color.orange, false, 2)
