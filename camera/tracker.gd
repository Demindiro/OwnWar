extends Camera


export(NodePath) var node setget set_node
export(float) var speed = 1
export(float) var angular_speed = 1
export(float) var keep_distance = 1

var _node


func _ready():
	call_deferred("set_node", node)
	set_process(false)


func _process(delta):
	var factor = clamp(delta * speed, 0, 1)
	var angular_factor = clamp(delta * angular_speed, 0, 1)
	var target_distance = (_node.translation - translation).length() - keep_distance
	var target_direction = (_node.translation - translation).normalized()
	var target_translation = target_direction * target_distance
	target_translation = translation
	var z = -target_direction
	var x = -z.cross(Vector3.UP).normalized()
	var y = -x.cross(z)
	transform = transform.interpolate_with(Transform(x, y, z, target_translation), angular_factor)


func set_node(p_node):
	node = p_node
	_node = get_node(node)
	set_process(_node != null)
