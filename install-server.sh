#!/bin/sh

for SERVER in lu0 lv0; do
	echo Installing on $SERVER
	cd bin/linux
	for file in *.so; do
		scp "$file" "ownwar@$SERVER:$file"
	done
	scp ownwar.pck "ownwar@$SERVER:ownwar.pck"
done
