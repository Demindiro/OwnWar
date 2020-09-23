class_name Vehicle

extends Spatial

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
		$"../Debug".draw_point(to_global(
			Vector3(hit[0][0], hit[0][1], hit[0][2]) + $GridMap.translation + Vector3.ONE / 2),
			hit[1], 0.55)


func _physics_process(_delta):
	if ai != null:
		assert(ai is AI)
		ai.process()
	drive_forward = clamp(drive_forward, -1, 1)
	drive_yaw = clamp(drive_yaw, -1, 1)
	for child in get_children():
		if child is VehicleWheel:
			var angle = asin(child.translation.dot(Vector3.FORWARD) / child.translation.length())
			child.steering = angle * drive_yaw
			child.engine_force = drive_forward * 40
			child.brake = brake * 1
		elif child is Weapon:
			if aim_weapons:
				child.aim_at(weapons_aim_point)
			if _fire_weapons:
				child.fire()
	_fire_weapons = false
	
			
func fire_weapons():
	_fire_weapons = true
	
	
func projectile_hit(origin: Vector3, direction: Vector3, damage: int):
	var local_origin = to_local(origin) - $GridMap.translation
	var local_direction = to_local(origin + direction) - to_local(origin)
	_raycast.start(local_origin, local_direction, 25, 25, 25)
	_debug_hits = []
	while not _raycast.finished:
		var key = [_raycast.x, _raycast.y, _raycast.z]
		var block = blocks.get(key)
		if block != null:
			_debug_hits.append([key, Color.orange])
			print(damage)
			if block[1] < damage:
				damage -= block[1]
				$GridMap.set_cell_item(key[0], key[1], key[2], GridMap.INVALID_CELL_ITEM)
				if block[2] != null:
					block[2].queue_free()
				# warning-ignore:return_value_discarded
				blocks.erase(key)
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
	print($GridMap.mesh_library)
	var data = parse_json(file.get_as_text())
	for key in data["blocks"]:
		var components = key.split(',')
		assert(len(components) == 3)
		var x = int(components[0])
		var y = int(components[1])
		var z = int(components[2])
		var name = data["blocks"][key][0]
		var rotation = data["blocks"][key][1]
		_spawn_block(x, y, z, rotation, Global.blocks[name])
	_set_collision_box(start_position, end_position)
	_correct_center_of_mass()
	return OK


func set_ai(p_ai):
	if ai != p_ai:
		ai = p_ai
		ai.init(self)


func _correct_center_of_mass() -> void:
	var total_mass = 0
	var position = Vector3.ZERO
	for coordinate in blocks:
		var block = blocks[coordinate]
		var mass = Global.blocks_by_id[block[0]].mass
		position += Vector3(coordinate[0], coordinate[1], coordinate[2]) * mass
		total_mass += mass
	position /= total_mass
	position += Vector3.ONE * 0.5
	$GridMap.translation = Vector3.ZERO
	#$CollisionShape.translation = Vector3.ZERO
	for child in get_children():
		child.translate(-position)
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
		node.transform = Transform(basis, Vector3(x, y, z) + Vector3.ONE / 2)
		add_child(node)
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
	$CollisionShape.transform.origin = center
	$CollisionShape.shape.extents = extents
