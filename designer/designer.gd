extends Node


const GRID_SIZE = 25
const SCALE = 4

export(bool) var enabled := true
export(PackedScene) var main_menu
export(PackedScene) var test_map

var block: Block
var blocks := {}
var _rotation := 0
var mirror := false
var ray_voxel_valid := false

onready var ray := preload("res://addons/voxel_raycast.gd").new()


func _ready():
	select_block("cube")
	set_enabled(true) # Disable UIs
	$Floor/Mirror.visible = mirror


func _input(event):
	if not $Camera.enabled:
		return
	if event is InputEventMouseButton and event.is_pressed():
		if event.is_action("designer_rotate_down"):
			_rotation -= 1
			if _rotation < 0:
				_rotation = 23
		elif event.is_action("designer_rotate_up"):
			_rotation += 1
			if _rotation >= 24:
				_rotation = 0


func _process(_delta):
	highlight_face()
	process_actions()


func set_enabled(var p_enabled):
	enabled = p_enabled
	if p_enabled:
		$HUD/Menu.visible = false
		$HUD/Inventory.visible = false
		$HUD/SaveVehicle.visible = false
		$HUD/LoadVehicle.visible = false
	$HUD/Tint.visible = not enabled
	$Camera.enabled = enabled
	set_process(enabled)
	set_process_input(enabled)
	set_physics_process(enabled)


func process_actions():
	if Input.is_action_just_pressed("ui_cancel"):
		set_enabled(false)
		$HUD/Menu.visible = true
	elif Input.is_action_pressed("designer_open_inventory"):
		set_enabled(false)
		$HUD/Inventory.visible = true
	elif Input.is_action_just_pressed("designer_place_block"):
		if ray_voxel_valid:
			var coordinate = _v2a(_a2v(ray.voxel) + _a2v(ray.get_normal()))
			place_block(coordinate, _rotation)
			if mirror:
				coordinate = [] + coordinate
				# warning-ignore:integer_division
				var mirror_x = (GRID_SIZE - 1) / 2
				var delta = coordinate[0] - mirror_x
				coordinate[0] = mirror_x - delta
				place_block(coordinate, Block.mirror_rotation(_rotation))
	elif Input.is_action_just_pressed("designer_remove_block"):
		if ray_voxel_valid:
			var coordinate = [] + ray.voxel
			remove_block(coordinate)
			if mirror:
				coordinate = [] + coordinate
				# warning-ignore:integer_division
				var mirror_x = (GRID_SIZE - 1) / 2
				var delta = coordinate[0] - mirror_x
				coordinate[0] = mirror_x - delta
				remove_block(coordinate)
	elif Input.is_action_just_pressed("designer_mirror"):
		mirror = not mirror
		$Floor/Mirror.visible = mirror


func place_block(coordinate, rotation):
	for c in coordinate:
		if c < 0 or c >= GRID_SIZE:
			return false
	if coordinate in blocks:
		return false
	var node = MeshInstance.new()
	node.mesh = block.mesh
	node.material_override = block.material
	if block.scene != null:
		var scene = block.scene.instance()
		node.add_child(scene)
	$Floor/Origin.add_child(node)
	node.translation = _a2v(coordinate)
	node.transform.basis = Block.rotation_to_basis(rotation)
	node.scale_object_local(Vector3.ONE * SCALE)
	blocks[coordinate] = [block.name, rotation, node]
	return true


func remove_block(coordinate):
	if coordinate in blocks:
		var node = blocks[coordinate][2]
		node.queue_free()
		# warning-ignore:return_value_discarded
		blocks.erase(coordinate)
		return true
	return false


func select_block(name):
	block = Global.get_block(name)
	for child in $Camera/MeshInstance.get_children():
		child.queue_free()
	for child in $Floor/Origin/Ghost.get_children():
		child.queue_free()
	$Camera/MeshInstance.mesh = block.mesh
	$Floor/Origin/Ghost.mesh = block.mesh
	if block.scene != null:
		$Camera/MeshInstance.add_child(block.scene.instance())
		var node = block.scene.instance()
		$Floor/Origin/Ghost.add_child(node)
		for child in get_children_recursive(node):
			if child is MeshInstance:
				if child.material_override != null:
					child.material_override = child.material_override.duplicate()
					child.material_override.flags_transparent = true
					child.material_override.albedo_color.a *= 0.2
				else:
					child.material_override = $Floor/Origin/Ghost.material_override
			elif child is Sprite3D:
				child.opacity *= 0.2


