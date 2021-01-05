extends Node


const MetaEditor := preload("meta_editor.gd")

class Block:
	var name: String
	var rotation: int
	var node: Spatial
	var color: Color
	var layer: int

	func _init(p_name: String, p_rotation: int, p_node: Spatial, p_color: Color,
		p_layer: int) -> void:
		name = p_name
		rotation = p_rotation
		node = p_node
		color = p_color
		layer = p_layer

	func to_array() -> Array:
		return [name, rotation, node, color, layer]


const GRID_SIZE = 25
const SCALE := 1 / OwnWar_Block.BLOCK_SCALE
export var enabled := true
export var main_menu: PackedScene
export var test_map: PackedScene
export var material: SpatialMaterial setget set_material
var selected_block: OwnWar_Block
var blocks := {}
var meta := {}
var vehicle_path := ""
var _rotation := 0
var mirror := false
var ray_voxel_valid := false
var selected_layer := 0 setget set_layer
var view_layer := -1 setget set_view_layer
var _snap_face := true
onready var ray := preload("res://addons/voxel_raycast.gd").new()
onready var _floor_origin: Spatial = $Floor/Origin
onready var _floor_origin_ghost: MeshInstance = $Floor/Origin/Ghost
onready var _floor = get_node("Floor")
onready var _camera: FreeCamera = $Camera
onready var _camera_mesh: MeshInstance = $Camera/Box/Viewport/Camera/Mesh
onready var _gui_menu: Control = $GUI/Menu
onready var _gui_inventory: Control = $GUI/Inventory
onready var _gui_color_picker: Control = $GUI/ColorPicker
onready var _gui_meta_editor: MetaEditor = $GUI/MetaEditor
onready var _hud_block_layer: OptionButton = $HUD/BlockLayer
onready var _hud_block_layer_view: OptionButton = $HUD/BlockLayerView
onready var _block_face_highlighter: Spatial = get_node("BlockFaceHighlighter")


func _enter_tree():
	get_tree().paused = true


func _exit_tree():
	save_vehicle()
	get_tree().paused = false


func _ready():
	# I'm too lazy for a proper debugging solution
	if vehicle_path == "" and OS.is_debug_build():
		vehicle_path = "user://vehicles/tank.json"
	get_tree().paused = false # To be sure because ??????
	select_block(OwnWar_Block.get_block_by_id(1).name)
	set_enabled(true) # Disable UIs
	_floor.enable_mirror(mirror)
	if File.new().file_exists(vehicle_path):
		call_deferred("load_vehicle")
	else:
		# Save it to create a "slot"
		save_vehicle()


func _input(event: InputEvent) -> void:
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
	if event.is_action_pressed("designer_snap_faces"):
		_snap_face = not _snap_face
	elif event.is_action_pressed("designer_vehicle_up"):
		_move_vehicle(Vector3.UP)
	elif event.is_action_pressed("designer_vehicle_down"):
		_move_vehicle(Vector3.DOWN)
	elif event.is_action_pressed("designer_vehicle_left"):
		_move_vehicle(Vector3.RIGHT)
	elif event.is_action_pressed("designer_vehicle_right"):
		_move_vehicle(Vector3.LEFT)
	elif event.is_action_pressed("designer_vehicle_back"):
		_move_vehicle(Vector3.FORWARD)
	elif event.is_action_pressed("designer_vehicle_forward"):
		_move_vehicle(Vector3.BACK)
	elif event.is_action_pressed("designer_vehicle_rotate"):
		_rotate_vehicle()
	elif event.is_action_pressed("designer_layer_next"):
		view_layer += 1
		selected_layer = view_layer
		if view_layer > 3:
			view_layer = -1
			selected_layer = 0
		set_layer(selected_layer)
		set_view_layer(view_layer)
	elif event.is_action_pressed("designer_layer_previous"):
		view_layer -= 1
		if view_layer < -1:
			view_layer = 3
		selected_layer = 0 if view_layer == -1 else view_layer
		set_layer(selected_layer)
		set_view_layer(view_layer)


func _process(_delta):
	#_camera_mesh_camera.transform = _camera.transform
	highlight_face()
	process_actions()


