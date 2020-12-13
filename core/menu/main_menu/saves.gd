tool
extends "res://core/menu/dialog/independent_panel.gd"


var _saves_hash := 0
var _timer: SceneTreeTimer


func _ready() -> void:
	_refresh_save_list()


func _exit_tree() -> void:
	if _timer != null:
		_timer.disconnect("timeout", self, "_refresh_save_list")
		_timer = null


func _refresh_save_list() -> void:
	var saves: Array = Util.iterate_dir_recursive("user://game_saves", "json")
	var h := saves.hash()
	if h != _saves_hash:
		print("Reloading saves list")
		Util.free_children($VBoxContainer)
		for path in saves:
			var button := Button.new()
			button.text = path.get_file().get_basename()
			var e := button.connect("pressed", self, "_load_game", [path])
			assert(e == OK)
			$VBoxContainer.add_child(button)
		_saves_hash = h
	_timer = get_tree().create_timer(1.0, true)
	var e := _timer.connect("timeout", self, "_refresh_save_list")
	assert(e == OK)


func _load_game(path: String) -> void:
	var e := OwnWar.GameMaster.load_game(path)
	if e != OK:
		Global.error("Failed to load game %d", e)
