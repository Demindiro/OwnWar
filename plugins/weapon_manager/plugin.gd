extends OwnWar.Plugin.Interface


const PLUGIN_VERSION := Vector3(0, 0, 1)
const MIN_VERSION := Vector3(0, 12, 0)
const PLUGIN_DEPENDENCIES := {}


const Munition := preload("munition.gd")
const Weapon := preload("weapon.gd")
const Projectile := preload("projectile.gd")


func pre_init():
	OwnWar.Block.add_block(preload("ammo_rack.tres"))
	OwnWar.Vehicle.add_manager("weapon", preload("weapon_manager.gd"))


func save_game(game_master: OwnWar.GameMaster) -> Dictionary:
	var s := []
	for p in game_master.get_tree().get_nodes_in_group("projectiles"):
		assert(Munition.is_munition(p.munition_id))
		var d := {
				"name": OwnWar.Matter.get_matter_name(p.munition_id),
				"transform": var2str(p.transform),
				"velocity": var2str(p.linear_velocity),
				"damage": p.damage,
			}
		if p.has_method("serialize_json"):
			d["meta"] = p.serialize_json()
		s.append(d)
	return {"projectiles": s}


func load_game(game_master: OwnWar.GameMaster, data: Dictionary) -> void:
	for s in data["projectiles"]:
		var id := OwnWar.Matter.get_matter_id(s["name"])
		var munition: Munition = Munition.get_munition(id)
		var shell: Projectile = munition.shell.instance()
		shell.transform = str2var(s["transform"])
		shell.linear_velocity = str2var(s["velocity"])
		shell.damage = s["damage"]
		shell.munition_id = id
		var meta = s.get("meta")
		if meta:
			assert(shell.has_method("deserialize_json"))
			# warning-ignore:unsafe_method_access
			shell.deserialize_json(meta)
		game_master.add_child(shell)