func set_enabled(var p_enabled):
	enabled = p_enabled
	if p_enabled:
		_gui_menu.visible = false
		_gui_inventory.visible = false
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
			_snap_face(_a2v(ray.get_normal()))
			place_block(selected_block, coordinate, _rotation, selected_layer)
			if mirror:
				coordinate = [] + coordinate
				# warning-ignore:integer_division
				var mirror_x = (GRID_SIZE - 1) / 2
				var delta = coordinate[0] - mirror_x
				coordinate[0] = mirror_x - delta
				var m_block: OwnWar_Block = selected_block.mirror_block
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
		_floor.enable_mirror(mirror)
	elif Input.is_action_just_pressed("designer_open_colorpicker"):
		set_enabled(false)
		_gui_color_picker.visible = true
	elif Input.is_action_just_pressed("designer_release_cursor"):
		_camera.enabled = false
	elif Input.is_action_just_released("designer_release_cursor"):
		_camera.enabled = true
	elif Input.is_action_just_pressed("designer_configure"):
		if ray_voxel_valid and ray.voxel in blocks:
			var block = OwnWar_Block.get_block(blocks[ray.voxel].name)
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
	if block.editor_node != null:
		var scene = block.editor_node.duplicate()
		node.add_child(scene)
	_floor_origin.add_child(node)
	node.translation = _a2v(coordinate)
	node.transform.basis = block.get_basis(rotation)
	node.scale_object_local(Vector3.ONE * SCALE)
	node.material_override = material
	for child in Util.get_children_recursive(node):
		if child is GeometryInstance and not child is Sprite3D:
			child.material_override = material
	blocks[coordinate] = Block.new(
		block.name,
		rotation,
		node,
		material.albedo_color,
		layer
	)
	return true


func remove_block(coordinate):
	if coordinate in blocks:
		var node = blocks[coordinate].node
		node.queue_free()
		# warning-ignore:return_value_discarded
		blocks.erase(coordinate)
		return true
	return false


func select_block(name):
	selected_block = OwnWar_Block.get_block(name)
	for child in _camera_mesh.get_children():
		child.queue_free()
	for child in _floor_origin_ghost.get_children():
		child.queue_free()
	_camera_mesh.mesh = selected_block.mesh
	_floor_origin_ghost.mesh = selected_block.mesh
	if selected_block.editor_node != null:
		var camera_node: Spatial = selected_block.editor_node.duplicate()
		_camera_mesh.add_child(camera_node)
		for child in Util.get_children_recursive(camera_node):
			var vi := child as VisualInstance
			if vi != null:
				vi.layers = 1 << 7 # TODO don't hardcode this
		var node: Spatial = selected_block.editor_node.duplicate()
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
			_snap_face(_a2v(direction))
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
				_floor_origin_ghost.transform.basis = selected_block \
					.get_basis(_rotation)
				_floor_origin_ghost.scale_object_local(Vector3.ONE * SCALE)
			else:
				ray_voxel_valid = false
	_floor_origin_ghost.visible = ray_voxel_valid
	_block_face_highlighter.visible = ray_hits_block
	_block_face_highlighter.set_color(Color.green if ray_voxel_valid else Color.red)


func save_vehicle() -> void:
	var data := {}
	data['game_version'] = Util.version_vector_to_str(OwnWar.VERSION)
	data['blocks'] = {}
	for coordinate in blocks:
		var block_data = blocks[coordinate].to_array()
		block_data.remove(2)
		data['blocks']["%d,%d,%d" % coordinate] = block_data

	data["meta"] = {}
	for coordinate in meta:
		data["meta"]["%d,%d,%d" % coordinate] = meta[coordinate]

	var file := File.new()
	var err = file.open(vehicle_path, File.WRITE)
	if err != OK:
		Global.error("Failed to open file '%s'" % vehicle_path, err)
	else:
		file.store_string(to_json(data))
		print("Saved vehicle as '%s'" % vehicle_path)


