extends Control


class ActionGroup:
	var input_name: String
	var button: BaseButton
	var actions: Array

	func _init(p_input_name: String, p_button: BaseButton, p_actions: Array
		) -> void:
		input_name = p_input_name
		button = p_button
		actions = p_actions

	func get_input_flags() -> int:
		return actions[0].input_flags

	func get_thumbnail() -> Texture:
		return actions[0].thumbnail

	func get_name() -> String:
		return actions[0].name


const SHORTCUT_PREFIX = "campaign_shortcut_"
const SHORTCUT_COUNT = 10
const SELECTED_UNIT_ICON := preload("res://addons/crosshairs/image0063.png")
export var team := "Player"
export var camera: NodePath
var selected_units = [] setget set_selected_units
onready var game_master = OwnWar.GameMaster.get_game_master(self)

var _selecting_units = false
var _mouse_position_start
var _last_mouse_position
var _units_teams_mask
var _current_action: ActionGroup
var _append_action = false
var _scroll = 0
var _unit_info_index = 0
onready var _camera: Camera = get_node(camera)
onready var _actions: Control = $Box/Actions


func _ready():
	assert(_camera != null)


func _process(_delta):
	set_unit_info()
	update()


func _unhandled_input(event):
	if event.is_action("campaign_append_action"):
		_append_action = event.pressed
		get_tree().set_input_as_handled()
	if event.is_action_pressed("campaign_debug"):
		if event.pressed:
			Debug.visible = not Debug.visible
		get_tree().set_input_as_handled()
	if event.is_action_pressed("ui_cancel"):
		if _current_action != null:
			if event.pressed:
				clear_action_button()
			get_tree().set_input_as_handled()


func _gui_input(event):
	if event.is_action("campaign_primary"):
		if _current_action != null:
			match _current_action.input_name:
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
					assert(false)
		else:
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
	show_feedback()
	show_action_feedback()
	for unit in selected_units:
		if (unit.translation - _camera.translation).dot(-_camera.transform.basis.z) > 0:
			var position = _camera.unproject_position(unit.translation)
			var rect = Rect2(position - Vector2.ONE * 32, Vector2.ONE * 64)
			draw_texture_rect(SELECTED_UNIT_ICON, rect, false, Color.orange)
	if _selecting_units:
		var rect = Rect2(_mouse_position_start, _last_mouse_position - _mouse_position_start)
		#draw_texture_rect(SELECTED_UNIT_ICON, rect, false, Color.purple)
		draw_rect(rect, Color.purple, false, 2)
		var units
		var color
		if _current_action == null:
			units = get_selected_units(PoolStringArray([team]))
			color = Color.green
		else:
			units = get_selected_units(_units_teams_mask)
			color = Color.red
		for unit in units:
			var position = _camera.unproject_position(unit.translation)
			rect = Rect2(position - Vector2.ONE * 32, Vector2.ONE * 64)
			draw_texture_rect(SELECTED_UNIT_ICON, rect, false, color)


