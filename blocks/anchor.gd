extends Spatial
class_name OwnWar_BlockAnchor


func init(coordinate: Vector3, voxel_body: OwnWar.VoxelBody, _vehicle: OwnWar_Vehicle) -> void:
	var e := connect("tree_exiting", voxel_body, "remove_anchor", [coordinate, voxel_body])
	assert(e == OK)
	voxel_body.add_anchor(coordinate, voxel_body)
