o "Starting with settings $OWNWAR_SETTINGS"
OWNWAR_SETTINGS=$OWNWAR_SETTINGS \
	/home/godot/godot \
	--main-pack ownwar.pck res://maps/the_pit/the_pit.tscn \
	2>&1 | tee logs/instance/`date +%y-%m-%d`.log

