extends Node


const BM := preload("res://plugins/basic_manufacturing/plugin.gd")
# Note: the amount of physics steps per idle frame is capped to 8, so you'll
# need to either launch the project _directly_ with --fixed-fps or patch the
# engine (look for max_physics_fps in main/main.cpp)
const SCALE := 125


func _ready():
	for u in get_tree().get_nodes_in_group("units"):
		if u is BM.Drill:
			u.material = BM.Drill.MAX_MATERIAL
	Engine.time_scale *= SCALE
	# Use 30 FPS to increase simulation speed
	Engine.iterations_per_second = 30 * SCALE
	print(Engine.time_scale)
	print(Engine.iterations_per_second)
