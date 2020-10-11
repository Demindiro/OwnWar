class_name Vehicle
extends Unit


var brake := 0.0
var max_cost: int
var voxel_bodies := []
var actions := []
var managers := {}
var _object_to_actions_map := {}
var _block_functions := {}
var _info_functions := {}
var _functions := {}
var _info := []
onready var debug_node = $"../Debug"


func _process(_delta):
	for body in voxel_bodies:
		body.debug_draw(debug_node)


func _physics_process(delta):
	global_transform = voxel_bodies[0].global_transform
	for manager_name in managers:
		if managers[manager_name].has_method("process"):
			managers[manager_name].process(delta)


func get_info():
	var info = .get_info()
	var remaining_health = 0
	var remaining_cost = 0
	for body in voxel_bodies:
		for coordinate in body.blocks:
			var block = body.blocks[coordinate]
			remaining_health += block[1]
			remaining_cost += Global.blocks_by_id[block[0]].cost
	info["Health"] = "%d / %d" % [remaining_health, max_health]
	info["Cost"] = "%d / %d" % [remaining_cost, max_cost]
	for info_function in _info:
		info_function.call_func(info)
	for info_name in _info_functions:
		var info_function = _info_functions[info_name]
		info[info_name] = info_function[0].call_func(info_function[1])
	return info


func has_function(function_name):
	if function_name in _functions:
		return true
	if function_name in _block_functions:
		return true
	return .has_function(function_name)


func call_function(function_name, arguments := []):
	var function = _functions.get(function_name)
	if function != null:
		return function.call_funcv(arguments)
	var block_function = _block_functions.get(function_name)
	if block_function != null:
		return block_function[0].call_func(block_function[1], arguments)
	return .call_function(function_name, arguments)


func load_from_file(path: String) -> int:
	var file := File.new()
	var err = file.open(path, File.READ)
	if err != OK:
		return err
	for body in voxel_bodies:
		body.queue_free()
	max_cost = 0
	max_health = 0
	var data = parse_json(file.get_as_text())
	data = Compatibility.convert_vehicle_data(data)
	for key in data["blocks"]:
		var components = key.split(',')
		assert(len(components) == 3)
		var x = int(components[0])
		var y = int(components[1])
		var z = int(components[2])
		var name = data["blocks"][key][0]
		var rotation = data["blocks"][key][1]
		var color_components = data["blocks"][key][2].split_floats(",")
		var color = Color(color_components[0], color_components[1],
				color_components[2], color_components[3])
		var layer = data["blocks"][key][3]
		if len(voxel_bodies) <= layer:
			voxel_bodies.resize(layer + 1)
		if voxel_bodies[layer] == null:
			voxel_bodies[layer] = VoxelBody.new()
			add_child(voxel_bodies[layer])
			voxel_bodies[layer].connect("hit", self, "_voxel_body_hit")
		voxel_bodies[layer].spawn_block(x, y, z, rotation, Global.blocks[name], color)
	for body in voxel_bodies:
		body.fix_physics(transform)
		body.init_blocks(self)
		max_cost += body.max_cost
	var center_of_mass_0 = voxel_bodies[0].center_of_mass
	for body in voxel_bodies:
		body.translate(-center_of_mass_0)
	return OK
	
	
func get_actions():
	return actions


func add_action(object, human_name, flags, function, arguments):
	var action = [human_name, flags, "do_action", [[object, function] + arguments]]
	actions.append(action)
	if object in _object_to_actions_map:
		_object_to_actions_map[object].append(action)
	else:
		object.connect("tree_exited", self, "remove_actions", [object])
		_object_to_actions_map[object] = [action]


func do_action(flags, arg0, arg1 = null):
	var object
	var function
	var arguments
	if arg1 != null:
		object = arg1[0]
		function = arg1[1]
		arguments = arg1.slice(1, len(arg1) - 1)
		arguments[0] = arg0
	else:
		object = arg0[0]
		function = arg0[1]
		arguments = arg0.slice(2, len(arg0) - 1)
	if is_instance_valid(object):
		object.callv(function, [flags] + arguments)


func remove_actions(object):
	for action in _object_to_actions_map[object]:
		actions.erase(action)
	_object_to_actions_map.erase(object)


func add_block_function(object, function, function_name):
	if function_name in _block_functions:
		_block_functions[function_name][1].append(object)
	else:
		_block_functions[function_name] = [funcref(object, function), [object]]
		object.connect("tree_exited", self, "remove_block_functions", [function_name, object])


func remove_block_functions(function_name, object):
	_block_functions[function_name][1].erase(object)


func add_info_function(object, function, info_name):
	if not info_name in _info_functions:
		_info_functions[info_name] = [funcref(object, function), [object]]
	else:
		_info_functions[info_name][1].append(object)


func remove_info_function(object, info_name):
	_info_functions[info_name][1].erase(object)


func add_manager(p_name, object):
	assert(not p_name in managers)
	managers[p_name] = object
	object.init(self)


func add_function(object, p_name):
	assert(not p_name in _functions)
	_functions[p_name] = funcref(object, p_name)


func add_info(object, p_name):
	_info.append(funcref(object, p_name))


func get_blocks(block_name):
	var id = Global.blocks[block_name].id
	return get_blocks_by_id(id)


func get_blocks_by_id(id):
	var filtered_blocks = []
	for body in voxel_bodies:
		for block in body.blocks.values():
			if block[0] == id:
				filtered_blocks.append(block.duplicate())
	return filtered_blocks


func get_cost():
	var cost = 0
	for body in voxel_bodies:
		cost += body.cost
	return cost


func get_linear_velocity():
	return voxel_bodies[0].linear_velocity


func _voxel_body_hit(_voxel_body):
	if get_cost() * 4 < max_cost:
		destroy()


static func path_to_name(path: String) -> String:
	assert(path.ends_with(Global.FILE_EXTENSION))
	return path.substr(0, len(path) - len(Global.FILE_EXTENSION)).capitalize()
	
	
static func name_to_path(p_name: String) -> String:
	return p_name.to_lower().replace(' ', '_') + '.json'
