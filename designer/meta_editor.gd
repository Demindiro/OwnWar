extends "res://menu/dialog/independent_panel.gd"


var _meta_types := {}
var _meta_data := {}
var _meta_fields := {}
var _escape_pressed := false


signal meta_changed(meta_data)


func _unhandled_input(event):
	if not visible:
		return
	if event.is_action("ui_cancel") or event.is_action("designer_configure"):
		if event.pressed:
			_escape_pressed = true
		elif _escape_pressed:
			visible = false
			_escape_pressed = false


func set_meta_items(block, meta_data):
	_meta_types = {}
	for meta_name in block.meta:
		_meta_types[meta_name] = typeof(block.meta[meta_name])
		if meta_name in meta_data:
			assert(typeof(meta_data[meta_name]) == _meta_types[meta_name])
			_meta_data[meta_name] = meta_data[meta_name]
		else:
			_meta_data[meta_name] = block.meta[meta_name]
		
		for child in $GridContainer.get_children():
			child.queue_free()
			$GridContainer.remove_child(child)
		
		var label = Label.new()
		label.text = meta_name
		$GridContainer.add_child(label)
		var edit = LineEdit.new()
		edit.text = str(_meta_data[meta_name])
		edit.connect("text_changed", self, "_field_changed", [meta_name])
		$GridContainer.add_child(edit)
		_meta_fields[meta_name] = edit


func _field_changed(new_text, meta_name):
	var converted_data
	match _meta_types[meta_name]:
		TYPE_INT:
			if new_text.is_valid_integer():
				converted_data = int(new_text)
			else:
				_revert_field_change(meta_name)
		_:
			push_error("Invalid meta type")
			assert(false)
			return
	_meta_data[meta_name] = converted_data
	emit_signal("meta_changed", _meta_data)


func _revert_field_change(meta_name):
	var text: String
	var data = _meta_data[meta_name]
	match _meta_types[meta_name]:
		TYPE_INT:
			text = str(data)
		_:
			push_error("Invalid meta type")
			assert(false)
			return
	_meta_fields[meta_name].text = text
