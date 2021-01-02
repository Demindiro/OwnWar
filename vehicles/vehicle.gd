tool
extends Spatial
class_name OwnWar_Vehicle


const Block := preload("res://core/block/block.gd")
const Compatibility := preload("res://core/compatibility.gd")
const VoxelBody := preload("voxel_body.gd")
const VoxelMesh := preload("voxel_mesh.gd")


const MANAGERS := {}
var max_cost: int
var voxel_bodies := []
var wheels := []
var weapons := []
var turn_left := false
var turn_right := false
var pitch_up := false
var pitch_down := false
var move_forward := false
var move_back := false
var aim_at := Vector3()
var fire := false
export var _file := "" setget load_from_file, get_file_path
var _server_mode := OS.has_feature("Server")


func _init() -> void:
	set_process(not _server_mode)


func _physics_process(_delta: float) -> void:
	if not Engine.editor_hint:
		if not _server_mode and len(voxel_bodies) > 0:
			transform = voxel_bodies[0].transform

		var drive_yaw := 0.0
		var drive_forward := 0.0
		var drive_brake := 0.0
		if turn_left:
			drive_yaw += 0.3
		if turn_right:
			drive_yaw -= 0.3
		if move_forward:
			drive_forward += 1.0
		if move_back:
			drive_forward -= 1.0
		if not move_forward and not move_back:
			drive_brake = 1.0
			# Reduce brake to prevent jitter
			if voxel_bodies[0].linear_velocity.length_squared() < 1.0:
				drive_brake = 0.2
		for wheel in wheels:
			wheel.steering = drive_yaw * wheel.max_angle
			wheel.engine_force = wheel.max_power * drive_forward
			wheel.brake = drive_brake * wheel.max_brake

		for weapon in weapons:
			weapon.aim_at(aim_at)
			if fire:
				weapon.fire()


func get_visual_origin() -> Vector3:
	return voxel_bodies[0].get_visual_transform().origin


func load_from_file(path: String, thumbnail_mode := false) -> int:
	_file = path
	var file := File.new()
	var err = file.open(path, File.READ)
	if err != OK:
		return err

	for body in voxel_bodies:
		body.queue_free()

	var data = parse_json(file.get_as_text())
	data = Compatibility.convert_vehicle_data(data)

	_file = path

	if Engine.editor_hint:
		return _load_from_file_editor(data)

	for key in data["blocks"]:
		var components = Util.decode_vec3i(key)
		var x = components[0]
		var y = components[1]
		var z = components[2]
		var name = data["blocks"][key][0]
		var rotation = data["blocks"][key][1]
		var color := Util.decode_color(data["blocks"][key][2])
		var layer = data["blocks"][key][3]
		if len(voxel_bodies) <= layer:
			voxel_bodies.resize(layer + 1)
		if voxel_bodies[layer] == null:
			voxel_bodies[layer] = VoxelBody.new()
			add_child(voxel_bodies[layer])
			voxel_bodies[layer].connect("hit", self, "_voxel_body_hit")
		voxel_bodies[layer].spawn_block(x, y, z, rotation, Block.get_block(name), color)

	var meta = {}
	for key in data["meta"]:
		var components = key.split(',')
		assert(len(components) == 3)
		var x = int(components[0])
		var y = int(components[1])
		var z = int(components[2])
		meta[[x, y, z]] = data["meta"][key]

	for body in voxel_bodies:
		body.fix_physics()
		body.init_blocks(self, meta)
	var center_of_mass_0 = voxel_bodies[0].center_of_mass
	for body in voxel_bodies:
		body.translate(-center_of_mass_0)

	for body in voxel_bodies:
		wheels += body.wheels
		weapons += body.weapons
	for w in wheels:
		var e: int = w.connect("tree_exited", self, "_erase_from", [wheels, w])
		assert(e == OK)
	for w in weapons:
		var e: int = w.connect("tree_exited", self, "_erase_from", [weapons, w])
		assert(e == OK)

	if not thumbnail_mode:
		var physics_bodies := []
		for child in Util.get_children_recursive(self):
			if child is PhysicsBody:
				physics_bodies.append(child)
		for a in physics_bodies:
			for b in physics_bodies:
				a.add_collision_exception_with(b)
	else:
		for child in Util.get_children_recursive(self):
			if child is RigidBody:
				child.axis_lock_angular_x = true
				child.axis_lock_angular_y = true
				child.axis_lock_angular_z = true
				child.axis_lock_linear_x = true
				child.axis_lock_linear_y = true
				child.axis_lock_linear_z = true

	return OK


