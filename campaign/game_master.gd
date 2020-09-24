extends Spatial


var material_count = []


func _ready():
	material_count.resize(2)
	material_count[0] = 100
	material_count[1] = 100
	$Drill.ore = $Ore


func add_material(team, count):
	material_count[team] += count
