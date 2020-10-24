extends Node


var id_to_munitions := {}


func _ready(deferred := false):
	var material_id: int = Matter.name_to_id.get("material", -1)
	if material_id < 0:
		if deferred:
			Global.error("Matter 'material' not found!")
			return
		else:
			call_deferred("_ready", true)
	for m in [
			preload("160mm/shell_160mm.tres"),
			preload("35mm/shell_35mm.tres"),
		]:
		# Ammo containers generally pack munition in a square pattern
		# Pretend that length = gauge * 3
		var volume: int = m.gauge * m.gauge * (m.gauge * 3)
		var id := Matter.add_matter(m.human_name, volume)
		id_to_munitions[id] = m
