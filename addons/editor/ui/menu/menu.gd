tool
extends EditorPlugin


class MenuInspector:	
	extends EditorInspectorPlugin
	
	
	class ButtonEditor:
		extends EditorProperty
		
		
		var vbox = VBoxContainer.new()
		var update = false
		var current_object = get_edited_object()
		
		
		func _ready():
			add_child(vbox)
			_update()
			
				
		func _update():
			current_object = get_edited_object()
			for child in vbox.get_children():
				child.queue_free()
			var buttons = get_edited_object()["buttons"]

			var edits_update = []
			for i in len(buttons):
				var edit_update = HBoxContainer.new()
				var edit_update_text = LineEdit.new()
				var edit_update_name  = LineEdit.new()
				edit_update_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				edit_update_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
				edit_update_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				edit_update_name.size_flags_vertical = Control.SIZE_EXPAND_FILL
				edit_update_text.text = buttons[i][0]
				edit_update_name.text = buttons[i][1]
				edit_update.add_child(edit_update_text)
				edit_update.add_child(edit_update_name)
				edit_update_text.connect("text_changed", self, "_update_button", [i, true])
				edit_update_name.connect("text_changed", self, "_update_button", [i, false])
				vbox.add_child(edit_update)
				add_focusable(edit_update_text)
				add_focusable(edit_update_name)
				edits_update.append([edit_update_text, edit_update_name])

#			var confirm_update = Button.new()
#			confirm_update.text = "Update"
#			confirm_update.connect("pressed", self, "_update_button", [edits_update])
#			vbox.add_child(confirm_update)

			var edit_add = HBoxContainer.new()
			var edit_add_text = LineEdit.new()
			var edit_add_name  = LineEdit.new()
			edit_add_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			edit_add_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
			edit_add_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			edit_add_name.size_flags_vertical = Control.SIZE_EXPAND_FILL
			edit_add.add_child(edit_add_text)
			edit_add.add_child(edit_add_name)
			vbox.add_child(edit_add)
			add_focusable(edit_add)

			var confirm_add = Button.new()
			confirm_add.text = "Add"
			confirm_add.connect("pressed", self, "_add_button", [[edit_add_text, edit_add_name]])
			vbox.add_child(confirm_add)
			
		
		func _update_button(new_text, index, edit_text = true):
			var buttons = get_edited_object()["buttons"]
			buttons[index][0 if edit_text else 1] = new_text
			update = false
			emit_changed(get_edited_property(), buttons)

		
		func _add_button(edit_add):
			var buttons = get_edited_object()["buttons"]
			buttons.append([edit_add[0].text, edit_add[1].text])
			update = true
			emit_changed(get_edited_property(), buttons)
			
		
		func update_property():
			var new_value = get_edited_object()[get_edited_property()]
			if update or current_object != get_edited_object():
				_update()
				
	
	class TitleEditor:
		extends EditorProperty
		
		
		var edit = LineEdit.new()
		
		
		func _ready():
			add_child(edit)
			add_focusable(edit)
			edit.connect("text_changed", self, "_set_title")
			
		
		func _set_title(new_text):
			get_edited_object()["title"] = new_text
			
			
		func update_property():
			edit.text = get_edited_object()["title"]

	
	func can_handle(object):
		return object is preload("res://menu/menu/menu.gd")
		
		
	func parse_property(object, type, path, hint, hint_text, usage):
		if type == TYPE_ARRAY:
			add_property_editor(path, ButtonEditor.new())
			return true
		elif type == TYPE_STRING:
			add_property_editor(path, TitleEditor.new())
			return true
		return false


var plugin


func _enter_tree():
	plugin = MenuInspector.new()
	add_inspector_plugin(plugin)


func _exit_tree():
	remove_inspector_plugin(plugin)
