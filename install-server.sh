#!/bin/sh

for SERVER in lu0 lv0; do
	echo Installing on $SERVER
	scp bin/linux/libhterrain.so "ownwar@$SERVER:libhterrain.so"
	scp bin/linux/libownwar.so "ownwar@$SERVER:libownwar.so"
	scp bin/linux/ownwar.pck "ownwar@$SERVER:ownwar.pck"
done
