extends Node


const MetaEditor := preload("meta_editor.gd")


const GRID_SIZE = 25
const SCALE = 4
export var enabled := true
export var main_menu: PackedScene
export var test_map: PackedScene
export var material: SpatialMaterial setget set_material
var selected_block: OwnWar.Block
var blocks := {}
var meta := {}
var _rotation := 0
var mirror := false
var ray_voxel_valid := false
var selected_layer := 0 setget set_layer
var view_layer := -1 setget set_view_layer
onready var ray := preload("res://addons/voxel_raycast.gd").new()
onready var _floor_origin: Spatial = $Floor/Origin
onready var _floor_origin_ghost: MeshInstance = $Floor/Origin/Ghost
onready var _floor_mirror: Spatial = $Floor/Mirror
onready var _camera: FreeCamera = $Camera
onready var _camera_mesh: MeshInstance = $Camera/MeshInstance
onready var _gui_menu: Control = $GUI/Menu
onready var _gui_inventory: Control = $GUI/Inventory
onready var _gui_save_vehicle: Control = $GUI/SaveVehicle
onready var _gui_load_vehicle: Control = $GUI/LoadVehicle
onready var _gui_color_picker: Control = $GUI/ColorPicker
onready var _gui_meta_editor: MetaEditor = $GUI/MetaEditor
onready var _hud_block_layer: OptionButton = $HUD/BlockLayer
onready var _hud_block_layer_view: OptionButton = $HUD/BlockLayerView
onready var _block_face_highlighter: Spatial = $BlockFaceHighlighter
onready var _block_face_highlighter_csgbox: CSGBox = $BlockFaceHighlighter/CSGBox


func _enter_tree():
	get_tree().paused = true


func _exit_tree():
	get_tree().paused = false


func _ready():
	select_block(OwnWar.Block.get_block_by_id(1).name)
	set_enabled(true) # Disable UIs
	_floor_mirror.visible = mirror


func _input(event):
	if not _camera.enabled:
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
		_gui_menu.visible = false
		_gui_inventory.visible = false
		_gui_save_vehicle.visible = false
		_gui_load_vehicle.visible = false
		_gui_color_picker.visible = false
		_gui_meta_editor.visible = false
	_camera.enabled = enabled
	set_process(enabled)
	set_process_input(enabled)
	set_physics_process(enabled)


func process_actions():
	if Input.is_action_just_pressed("ui_cancel"):
		set_enabled(false)
		_gui_menu.visible = true
	elif Input.is_action_pressed("designer_open_inventory"):
		set_enabled(false)
		_gui_inventory.visible = true
	elif Input.is_action_just_pressed("designer_place_block"):
		if ray_voxel_valid and not Input.is_action_pressed("designer_release_cursor"):
			var coordinate = _v2a(_a2v(ray.voxel) + _a2v(ray.get_normal()))
			place_block(selected_block, coordinate, _rotation, selected_layer)
			if mirror:
				coordinate = [] + coordinate
				# warning-ignore:integer_division
				var mirror_x = (GRID_SIZE - 1) / 2
				var delta = coordinate[0] - mirror_x
				coordinate[0] = mirror_x - delta
				var m_block: OwnWar.Block = selected_block.mirror_block
				place_block(m_block, coordinate, m_block \
						.get_mirror_rotation(_rotation), selected_layer)
	elif Input.is_action_just_pressed("designer_remove_block"):
		if not ray.finished and not Input.is_action_pressed("designer_release_cursor"):
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
		_floor_mirror.visible = mirror
	elif Input.is_action_just_pressed("designer_open_colorpicker"):
		set_enabled(false)
		_gui_color_picker.visible = true
	elif Input.is_action_just_pressed("designer_release_cursor"):
		_camera.enabled = false
	elif Input.is_action_just_released("designer_release_cursor"):
		_camera.enabled = true
	elif Input.is_action_just_pressed("designer_configure"):
		if ray_voxel_valid and ray.voxel in blocks:
			var block = OwnWar.Block.get_block(blocks[ray.voxel][0])
			if len(block.meta) > 0:
				var meta_data = meta[ray.voxel] if ray.voxel in meta else block.meta
				set_enabled(false)
				_gui_meta_editor.set_meta_items(block, meta_data)
				_gui_meta_editor.visible = true


