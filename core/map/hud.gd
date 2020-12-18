extends Control


const SHORTCUT_PREFIX = "campaign_shortcut_"
const SHORTCUT_COUNT = 10
export var team := "Player"
export var camera: NodePath
var selected_units = [] setget set_selected_units
onready var game_master = OwnWar.GameMaster.get_game_master(self)

var _selecting_units = false
var _mouse_position_start
var _last_mouse_position
var _units_teams_mask
var _action_input_name
var _action_button
var _action
var _append_action = false
var _scroll = 0
var _unit_info_index = 0
onready var _camera: Camera = get_node(camera)
onready var _fps_label: Label = $FPS
onready var _drawcalls_label: Label = $DrawCalls
onready var _actions: Control = $Box/Actions


func _ready():
	assert(_camera != null)


func _process(_delta):
	if len(selected_units) > 0 or _selecting_units:
		update()
	_fps_label.text = "FPS: " + str(Engine.get_frames_per_second())
	var draw_calls = get_tree().root.get_render_info(Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	_drawcalls_label.text = "Draw calls: " + str(draw_calls)
	set_unit_info()
	show_feedback()
	show_action_feedback()
	# Temporary hack to show changed ImageTextures and force the scale to 0.5
	for child in _actions.get_children():
		child.update()


func _unhandled_input(event):
	if event.is_action("campaign_append_action"):
		_append_action = event.pressed
		get_tree().set_input_as_handled()
	if event.is_action_pressed("campaign_debug"):
		if event.pressed:
			Debug.visible = not Debug.visible
		get_tree().set_input_as_handled()
	if event.is_action_pressed("ui_cancel"):
		if _action_button != null:
			if event.pressed:
				clear_action_button()
			get_tree().set_input_as_handled()


func _gui_input(event):
	if event.is_action("campaign_primary"):
		match _action_input_name:
			"coordinate":
				if not event.pressed:
					var origin = _camera.project_ray_origin(event.position)
					var normal = _camera.project_ray_normal(event.position)
					var space_state = _camera.get_world().direct_space_state
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
					set_selected_units(get_selected_units(PoolStringArray([team])))
					filter_units()
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
		if (unit.translation - _camera.translation).dot(-_camera.transform.basis.z) > 0:
			var position = _camera.unproject_position(unit.translation)
			var rect = Rect2(position - Vector2.ONE * 25, Vector2.ONE * 50)
			draw_rect(rect, Color.orange, false, 2)
#		if unit is Vehicle and unit.ai.target != null and \
#				(unit.ai.target.translation - _camera.translation).dot(-_camera.transform.basis.z) > 0:
#			var position = _camera.unproject_position(unit.ai.target.translation)
#			var rect = Rect2(position - Vector2.ONE * 25, Vector2.ONE * 50)
#			draw_rect(rect, Color.red, false, 2)
	if _selecting_units:
		var rect = Rect2(_mouse_position_start, _last_mouse_position - _mouse_position_start)
		draw_rect(rect, Color.purple, false, 2)
		var units
		var color
		if _action_input_name == null:
			units = get_selected_units(PoolStringArray([team]))
			color = Color.green
		else:
			units = get_selected_units(_units_teams_mask)
			color = Color.red
		for unit in units:
			var position = _camera.unproject_position(unit.translation)
			rect = Rect2(position - Vector2.ONE * 25, Vector2.ONE * 50)
			draw_rect(rect, color, false, 2)


func filter_units():
	for child in _actions.get_children():
		child.queue_free()

	if len(selected_units) == 0:
		return

	var unique_units = {}
	for unit in selected_units:
		unique_units[unit.unit_name] = null

	if len(unique_units) == 1:
		set_action_buttons(selected_units[0].unit_name)
		return

	var shortcut_index = 0
	for unit_name in unique_units:
		var button := Button.new()
		button.text = unit_name
		var e := button.connect("pressed", self, "set_action_buttons", [unit_name])
		assert(e == OK)
		if shortcut_index < SHORTCUT_COUNT:
			var input_event = InputEventAction.new()
			input_event.action = SHORTCUT_PREFIX + str(shortcut_index)
			button.shortcut = ShortCut.new()
			button.shortcut.shortcut = input_event
			button.text += " (" + str((shortcut_index + 1) % 10) + ")"
			shortcut_index += 1
		_actions.add_child(button)


func set_action_buttons(unit_name: String, sub_action: FuncRef = null,
		arguments := []) -> void:
	var filtered_units = []
	for unit in selected_units:
		if unit.unit_name == unit_name:
			filtered_units.append(unit)
	set_selected_units(filtered_units)

	clear_action_button()
	for child in _actions.get_children():
		child.queue_free()

	if len(selected_units) == 0:
		return

	var unit = selected_units[0]
	var shortcut_index = 0
	for r_action in unit.get_actions() if sub_action == null else \
			sub_action.call_funcv([get_modifier_flags()] + arguments):
		var action: OwnWar.Action = r_action

		var button := TextureButton.new()
		if action.thumbnail != null:
			button.texture_normal = action.thumbnail
		else:
			button.texture_normal = preload("../designer/ellipsis.png")
		button.rect_min_size = Vector2(96, 96)
		button.hint_tooltip = action.name
		if action.input_flags & OwnWar.Unit.Action.SUBACTION:
			var e := button.connect("pressed", self, "set_action_buttons",
				[unit_name, action.function, action.arguments])
			assert(e == OK)
		elif action.input_flags & OwnWar.Unit.Action.INPUT_COORDINATE:
			var e := button.connect("pressed", self, "get_coordinate",
				[button, action])
			assert(e == OK)
			button.toggle_mode = true
		elif action.input_flags & OwnWar.Unit.Action.INPUT_UNITS:
			if action.input_flags & OwnWar.Unit.Action.INPUT_ENEMY_UNITS:
				_units_teams_mask = []
				for t in game_master.teams:
					if t != team:
						_units_teams_mask.append(t)
			else:
				_units_teams_mask = [team]
			var e := button.connect("pressed", self, "get_units",
				[button, action])
			assert(e == OK)
			button.toggle_mode = true
		elif action.input_flags & OwnWar.Unit.Action.INPUT_TOGGLE:
			var e := button.connect("pressed", self, "send_toggle",
				[button, action])
			assert(e == OK)
			button.toggle_mode = true
			button.pressed = action.pressed
		else:
			var e := button.connect("pressed", self, "send_plain", [action])
			assert(e == OK)

		if shortcut_index < SHORTCUT_COUNT:
			var input_event = InputEventAction.new()
			input_event.action = SHORTCUT_PREFIX + str(shortcut_index)
			button.shortcut = ShortCut.new()
			button.shortcut.shortcut = input_event
			#button.text += " (" + str((shortcut_index + 1) % 10) + ")"
			shortcut_index += 1

		_actions.add_child(button)

	var button := Button.new()
	var input_event := InputEventAction.new()
	input_event.action = SHORTCUT_PREFIX + "cancel"
	button.text = "X"
	button.shortcut = ShortCut.new()
	button.shortcut.shortcut = input_event
	if sub_action == null:
		var e := button.connect("pressed", self, "clear_units")
		assert(e == OK)
	else:
		var e := button.connect("pressed", self, "set_action_buttons", [unit.unit_name])
		assert(e == OK)
	_actions.add_child(button)


func get_coordinate(button: BaseButton, action: OwnWar.Action) -> void:
	assert(button != null)
	if button == _action_button:
		clear_action_button()
		return
	clear_action_button()
	_action_input_name = "coordinate"
	_action_button = button
	_action = action
	button.pressed = true


func get_units(button: BaseButton, action: OwnWar.Action) -> void:
	assert(button != null)
	if button == _action_button:
		clear_action_button()
		return
	clear_action_button()
	_action_input_name = "units"
	_action_button = button
	_action = action
	button.pressed = true


func send_coordinate(coordinate: Vector3) -> void:
	for unit in selected_units:
		var arguments = [get_modifier_flags(), coordinate]
		if _action.input_flags & OwnWar.Unit.Action.INPUT_SCROLL:
			arguments += [_scroll]
		arguments += _action.arguments
		_action.function.call_funcv(arguments)
	clear_action_button()


func send_units(units: Array) -> void:
	for unit in selected_units:
		var arguments = [get_modifier_flags(), units] + _action.arguments
		_action.function.call_funcv(arguments)
	clear_action_button()


func send_toggle(button: BaseButton, action: OwnWar.Action) -> void:
	for unit in selected_units:
		var arguments = [get_modifier_flags(), button.pressed] + action.arguments
		action.function.call_funcv(arguments)


func send_plain(action: OwnWar.Action) -> void:
	for unit in selected_units:
		var arguments = [get_modifier_flags()] + action.arguments
		action.function.call_funcv(arguments)


func clear_action_button():
	if _action_button:
		_action_button.pressed = false
	_action_input_name = null
	_action_button = null
	_action = null


func get_selected_units(teams_mask: PoolStringArray) -> Array:
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
	for t in game_master.get_teams():
		if t in teams_mask:
			for child in game_master.get_units(t):
				var screen_pos = _camera.unproject_position(child.translation)
				if rect.has_point(screen_pos):
					var direction: Vector3 = _camera.translation - child.translation
					if _camera.transform.basis.z.dot(direction) > 0:
						units.append(child)
	return units


func set_selected_units(units):
	for unit in selected_units:
		unit.disconnect("destroyed", self, "_unit_destroyed")
		unit.hide_feedback()
	for unit in units:
		unit.connect("destroyed", self, "_unit_destroyed")
	selected_units = units


func get_modifier_flags():
	var flags = 0
	flags |= 0x1 if _append_action else 0
	return flags


func set_unit_info():
	for child in $UnitInfo/GridContainer.get_children():
		child.queue_free()
	if len(selected_units) == 0:
		return
	if _unit_info_index >= len(selected_units):
		_unit_info_index = 0
	elif _unit_info_index < 0:
		_unit_info_index = len(selected_units) - 1
	var unit_info = selected_units[_unit_info_index].get_info()
	for key in unit_info:
		var label_key = Label.new()
		var label_value = Label.new()
		label_key.text = key
		label_value.text = str(unit_info[key])
		label_key.clip_text = true
		label_value.clip_text = true
		label_key.size_flags_horizontal = Label.SIZE_EXPAND_FILL
		label_value.size_flags_horizontal = Label.SIZE_EXPAND_FILL
		label_value.align = Label.ALIGN_RIGHT
		$UnitInfo/GridContainer.add_child(label_key)
		$UnitInfo/GridContainer.add_child(label_value)


func clear_units():
	set_selected_units([])
	filter_units()
	update()


func show_feedback():
	for unit in selected_units:
		unit.show_feedback()


func show_action_feedback():
	match _action_input_name:
		"coordinate":
			var origin = _camera.project_ray_origin(_last_mouse_position)
			var normal = _camera.project_ray_normal(_last_mouse_position)
			var space_state = _camera.get_world().direct_space_state
			var result = space_state.intersect_ray(origin, origin + \
					normal * 1_000_000)
			if len(result) > 0:
				for unit in selected_units:
					if _action.feedback != null:
						var arguments := [
							_camera.get_viewport(),
							get_modifier_flags(),
							result.position,
						]
						if _action.input_flags & OwnWar.Unit.Action.INPUT_SCROLL:
							arguments += [_scroll]
						arguments += _action.arguments
						_action.feedback.call_funcv(arguments)
		"units":
			pass
		_:
			pass


func _unit_destroyed(unit):
	selected_units.erase(unit)
	set_action_buttons(selected_units)
	update()


func _on_Designer_load_game(data):
	var transform: String = data.get("camera_transform", "")
	if transform != "":
		_camera.set_transform(str2var(transform))


func _on_Designer_save_game(data):
	data["camera_transform"] = var2str(_camera.global_transform)