func get_blocks(block_name):
	var id = Block.get_block(block_name).id
	return get_blocks_by_id(id)


func get_blocks_by_id(id):
	var filtered_blocks = []
	for body in voxel_bodies:
		for block in body.blocks.values():
			if block.id == id:
				filtered_blocks.append(block)
	return filtered_blocks


func get_cost():
	var cost = 0
	for body in voxel_bodies:
		cost += body.cost
	return cost


func get_linear_velocity():
	return voxel_bodies[0].linear_velocity


func get_aabb() -> AABB:
	var aabb := AABB()
	for vb in voxel_bodies:
		for crd in vb.blocks:
			aabb.position = Vector3(crd[0], crd[1], crd[2])
			aabb.size = Vector3.ONE
			break
	for vb in voxel_bodies:
		for crd in vb.blocks:
			var v := Vector3(crd[0], crd[1], crd[2])
			aabb = aabb.expand(v).expand(v + Vector3.ONE)
	return aabb


func get_file_path() -> String:
	return _file


func debug_draw() -> void:
	var text := "Actions: "
	if turn_left:
		text += "left, "
	if turn_right:
		text += "right, "
	if pitch_up:
		text += "up, "
	if pitch_down:
		text += "down, "
	if move_forward:
		text += "forward, "
	if move_back:
		text += "back, "
	if fire:
		text += "fire, "
	Debug.draw_text(get_visual_origin(), text, Color.cyan)


func _voxel_body_hit(_voxel_body):
	if get_cost() * 4 < max_cost and not is_queued_for_deletion():
		get_parent().remove_child(self)
		queue_free()


static func path_to_name(path: String) -> String:
	assert(path.ends_with(Global.FILE_EXTENSION))
	return path.substr(0, len(path) - len(Global.FILE_EXTENSION)).capitalize()


static func name_to_path(p_name: String) -> String:
	return p_name.to_lower().replace(' ', '_') + '.json'


static func add_manager(p_name: String, script: GDScript):
	assert(not p_name in MANAGERS)
	MANAGERS[p_name] = script


func _load_from_file_editor(data: Dictionary) -> int:
	var vm_inst: MeshInstance = null
	for c in get_children():
		if c is MeshInstance and c.name == "_Editor_VoxelMesh":
			vm_inst = c
			break
	if vm_inst == null:
		vm_inst = MeshInstance.new()
		vm_inst.name = "_Editor_VoxelMesh"
		add_child(vm_inst)
	var vm := VoxelMesh.new()
	vm_inst.mesh = vm

	# TODO center of mass isn't accurate
	var com := Vector3.ZERO
	var count := 0.0
	var cube := CubeMesh.new()
	cube.size = Vector3.ONE * Block.BLOCK_SCALE
	for key in data["blocks"]:
		var components = Util.decode_vec3i(key)
		var x = components[0]
		var y = components[1]
		var z = components[2]
		var color := Util.decode_color(data["blocks"][key][2])
		vm.add_mesh(cube, color, [x, y, z], 0)
		com = (com * count + Vector3(x, y, z)) / (count + 1.0)
		count += 1.0
	vm.generate()
	vm_inst.transform.origin = -com * Block.BLOCK_SCALE

	return OK


func _erase_from(array: Array, item) -> void:
	array.erase(item)
