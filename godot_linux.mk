# Makefile for building the Godot engine on Linux platforms

OSXCROSS_SDK   ?= darwin16
GODOT_SOURCE   ?= ../../godot/godot-stable/
JOBS           ?= 32
CXX             = gcc
GODOT_NAME     ?= godot_ownwar_template

godot: godot-linux godot-osx godot-windows godot-server

godot-linux:
	scons -C $(GODOT_SOURCE) -j$(JOBS) platform=linux profile=$$PWD/godot_config.py
	mkdir -p bin/template
	mv $(GODOT_SOURCE)/bin/godot.x11.opt.x64 bin/template/$(GODOT_NAME)_linux

godot-osx:
	scons -C $(GODOT_SOURCE) -j$(JOBS) platform=osx osxcross_sdk=$(OSXCROSS_SDK) profile=$$PWD/godot_config.py
	mkdir -p bin/template
	rm -rf bin/osx/$(GODOT_NAME).app
	cp -r $(GODOT_SOURCE)/misc/dist/osx_tools.app bin/template/$(GODOT_NAME)_osx.app
	mkdir -p bin/template/$(GODOT_NAME)_osx.app/Contents/MacOS
	cp $(GODOT_SOURCE)/bin/godot.osx.opt.x64 bin/template/$(GODOT_NAME)_osx.app/Contents/MacOS/godot_osx_release.64
	chmod +x bin/template/$(GODOT_NAME)_osx.app/Contents/MacOS/godot_osx_release.64
	rm -rf bin/template/$(GODOT_NAME)_osx.zip
	@# APPARENTLY Godot expects the root path to be either 'osx_template.app' OR ''.
	@# Very intuitive much wow much appreciated.
	cd bin/template/$(GODOT_NAME)_osx.app && zip -q -9 -r ../$(GODOT_NAME)_osx.zip *

godot-windows:
	scons -C $(GODOT_SOURCE) -j$(JOBS) platform=windows profile=$$PWD/godot_config.py
	mkdir -p bin/template
	mv $(GODOT_SOURCE)/bin/godot.windows.opt.x64.exe bin/template/$(GODOT_NAME)_windows.exe

godot-server:
	scons -C $(GODOT_SOURCE) -j$(JOBS) platform=server profile=$$PWD/godot_config.py
	mkdir -p bin/template
	mv $(GODOT_SOURCE)/bin/godot_server.x11.opt.x64 bin/template/$(GODOT_NAME)_server


godot-clean-osx:
	rm -rf $(GODOT_SOURCE)/bin/$(GODOT_NAME).app
	rm -f $(GODOT_SOURCE)/bin/godot.osx.opt.x64
	rm -f bin/$(GODOT_NAME).zip
