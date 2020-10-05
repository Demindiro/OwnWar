class_name Vehicle

extends Unit

export(GDScript) var ai_script
export var invulnerable := false

var start_position := Vector3.ONE * INF
var end_position := Vector3.ONE * -INF
var ai: AI setget set_ai
var drive_forward := 0.0
var drive_yaw := 0.0
var drive_roll := 0.0
var brake := 0.0
var weapons_aim_point := Vector3.ZERO
var aim_weapons := false
var blocks := {}
var center_of_mass := Vector3.ZERO
var max_cost: int

var _fire_weapons := false
var _raycast := preload("res://addons/voxel_raycast.gd").new()

var _debug_hits := []


func _ready():
	$GridMap.mesh_library = Global._blocks_mesh_library
	if ai == null:
		if ai_script != null:
			self.ai = ai_script.new()
		else:
			self.ai = load(Global.DEFAULT_AI_SCRIPT).new()
	$CollisionShape.shape = $CollisionShape.shape.duplicate() # Make shape unique
		

func _process(_delta):
	if ai != null:
		ai.debug_draw($"../Debug")
	for child in get_children():
		if child is Weapon:
			child.debug_draw($"../Debug")
	for hit in _debug_hits:
		var position = Vector3(hit[0][0], hit[0][1], hit[0][2]) + Vector3.ONE / 2
		$"../Debug".draw_point(to_global(position * Global.BLOCK_SCALE - center_of_mass),
				hit[1], 0.55 * Global.BLOCK_SCALE)


func _physics_process(delta):
	if ai != null:
		assert(ai is AI)
		ai.process(delta)
	drive_forward = clamp(drive_forward, -1, 1)
	drive_yaw = clamp(drive_yaw, -1, 1)
	for child in get_children():
		if child is VehicleWheel:
			var angle = asin(child.translation.dot(Vector3.FORWARD) / child.translation.length())
			child.steering = angle * drive_yaw
			child.engine_force = drive_forward * 30
			child.brake = brake * 0.1
		elif child is Weapon:
			if aim_weapons:
				child.aim_at(weapons_aim_point)
			if _fire_weapons:
				child.fire()
	_fire_weapons = false
	
	
func get_info():
	var info = .get_info()
	var remaining_health = 0
	var remaining_cost = 0
	for coordinate in blocks:
		var block = blocks[coordinate]
		remaining_health += block[1]
		remaining_cost += Global.blocks_by_id[block[0]].cost
	info["Health"] = "%d / %d" % [remaining_health, max_health]
	info["Cost"] = "%d / %d" % [remaining_cost, max_cost]
	return info
	
			
func fire_weapons():
	_fire_weapons = true
	
	
func projectile_hit(origin: Vector3, direction: Vector3, damage: int):
	var local_origin = to_local(origin) + center_of_mass
	local_origin /= Global.BLOCK_SCALE
	var local_direction = to_local(origin + direction) - to_local(origin)
	_raycast.start(local_origin, local_direction, 25, 25, 25)
	_debug_hits = []
	while not _raycast.finished:
		var key = [_raycast.x, _raycast.y, _raycast.z]
		var block = blocks.get(key)
		if block != null:
			_debug_hits.append([key, Color.orange])
			if block[1] < damage:
				damage -= block[1]
				$GridMap.set_cell_item(key[0], key[1], key[2], GridMap.INVALID_CELL_ITEM)
				if block[2] != null:
					block[2].queue_free()
				# warning-ignore:return_value_discarded
				blocks.erase(key)
				cost -= Global.blocks_by_id[block[0]].cost
				if float(cost) / float(max_cost) < 0.75:
					destroy()
			else:
				block[1] -= damage
				damage = 0
				break
		else:
			_debug_hits.append([key, Color.yellow])
		_raycast.step()
	return damage


func load_from_file(path: String) -> int:
	var file := File.new()
	var err = file.open(path, File.READ)
	if err != OK:
		return err
	for coordinate in blocks:
		var block = blocks[coordinate]
		if block[2] != null:
			block[2].queue_free()
	blocks.clear()
	$GridMap.clear()
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
		_spawn_block(x, y, z, rotation, Global.blocks[name])
	cost = max_cost
	_set_collision_box(start_position, end_position)
	_correct_center_of_mass()
	return OK
	

func coordinate_to_vector(coordinate):
	var position = Vector3(coordinate[0], coordinate[1], coordinate[2])
	position *= Global.BLOCK_SCALE
	return position - center_of_mass
	
	
func get_actions():
	return [
			['Set waypoint', Action.INPUT_COORDINATE, 'set_waypoint', []],
			['Set targets', Action.INPUT_ENEMY_UNITS, 'set_targets', []],
		]


func set_waypoint(flags, waypoint):
	ai.waypoint = waypoint


func set_targets(flags, targets):
	ai.target = targets[0] if len(targets) > 0 else null


func set_ai(p_ai):
	if ai != p_ai:
		ai = p_ai
		ai.init(self)
		

static func path_to_name(path: String) -> String:
	assert(path.ends_with(Global.FILE_EXTENSION))
	return path.substr(0, len(path) - len(Global.FILE_EXTENSION)).capitalize()
	
	
static func name_to_path(p_name: String) -> String:
	return p_name.to_lower().replace(' ', '_') + '.json'


func _correct_center_of_mass() -> void:
	var total_mass = 0
	center_of_mass = Vector3.ZERO
	for coordinate in blocks:
		var block = blocks[coordinate]
		var mass = Global.blocks_by_id[block[0]].mass
		center_of_mass += Vector3(coordinate[0], coordinate[1], coordinate[2]) * mass
		total_mass += mass
	assert(total_mass > 0)
	center_of_mass /= total_mass
	center_of_mass += Vector3.ONE * 0.5
	center_of_mass *= Global.BLOCK_SCALE
	$GridMap.translation = Vector3.ZERO
	for child in get_children():
		child.translate(-center_of_mass)
		if child is VehicleWheel:
			remove_child(child) # Necessary to force VehicleWheel to move
			add_child(child)    # See VehicleWheel3D::_notification in vehicle_body_3d.cpp:81



func _spawn_block(x: int, y: int, z: int, r: int, block: Block) -> void:
	var basis := Block.rotation_to_basis(r)
	var orthogonal_index := Block.rotation_to_orthogonal_index(r)
	var node = null
	$GridMap.set_cell_item(x, y, z, block.id, orthogonal_index)
	if block.scene != null:
		node = block.scene.instance()
		assert(node is Spatial)
		var position = Vector3(x, y, z) + Vector3.ONE / 2
		node.transform = Transform(basis, position * Global.BLOCK_SCALE)
		add_child(node)
	max_cost += block.cost
	max_health += block.health
	blocks[[x, y, z]] = [block.id, block.health, node]
	start_position.x = float(x) if start_position.x > x else start_position.x
	start_position.y = float(y) if start_position.y > y else start_position.y
	start_position.z = float(z) if start_position.z > z else start_position.z
	end_position.x = float(x) if end_position.x < x else end_position.x
	end_position.y = float(y) if end_position.y < y else end_position.y
	end_position.z = float(z) if end_position.z < z else end_position.z


func _set_collision_box(start: Vector3, end: Vector3) -> void:
	end += Vector3.ONE
	var center = (start + end) / 2
	var extents = (end - start) / 2
	$CollisionShape.transform.origin = center * Global.BLOCK_SCALE
	$CollisionShape.shape.extents = extents * Global.BLOCK_SCALE