func load_vehicle() -> void:
	var file := File.new()
	var err := file.open(vehicle_path, File.READ)
	if err != OK:
		Global.error("Failed to open file '%s'" % vehicle_path, err)
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
			var block = OwnWar_Block.get_block(data['blocks'][key][0])
			var color_components = data["blocks"][key][2].split_floats(",")
			var color = Color(color_components[0], color_components[1],
					color_components[2], color_components[3])
			_on_ColorPicker_pick_color(color)
			place_block(block, coordinate, data['blocks'][key][1], data["blocks"][key][3])

		meta = {}
		for crd in data["meta"]:
			var crd_arr: Array = crd.split(",")
			var c := [int(crd[0]), int(crd[1]), int(crd[2])]
			meta[c] = data["meta"][crd]

		print("Loaded vehicle from '%s'" % vehicle_path)


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
	_hud_block_layer.select(p_layer)


func set_view_layer(p_view_layer: int):
	view_layer = p_view_layer
	for coordinate in blocks:
		var block: Block = blocks[coordinate]
		var color := block.color
		if view_layer != -1 and block.layer != view_layer:
			color.a *= 0.1
		var material := MaterialCache.get_material(color)
		block.node.material_override = material
		for child in Util.get_children_recursive(block.node):
			if child is GeometryInstance and not child is Sprite3D:
				child.material_override = material
	_hud_block_layer_view.select(p_view_layer + 1)


func _snap_face(direction: Vector3) -> void:
	if _snap_face:
		var dir := OwnWar_Block.axis_to_direction(direction)
		assert(dir != -1)
		_rotation &= 0b11
		_rotation |= dir


func _move_vehicle(direction: Vector3) -> void:
	var aabb := _get_vehicle_aabb()
	aabb.position += direction
	if AABB(Vector3.ZERO, Vector3.ONE * GRID_SIZE).encloses(aabb):
		var dict := {}
		for crd in blocks:
			var b: Block = blocks[crd]
			dict[_v2a(_a2v(crd) + direction)] = b
			b.node.translation += direction
		blocks = dict


func _rotate_vehicle() -> void:
	var aabb := _get_vehicle_aabb()
	var center := aabb.position + (aabb.size / 2.0).round()
	var lower := aabb.position - center
	lower = Vector3(-lower.z, lower.y, lower.x)
	aabb.position = lower + center
	aabb.size = Vector3(-aabb.size.z, aabb.size.y, aabb.size.x)
	aabb = aabb.abs()
	if AABB(Vector3.ZERO, Vector3.ONE * GRID_SIZE).encloses(aabb):
		var dict := {}
		for crd in blocks:
			var b: Block = blocks[crd]
			lower = _a2v(crd) - center
			lower = Vector3(-lower.z, lower.y, lower.x)
			dict[_v2a(lower + center)] = b
			b.node.translation = lower + center
			b.node.rotate_y(-PI / 2.0)
			b.rotation = OwnWar_Block.basis_to_rotation(b.node.transform.basis)
		blocks = dict


func _get_vehicle_aabb() -> AABB:
	var aabb: AABB
	for crd in blocks:
		aabb = AABB(_a2v(crd), Vector3.ZERO)
		break
	for crd in blocks:
		aabb = aabb.expand(_a2v(crd))
	return aabb


# Vector3i in Godot 4...
# Gib Godot 4 pls (> °-°)>
func _v2a(v: Vector3) -> Array:
	v = v.round()
	return [int(v.x), int(v.y), int(v.z)]


func _a2v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


func _on_Exit_pressed():
	Global.goto_scene(main_menu)


func _on_Test_pressed():
	Global.goto_scene(test_map)


func _on_ColorPicker_pick_color(color):
	var mat := SpatialMaterial.new()
	mat.albedo_color = color
	set_material(mat)


func _on_BlockLayer_item_selected(index):
	set_layer(index)
	if view_layer != selected_layer and view_layer >= 0:
		set_view_layer(index)


func _on_BlockLayerView_item_selected(index):
	index -= 1
	set_view_layer(index)
	if index >= 0:
		set_layer(index)


func _on_MetaEditor_meta_changed(meta_data):
	meta[ray.voxel] = meta_data.duplicate()


func _on_Designer_pressed() -> void:
	var scene = preload("res://maps/test/test.tscn").instance()
	if vehicle_path != "":
		scene.vehicle_path = vehicle_path
	queue_free()
	var tree := get_tree()
	tree.root.remove_child(self)
	tree.root.add_child(scene)
	tree.current_scene = scene
