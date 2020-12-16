tool
extends "res://core/menu/dialog/independent_panel.gd"


signal save(path)
signal cancel()

export var save_directory := ""
var _path := ""
onready var _list: Control = $Box/Box/Box/Box
onready var _save: Button = $Box/Save
onready var _name: LineEdit = $Box/Name


func _ready() -> void:
	Util.free_children(_list)
	var files := Util.iterate_dir(save_directory, "json")
	for file in files:
		var button := Button.new()
		button.text = Util.humanize_file_name(file)
		var path := save_directory.plus_file(file)
		var e := button.connect("pressed", self, "_button_save", [button, path])
		assert(e == OK)
		_list.add_child(button)


func _button_save(button: Button, path: String) -> void:
	_name.text = button.text
	_save(path)


func _save(path: String) -> void:
	emit_signal("save", path)


func _create_saves_dir() -> void:
	var e := Util.create_dirs(save_directory)
	assert(e == OK)


func _on_Name_text_changed(new_text: String) -> void:
	_path = Util.filenamize_human_name(new_text) + ".json"
	_save.disabled = not _path.is_valid_filename()


func _on_Cancel_pressed() -> void:
	emit_signal("cancel")


func _on_Save_pressed() -> void:
	if _path.is_valid_filename():
		_save(_path)
