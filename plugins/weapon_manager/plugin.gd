const PLUGIN_ID := "weapon_manager"
const PLUGIN_VERSION := Vector3(0, 0, 1)
const MIN_VERSION := Vector3(0, 12, 0)
const PLUGIN_DEPENDENCIES := {}


const Munition := preload("munition.gd")
const Weapon := preload("weapon.gd")


static func pre_init(_plugin_path: String):
	Block.add_block(preload("ammo_rack.tres"))
	Vehicle.add_manager("weapon", preload("weapon_manager.gd"))


static func init(_plugin_path: String):
	pass


static func post_init(_plugin_path: String):
	pass


static func save_game(game_master: GameMaster) -> Dictionary:
	var s := []
	for p in game_master.get_tree().get_nodes_in_group("projectiles"):
		s.append([p.munition_name, var2str(p.transform), p.serialize_json()])
	return {"projectiles": s}


static func load_game(game_master: GameMaster, data: Dictionary) -> void:
	for s in data["projectiles"]:
		var id = Matter.name_to_id[s[0]]
		var shell = Munition.get_munition(id).shell.instance()
		shell.transform = str2var(s[1])
		shell.deserialize_json()
