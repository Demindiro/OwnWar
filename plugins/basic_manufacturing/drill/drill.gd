extends Structure


const MAX_MATERIAL := 100
var ore
var _ticks_until_next := 0
var material := 0
onready var _material_id: int = Matter.get_matter_id("material")


func _physics_process(_delta):
	_ticks_until_next += 1
	if _ticks_until_next >= Engine.iterations_per_second:
		if material < MAX_MATERIAL:
			material += ore.take_material(1)
			emit_signal("dump_matter", _material_id, material)
			_ticks_until_next = 0
			if ore.material == 0:
				set_process(false)
				set_physics_process(false)
				

func get_info():
	var info = .get_info()
	info["Ore"] = ore.material
	info["Material"] = "%d / %d" % [material, MAX_MATERIAL]
	return info


func get_matter_count(id: int) -> int:
	if id == _material_id:
		return material
	return 0


func get_matter_space(id: int) -> int:
	if id == _material_id:
		return MAX_MATERIAL - material
	return 0


func get_take_matter_list() -> PoolIntArray:
	return PoolIntArray([_material_id])


func provide_matter(id: int) -> int:
	return material if _material_id == id else 0


func dump_matter(id: int) -> int:
	return material if _material_id == id else 0


func take_matter(id: int, amount: int) -> int:
	if id == _material_id:
		if amount < material:
			material -= amount
		else:
			amount = material
			material = 0
	emit_signal("dump_matter", _material_id, material)
	return amount


func take_material(p_material):
	return take_matter(_material_id, p_material)


func serialize_json() -> Dictionary:
	var data := {
			"material": material,
			"ticks_until_next": _ticks_until_next,
		}
	if ore != null:
		data["ore_translation"] = ore.translation
	return data


func deserialize_json(data: Dictionary) -> void:
	material = data["material"]
	_ticks_until_next = data["ticks_until_next"]
	var ore_translation = data.get("ore_translation")
	if ore_translation != null:
		for o in get_tree().get_nodes_in_group("ores"):
			if o.translation == ore_translation:
				ore = o
				break
		assert(ore != null)


func init(p_ore):
	ore = p_ore
	ore.drill = self
