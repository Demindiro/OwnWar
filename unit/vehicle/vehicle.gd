class_name Vehicle
extends Unit


export(GDScript) var ai_script
var ai: AI setget set_ai
var drive_forward := 0.0
var drive_yaw := 0.0
var brake := 0.0
var weapons_aim_point := Vector3.ZERO
var aim_weapons := false
var max_cost: int
var voxel_bodies := []
var _fire_weapons := false
onready var debug_node = $"../Debug"


func _ready():
	if ai == null:
		if ai_script != null:
			self.ai = ai_script.new()
		else:
			self.ai = load(Global.DEFAULT_AI_SCRIPT).new()


func _process(_delta):
	if ai != null:
		ai.debug_draw(debug_node)
	for body in voxel_bodies:
		body.debug_draw(debug_node)


func _physics_process(delta):
	global_transform = voxel_bodies[0].global_transform
	if ai != null:
		assert(ai is AI)
		ai.process(delta)
	drive_forward = clamp(drive_forward, -1, 1)
	drive_yaw = clamp(drive_yaw, -1, 1)
	for body in voxel_bodies:
		for child in body.get_children():
			if child is VehicleWheel:
				var angle = asin(child.translation.dot(Vector3.FORWARD) /
						child.translation.length())
				child.steering = angle * drive_yaw
				child.engine_force = drive_forward * 300.0
				child.brake = brake * 1.0
			elif child is Weapon:
				if aim_weapons:
					child.aim_at(weapons_aim_point)
				if _fire_weapons:
					child.fire()
			elif child is Cannon:
				if aim_weapons:
					child.aim_at(weapons_aim_point)
				else:
					child.set_angle(0)
				if _fire_weapons:
					child.fire()
			elif child.get_child_count() > 0 and child.get_child(0) is Connector:
				if aim_weapons:
					child.get_child(0).aim_at(weapons_aim_point)
				else:
					child.get_child(0).set_angle(0)
	_fire_weapons = false


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
	return info
	
			
func fire_weapons():
	_fire_weapons = true


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
	return [
			['Set waypoint', Action.INPUT_COORDINATE, 'set_waypoint', []],
			['Set targets', Action.INPUT_ENEMY_UNITS, 'set_targets', []],
		]


func set_waypoint(_flags, waypoint):
	ai.waypoint = waypoint


func set_targets(_flags, targets):
	ai.target = targets[0] if len(targets) > 0 else null


func set_ai(p_ai):
	if ai != p_ai:
		ai = p_ai
		ai.init(self)


func get_cost():
	var cost = 0
	for body in voxel_bodies:
		cost += body.cost
	return cost


func get_linear_velocity():
	return voxel_bodies[0].linear_velocity


func get_cannons():
	var cannons := []
	for body in voxel_bodies:
		for coordinate in body.blocks:
			var block = voxel_bodies[coordinate]
			if block is Cannon:
				cannons.append(block)
	return cannons


func _voxel_body_hit(_voxel_body):
	if get_cost() * 4 / 3 < max_cost:
		destroy()


static func path_to_name(path: String) -> String:
	assert(path.ends_with(Global.FILE_EXTENSION))
	return path.substr(0, len(path) - len(Global.FILE_EXTENSION)).capitalize()
	
	
static func name_to_path(p_name: String) -> String:
	return p_name.to_lower().replace(' ', '_') + '.json'
