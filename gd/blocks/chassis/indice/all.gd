extends "indice.gd"


func start(p_segments: int, indice_count: int):
	.start(p_segments, indice_count)
	for i in range(len(indices)):
		indices[i] = segments
	indices[0] += 1


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


func get_name(prefix: String):
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
				break
		if found:
			# warning-ignore:integer_division
			var name = prefix + "_" + str(segments / divisor)
			var pre = "_"
			for index in indices:
				name += pre + str(index / divisor)
				pre = "-"
			return name
