tool
extends OptionButtonPreset


func _on_ChangeTeam_item_selected(index: int) -> void:
	$"..".team = index
