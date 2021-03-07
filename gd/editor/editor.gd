extends Node


# TODO
const BLOCK_SCALE := 0.25

# TODO
var BlockManager := preload("res://blocks/block_manager.gdns").new()


# Set to true if recording for trailer footage
const TRAILER_MODE := false


class Block:
	var id: int
	var position: Vector3
	var rotation: int
	var node: Spatial
	var color: Color
	var layer: int

	func _init(p_id: int, p_position: Array, p_rotation: int,
		p_node: Spatial, p_color: Color, p_layer: int) -> void:
		id = p_id
		position = Vector3(p_position[0], p_position[1], p_position[2])
		rotation = p_rotation
		node = p_node
		color = p_color
		layer = p_layer

const ErrorWindow := preload("error_window.gd")

signal block_placed(block, position)
signal block_removed(block, position)
signal vehicle_moved(position)
signal vehicle_rotated(center)
signal toggled_edit_mode(enable)

const GRID_SIZE = 25
const SCALE := 1 / BLOCK_SCALE

export var enabled := true
export var main_menu: PackedScene
export var test_map: PackedScene
export var material: SpatialMaterial setget set_material

export var place_sound := NodePath()
export var remove_sound := NodePath()
export var fail_place_or_remove_sound := NodePath()
export var rotate_sound := NodePath()
onready var place_sound_player: AudioStreamPlayer = get_node(place_sound)
onready var remove_sound_player: AudioStreamPlayer = get_node(remove_sound)
onready var fail_place_or_remove_player: AudioStreamPlayer = get_node(fail_place_or_remove_sound)
onready var rotate_player: AudioStreamPlayer = get_node(rotate_sound)

export var error_window_path := NodePath()
var queued_error_message := ""
onready var error_window: ErrorWindow = get_node(error_window_path)

export var camera_path := NodePath()
onready var camera: FreeCamera = get_node(camera_path)

var selected_block: OwnWar_Block
var blocks := {}
var vehicle_name := ""
var vehicle_path := ""
var _rotation := 0
var mirror := false
var ray_voxel_valid := false
var _snap_face := true

export var max_layers := 8
export var _layer_selector := NodePath()
var selected_layer := 0 setget set_layer
var edit_mode := false setget set_edit_mode
var map_rotations := true
onready var layer_selector: OptionButton = get_node(_layer_selector)

var mainframe_count := 0

onready var ray := preload("res://addons/voxel_raycast.gd").new()
onready var _floor_origin: Spatial = $Floor/Origin
onready var _floor_origin_ghost: MeshInstance = $Floor/Origin/Ghost
onready var _floor = get_node("Floor")
onready var _camera: FreeCamera = $Camera
onready var _camera_mesh: MeshInstance = $Camera/Box/Viewport/Camera/Mesh
onready var _gui_menu: Control = $Menu
onready var _gui_inventory: Control = $Inventory
onready var _gui_color_picker: Control = $ColorPicker
onready var _block_face_highlighter: Spatial = get_node("BlockFaceHighlighter")


onready var outline: OwnWar_Outline = get_node("Outline")


func _enter_tree():
	get_tree().paused = true


func _ready():
	# I'm too lazy for a proper debugging solution
	if vehicle_path == "":
		if vehicle_name == "" and OS.is_debug_build():
			vehicle_name = "tank"
		else:
			assert(false, "vehicle_name is empty")
		vehicle_path = OwnWar.get_vehicle_path(vehicle_name)
	get_tree().paused = false # To be sure because ??????
	select_block(1)
	set_enabled(true) # Disable UIs
	set_mirror(mirror)
	if File.new().file_exists(vehicle_path):
		call_deferred("load_vehicle")
	else:
		# Save it to create a "slot"
		save_vehicle()
	for i in max_layers:
		layer_selector.add_item("Layer %d" % i, i)

	var e := OwnWar_Settings.connect("mouse_move_sensitivity_changed", camera, "set_angular_speed")
	assert(e == OK)

	if TRAILER_MODE:
		for child in Util.get_children_recursive(self):
			if child is Control or child.name == "TODO text" or child.name == "Ghost" or child.name == "BlockFaceHighlighter":
				child.visible = false
		set_process(false)
		set_process_input(false)


