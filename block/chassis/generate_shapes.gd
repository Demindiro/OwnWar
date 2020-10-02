extends Reference


var result
var finished := true
var segments: int
var scale: Vector3
var offset: Vector3
var indices: PoolIntArray
var name := "mesh"


func start(p_segments: int, p_scale: Vector3, p_offset: Vector3):
	segments = p_segments
	scale = p_scale
	offset = p_offset
	for i in range(len(indices)):
		indices[i] = segments
	indices[0] += 1
	finished = false
	
	
func step():
	for i in len(indices):
		indices[i] -= 1
		if indices[i] == 0:
			if i == len(indices) - 1:
				finished = true
				return
			indices[i] = segments
		else:
			break
	pass


func get_name():
	var lowest_value = segments
	for value in indices:
		if value < lowest_value:
			lowest_value = value
	for divisor in range(lowest_value, 0, -1):
		var found = true
		if segments % divisor != 0:
			continue
		for value in indices:
			if value % divisor != 0:
				found = false
				pass
				break
		if found:
			var _name = name + "_" + str(segments / divisor)
			var pre = "_"
			for index in indices:
				_name += pre + str(index / divisor)
				pre = "-"
			return _name


func _set_indices_count(count: int):
	indices.resize(count)
