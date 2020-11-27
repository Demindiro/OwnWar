tool
extends OptionButtonPreset


const Hud := preload("res://core/map/hud.gd")


var _hud: Hud


func _enter_tree() -> void:
	_hud = get_parent()


func _on_ChangeTeam_item_selected(index: int) -> void:
	_hud.team = "Player" if index == 0 else "Enemy"
