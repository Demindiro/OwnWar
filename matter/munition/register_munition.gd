class_name RegisterMunition
extends Node


var id_to_munitions := {}


func _ready():
	for m in [
			preload("160mm/shell_160mm.tres"),
			preload("35mm/shell_35mm.tres"),
		]:
		# Ammo containers generally pack munition in a square pattern
		# Pretend that length = gauge * 3
		var volume: float = m.gauge * m.gauge * (m.gauge * 3.0)
		var id := Matter.add_matter(m.human_name, m.gauge)
		id_to_munitions[id] = m
