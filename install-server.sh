#!/bin/sh

for SERVER in lu0 lv0; do
	scp bin/linux/libhterrain.so "ownwar@$SERVER:ownwar.pck"
	scp bin/linux/libownwar.so "ownwar@$SERVER:ownwar.pck"
	scp bin/linux/ownwar.pck "ownwar@$SERVER:ownwar.pck"
done
