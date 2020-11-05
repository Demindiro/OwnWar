extends Node


var game_master
var material_id


func _physics_process(_delta):
	game_master.get_unit_by_uid(0).put_matter(material_id, 1 << 62)
	game_master.get_unit_by_uid(241).put_matter(material_id, 1 << 62)


func _on_GUI_load_vehicle(path):
	game_master.get_unit_by_uid(241).spawn_vehicle(0, path)


func _on_FilthyHack_ready():
	# I need something that is called after _enter_tree but just right before
	# _ready. This works I guess...
	game_master = GameMaster.get_game_master(self)
	material_id = Matter.name_to_id["material"]
	for child in get_children():
		if child is Unit:
			game_master.units[child.team].append(child)
			child.uid = game_master.uid_counter
			game_master.uid_counter += 241
	game_master.get_unit_by_uid(964).put_matter(material_id, 500)
