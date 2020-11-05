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
		assert(Munition.is_munition(p.munition_id))
		var d := {
				"name": Matter.matter_name[p.munition_id],
				"transform": var2str(p.transform),
				"velocity": var2str(p.linear_velocity),
				"damage": p.damage,
			}
		if p.has_method("serialize_json"):
			d["meta"] = p.serialize_json()
		s.append(d)
	return {"projectiles": s}


static func load_game(game_master: GameMaster, data: Dictionary) -> void:
	for s in data["projectiles"]:
		var id = Matter.name_to_id[s["name"]]
		var shell = Munition.get_munition(id).shell.instance()
		shell.transform = str2var(s["transform"])
		shell.linear_velocity = str2var(s["velocity"])
		shell.damage = s["damage"]
		shell.munition_id = id
		var meta = s.get("meta")
		if meta:
			assert(shell.has_method("deserialize_json"))
			shell.deserialize_json(meta)
		game_master.add_child(shell)
