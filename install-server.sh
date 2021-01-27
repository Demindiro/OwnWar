#!/bin/sh

for SERVER in lu0 lv0; do
	scp bin/libhterrain.so "ownwar@$SERVER:ownwar.pck"
	scp bin/libownwar.so "ownwar@$SERVER:ownwar.pck"
	scp bin/ownwar.pck "ownwar@$SERVER:ownwar.pck"
done
