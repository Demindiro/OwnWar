# Makefile for building the Godot engine on Linux platforms

OSXCROSS_SDK   ?= darwin16
GODOT_SOURCE   ?= ../../godot/godot-stable/
JOBS           ?= 32
CXX             = gcc
GODOT_NAME     ?= godot_ownwar_template


godot-linux:
	scons -C $(GODOT_SOURCE) -j$(JOBS) platform=linux profile=$$PWD/godot_config.py
	mkdir -p bin/linux/
	mv $(GODOT_SOURCE)/bin/godot.x11.opt.x64 bin/linux/$(GODOT_NAME)

godot-osx:
	scons -C $(GODOT_SOURCE) -j$(JOBS) platform=osx osxcross_sdk=$(OSXCROSS_SDK) profile=$$PWD/godot_config.py
	mkdir -p bin/osx/
	cp -r $(GODOT_SOURCE)/misc/dist/osx_tools.app $(GODOT_SOURCE)/bin/$(GODOT_OSX_NAME)
	mkdir -p $(GODOT_OSX_NAME)/Contents/MacOS
	cp $(GODOT_SOURCE)/bin/godot.osx.opt.x64 $(GODOT_OSX_NAME)/Contents/MacOS/godot_osx_release.64
	chmod +x $(GODOT_OSX_NAME)/Contents/MacOS/godot_osx_release.64
	zip -q -9 -r bin/osx/$(GODOT_OSX_NAME).zip $(GODOT_SOURCE)/bin/$(GODOT_OSX_NAME).app

godot-windows:
	scons -C $(GODOT_SOURCE) -j$(JOBS) platform=windows profile=$$PWD/godot_config.py
	mkdir -p bin/windows/
	mv $(GODOT_SOURCE)/bin/godot.windows.opt.x64.exe bin/windows/$(GODOT_NAME).exe

godot-server:
	scons -C $(GODOT_SOURCE) -j$(JOBS) platform=server profile=$$PWD/godot_config.py
	mkdir -p bin/server/
	mv $(GODOT_SOURCE)/bin/godot_server.x11.opt.x64 bin/server/godot_ownwar_template


godot-clean-osx:
	rm -rf $(GODOT_SOURCE)/bin/$(GODOT_OSX_NAME).app
	rm -f $(GODOT_SOURCE)/bin/godot.osx.opt.x64
	rm -f bin/$(GODOT_OSX_NAME).zip
