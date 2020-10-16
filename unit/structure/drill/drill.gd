extends Unit


const MAX_MATERIAL := 100
var ore: Ore
var _ticks_until_next := 0
var material := 0


func _physics_process(_delta):
	_ticks_until_next += 1
	if _ticks_until_next >= Engine.iterations_per_second:
		if material < MAX_MATERIAL:
			material += ore.take_material(1)
			send_message("dump_material", material)
			send_message("provide_material", material)
			_ticks_until_next = 0
			if ore.material == 0:
				set_process(false)
				set_physics_process(false)
				

func get_info():
	var info = .get_info()
	info["Ore"] = ore.material
	info["Material"] = "%d / %d" % [material, MAX_MATERIAL]
	return info


func request_info(info: String):
	if info == "dump_material" or info == "provide_material":
		return material
	return .request_info(info)


func take_material(p_material):
	if p_material < material:
		material -= p_material
		send_message("dump_material", material)
		send_message("provide_material", material)
		return p_material
	else:
		var remainder = material
		material = 0
		send_message("dump_material", material)
		send_message("provide_material", material)
		return remainder


func init(p_ore):
	ore = p_ore
	ore.drill = self
