extends Node


const BM := preload("res://plugins/basic_manufacturing/plugin.gd")

onready var material_id = OwnWar.Matter.get_matter_id("material")
onready var _player_spawn_platform: BM.SpawnPlatform = $"../Player/SpawnPlatform"
onready var _enemy_spawn_platform: BM.SpawnPlatform = $"../Enemy/SpawnPlatform"
onready var _player_storage_pod: BM.StoragePod = $"../Player/StoragePod"
onready var _gui: Control = $"../GUI"


func _ready() -> void:
	# warning-ignore:return_value_discarded
	_player_storage_pod.put_matter(material_id, 500)


func _physics_process(_delta: float) -> void:
	# warning-ignore:return_value_discarded
	_player_spawn_platform.put_matter(material_id, 1 << 62)
	# warning-ignore:return_value_discarded
	_enemy_spawn_platform.put_matter(material_id, 1 << 62)


func _on_Designer_save_game(data: Dictionary) -> void:
	data["designer_map_data"] = {
			"player_spawn_platform_uid": _player_spawn_platform.uid,
			"enemy_spawn_platform_uid": _enemy_spawn_platform.uid,
			"player_storage_pod_uid": _player_storage_pod.uid,
		}


func _on_Designer_load_game(data: Dictionary) -> void:
	var gm: OwnWar.GameMaster = OwnWar.GameMaster.get_game_master(self)
	var d = data.get("designer_map_data")
	if d != null:
		_player_spawn_platform = gm.get_unit_by_uid(d["player_spawn_platform_uid"])
		_enemy_spawn_platform = gm.get_unit_by_uid(d["enemy_spawn_platform_uid"])
		_player_storage_pod = gm.get_unit_by_uid(d["player_storage_pod_uid"])
	else:
		# Magic constants from before v0.14.1
		_player_spawn_platform = gm.get_unit_by_uid(0)
		_enemy_spawn_platform = gm.get_unit_by_uid(241)
		_player_storage_pod = gm.get_unit_by_uid(964)


func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		get_tree().paused = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_gui.visible = true


func _on_GUI_cancel():
	get_tree().paused = false
	_gui.visible = false


func _on_GUI_restart():
	get_tree().paused = false
	var e := get_tree().reload_current_scene()
	assert(e == OK)



func _on_Designer_pressed():
	Global.goto_scene(Global.SCENE_DESIGNER)


func _on_GUI_exit():
	OwnWar.goto_main_menu(get_tree())

