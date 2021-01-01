extends Reference


var name := "mesh"
var mesh_generator
var indice_generator
var indice_count := 0
var fractions: PoolRealArray
var finished := true


func _set_generator():
	var dir: String = Util.get_script_dir(self) 
	# https://github.com/godotengine/godot/issues/35832
	var dir_bb := dir.get_base_dir().get_base_dir()
	# warning-ignore:unsafe_method_access
	mesh_generator = load(dir_bb.plus_file("mesh/%s.gd") % name).new()
	# warning-ignore:unsafe_method_access
	indice_generator = load(dir_bb.plus_file("indice/all.gd")).new()


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


func get_mesh(_data: Array):
	pass


func set_indices(indices: PoolIntArray):
	assert(len(indices) == indice_count)
	indice_generator.indices = indices
	fractions = PoolRealArray()
	for index in indice_generator.indices:
		fractions.append(float(index) / float(indice_generator.segments))


func _set_indices_count(count: int):
	indice_count = count
