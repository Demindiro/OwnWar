extends Spatial


export(PackedScene) var vehicle_template
export(GDScript) var ai

var selected_units = []

var _selecting_units = false
var _mouse_position_start
var _last_mouse_position


func _ready():
	$Vehicle.load_from_file("user://vehicles/apc.json")
	var wall = vehicle_template.instance()
	wall.translation = Vector3.UP * 10 + Vector3.FORWARD * 10
	wall.call_deferred("rotate_y", PI)
	wall.load_from_file("user://vehicles/wall.json")
	wall.name = "Wall"
	wall.axis_lock_linear_y = true
	wall.axis_lock_angular_x = true
	wall.axis_lock_angular_y = true
	wall.axis_lock_angular_z = true
	add_child(wall)


func _process(_delta):
	$Vehicle.ai.target = $Wall
	if len(selected_units) > 0:
		$HUD.update()


func _input(event):
	if event.is_action_type():
		if event.is_action("campaign_select_units"):
			if event.pressed:
				_mouse_position_start = _last_mouse_position
				_selecting_units = true
			else:
				var units = get_selected_units()
				_selecting_units = false
				if Input.is_action_pressed("campaign_attack"):
					var enemy_units = get_selected_units()
					_selecting_units = false
					if len(enemy_units) > 0:
						for unit in selected_units:
							unit.ai.target = enemy_units[0]
					else:
						for unit in selected_units:
							unit.ai.target = null
				else:
					selected_units = units
			$Camera.enabled = not _selecting_units
			$HUD.update()
		elif event.is_action_pressed("campaign_set_waypoint"):
			var origin = $Camera.project_ray_origin(event.position)
			var normal = $Camera.project_ray_normal(event.position)
			var space_state := get_world().direct_space_state
			var result = space_state.intersect_ray(origin, origin + normal * 1000)
			if len(result) > 0:
				for unit in selected_units:
					unit.ai.waypoint = result.position
			$HUD.update()
		elif event.is_action_pressed("campaign_debug"):
			$Debug.visible = not $Debug.visible
	elif event is InputEventMouseMotion:
		_last_mouse_position = event.position
		if _selecting_units:
			$HUD.update()


func load_vehicle(path):
	var vehicle = vehicle_template.instance()
	vehicle.ai_script = ai
	vehicle.load_from_file(path)
	vehicle.debug = true
	add_child(vehicle)
	vehicle.translation.y = 3


func get_selected_units():
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
	var units = []
	for child in get_children():
		if child is Vehicle and rect.has_point(
				$Camera.unproject_position(child.translation)):
			units.append(child)
	return units


func _on_HUD_draw():
	if _selecting_units:
		var rect = Rect2(_mouse_position_start, _last_mouse_position - _mouse_position_start)
		$HUD.draw_rect(rect, Color.purple, false, 2)
	for unit in selected_units:
		if (unit.translation - $Camera.translation).dot(-$Camera.transform.basis.z) > 0:
			var position = $Camera.unproject_position(unit.translation)
			var rect = Rect2(position - Vector2.ONE * 25, Vector2.ONE * 50)
			$HUD.draw_rect(rect, Color.orange, false, 2)
