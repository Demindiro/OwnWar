extends Spatial
class_name OwnWar_VehiclePreview


var voxel_mesh := OwnWar_VoxelMesh.new()
var mesh_instance := MeshInstance.new()
var aabb := AABB()
var cost := 0
var mass := 0.0
var block_count := 0


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

	var MAGIC := 493279249 # Totally random, not derived from a name
	var REVISION := 0
	var magic := spb.get_u32()
	if magic != MAGIC:
		print("Magic is wrong! ", magic)
		assert(false)
		return ERR_INVALID_DATA
	var revision := spb.get_u16()
	if revision != REVISION:
		print("Revision doesn't match!")
		assert(false)
		return ERR_INVALID_DATA
	var layer_count := spb.get_u8()
	for _i in layer_count:
		var _layer := spb.get_u8()
		var _aabb_px := spb.get_u8()
		var _aabb_py := spb.get_u8()
		var _aabb_pz := spb.get_u8()
		var _aabb_sx := spb.get_u8()
		var _aabb_sy := spb.get_u8()
		var _aabb_sz := spb.get_u8()
		var size := spb.get_32()
		for _j in size:
			var x := spb.get_u8()
			var y := spb.get_u8()
			var z := spb.get_u8()
			var id := spb.get_u16()
			var rot := spb.get_u8()
			var clr := Color()
			clr.r8 = spb.get_u8()
			clr.g8 = spb.get_u8()
			clr.b8 = spb.get_u8()
			var blk: OwnWar_Block = OwnWar_Block.get_block_by_id(id)
			voxel_mesh.add_block(blk, clr, [x, y, z], rot)
			if blk.editor_node != null:
				var node := blk.editor_node.duplicate()
				add_child(node)
				node.transform = Transform(
					OwnWar_Block.rotation_to_basis(rot),
					(Vector3(x, y, z) + Vector3.ONE / 2) * OwnWar_Block.BLOCK_SCALE - center
				)
			if aabb == AABB():
				aabb.position = Vector3(x, y, z)
				aabb.size = Vector3.ONE
			else:
				aabb = aabb.expand(Vector3(x, y, z)).expand(Vector3(x + 1, y + 1, z + 1))
			block_count += 1
			cost += blk.cost
			mass += blk.mass

	# TODO should we center based on AABB or editor grid size?
	mesh_instance.translation -= Vector3(25, 25, 25) * OwnWar_Block.BLOCK_SCALE / 2

	return OK

