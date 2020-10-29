class_name Vehicle
extends Unit


const MANAGERS := {}
var max_cost: int
var voxel_bodies := []
var actions := []
var managers := {}
var _object_to_actions_map := {}
var _info := []
var _matter_handlers_count := []
var _matter_handlers_space := []
var _matter_handlers_put := []
var _matter_handlers_take := []
var _matter_put_list := PoolIntArray()
var _matter_take_list := PoolIntArray()
onready var debug_node = $"../Debug"


func _process(_delta):
	for body in voxel_bodies:
		body.debug_draw(debug_node)


func _physics_process(delta):
	if len(voxel_bodies) > 0:
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
	return info


func get_matter_count(id: int) -> int:
	var count := 0
	for f in _matter_handlers_count:
		count += f.call_func(id)
	return count


func get_matter_space(id: int) -> int:
	var space := 0
	for f in _matter_handlers_space:
		space += f.call_func(id)
	return space


func get_put_matter_list() -> PoolIntArray:
	return _matter_put_list


func get_take_matter_list() -> PoolIntArray:
	return _matter_take_list


func put_matter(id: int, amount: int) -> int:
	for f in _matter_handlers_put:
		amount = f.call_func(id, amount)
		assert(amount >= 0)
		if amount == 0:
			break
	return amount


func take_matter(id: int, amount: int) -> int:
	var total := 0
	for f in _matter_handlers_put:
		total += f.call_func(id, amount - total)
		assert(total >= 0 and total <= amount)
		if total == amount:
			break
	return total


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

	var meta = {}
	for key in data["meta"]:
		var components = key.split(',')
		assert(len(components) == 3)
		var x = int(components[0])
		var y = int(components[1])
		var z = int(components[2])
		meta[[x, y, z]] = data["meta"][key]

	for body in voxel_bodies:
		body.fix_physics(transform)
		body.init_blocks(self, meta)
		max_cost += body.max_cost
	var center_of_mass_0 = voxel_bodies[0].center_of_mass
	for body in voxel_bodies:
		body.translate(-center_of_mass_0)
	var new_name = path.get_file()
	unit_name = "vehicle_" + new_name.substr(0, len(new_name) - 5)
	return OK
	
	
func get_actions():
	return actions


func add_action(object, human_name, flags, function, arguments):
	var action = [human_name, flags, "do_action", [[object, function] + arguments]]
	actions.append(action)
	if object in _object_to_actions_map:
		_object_to_actions_map[object].append(action)
	else:
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


func get_manager(p_name: String) -> GDScript:
	var manager = managers.get(p_name)
	if manager == null:
		manager = MANAGERS[p_name].new()
		managers[p_name] = manager
		manager.init(self)
	return manager


func add_matter_put(id: int) -> void:
	if not id in _matter_put_list:
		_matter_put_list.append(id)


func add_matter_take(id: int) -> void:
	if not id in _matter_take_list:
		_matter_take_list.append(id)


func add_matter_count_handler(function: FuncRef) -> void:
	_matter_handlers_count.append(function)


func add_matter_space_handler(function: FuncRef) -> void:
	_matter_handlers_space.append(function)


func add_matter_put_handler(function: FuncRef) -> void:
	_matter_handlers_put.append(function)


func add_matter_take_handler(function: FuncRef) -> void:
	_matter_handlers_take.append(function)


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


static func add_manager(p_name: String, script: GDScript):
	assert(not p_name in MANAGERS)
	MANAGERS[p_name] = script