#!/bin/sh

cd bin/server

case $1 in
	pck-only)
		for SERVER in lu0 lv0; do
			echo Installing PCK on $SERVER
			for file in *.pck; do
				scp "$file" "ownwar@$SERVER:$file"
			done
		done
		;;
	lib-only)
		for SERVER in lu0 lv0; do
			echo Installing PCK \& libraries on $SERVER
			for file in *.so *.pck; do
				scp "$file" "ownwar@$SERVER:$file"
			done
		done
		;;
	*)
		for SERVER in lu0 lv0; do
			echo Installing on $SERVER
			for file in *.so *.pck ownwar; do
				scp "$file" "ownwar@$SERVER:$file"
			done
		done
		;;
esac
