extends PanelContainer


onready var _name_gui: LineEdit = get_node("Box/Name")


signal create_vehicle(name)


func goto_designer() -> void:
	var path := Util.filenamize_human_name(_name_gui.text)
	path = "user://vehicles".plus_file(path) + ".json"
	emit_signal("create_vehicle", path)


func activate() -> void:
	visible = true
	_name_gui.grab_focus()
