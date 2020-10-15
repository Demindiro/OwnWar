extends Unit


export var max_material := 1000
var ore: Ore
var _ticks_until_next := 0
var material := 0


func _physics_process(_delta):
	_ticks_until_next += 1
	if _ticks_until_next >= Engine.iterations_per_second:
		if material < max_material:
			material += ore.take_material(1)
			_ticks_until_next = 0
			if ore.material == 0:
				set_process(false)
				set_physics_process(false)
				

func get_info():
	var info = .get_info()
	info["Ore"] = ore.material
	info["Material"] = "%d / %d" % [material, max_material]
	return info


func take_material(p_material):
	if p_material < material:
		material -= p_material
		return p_material
	else:
		var remainder = material
		material = 0
		return remainder


func init(p_ore):
	ore = p_ore
	ore.drill = self
