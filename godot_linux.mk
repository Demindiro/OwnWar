# Makefile for building the Godot engine on Linux platforms

OSXCROSS_SDK ?= darwin16
GODOT_SOURCE ?= ../../godot/godot-stable/
JOBS         ?= 32
CXX           = gcc


godot-native:
	scons -C $(GODOT_SOURCE) -j$(JOBS) profile=$$PWD/godot_config.py

godot-linux:
	scons -C $(GODOT_SOURCE) -j$(JOBS) platform=linux profile=$$PWD/godot_config.py

godot-osx:
	scons -C $(GODOT_SOURCE) -j$(JOBS) platform=osx osxcross_sdk=$(OSXCROSS_SDK) profile=$$PWD/godot_config.py

godot-windows:
	scons -C $(GODOT_SOURCE) -j$(JOBS) platform=windows profile=$$PWD/godot_config.py
