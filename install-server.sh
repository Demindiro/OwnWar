#!/bin/sh

cd bin/server
for SERVER in lu0 lv0; do
	echo Installing on $SERVER
	for file in *.so *.pck ownwar; do
		scp "$file" "ownwar@$SERVER:$file"
	done
done