func filter_units():
	for child in _actions.get_children():
		child.queue_free()

	if len(selected_units) == 0:
		return

	var unique_units = {}
	for unit in selected_units:
		unique_units[unit.unit_name] = unit

	if len(unique_units) == 1:
		set_action_buttons(selected_units[0].unit_name)
		return

	var shortcut_index = 0
	for unit_name in unique_units:
		var button := TextureButton.new()
		var unit: OwnWar.Unit = unique_units[unit_name]
		var tex := ImageTexture.new()
		if unit is OwnWar.Vehicle:
			var v: OwnWar.Vehicle = unit
			var _imm := OwnWar_Thumbnail.get_vehicle_thumbnail_async(
				v.get_file_path(),
				funcref(tex, "create_from_image")
			)
		else:
			var _imm := OwnWar_Thumbnail.get_unit_thumbnail_async(
				unit_name,
				funcref(tex, "create_from_image")
			)
		button.texture_normal = tex
		var e := button.connect("pressed", self, "set_action_buttons", [unit_name])
		assert(e == OK)
		if shortcut_index < SHORTCUT_COUNT:
			var input_event = InputEventAction.new()
			input_event.action = SHORTCUT_PREFIX + str(shortcut_index)
			button.shortcut = ShortCut.new()
			button.shortcut.shortcut = input_event
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

	# Get and group actions first
	var unit_actions := []
	for unit in selected_units:
		if sub_action == null:
			unit_actions.append(unit.get_actions())
		else:
			var act = sub_action.call_funcv([get_modifier_flags()] + arguments)
			unit_actions.append(act)

	var action_groups := []
	for i in range(len(unit_actions[0])):
		var a := []
		for act in unit_actions:
			a.append(act[i])
		action_groups.append(ActionGroup.new("", null, a))

	var unit = selected_units[0]
	var shortcut_index = 0
	for ag in action_groups:
		var action_group: ActionGroup = ag
		var button := TextureButton.new()
		button.enabled_focus_mode = BaseButton.FOCUS_NONE
		if action_group.get_thumbnail() != null:
			button.texture_normal = action_group.get_thumbnail()
		else:
			button.texture_normal = preload("../designer/ellipsis.png")
		button.rect_min_size = Vector2(96, 96)
		button.hint_tooltip = action_group.get_name()
		action_group.button = button
		var input_flags := action_group.get_input_flags()
		if input_flags & OwnWar.Unit.Action.SUBACTION:
			action_group.input_name = "sub_action"
			var e := button.connect(
				"pressed",
				self,
				"set_action_buttons",
				[
					unit_name,
					action_group.actions[0].function,
					action_group.actions[0].arguments
				]
			)
			assert(e == OK)
		elif input_flags & OwnWar.Unit.Action.INPUT_COORDINATE:
			action_group.input_name = "coordinate"
			var e := button.connect(
				"pressed",
				self,
				"get_coordinate",
				[action_group]
			)
			assert(e == OK)
			button.toggle_mode = true
		elif input_flags & OwnWar.Unit.Action.INPUT_UNITS:
			action_group.input_name = "units"
			if input_flags & OwnWar.Unit.Action.INPUT_ENEMY_UNITS:
				_units_teams_mask = []
				for t in game_master.teams:
					if t != team:
						_units_teams_mask.append(t)
			else:
				_units_teams_mask = [team]
			var e := button.connect(
				"pressed",
				self,
				"get_units",
				[action_group]
			)
			assert(e == OK)
			button.toggle_mode = true
		elif input_flags & OwnWar.Unit.Action.INPUT_TOGGLE:
			action_group.input_name = "toggle"
			var e := button.connect(
				"pressed",
				self,
				"send_toggle",
				[action_group]
			)
			assert(e == OK)
			button.toggle_mode = true
			button.pressed = action_group.actions[0].pressed
		else:
			action_group.input_name = "plain"
			var e := button.connect(
				"pressed",
				self,
				"send_plain",
				[action_group]
			)
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


func get_coordinate(action_group: ActionGroup) -> void:
	assert(action_group != null)
	if action_group == _current_action:
		clear_action_button()
		return
	clear_action_button()
	_current_action = action_group
	_current_action.button.pressed = true
	var cursor: Texture = action_group.actions[0].cursor
	if cursor != null:
		Input.set_custom_mouse_cursor(cursor, 0, cursor.get_size() / 2.0)


func get_units(action_group: ActionGroup) -> void:
	assert(action_group != null)
	if action_group == _current_action:
		clear_action_button()
		return
	clear_action_button()
	_current_action = action_group
	_current_action.button.pressed = true
	var cursor: Texture = action_group.actions[0].cursor
	if cursor != null:
		Input.set_custom_mouse_cursor(cursor, 0, cursor.get_size() / 2.0)


func send_coordinate(coordinate: Vector3) -> void:
	for a in _current_action.actions:
		var action: OwnWar.Action = a
		var arguments = [get_modifier_flags(), coordinate]
		if action.input_flags & OwnWar.Unit.Action.INPUT_SCROLL:
			arguments += [_scroll]
		arguments += action.arguments
		action.function.call_funcv(arguments)
	clear_action_button()


func send_units(units: Array) -> void:
	for a in _current_action.actions:
		var action: OwnWar.Action = a
		var arguments = [get_modifier_flags(), units] + action.arguments
		action.function.call_funcv(arguments)
	clear_action_button()


func send_toggle(action_group: ActionGroup) -> void:
	for action in action_group.actions:
		var arguments = [get_modifier_flags(), action_group.button.pressed] + \
			action.arguments
		action.function.call_funcv(arguments)


func send_plain(action_group: ActionGroup) -> void:
	for action in action_group.actions:
		var arguments = [get_modifier_flags()] + action.arguments
		action.function.call_funcv(arguments)


func clear_action_button():
	if _current_action != null:
		_current_action.button.pressed = false
		_current_action = null
	Input.set_custom_mouse_cursor(null)


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
		unit.show_feedback(self)


func show_action_feedback():
	if _current_action != null:
		match _current_action.input_name:
			"coordinate":
				var origin = _camera.project_ray_origin(_last_mouse_position)
				var normal = _camera.project_ray_normal(_last_mouse_position)
				var space_state = _camera.get_world().direct_space_state
				var result = space_state.intersect_ray(origin, origin + \
						normal * 1_000_000)
				if len(result) > 0:
					for a in _current_action.actions:
						var action: OwnWar.Action = a
						if action.feedback != null:
							var arguments := [
								self,
								get_modifier_flags(),
								result.position,
							]
							if action.input_flags & OwnWar.Unit.Action.INPUT_SCROLL:
								arguments += [_scroll]
							arguments += action.arguments
							action.feedback.call_funcv(arguments)
			"units":
				pass
			_:
				assert(false)


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
