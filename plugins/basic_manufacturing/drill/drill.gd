extends OwnWar_Structure


const Ore := preload("ore.gd")
const MAX_MATERIAL := 100
var ore: Ore
var material := 0
var _time_until_next := 0.0
onready var _material_id: int = OwnWar.Matter.get_matter_id("material")


func _physics_process(delta: float) -> void:
	_time_until_next += delta
	if _time_until_next >= 0.0:
		if material < MAX_MATERIAL:
			material += ore.take_material(1)
			emit_signal("dump_matter", _material_id, material)
			_time_until_next = 0.0
			if ore.material == 0:
				set_process(false)
				set_physics_process(false)


func get_info() -> Dictionary:
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


func provides_matter(id: int) -> int:
	return material if _material_id == id else 0


func dumps_matter(id: int) -> int:
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


func take_material(p_material: int) -> int:
	return take_matter(_material_id, p_material)


func serialize_json() -> Dictionary:
	var data := {
			"material": material,
			"time_until_next": _time_until_next,
		}
	if ore != null:
		data["ore_translation"] = var2str(ore.translation)
	return data


func deserialize_json(data: Dictionary) -> void:
	breakpoint
	material = data["material"]
	if "ticks_until_next" in data:
		_time_until_next = data["ticks_until_next"] / 150.0
	else:
		_time_until_next = data["time_until_next"]
	var ore_translation = data.get("ore_translation")
	if ore_translation != null:
		var ot: Vector3 = str2var(ore_translation)
		for o in get_tree().get_nodes_in_group("ores"):
			if o.translation == ot:
				breakpoint
				ore = o
				break
		assert(ore != null)


func init(p_ore) -> void:
	ore = p_ore
	ore.drill = self
