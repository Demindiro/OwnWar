extends Spatial


func _ready():
	$GridMap.mesh_library = Global._blocks_mesh_library
	for x in range(3):
		for y in range(3):
			if x == 1 and y == 1:
				continue
			$GridMap.set_cell_item(x, y, 0, 0, 0)
