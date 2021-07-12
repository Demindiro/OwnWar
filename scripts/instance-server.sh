echo "Starting with settings $OWNWAR_SETTINGS"

OWNWAR_SETTINGS=$OWNWAR_SETTINGS \
	./ownwar \
	--main-pack ownwar.pck res://maps/the_pit/the_pit.tscn \
	2>&1 | tee logs/instance/`date +%y-%m-%d`.log

