tool
extends ScrollContainer


export var _list := NodePath()

var selected_action := []

onready var list: Control = get_node(_list)


func _ready() -> void:
	var actions := Array(InputMap.get_actions())
	actions.sort()
	for action in actions:
		if action.begins_with("ui_"):
			# Don't bother with redundant ui_ actions (also prevents setting ui_cancel by accident)
			continue
		var box := HBoxContainer.new()
		var name_s := Label.new()
		var value := Button.new()
		name_s.text = Util.humanize_file_name(action)
		name_s.size_flags_horizontal = SIZE_EXPAND_FILL
		value.text = "N/A"
		for input in InputMap.get_action_list(action):
			value.text = _event_to_string(input)
			break
		value.size_flags_horizontal = SIZE_EXPAND_FILL
		value.shortcut_in_tooltip = false
		var e := value.connect("pressed", value, "set", ["text", "Press a key..."])
		assert(e == OK)
		e = value.connect("pressed", self, "set", ["selected_action", [value, action]])
		assert(e == OK)
		box.add_child(name_s)
		box.add_child(value)
		list.add_child(box)


func _input(event: InputEvent) -> void:
	if len(selected_action) > 0 and (event is InputEventKey or event is InputEventMouseButton):
		var button: Button = selected_action[0]
		var action: String = selected_action[1]
		if event is InputEventKey and event.scancode == KEY_ESCAPE:
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, InputEvent.new())
			button.text = "N/A"
		else:
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, event)
			button.text = _event_to_string(event)
		button.release_focus()
		selected_action = []
		OwnWar_Settings.dirty = true


func _event_to_string(event: InputEvent) -> String:
	if event is InputEventKey:
		return event.as_text()
	elif event is InputEventMouseButton:
		var text: String = "Mouse button %d" % event.button_index
		match event.button_index:
			BUTTON_LEFT:
				text += " (left)"
			BUTTON_RIGHT:
				text += " (right)"
			BUTTON_MIDDLE:
				text += " (middle)"
			BUTTON_XBUTTON1:
				text += " (extra 1)"
			BUTTON_XBUTTON2:
				text += " (extra 2)"
			BUTTON_WHEEL_UP:
				text += " (wheel up)"
			BUTTON_WHEEL_DOWN:
				text += " (wheel down)"
			BUTTON_WHEEL_LEFT:
				text += " (wheel left)"
			BUTTON_WHEEL_RIGHT:
				text += " (wheel right)"
		return text
	return "N/A"
