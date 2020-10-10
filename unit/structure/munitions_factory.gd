extends Unit


export var max_material := 10
export var max_munition := 20
export var material_per_munition := 3
export var time_between_munitions := 1.0
#export(Array, Munition) var munition_types := []
export(Array, Resource) var munition_types := []
var material := 0
var munition := []
var _producing_munition := false
var _time_until_munition_produced := 0.0


func _physics_process(delta):
	if _producing_munition:
		if _time_until_munition_produced >= time_between_munitions:
			if len(munition) < max_munition:
				var new_munition = munition_types[0].duplicate()
				munition.append(new_munition)
				_visualize_munitions()
				_producing_munition = false
				_time_until_munition_produced -= time_between_munitions
		else:
			_time_until_munition_produced += delta
	else:
		if material_per_munition <= material:
			material -= material_per_munition
			_producing_munition = true


func get_info():
	var info = .get_info()
	info["Material"] = "%d / %d" % [material, max_material]
	info["Munition"] = "%d / %d" % [len(munition), max_munition]
	return info


func put_material(p_material: int) -> int:
	var remainder = 0
	material += p_material
	if material > max_material:
		remainder = material - max_material
		material = max_material
	return remainder


func take_munition():
	if len(munition) > 0:
		var taken_munition = munition.pop_front()
		_visualize_munitions()
		return taken_munition
	return null


func get_munition_count():
	return len(munition)


func _visualize_munitions():
	$MultiMeshInstance.multimesh.instance_count = len(munition)
	for i in range(len(munition)):
		var munition_transform := Transform2D(Vector2.UP, Vector2.RIGHT,
			Vector2(i % 5, i / 5) / 3)
		$MultiMeshInstance.multimesh.set_instance_transform_2d(i, munition_transform)
