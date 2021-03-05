tool
extends ImmediateGeometry


const FADE_TIME := 1.0


var points := PoolVector3Array()
var index := 0
var time := 0.0


func _ready() -> void:
	set_as_toplevel(true)
	transform = Transform()
	for _i in 16:
		points.push_back(get_parent().global_transform.origin)


func _process(delta: float) -> void:
	# Make sure the tracer's length isn't FPS dependent
	time += delta
	if time < FADE_TIME / len(points):
		return

	global_transform = Transform() # TODO damn editor...
	var pos: Vector3 = get_parent().global_transform.origin

	while time > FADE_TIME / len(points):
		index = posmod(index - 1, len(points))
		points[index] = pos
		time -= delta
	
	clear()
	begin(Mesh.PRIMITIVE_LINE_STRIP)
	set_color(Color.green)
	for i in len(points):
		i = (i + index) % len(points)
		add_vertex(points[i])
	end()
