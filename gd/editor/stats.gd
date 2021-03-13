extends PanelContainer


export var _count_label := NodePath()
export var _cost_label := NodePath()
export var _mass_label := NodePath()
export var _center_of_mass := NodePath()

var count := 0
var cost := 0
var mass := 0.0
var center_of_mass := Vector3()
var show_mass_indicator := false setget enable_mass_indicator

onready var count_label: Label = get_node(_count_label)
onready var cost_label: Label = get_node(_cost_label)
onready var mass_label: Label = get_node(_mass_label)
onready var center_of_mass_node: Control = get_node(_center_of_mass)


func _process(_delta: float) -> void:
	var cam := get_tree().root.get_camera()
	if cam == null:
		return
	if cam.is_position_behind(center_of_mass) or mass <= 0:
		center_of_mass_node.visible = false
	else:
		center_of_mass_node.visible = show_mass_indicator
		var proj := cam.unproject_position(center_of_mass)
		center_of_mass_node.rect_position = proj - Vector2(31.5, 31.5)


func block_placed(id: int, position: Vector3) -> void:
	var block = OwnWar_BlockManager.new().get_block(id)
	position += Vector3(0.5, 0.5, 0.5)
	center_of_mass = center_of_mass * mass + position * block.mass

	count += 1
	cost += block.cost
	mass += block.mass
	count_label.text = str(count)
	cost_label.text = str(cost)
	mass_label.text = str(mass)

	if mass > 0:
		center_of_mass /= mass


func block_removed(id: int, position: Vector3) -> void:
	var block = OwnWar_BlockManager.new().get_block(id)
	position += Vector3(0.5, 0.5, 0.5)
	center_of_mass = center_of_mass * mass - position * block.mass

	count -= 1
	cost -= block.cost
	mass -= block.mass
	count_label.text = str(count)
	cost_label.text = str(cost)
	mass_label.text = str(mass)

	if mass > 0:
		center_of_mass /= mass


func vehicle_moved(direction: Vector3) -> void:
	center_of_mass += direction


func vehicle_rotated(center: Vector3) -> void:
	center += Vector3(0.5, 0.5, 0.5)
	var rot := Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))
	center_of_mass -= center
	center_of_mass = rot * center_of_mass
	center_of_mass += center


func enable_mass_indicator(enable: bool) -> void:
	show_mass_indicator = enable
