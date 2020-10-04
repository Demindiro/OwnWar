extends Reference


var result
var name := "mesh"
var mesh_generator
var indice_generator
var indice_count := 0
var fractions: PoolRealArray
var finished := true


func _set_generator():
	mesh_generator = load("res://block/chassis/mesh/%s.gd" % name).new()
	indice_generator = load("res://block/chassis/indice/all.gd").new()


func start(p_segments: int):
	indice_generator.start(p_segments, indice_count)
	finished = indice_generator.finished
	
	
func step():
	indice_generator.step()
	fractions = PoolRealArray()
	for index in indice_generator.indices:
		fractions.append(float(index) / float(indice_generator.segments))
	finished = indice_generator.finished


func get_name():
	return indice_generator.get_name(mesh_generator.name)


func get_mesh(data: Array):
	pass


func _set_indices_count(count: int):
	indice_count = count
