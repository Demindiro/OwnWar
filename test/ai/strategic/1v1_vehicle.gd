extends OwnWar_GameMaster


func _physics_process(_delta) -> void:
	var id := OwnWar.Matter.get_matter_id("160mm AP")
	$A/Vehicle.put_matter(id, 10000)
	$B/Vehicle.put_matter(id, 10000)
	id = OwnWar.Matter.get_matter_id("fuel")
	$A/Vehicle.put_matter(id, 10000)
	$B/Vehicle.put_matter(id, 10000)
