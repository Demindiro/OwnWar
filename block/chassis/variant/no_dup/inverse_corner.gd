extends "res://block/chassis/variant/complex/inverse_corner.gd"


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
	var w = result[5]
	# Dedup
	if x.x < y.y or y.y < z.z:
		return false
	# No pointiness
	if (y.y < u.y or z.z < u.z) or (x.x < v.x or z.z < v.z) or (x.x < w.x or y.y < w.y):
		return false
	return true