func place_block(block, coordinate, rotation, layer):
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
	_floor_origin.add_child(node)
	node.translation = _a2v(coordinate)
	node.transform.basis = block.get_basis(rotation)
	node.scale_object_local(Vector3.ONE * SCALE)
	node.material_override = material
	for child in Util.get_children_recursive(node):
		if child is GeometryInstance and not child is Sprite3D:
			child.material_override = material
	blocks[coordinate] = [block.name, rotation, node, material.albedo_color, layer]
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
	selected_block = OwnWar.Block.get_block(name)
	for child in _camera_mesh.get_children():
		child.queue_free()
	for child in _floor_origin_ghost.get_children():
		child.queue_free()
	_camera_mesh.mesh = selected_block.mesh
	_floor_origin_ghost.mesh = selected_block.mesh
	if selected_block.scene != null:
		_camera_mesh.add_child(selected_block.scene.instance())
		var node = selected_block.scene.instance()
		_floor_origin_ghost.add_child(node)
		for child in Util.get_children_recursive(node):
			if child is MeshInstance:
				if child.material_override != null:
					child.material_override = child.material_override.duplicate()
					child.material_override.flags_transparent = true
					child.material_override.albedo_color.a *= 0.2
				else:
					child.material_override = _floor_origin_ghost.material_override
			elif child is Sprite3D:
				child.opacity *= 0.2
	_camera_mesh.material_override = material
	for child in Util.get_children_recursive(_camera_mesh):
		if child is GeometryInstance and not child is Sprite3D:
			child.material_override = material


func highlight_face():
	ray.start(_camera.translation, -_camera.transform.basis.z, GRID_SIZE, GRID_SIZE, GRID_SIZE)
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
			_block_face_highlighter.transform = Transform(x, y, z,
					_a2v(place_at) + (Vector3.ONE - _a2v(direction)) * 0.5)
			if AABB(Vector3.ZERO, Vector3.ONE * (GRID_SIZE - 1)).has_point(_a2v(place_at)) \
					and not place_at in blocks:
				ray_voxel_valid = true
				_floor_origin_ghost.translation = _a2v(place_at)
				_floor_origin_ghost.transform.basis = selected_block.get_basis(_rotation)
				_floor_origin_ghost.scale_object_local(Vector3.ONE * SCALE)
			else:
				ray_voxel_valid = false
	_floor_origin_ghost.visible = ray_voxel_valid
	_block_face_highlighter.visible = ray_hits_block
	var csgbox_mat: SpatialMaterial = _block_face_highlighter_csgbox.material
	csgbox_mat.albedo_color = Color.green if ray_voxel_valid else Color.red


func save_vehicle(var path):
	var data := {}
	data['game_version'] = Util.version_vector_to_str(OwnWar.VERSION)
	data['blocks'] = {}
	for coordinate in blocks:
		var block_data = blocks[coordinate].duplicate()
		block_data.remove(2)
		data['blocks']["%d,%d,%d" % coordinate] = block_data

	data["meta"] = {}
	for coordinate in meta:
		data["meta"]["%d,%d,%d" % coordinate] = meta[coordinate]

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
		data = OwnWar.Compatibility.convert_vehicle_data(data)
		for child in _floor_origin.get_children():
			if child.name != "Ghost":
				child.queue_free()
		blocks.clear()
		for key in data['blocks']:
			var coordinate = [null, null, null]
			var key_components = key.split(',')
			assert(len(key_components) == 3)
			for i in range(3):
				coordinate[i] = int(key_components[i])
			var block = OwnWar.Block.get_block(data['blocks'][key][0])
			var color_components = data["blocks"][key][2].split_floats(",")
			var color = Color(color_components[0], color_components[1],
					color_components[2], color_components[3])
			_on_ColorPicker_pick_color(color)
			place_block(block, coordinate, data['blocks'][key][1], data["blocks"][key][3])

		meta = data["meta"]

		print("Loaded vehicle from '%s'" % path)


func set_material(p_material: SpatialMaterial):
	# Damn exports...
	if not has_node("Floor/Origin/Ghost"):
		call_deferred("set_material", p_material)
		return
	material = p_material
	var ghost_material := material.duplicate() as SpatialMaterial
	ghost_material.flags_transparent = true
	ghost_material.albedo_color.a *= 0.6
	_floor_origin_ghost.material_override = ghost_material
	_camera_mesh.material_override = material
	for child in Util.get_children_recursive(_floor_origin_ghost):
		if child is GeometryInstance and not child is Sprite3D:
			child.material_override = ghost_material
	for child in Util.get_children_recursive(_camera_mesh):
		if child is GeometryInstance and not child is Sprite3D:
			child.material_override = material


func set_layer(p_layer: int):
	selected_layer = p_layer


func set_view_layer(p_view_layer: int):
	view_layer = p_view_layer
	for coordinate in blocks:
		var block = blocks[coordinate]
		block[2].visible = view_layer < 0 or block[4] == view_layer


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


func _on_ColorPicker_pick_color(color):
	var mat := SpatialMaterial.new()
	mat.albedo_color = color
	set_material(mat)


func _on_BlockLayer_item_selected(index):
	set_layer(index)
	if view_layer != selected_layer and view_layer >= 0:
		set_view_layer(index)
		_hud_block_layer_view.select(index + 1)


func _on_BlockLayerView_item_selected(index):
	index -= 1
	set_view_layer(index)
	if index >= 0:
		set_layer(index)
		_hud_block_layer.select(index)


func _on_MetaEditor_meta_changed(meta_data):
	meta[ray.voxel] = meta_data.duplicate()