func _input(event: InputEvent) -> void:
	# TODO fix BaseButton so it also detects mouse button shortcuts
	if event.is_action_pressed("editor_rotate_up"):
		rotate_block_up()
	elif event.is_action_pressed("editor_rotate_down"):
		rotate_block_down()


func _process(_delta):
	highlight_face()
	process_actions()


func _exit_tree():
	save_vehicle()
	get_tree().paused = false

	OwnWar_Settings.disconnect("mouse_move_sensitivity_changed", camera, "set_angular_speed")


func set_enabled(var p_enabled):
	enabled = p_enabled
	if p_enabled:
		_gui_menu.visible = false
		_gui_inventory.visible = false
		_gui_color_picker.visible = false
	_camera.enabled = enabled
	set_process(enabled)
	set_process_input(enabled)
	set_physics_process(enabled)


func process_actions():
	if Input.is_action_just_pressed("ui_cancel"):
		set_enabled(false)
		_gui_menu.visible = true
	elif Input.is_action_pressed("editor_open_inventory"):
		set_enabled(false)
		_gui_inventory.visible = true
	elif Input.is_action_just_pressed("editor_place_block"):
		if ray_voxel_valid and not Input.is_action_pressed("editor_release_cursor"):
			var coordinate = _v2a(_a2v(ray.voxel) + _a2v(ray.get_normal()))
			snap_face(_a2v(ray.get_normal()))
			var placed := place_block(selected_block, coordinate, _rotation,
				material.albedo_color, selected_layer)
			if placed and mirror:
				coordinate = [] + coordinate
				# warning-ignore:integer_division
				var mirror_x = (GRID_SIZE - 1) / 2
				var delta = coordinate[0] - mirror_x
				coordinate[0] = mirror_x - delta
				var m_block: OwnWar_Block = selected_block.mirror_block
				var _success := place_block(m_block, coordinate, m_block.get_mirror_rotation(_rotation),
					material.albedo_color, selected_layer)
			if placed:
				place_sound_player.play()
			else:
				error_window.show_error(queued_error_message)
				fail_place_or_remove_player.play()
	elif Input.is_action_just_pressed("editor_remove_block"):
		if not ray.finished and not Input.is_action_pressed("editor_release_cursor"):
			var coordinate = [] + ray.voxel
			var removed := remove_block(coordinate)
			if removed and mirror:
				coordinate = [] + coordinate
				# warning-ignore:integer_division
				var mirror_x = (GRID_SIZE - 1) / 2
				var delta = coordinate[0] - mirror_x
				coordinate[0] = mirror_x - delta
				var _success := remove_block(coordinate)
			if removed:
				remove_sound_player.play()
			else:
				error_window.show_error(queued_error_message)
				fail_place_or_remove_player.play()
	elif Input.is_action_just_pressed("editor_open_colorpicker"):
		set_enabled(false)
		_gui_color_picker.visible = true
	elif Input.is_action_just_pressed("editor_release_cursor"):
		_camera.enabled = false
	elif Input.is_action_just_released("editor_release_cursor"):
		_camera.enabled = true