func highlight_face():
	ray.start($Camera.translation, -$Camera.transform.basis.z, GRID_SIZE, GRID_SIZE, GRID_SIZE)
	var ray_hits_block = not ray.finished
	if ray.finished:
		ray_voxel_valid = false
	else:
		while not ray.finished:
			if blocks.has(ray.voxel):
				break
			ray.step()
		if ray.finished and ray.y != -1:
			ray_voxel_valid = false
			ray_hits_block = false
		else:
			var direction = ray.get_normal()
			var place_at = _v2a(_a2v(ray.voxel) + _a2v(direction))
			var x = _a2v(direction)
			var y = Vector3.RIGHT.cross(x)
			var z = y.cross(x)
			if y.length_squared() < 0.01:
				z = Vector3.UP.cross(x)
				y = z.cross(x)
			$BlockFaceHighlighter.transform = Transform(x, y, z, _a2v(place_at) + 
					(Vector3.ONE - _a2v(direction)) * 0.5)
			if AABB(Vector3.ZERO, Vector3.ONE * (GRID_SIZE - 1)).has_point(_a2v(place_at)) \
					and not place_at in blocks:
				ray_voxel_valid = true
				$Floor/Origin/Ghost.translation = _a2v(place_at)
				$Floor/Origin/Ghost.transform.basis = Block.rotation_to_basis(_rotation)
				$Floor/Origin/Ghost.scale_object_local(Vector3.ONE * SCALE)
			else:
				ray_voxel_valid = false
	$Floor/Origin/Ghost.visible = ray_voxel_valid
	$BlockFaceHighlighter.visible = ray_hits_block
	$BlockFaceHighlighter/CSGBox.material.albedo_color = Color.green if ray_voxel_valid else Color.red
	

func save_vehicle(var path):
	var data := {}
	data['game_version'] = Global.VERSION
	data['blocks'] = {}
	for coordinate in blocks:
		data['blocks']["%d,%d,%d" % coordinate] = blocks[coordinate].slice(0, 1)
	var file := File.new()
	var err = file.open(path, File.WRITE)
	if err != OK:
		Global.error("Failed to open file '%s'" % path, err)
	else:
		file.store_string(to_json(data))
		print("Saved vehicle as '%s'" % path)


func load_vehicle(path):
	var file := File.new()
	var err = file.open(path, File.READ)
	if err != OK:
		Global.error("Failed to open file '%s'" % path, err)
	else:
		var data = parse_json(file.get_as_text())
		for child in $Floor/Origin.get_children():
			if child.name != "Ghost":
				child.queue_free()
		blocks.clear()
		for key in data['blocks']:
			var coordinate = [null, null, null]
			var key_components = key.split(',')
			assert(len(key_components) == 3)
			for i in range(3):
				coordinate[i] = int(key_components[i])
			block = Global.get_block(data['blocks'][key][0])
			place_block(coordinate, data['blocks'][key][1])
		print("Loaded vehicle from '%s'" % path)


# REEEEEEE https://github.com/godotengine/godot/issues/16105
func get_children_recursive(node = null, array = []):
	node = node if node != null else self
	for child in node.get_children():
		array.append(child)
		get_children_recursive(child, array)
	return array


# Vector3i in Godot 4...
# Gib Godot 4 pls (> °-°)>
func _v2a(v):
	v.round()
	return [int(v.x), int(v.y), int(v.z)]


func _a2v(a):
	return Vector3(a[0], a[1], a[2])


func _on_Exit_pressed():
	Global.goto_scene(main_menu)


func _on_Test_pressed():
	Global.goto_scene(test_map)


func _on_LoadVehicle_load_vehicle(path):
	load_vehicle(path)
	set_enabled(true)
