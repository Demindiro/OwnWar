class_name OwnWar
extends Object


const VERSION := Vector3(0, 15, 2)
const COLLISION_MASK_TERRAIN := 1 << (8 - 1)

const _MAIN_MENU_SCENES := PoolStringArray()


static func add_main_menu_background(path: String) -> void:
	assert(path.is_abs_path())
	assert(File.new().file_exists(path))
	_MAIN_MENU_SCENES.append(path)


static func get_random_main_menu_background() -> PackedScene:
	if len(_MAIN_MENU_SCENES) == 0:
		return null
	var i := randi() % len(_MAIN_MENU_SCENES)
	var ret: PackedScene = load(_MAIN_MENU_SCENES[i])
	return ret