func place_block(block: OwnWar_Block, coordinate: Array, rotation: int,
	color: Color, layer: int) -> bool:
	if not edit_mode:
		queued_error_message = "Enter edit mode to place blocks"
		return false
	for c in coordinate:
		if c < 0 or c >= GRID_SIZE:
			queued_error_message = "Location is outside grid"
			return false
	if coordinate in blocks:
		queued_error_message = "A block is already placed here"
		return false
	var mi := MeshInstance.new()
	var node: Spatial = null
	mi.mesh = block.mesh
	if block.editor_node != null:
		node = block.editor_node.duplicate()
		mi.add_child(node)
	if node != null:
		if node.has_method("set_color"):
			node.set_color(color)
		if map_rotations and node.has_method("map_rotation"):
			rotation = node.map_rotation(rotation)
	_floor_origin.add_child(mi)
	mi.translation = _a2v(coordinate)
	mi.transform.basis = block.get_basis(rotation)
	mi.scale_object_local(Vector3.ONE * SCALE)
	mi.material_override = SpatialMaterial.new()
	mi.material_override.albedo_color = color
	blocks[coordinate] = Block.new(
		block.id,
		coordinate,
		rotation,
		mi,
		color,
		layer
	)
	if block.id == OwnWar.MAINFRAME_ID:
		mainframe_count += 1
	emit_signal("block_placed", block, Vector3(coordinate[0], coordinate[1], coordinate[2]))

	outline.outline_node(mi)
	if node != null:
		for n in Util.get_children_recursive(node):
			if n != null and n is MeshInstance and not n.has_meta("no_outline"):
				outline.outline_node(n)
	return true


func remove_block(coordinate: Array) -> bool:
	if edit_mode and coordinate in blocks:
		var blk: Block = blocks[coordinate]
		if blk.layer != selected_layer:
			queued_error_message = "Switch layer to remove this block"
			return false
		var node = blk.node
		node.queue_free()
		if blk.id == OwnWar.MAINFRAME_ID:
			mainframe_count -= 1
		emit_signal("block_removed", BlockManager.get_block(blk.id), Vector3(coordinate[0], coordinate[1], coordinate[2]))
		var _e := blocks.erase(coordinate)
		return true
	if not edit_mode:
		queued_error_message = "Enter edit mode to remove blocks"
	else:
		queued_error_message = "No block found at this location"
	return false


func select_block(id: int) -> void:
	selected_block = BlockManager.get_block(id)
	for child in _camera_mesh.get_children():
		child.queue_free()
	for child in _floor_origin_ghost.get_children():
		child.queue_free()
	_camera_mesh.mesh = selected_block.mesh
	_floor_origin_ghost.mesh = selected_block.mesh
	if selected_block.editor_node != null:
		var camera_node: Spatial = selected_block.editor_node.duplicate()
		var ghost_node: Spatial = selected_block.editor_node.duplicate()
		_camera_mesh.add_child(camera_node)
		_floor_origin_ghost.add_child(ghost_node)
		for child in Util.get_children_recursive(camera_node):
			var vi := child as VisualInstance
			if vi != null:
				vi.layers = 1 << 7 # TODO don't hardcode this
		var color := material.albedo_color
		if ghost_node.has_method("set_color"):
			camera_node.set_color(color)
			ghost_node.set_color(color)
		if ghost_node.has_method("set_transparency"):
			ghost_node.set_transparency(0.5)
		if ghost_node.has_method("set_preview_mode"):
			ghost_node.set_preview_mode(true)
	_camera_mesh.material_override = material


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
			snap_face(_a2v(direction))
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
				var rot := _rotation
				if map_rotations and _floor_origin_ghost.get_child_count() > 0:
					if _floor_origin_ghost.get_child(0).has_method("map_rotation"):
						rot = _floor_origin_ghost.get_child(0).map_rotation(rot)
				ray_voxel_valid = true
				_floor_origin_ghost.translation = _a2v(place_at)
				_floor_origin_ghost.transform.basis = selected_block \
					.get_basis(rot)
				_floor_origin_ghost.scale_object_local(Vector3.ONE * SCALE)
			else:
				ray_voxel_valid = false
	_floor_origin_ghost.visible = ray_voxel_valid
	_block_face_highlighter.visible = ray_hits_block
	_block_face_highlighter.set_color(Color.green if ray_voxel_valid else Color.red)


