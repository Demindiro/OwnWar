class_name Vehicle

extends Spatial


func _ready():
	$GridMap.mesh_library = Global._blocks_mesh_library
	for x in range(3):
		for y in range(3):
			if x == 1 and y == 1:
				continue
			$GridMap.set_cell_item(x, y, 0, 0, 0)
	_set_collision_box(Vector3(0, 0, 0), Vector3(2, 2, 0))


func _set_collision_box(start: Vector3, end: Vector3) -> void:
	start -= Vector3.ONE / 2
	end += Vector3.ONE / 2
	var center = (start + end) / 2
	var extents = (end - start) / 2
	$CollisionShape.transform.origin = center
	$CollisionShape.shape.extents = extents
