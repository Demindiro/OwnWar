extends "../complex/edge_b.gd"


var _blacklist = [
		PoolIntArray([2, 2, 2, 2, 2, 1, 2]),
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
	# Dedup
	if x.x < y.y or y.y < z.z:
		return false
	# No pointiness
	if (x.x < u.x or z.z < u.z) or (x.x < v.x or y.y < v.y):
		return false
	# No vertices on diagonal
	if (x - u).cross(x - z).length_squared() < 1e-5 or \
			(x - v).cross(x - y).length_squared() < 1e-5:
		return false
	return not _is_blacklisted()


func _is_blacklisted():
	return indice_generator.indices in _blacklist
