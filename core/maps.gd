class_name Maps


const MAPS := {}


static func add_map(p_name: String, map_path: String):
	assert(not p_name in MAPS)
	MAPS[p_name] = map_path