func save_vehicle() -> void:
	if TRAILER_MODE:
		print("Refusing to save in trailer mode to prevent data loss")
		return
	var MAGIC := 493279249 # Totally random, not derived from a name
	var REVISION := 0
	var file := File.new()
	var err := Util.create_dirs(vehicle_path.get_base_dir())
	if err != OK:
		print("Failed to create directory %s: %s" % [
			vehicle_path.get_base_dir(),
			Global.ERROR_TO_STRING[err]
		])
		assert(false)
		return
	err = file.open_compressed(vehicle_path, File.WRITE, File.COMPRESSION_GZIP)
	if err != OK:
		print("Failed to open file %s: %s" % [vehicle_path, Global.ERROR_TO_STRING[err]])
		assert(false)
		return
	file.store_32(MAGIC)
	file.store_16(REVISION)
	var by_layer := {}
	for crd in blocks:
		var b: Block = blocks[crd]
		var arr = by_layer.get(b.layer)
		if arr == null:
			assert(len(by_layer) < 255, "Layer count must remain below 256")
			by_layer[b.layer] = [b]
		else:
			arr.push_back(b)
	file.store_8(len(by_layer))
	for layer in by_layer:
		file.store_8(layer)
		var list: Array = by_layer[layer]
		var aabb := AABB(list[0].position, Vector3.ONE)
		for b in list:
			aabb = aabb.expand(b.position).expand(b.position + Vector3.ONE)
		file.store_8(int(aabb.position.x))
		file.store_8(int(aabb.position.y))
		file.store_8(int(aabb.position.z))
		file.store_8(int(aabb.size.x))
		file.store_8(int(aabb.size.y))
		file.store_8(int(aabb.size.z))
		file.store_32(len(list))
		for b in list:
			file.store_8(int(b.position.x))
			file.store_8(int(b.position.y))
			file.store_8(int(b.position.z))
			file.store_16(b.id)
			file.store_8(b.rotation)
			file.store_8(b.color.r8)
			file.store_8(b.color.g8)
			file.store_8(b.color.b8)
	print("Saved vehicle as %s" % vehicle_path)


func load_vehicle() -> void:

	if TRAILER_MODE:
		while not Input.is_key_pressed(KEY_KP_5):
			yield(get_tree(), "idle_frame")

	var prev_edit_mode := edit_mode
	var prev_map_rotations := map_rotations
	edit_mode = true
	map_rotations = false
	var MAGIC := 493279249 # Totally random, not derived from a name
	var REVISION := 0
	var file := File.new()
	var err = file.open_compressed(vehicle_path, File.READ, File.COMPRESSION_GZIP)
	if err != OK:
		Global.error("Failed to open file %s: %s" % [vehicle_path, Global.ERROR_TO_STRING[err]])
	else:
		for child in _floor_origin.get_children():
			if child.name != "Ghost":
				child.queue_free()
		blocks.clear()
		var data := file.get_buffer(file.get_len())
		var loader := OwnWar_VehicleLoader.new()
		err = loader.load_from_data(data)
		if err != OK:
			print("Failed to load vehicle:", Global.ERROR_TO_STRING[err])
			return
		for layer in loader.bodies:
			var body: OwnWar_VehicleLoader.Body = loader.bodies[layer]
			for blk in body.blocks:
				var x := int(blk.position.x)
				var y := int(blk.position.y)
				var z := int(blk.position.z)
				var _success := place_block(blk.block, [x, y, z], blk.rotation, blk.color, layer)
				if TRAILER_MODE:
					edit_mode = false
					update_block_visibility()
					edit_mode = true
					yield(get_tree(), "idle_frame")
		print("Loaded vehicle from %s" % vehicle_path)
	edit_mode = prev_edit_mode
	map_rotations = prev_map_rotations
	update_block_visibility()


func set_material(p_material: SpatialMaterial):
	# Damn exports...
	if not has_node("Floor/Origin/Ghost"):
		call_deferred("set_material", p_material)
		return
	material = p_material
	var ghost_material := material.duplicate() as SpatialMaterial
	ghost_material.flags_transparent = true
	ghost_material.albedo_color.a *= 0.5
	_floor_origin_ghost.material_override = ghost_material
	_camera_mesh.material_override = material
	for node in _floor_origin_ghost.get_children():
		if node.has_method("set_color"):
			node.set_color(material.albedo_color)
	for node in _camera_mesh.get_children():
		if node.has_method("set_color"):
			var color := material.albedo_color
			color.a *= 0.5
			node.set_color(color)


