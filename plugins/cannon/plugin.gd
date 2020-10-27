const PLUGIN_ID := "cannon"
const PLUGIN_VERSION := Vector3(0, 0, 1)
const MIN_VERSION := Vector3(0, 12, 0)


func _init():
	Block.add_block(preload("160mm/80mm_cannon.tres"))
	Block.add_block(preload("35mm/35mm_cannon.tres"))
