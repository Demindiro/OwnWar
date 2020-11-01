tool
extends "res://core/menu/dialog/independent_panel.gd"


var _saves_hash := 0


func _ready() -> void:
	_refresh_save_list()


func _refresh_save_list() -> void:
	var saves: Array = Util.iterate_dir_recursive("user://game_saves", "json")
	var h := saves.hash()
	if h != _saves_hash:
		print("Reloading saves list")
		Util.free_children($VBoxContainer)
		for path in saves:
			var button := Button.new()
			button.text = path.get_file().get_basename()
			button.connect("pressed", self, "_load_game", [path])
			$VBoxContainer.add_child(button)
		_saves_hash = h
# warning-ignore:return_value_discarded
	get_tree().create_timer(1.0, true).connect("timeout", self, "_refresh_save_list")


func _load_game(path: String) -> void:
	GameMaster.load_game(path)