func set_layer(p_layer: int) -> void:
	selected_layer = p_layer
	layer_selector.select(p_layer)
	update_block_visibility()


func set_edit_mode(enable: bool) -> void:
	edit_mode = enable
	update_block_visibility()
	emit_signal("toggled_edit_mode", enable)


func set_mirror(enable: bool) -> void:
	mirror = enable
	_floor.enable_mirror(enable)


func set_snap_faces(enable: bool) -> void:
	_snap_face = enable


func set_map_rotations(enable: bool) -> void:
	map_rotations = enable


func next_layer() -> void:
	selected_layer += 1
	if selected_layer >= max_layers:
		selected_layer = 0
	set_layer(selected_layer)


func previous_layer() -> void:
	selected_layer -= 1
	if selected_layer < 0:
		selected_layer = max_layers - 1
	set_layer(selected_layer)


func update_block_visibility() -> void:
	for coordinate in blocks:
		var block: Block = blocks[coordinate]
		var color := block.color
		var transparent := edit_mode and block.layer != selected_layer
		if transparent:
			color.a *= 0.15
		var mat := MaterialCache.get_material(color)
		block.node.material_override = mat
		for node in block.node.get_children():
			if node.has_method("set_color"):
				node.set_color(color)
			if node.has_method("set_transparency"):
				node.set_transparency(0.15 if transparent else 1.0)
			if node.has_method("set_preview_mode"):
				node.set_preview_mode(not edit_mode)


func rotate_block_down() -> void:
	_rotation = posmod(_rotation - 1, 24)
	rotate_player.play()


func rotate_block_up() -> void:
	_rotation = posmod(_rotation + 1, 24)
	rotate_player.play()


func snap_face(direction: Vector3) -> void:
	if _snap_face:
		var dir: int = BlockManager.axis_to_direction(direction)
		assert(dir != -1)
		_rotation &= 0b11
		_rotation |= dir


func move_vehicle(direction: Vector3) -> void:
	var aabb := _get_vehicle_aabb()
	aabb.position += direction
	if AABB(Vector3.ZERO, Vector3.ONE * GRID_SIZE).encloses(aabb):
		var dict := {}
		for crd in blocks:
			var b: Block = blocks[crd]
			dict[_v2a(_a2v(crd) + direction)] = b
			b.node.translation += direction
			b.position += direction
		blocks = dict
		emit_signal("vehicle_moved", direction)
	else:
		error_window.show_error("No place to move vehicle")
		fail_place_or_remove_player.play()


func rotate_vehicle() -> void:
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
			b.position = lower + center
			b.node.translation = lower + center
			b.node.rotate_y(-PI / 2.0)
			b.rotation = OwnWar_Block.basis_to_rotation(b.node.transform.basis)
		blocks = dict
		emit_signal("vehicle_rotated", center)
	else:
		error_window.show_error("No place to rotate vehicle (try centering it)")
		fail_place_or_remove_player.play()


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


func _on_ColorPicker_pick_color(color):
	var mat := SpatialMaterial.new()
	mat.albedo_color = color
	set_material(mat)


func _on_Designer_pressed() -> void:
	if mainframe_count == 1:
		var scene = preload("res://maps/test/test.tscn").instance()
		scene.vehicle_path = vehicle_path
		queue_free()
		var tree := get_tree()
		tree.root.remove_child(self)
		tree.root.add_child(scene)
		tree.current_scene = scene
	else:
		assert(mainframe_count >= 0, "Negative mainframe count!")
		if mainframe_count == 0:
			error_window.show_error("Vehicle has no mainframe")
		else:
			error_window.show_error("Vehicle has multiple mainframes")
		fail_place_or_remove_player.play()
