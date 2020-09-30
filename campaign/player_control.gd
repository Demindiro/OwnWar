extends Control


const SHORTCUT_PREFIX = "campaign_shortcut_"
const SHORTCUT_COUNT = 10
export(GDScript) var ai
export var team := 0
var selected_units = [] setget set_selected_units
onready var game_master = get_tree().get_current_scene()

var _selecting_units = false
var _mouse_position_start
var _last_mouse_position
var _units_teams_mask
var _action_input_name
var _action_to_units
var _action_button
var _action_flags
var _append_action = false
var _scroll = 0
var _unit_info_index = 0

onready var _action_button_template := find_node("Template")


func _ready():
	_action_button_template.get_parent().remove_child(_action_button_template)


func _process(_delta):
	if len(selected_units) > 0 or _selecting_units:
		update()
	$FPS.text = "FPS: " + str(round(1.0 / _delta))
	set_unit_info()


func _unhandled_input(event):
	if event.is_action("campaign_append_action"):
		_append_action = event.pressed
	elif event.is_action("campaign_debug"):
		if event.pressed:
			$"../Debug".visible = not $"../Debug".visible
	elif event.is_action("ui_cancel"):
		if _action_button != null:
			if event.pressed:
				clear_action_button()


func _gui_input(event):
	if event.is_action("campaign_primary"):
		match _action_input_name:
			"coordinate":
				if not event.pressed:
					var origin = $Camera.project_ray_origin(event.position)
					var normal = $Camera.project_ray_normal(event.position)
					var space_state = game_master.get_world().direct_space_state
					var result = space_state.intersect_ray(origin, origin + normal * 1000)
					if len(result) > 0:
						send_coordinate(result.position)
			"units":
				if event.pressed:
					_selecting_units = true
					_mouse_position_start = _last_mouse_position
				else:
					_selecting_units = false
					var units = get_selected_units(_units_teams_mask)
					send_units(units)
			_:
				if event.pressed:
					_selecting_units = true
					_mouse_position_start = _last_mouse_position
				else:
					_selecting_units = false
					set_selected_units(get_selected_units(1 << team))
					set_action_buttons(selected_units)
					_unit_info_index = 0
					set_unit_info()
		update()
	elif event.is_action("campaign_scroll_up"):
		if event.pressed:
			_scroll += 1
	elif event.is_action("campaign_scroll_down"):
		if event.pressed:
			_scroll -= 1
	elif event is InputEventMouseMotion:
		_last_mouse_position = event.position
		if _selecting_units:
			update()


func _draw():
	for unit in selected_units:
		if (unit.translation - $Camera.translation).dot(-$Camera.transform.basis.z) > 0:
			var position = $Camera.unproject_position(unit.translation)
			var rect = Rect2(position - Vector2.ONE * 25, Vector2.ONE * 50)
			draw_rect(rect, Color.orange, false, 2)
		if unit is Vehicle and unit.ai.target != null and \
				(unit.ai.target.translation - $Camera.translation).dot(-$Camera.transform.basis.z) > 0:
			var position = $Camera.unproject_position(unit.ai.target.translation)
			var rect = Rect2(position - Vector2.ONE * 25, Vector2.ONE * 50)
			draw_rect(rect, Color.red, false, 2)
	if _selecting_units:
		var rect = Rect2(_mouse_position_start, _last_mouse_position - _mouse_position_start)
		draw_rect(rect, Color.purple, false, 2)
		var units
		var color
		if _action_input_name == null:
			units = get_selected_units(1 << team)
			color = Color.green
		else:
			units = get_selected_units(_units_teams_mask)
			color = Color.red
		for unit in units:
			var position = $Camera.unproject_position(unit.translation)
			rect = Rect2(position - Vector2.ONE * 25, Vector2.ONE * 50)
			draw_rect(rect, color, false, 2)


func _notification(notification):
	match notification:
		NOTIFICATION_PREDELETE:
			_action_button_template.free()


