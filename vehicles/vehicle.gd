class_name Vehicle

extends Spatial

export(GDScript) var ai_script
export var debug := false

var start_position := Vector3.ONE * INF
var end_position := Vector3.ONE * -INF
var ai: AI
var drive_forward := 0.0
var drive_yaw := 0.0
var drive_roll := 0.0
var brake := 0.0
var weapons_aim_point := Vector3.ZERO


func _ready():
	$GridMap.mesh_library = Global._blocks_mesh_library
	if ai_script != null:
		ai = ai_script.new()
		ai.init(self)
		

func _process(_delta):
	if debug:
		if ai != null:
			ai.debug_draw($"../ImmediateGeometry")
		for child in get_children():
			if child is Weapon:
				child.debug_draw($"../ImmediateGeometry")
				
	
	
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
			child.aim_at(weapons_aim_point)


func load_from_file(path: String) -> int:
	var file := File.new()
	var err = file.open(path, File.READ)
	if err != OK:
		return err
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


func _correct_center_of_mass() -> void:
	var total_mass = 0
	var position = Vector3.ZERO
	for cell in $GridMap.get_used_cells():
		var id = $GridMap.get_cell_item(cell.x, cell.y, cell.z)
		var mass = Global.blocks_by_id[id].mass
		position += cell * mass
		total_mass += mass
	position /= total_mass
	position += Vector3.ONE * 0.5
	for child in get_children():
		child.translate(-position)
		if child is VehicleWheel:
			remove_child(child) # Necessary to force VehicleWheel to move
			add_child(child)    # See VehicleWheel3D::_notification in vehicle_body_3d.cpp:81



func _spawn_block(x: int, y: int, z: int, r: int, block: Block) -> void:
	var basis := Block.rotation_to_basis(r)
	var orthogonal_index := Block.rotation_to_orthogonal_index(r)
	$GridMap.set_cell_item(x, y, z, block.id, orthogonal_index)
	if block.scene != null:
		var node = block.scene.instance()
		assert(node is Spatial)
		node.translation = Vector3(x, y, z) + Vector3.ONE / 2
		add_child(node)
	start_position.x = x if start_position.x > x else start_position.x
	start_position.y = y if start_position.y > y else start_position.y
	start_position.z = z if start_position.z > z else start_position.z
	end_position.x = x if end_position.x < x else end_position.x
	end_position.y = y if end_position.y < y else end_position.y
	end_position.z = z if end_position.z < z else end_position.z


func _set_collision_box(start: Vector3, end: Vector3) -> void:
	end += Vector3.ONE
	var center = (start + end) / 2
	var extents = (end - start) / 2
	$CollisionShape.transform.origin = center
	$CollisionShape.shape.extents = extents
