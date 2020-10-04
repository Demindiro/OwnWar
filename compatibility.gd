class_name Compatibility
extends Resource


# A version number consists of 3 numbers
# Coincidentally, a Vector3 also consists of 3 numbers and the '<' and '>'
# operators compare first X, then Y, then Z.
# So it's ideal for comparing version numbers
const BLOCK_MAPPINGS = [
		[Vector3(0, 4, 0), {
				"cube": "cube_1_1-1-1-1-1-1-1-1-1-1-1-1",
				"edge": "edge_1_1-1-1-1-1-1-1",
			}],
	]


static func version_string_to_vector(version: String):
	var numbers = version.split(".")
	assert(len(numbers) == 3)
	return Vector3(int(numbers[0]), int(numbers[1]), int(numbers[2]))


static func get_block_name_mapping(from_version: Vector3, to_version: Vector3):
	var index = 0
	var mappings = []
	while BLOCK_MAPPINGS[index][0] <= from_version:
		index += 1
	while BLOCK_MAPPINGS[index][0] <= to_version:
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
