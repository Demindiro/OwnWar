extends Reference


var result
var finished := true
var segments: int
var scale: Vector3
var offset: Vector3


func start(p_segments: int, p_scale: Vector3, p_offset: Vector3):
	segments = p_segments
	scale = p_scale
	offset = p_offset
	
	
func step():
	pass
