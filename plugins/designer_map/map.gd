extends Node


onready var game_master = GameMaster.get_game_master(self)
onready var material_id = Matter.get_matter_id("material")

var _player_spawn_platform_uid := -1
var _enemy_spawn_platform_uid := -1
var _player_storage_pod_uid := -1


func _ready(deferred := false):
	if deferred:
		game_master.get_unit_by_uid(_player_storage_pod_uid) \
				.put_matter(material_id, 500)
	else:
		_player_spawn_platform_uid = $"../Player/SpawnPlatform".uid
		_enemy_spawn_platform_uid = $"../Enemy/SpawnPlatform".uid
		_player_storage_pod_uid = $"../Player/StoragePod".uid
		call_deferred("_ready", true)


func _physics_process(_delta):
	game_master.get_unit_by_uid(_player_spawn_platform_uid) \
			.put_matter(material_id, 1 << 62)
	game_master.get_unit_by_uid(_enemy_spawn_platform_uid) \
			.put_matter(material_id, 1 << 62)


func _on_Designer_save_game(data: Dictionary) -> void:
	data["designer_map_data"] = {
			"player_spawn_platform_uid": _player_spawn_platform_uid,
			"enemy_spawn_platform_uid": _enemy_spawn_platform_uid,
			"player_storage_pod_uid": _player_storage_pod_uid,
		}


func _on_Designer_load_game(data: Dictionary) -> void:
	var d = data.get("designer_map_data")
	if d != null:
		_player_spawn_platform_uid = d["player_spawn_platform_uid"]
		_enemy_spawn_platform_uid = d["player_spawn_platform_uid"]
		_player_storage_pod_uid = d["player_spawn_platform_uid"]
	else:
		# Magic constants from before v0.14.1
		_player_spawn_platform_uid = 0
		_enemy_spawn_platform_uid = 241
		_player_storage_pod_uid = 964

