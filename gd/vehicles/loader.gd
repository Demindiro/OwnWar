class_name OwnWar_VehicleLoader


class Body:
	var aabb: AABB
	var blocks: Array

class Block:
	var block: OwnWar_Block
	var position: Vector3
	var rotation: int
	var color: Color

	func _init(spb: StreamPeerBuffer):
		position.x = spb.get_u8()
		position.y = spb.get_u8()
		position.z = spb.get_u8()
		var id := spb.get_u16()
		block = OwnWar_BlockManager.new().get_block(id)
		rotation = spb.get_u8()
		color.r8 = spb.get_u8()
		color.g8 = spb.get_u8()
		color.b8 = spb.get_u8()


const MAGIC := 493279249
const REVISION := 0

var valid := false
var bodies := {}
var mainframe_count := 0


func load_from_data(data: PoolByteArray) -> int:
	var mainframe_id := OwnWar.MAINFRAME_ID
	
	var spb := StreamPeerBuffer.new()
	spb.data_array = data

	var magic := spb.get_u32()
	if magic != MAGIC:
		print("Magic is wrong! ", magic)
		return ERR_INVALID_DATA

	var revision := spb.get_u16()
	if revision != REVISION:
		print("Revision doesn't match!")
		return ERR_INVALID_DATA

	var layer_count := spb.get_u8()
	for _i in layer_count:
		var layer := spb.get_u8()
		if layer in bodies:
			print("File data corrupt: double layer %d" % layer)
			return ERR_INVALID_DATA
		var aabb := AABB()
		aabb.position.x = spb.get_u8()
		aabb.position.y = spb.get_u8()
		aabb.position.z = spb.get_u8()
		aabb.size.x = spb.get_u8()
		aabb.size.y = spb.get_u8()
		aabb.size.z = spb.get_u8()
		var vb := []
		var size := spb.get_32()
		for _j in size:
			var blk := Block.new(spb)
			vb.push_back(blk)
			if blk.block.id == mainframe_id:
				mainframe_count += 1
		var body := Body.new()
		body.aabb = aabb
		body.blocks = vb
		bodies[layer] = body

	valid = mainframe_count == 1
	return OK
