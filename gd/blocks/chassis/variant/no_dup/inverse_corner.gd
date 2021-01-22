extends "../complex/inverse_corner.gd"


var _blacklist = [
		PoolIntArray([2, 2, 2, 2, 2, 2, 1, 2, 2]),
		PoolIntArray([2, 2, 2, 2, 2, 2, 2, 1, 2]),
		PoolIntArray([2, 2, 2, 2, 2, 2, 2, 2, 1]),
		PoolIntArray([2, 2, 1, 2, 1, 1, 1, 2, 2]),
		PoolIntArray([2, 2, 2, 2, 2, 2, 1, 2, 1]),
	]


func step():
	.step()
	while not _is_valid():
		.step()
		if finished:
			return


func _is_valid():
	var result = get_result()
	var x = result[0]
	var y = result[1]
	var z = result[2]
	var u = result[3]
	var v = result[4]
	var w = result[5]
	# Dedup
	if x.x < y.y or y.y < z.z:
		return false
	# No pointiness
	if (y.y < u.y or z.z < u.z) or (x.x < v.x or z.z < v.z) or (x.x < w.x or y.y < w.y):
		return false
	# No mirror
	if u.y < u.z or v.x < v.z or w.y < w.z:
		return false
	# No vertices on diagonal
	if (x - w).cross(y - x).length_squared() < 1e-5 or \
			(x - v).cross(z - v).length_squared() < 1e-5 or \
			(y - u).cross(z - u).length_squared() < 1e-5:
		return false
	return not _is_blacklisted()


func _is_blacklisted():
	return indice_generator.indices in _blacklist
