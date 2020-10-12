extends MeshInstance


func _ready():
	var voxel_mesh := VoxelMesh.new()
	var block_cube := Global.blocks["cube_b_1_1-1-1-1-1-1-1-1-1-1-1-1"] as Block
	var block_edge := Global.blocks["edge_b_1_1-1-1-1-1-1-1"] as Block
	voxel_mesh.add_block(block_cube, Color.white, [0, 0, 0], 0)
	voxel_mesh.add_block(block_cube, Color.white, [0, 2, 0], 0)
	voxel_mesh.add_block(block_cube, Color.red, [4, 2, 5], 0)
	voxel_mesh.add_block(block_cube, Color.white, [4, 1, 1], 0)
	voxel_mesh.add_block(block_cube, Color.white, [4, 1, 2], 0)
	voxel_mesh.add_block(block_edge, Color.white, [-4, 1, 1], 0)
	voxel_mesh.add_block(block_edge, Color.white, [-4, 1, 2], 2)
	voxel_mesh.add_block(block_cube, Color.white, [4, 1, 4], 0)
	voxel_mesh.add_block(block_cube, Color.green, [4, 3, 5], 0)
	voxel_mesh.add_block(block_cube, Color.blue, [4, 4, 5], 0)
	voxel_mesh.add_block(block_cube, Color.white, [-5, -1, -1], 0)
	voxel_mesh.add_block(block_cube, Color.blue, [-5, -2, 0], 0)
	mesh = voxel_mesh
