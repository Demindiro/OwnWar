extends Unit


export var max_material := 10
export var max_shells := 20
export var material_per_shell := 3
export var time_between_shells := 1.0
var material := 0
var shells := 0
var _producing_shell := false
var _time_until_shell_produced := 0.0


func _physics_process(delta):
	if _producing_shell:
		if _time_until_shell_produced >= time_between_shells:
			if shells < max_shells:
				shells += 1
				_visualize_shells()
				_producing_shell = false
				_time_until_shell_produced -= time_between_shells
		else:
			_time_until_shell_produced += delta
	else:
		if material_per_shell <= material:
			material -= material_per_shell
			_producing_shell = true


func get_info():
	var info = .get_info()
	info["Material"] = "%d / %d" % [material, max_material]
	info["Shells"] = "%d / %d" % [shells, max_shells]
	return info


func put_material(p_material: int) -> int:
	var remainder = 0
	material += p_material
	if material > max_material:
		remainder = material - max_material
		material = max_material
	return remainder


func take_shell():
	if shells > 0:
		shells -= 1
		_visualize_shells()
		return true
	return false


func _visualize_shells():
	$MultiMeshInstance.multimesh.instance_count = shells
	for i in range(shells):
		var shell_transform := Transform2D(Vector2.UP, Vector2.RIGHT,
			Vector2(i % 5, i / 5) / 3)
		$MultiMeshInstance.multimesh.set_instance_transform_2d(i, shell_transform)
