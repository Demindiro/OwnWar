extends "res://block/chassis/variant/complex/edge_b.gd"


func step():
	.step()
	while not _is_valid():
		.step()
		if finished:
			return


func _is_valid():
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
	return true
