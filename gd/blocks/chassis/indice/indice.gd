extends Reference


var finished := true
var segments: int
var indices: PoolIntArray


func start(p_segments: int, indice_count: int):
	indices.resize(indice_count)
	segments = p_segments
	finished = false


func step():
	pass


func get_name(_prefix: String):
	pass