func set_action_buttons(units):
	clear_action_button()
	var action_to_units = {}
	var action_names = {}
	for unit in units:
		for action in unit.get_actions():
			var key = [action[0], action[1]]
			var value = [unit, action[2], action[3]]
			if action[1] & Unit.Action.INPUT_TOGGLE:
				value += [action[4]]
			if key in action_to_units:
				action_to_units[key].append(value)
			else:
				action_to_units[key] = [value]
	for child in $Actions.get_children():
		child.queue_free()
	var shortcut_index = 0
	for action in action_to_units:
		var button = _action_button_template.duplicate()
		button.text = action[0]
		if action[1] & Unit.Action.INPUT_COORDINATE:
			button.connect("pressed", self, "get_coordinate",
					[button, action_to_units[action], action[1]])
			button.toggle_mode = true
		elif action[1] & Unit.Action.INPUT_UNITS:
			if action[1] & Unit.Action.INPUT_ENEMY_UNITS:
				_units_teams_mask = ~(1 << team)
			else:
				_units_teams_mask = 1 << team
			button.connect("pressed", self, "get_units", [button, action_to_units[action]])
			button.toggle_mode = true
		elif action[1] & Unit.Action.INPUT_TOGGLE:
			button.connect("pressed", self, "send_toggle", [button, action_to_units[action]])
			button.toggle_mode = true
			button.pressed = action_to_units[action][0][3]
		else:
			button.connect("pressed", self, "send_plain", [action_to_units[action]])
		if shortcut_index < SHORTCUT_COUNT:
			var input_event = InputEventAction.new()
			input_event.action = SHORTCUT_PREFIX + str(shortcut_index)
			button.shortcut = ShortCut.new()
			button.shortcut.shortcut = input_event
			button.text += " (" + str((shortcut_index + 1) % 10) + ")"
			shortcut_index += 1
		$Actions.add_child(button)
		
		
func get_coordinate(button, action_to_units, action_flags):
	if button == _action_button:
		clear_action_button()
		return
	clear_action_button()
	_action_input_name = "coordinate"
	_action_button = button
	_action_to_units = action_to_units
	_action_flags = action_flags
	button.pressed = true
	
	
func get_units(button, action_to_units):
	if button == _action_button:
		clear_action_button()
		return
	clear_action_button()
	_action_input_name = "units"
	_action_button = button
	_action_to_units = action_to_units
	button.pressed = true
		
		
func send_coordinate(coordinate):
	for action in _action_to_units:
		var unit = action[0]
		var function = action[1]
		var arguments = [get_modifier_flags(), coordinate]
		if _action_flags & Unit.Action.INPUT_SCROLL:
			arguments += [_scroll]
		arguments += action[2]
		funcref(unit, function).call_funcv(arguments)
	
	
func send_units(units):
	for action in _action_to_units:
		var unit = action[0]
		var function = action[1]
		var arguments = [get_modifier_flags(), units] + action[2]
		funcref(unit, function).call_funcv(arguments)
		

func send_toggle(button, action_to_units):
	for action in action_to_units:
		var unit = action[0]
		var function = action[1]
		var arguments = [get_modifier_flags(), button.pressed] + action[2]
		funcref(unit, function).call_funcv(arguments)
		

func send_plain(action_to_units):
	for action in action_to_units:
		var unit = action[0]
		var function = action[1]
		var arguments = [get_modifier_flags()] + action[2]
		funcref(unit, function).call_funcv(arguments)


func clear_action_button():
	if _action_button:
		_action_button.pressed = false
	_action_input_name = null
	_action_button = null
	_action_to_units = null


func get_selected_units(teams_mask):
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
	for i in range(len(game_master.teams)):
		if teams_mask & (1 << i):
			for child in game_master.units[i]:
				if rect.has_point($Camera.unproject_position(child.translation)):
					units.append(child)
	return units


func set_selected_units(units):
	for unit in selected_units:
		unit.disconnect("destroyed", self, "_unit_destroyed")
	for unit in units:
		unit.connect("destroyed", self, "_unit_destroyed")
	selected_units = units


func get_modifier_flags():
	var flags = 0
	flags |= 0x1 if _append_action else 0
	return flags


func set_unit_info():
	if len(selected_units) == 0:
		return
	if _unit_info_index >= len(selected_units):
		_unit_info_index = 0
	elif _unit_info_index < 0:
		_unit_info_index = len(selected_units) - 1
	var unit_info = selected_units[_unit_info_index].get_info()
	for child in $UnitInfo/GridContainer.get_children():
		child.queue_free()
	for key in unit_info:
		var label_key = Label.new()
		var label_value = Label.new()
		label_key.text = key
		label_value.text = str(unit_info[key])
		label_key.clip_text = true
		label_value.clip_text = true
		label_key.size_flags_horizontal |= Label.SIZE_EXPAND_FILL
		label_value.size_flags_horizontal |= Label.SIZE_EXPAND_FILL
		label_value.align = Label.ALIGN_RIGHT
		$UnitInfo/GridContainer.add_child(label_key)
		$UnitInfo/GridContainer.add_child(label_value)


func _unit_destroyed(unit):
	selected_units.erase(unit)
	set_action_buttons(selected_units)
	update()
