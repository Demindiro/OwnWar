class_name OwnWar_VehicleLoader


class Body:
	var aabb: AABB
	var blocks: Array

class Block:
	var block: OwnWar_Block
	var position: Vector3
	var rotation: int
	var color: Color


var loader := preload("loader.gdns").new()
var manager := OwnWar_BlockManager.new()


var valid := false
var bodies := {}
var mainframe_count := 0


func load_from_data(data: PoolByteArray) -> int:
	var mainframe_id := OwnWar.MAINFRAME_ID

	var t := OS.get_ticks_usec()
	var ret: int = loader.load_data(data);
	if ret != OK:
		return ret

	var colors: PoolColorArray = loader.get_colors()
	var layer_count: int = loader.get_layer_count()
	for layer in layer_count:
		var try_aabb = loader.get_layer_aabb(layer)
		if try_aabb == null:
			continue
		var aabb: AABB = try_aabb
		var layer_data: PoolIntArray = loader.get_blocks_in_layer(layer)
		var vb := []
		var size := len(layer_data) / 2
		for i in size:
			var a := layer_data[i * 2]
			var b := layer_data[i * 2 + 1]
			var blk := Block.new()
			blk.position.x = (a >> 16) & 0xff
			blk.position.y = (a >> 8) & 0xff
			blk.position.z = a & 0xff
			blk.rotation = (b >> 24) & 0xff
			blk.color = colors[(b >> 16) & 0xff]
			blk.block = manager.get_block(b & 0xffff)
			vb.push_back(blk)
			if blk.block.id == mainframe_id:
				mainframe_count += 1
		var body := Body.new()
		aabb.size += Vector3.ONE
		body.aabb = aabb
		body.blocks = vb
		bodies[layer] = body

	valid = mainframe_count == 1
	return OK
