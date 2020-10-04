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
	]


static func version_string_to_vector(version: String):
	var numbers = version.split(".")
	assert(len(numbers) == 3)
	return Vector3(int(numbers[0]), int(numbers[1]), int(numbers[2]))


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
	var file_version = version_string_to_vector(data["game_version"])
	var game_version = version_string_to_vector(Global.VERSION)
	if file_version > game_version:
		Global.error("Can't load vehicle data: the data was created in a more " +
			"recent version of the game")
		return null
	var mapping = get_block_name_mapping(file_version, game_version)
	print(file_version)
	print(game_version)
	print(mapping)
	var converted_data = {}
	var converted_blocks = {}
	converted_data["game_version"] = Global.VERSION
	var old_blocks = data["blocks"]
	for key in old_blocks:
		var block_data = data["blocks"][key].duplicate(true)
		if block_data[0] in mapping:
			block_data[0] = mapping[block_data[0]]
		converted_blocks[key] = block_data
	converted_data["blocks"] = converted_blocks
	return converted_data
