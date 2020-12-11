extends PluginInterface


const MIN_VERSION := Vector3(0, 15, 1)
const PLUGIN_VERSION := Vector3(0, 0, 1)
const PLUGIN_DEPENDENCIES := {
	"chassis_blocks": Vector3(0, 0, 1),
	"turret": Vector3(0, 0, 1),
	"wheel": Vector3(0, 0, 1),
	"cannon": Vector3(0, 0, 1),
}


func pre_init():
	var dir = Util.get_script_dir(self)
	OwnWar.add_main_menu_background(dir.plus_file("background.tscn"))
