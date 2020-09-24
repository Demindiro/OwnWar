extends Control


export(GDScript) var ai
export var team := 0

var selected_units = []

onready var game_master = get_tree().get_current_scene()

var _selecting_units = false
var _mouse_position_start
var _last_mouse_position

onready var _action_button_template := find_node("Template")


func _ready():
	_action_button_template.get_parent().remove_child(_action_button_template)


func _process(_delta):
	if len(selected_units) > 0:
		update()
	$Resources.text = str(game_master.material_count[team])


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
							if unit is Vehicle:
								unit.ai.target = enemy_units[0]
					else:
						for unit in selected_units:
							if unit is Vehicle:
								unit.ai.target = null
				else:
					selected_units = units
					set_action_buttons(units)
			$Camera.enabled = not _selecting_units
			update()
		elif event.is_action_pressed("campaign_set_waypoint"):
			var origin = $Camera.project_ray_origin(event.position)
			var normal = $Camera.project_ray_normal(event.position)
			var space_state = game_master.get_world().direct_space_state
			var result = space_state.intersect_ray(origin, origin + normal * 1000)
			if len(result) > 0:
				for unit in selected_units:
					if unit is Vehicle:
						unit.ai.waypoint = result.position
			update()
		elif event.is_action_pressed("campaign_debug"):
			$Debug.visible = not $Debug.visible
	elif event is InputEventMouseMotion:
		_last_mouse_position = event.position
		if _selecting_units:
			update()
			

func _exit_tree():
	_action_button_template.free()
			
			
func set_action_buttons(units):
	var common_actions = null
	for unit in units:
		var actions = unit.get_actions()
		if common_actions == null:
			common_actions = actions
		else:
			for action in common_actions:
				if not action in actions:
					common_actions.erase(action)
	for child in $Actions/HBoxContainer.get_children():
		child.queue_free()
	if common_actions == null:
		return
	for action in common_actions:
		var button = _action_button_template.duplicate()
		button.text = action[0]
		for unit in units:
			button.connect("pressed", unit, action[1], action.slice(2, len(action) - 1))
		$Actions/HBoxContainer.add_child(button)


func load_vehicle(path):
	var vehicle = load(Global.SCENE_VEHICLE).instance()
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
	for child in game_master.get_children():
		if child is Unit and rect.has_point(
				$Camera.unproject_position(child.translation)):
			units.append(child)
	return units


func _on_HUD_draw():
	if _selecting_units:
		var rect = Rect2(_mouse_position_start, _last_mouse_position - _mouse_position_start)
		draw_rect(rect, Color.purple, false, 2)
	for unit in selected_units:
		if (unit.translation - $Camera.translation).dot(-$Camera.transform.basis.z) > 0:
			var position = $Camera.unproject_position(unit.translation)
			var rect = Rect2(position - Vector2.ONE * 25, Vector2.ONE * 50)
			draw_rect(rect, Color.orange, false, 2)
