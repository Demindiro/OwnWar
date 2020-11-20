extends Node

func _ready():
	var drill: Spatial = null
	var ore: Spatial = null
	var children = get_children()
	assert(len(children) == 2)

	if children[0] is preload("drill.gd"):
		drill = children[0]
		ore = children[1]
	else:
		drill = children[1]
		ore = children[0]
	assert(drill is preload("drill.gd"))
	assert(ore is preload("ore.gd"))

	drill.init(ore)
