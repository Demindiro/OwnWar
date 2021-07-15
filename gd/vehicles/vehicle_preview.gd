extends Spatial
class_name OwnWar_VehiclePreview


# TODO
const BLOCK_SCALE := 0.25
const GRID_SIZE := 37


var voxel_mesh := OwnWar_VoxelMesh.new()
var mesh_instance := MeshInstance.new()
var aabb := AABB()
var cost := 0
var mass := 0.0
var block_count := 0
var mainframe_count := 0
var is_valid := false
var invalid_reason = null


func _ready() -> void:
	mesh_instance.mesh = voxel_mesh
	add_child(mesh_instance)


func _process(_delta: float) -> void:
	if voxel_mesh.dirty:
		voxel_mesh.generate()


func load_from_file(path: String) -> int:
	var file := File.new()
	var err := file.open_compressed(path, File.READ, File.COMPRESSION_GZIP)
	if err != OK:
		err = file.open(path, File.READ)
	if err != OK:
		return err

	return load_from_data(file.get_buffer(file.get_len()))


func load_from_data(data: PoolByteArray) -> int:

	var spb := StreamPeerBuffer.new()
	spb.data_array = data

	var center := Vector3.ONE * GRID_SIZE * BLOCK_SCALE / 2

	var loader := OwnWar_VehicleLoader.new()
	var err := loader.load_from_data(data)
	if err != OK:
		print("Failed to load vehicle: ", Global.ERROR_TO_STRING[err])
		return err

	var BlockManager := preload("res://blocks/block_manager.gdns").new()
	for layer in loader.bodies:
		var body: OwnWar_VehicleLoader.Body = loader.bodies[layer]
		for block in body.blocks:
			var blk: OwnWar_Block = block.block
			voxel_mesh.add_block_gd(blk, block.color, block.position, block.rotation)
			if blk.editor_node != null:
				var node: Spatial = blk.editor_node.duplicate()
				node.set("team_color", OwnWar.ALLY_COLOR)
				add_child(node)
				if node.has_method("set_preview_mode"):
					node.set_preview_mode(true)
				node.transform = Transform(
					BlockManager.rotation_to_basis(block.rotation),
					(block.position + Vector3.ONE / 2) * BLOCK_SCALE - center
				)
				if node.has_method("set_color"):
					node.set_color(block.color)
			if aabb == AABB():
				aabb.position = block.position
				aabb.size = Vector3.ONE
			else:
				aabb = aabb.expand(block.position).expand(block.position + Vector3.ONE)
			block_count += 1
			cost += blk.cost
			mass += blk.mass
	
	mainframe_count = loader.mainframe_count

	# TODO should we center based on AABB or editor grid size?
	mesh_instance.translation -= Vector3.ONE * GRID_SIZE * BLOCK_SCALE / 2
	mesh_instance.translation += Vector3.ONE * BLOCK_SCALE / 2

	# Try to load the vehicle as an actual vehicle to see if it's valid.
	var v = OwnWar_Vehicle.new()
	var e = v.load_from_data(data, 0, Color(), Transform(), false, false, 0)
	if e == null:
		v.destroy()
		is_valid = true
	else:
		invalid_reason = e

	return OK
