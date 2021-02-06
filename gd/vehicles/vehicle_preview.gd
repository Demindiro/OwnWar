extends Spatial
class_name OwnWar_VehiclePreview


var voxel_mesh := OwnWar_VoxelMesh.new()
var mesh_instance := MeshInstance.new()
var aabb := AABB()
var cost := 0
var mass := 0.0
var block_count := 0
var mainframe_count := 0


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
		return err

	return load_from_data(file.get_buffer(file.get_len()))


func load_from_data(data: PoolByteArray) -> int:

	var spb := StreamPeerBuffer.new()
	spb.data_array = data

	var center := Vector3(25, 25, 25) * OwnWar_Block.BLOCK_SCALE / 2

	var loader := OwnWar_VehicleLoader.new()
	var err := loader.load_from_data(data)
	if err != OK:
		print("Failed to load vehicle: ", Global.ERROR_TO_STRING[err])
		return err

	for layer in loader.bodies:
		var body: OwnWar_VehicleLoader.Body = loader.bodies[layer]
		for block in body.blocks:
			var blk: OwnWar_Block = block.block
			var x := int(block.position.x)
			var y := int(block.position.y)
			var z := int(block.position.z)
			voxel_mesh.add_block(blk, block.color, [x, y, z], block.rotation)
			if blk.editor_node != null:
				var node := blk.editor_node.duplicate()
				add_child(node)
				if node.has_method("set_preview_mode"):
					node.set_preview_mode(true)
				node.transform = Transform(
					OwnWar_Block.rotation_to_basis(block.rotation),
					(Vector3(x, y, z) + Vector3.ONE / 2) * OwnWar_Block.BLOCK_SCALE - center
				)
				if node.has_method("set_color"):
					node.set_color(block.color)
			if aabb == AABB():
				aabb.position = Vector3(x, y, z)
				aabb.size = Vector3.ONE
			else:
				aabb = aabb.expand(Vector3(x, y, z)).expand(Vector3(x + 1, y + 1, z + 1))
			block_count += 1
			cost += blk.cost
			mass += blk.mass
	
	mainframe_count = loader.mainframe_count

	# TODO should we center based on AABB or editor grid size?
	mesh_instance.translation -= Vector3(25, 25, 25) * OwnWar_Block.BLOCK_SCALE / 2

	return OK


func is_valid() -> bool:
	return mainframe_count == 1
