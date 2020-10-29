class_name Compatibility
extends Resource


# A version number consists of 3 numbers
# Coincidentally, a Vector3 also consists of 3 numbers and the '<' and '>'
# operators compare first X, then Y, then Z.
# So it's ideal for comparing version numbers
const BLOCK_MAPPINGS = [
		[Vector3(0, 4, 0), {
				"cube": "cube_b_1_1-1-1-1-1-1-1-1-1-1-1-1",
				"edge": "edge_b_1_1-1-1-1-1-1-1",
			}],
		[Vector3(0, 12, 1), {
				"railgun": "vane",
			}],
	]


static func get_block_name_mapping(from_version: Vector3, to_version: Vector3):
	var index = 0
	var mappings = []
	while index < len(BLOCK_MAPPINGS) and BLOCK_MAPPINGS[index][0] <= from_version:
		index += 1
	while index < len(BLOCK_MAPPINGS) and BLOCK_MAPPINGS[index][0] <= to_version:
		mappings.append(BLOCK_MAPPINGS[index][1])
		index += 1
	if len(mappings) == 0:
		return {}
	var final_mapping = mappings.pop_front()
	while len(mappings) > 0:
		var mapping = mappings.pop_front()
		for key in final_mapping:
			var value = final_mapping[key]
			if value in mapping:
				final_mapping[key] = mapping[key]
	return final_mapping


static func convert_vehicle_data(data):
	var file_version = Util.version_str_to_vector(data["game_version"])
	if file_version > Global.VERSION:
		Global.error("Can't load vehicle data: the data was created in a more " +
			"recent version of the game")
		return null
	var mapping = get_block_name_mapping(file_version, Global.VERSION)
	var converted_data = {}
	var converted_blocks = {}
	converted_data["game_version"] = Util.version_vector_to_str(Global.VERSION)
	var old_blocks = data["blocks"]
	for key in old_blocks:
		var block_data = _convert_block_data(data["blocks"][key], file_version)
		if block_data[0] in mapping:
			block_data[0] = mapping[block_data[0]]
		converted_blocks[key] = block_data
	converted_data["blocks"] = converted_blocks

	converted_data["meta"] = data.get("meta", {})

	return converted_data
	
	
static func _convert_block_data(data, file_version):
	data = data.duplicate(true)
	if file_version < Vector3(0, 5, 0):
		assert(len(data) == 2)
		data.append("1,1,1,1")
	if file_version < Vector3(0, 6, 0):
		assert(len(data) == 3)
		data.append(0)
	return data
