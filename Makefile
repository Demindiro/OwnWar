GODOT=godot-headless
TARGET_LINUX?=x86_64-unknown-linux-gnu
TARGET_OSX?=x86_64-apple-darwin
TARGET_WINDOWS?=x86_64-pc-windows-gnu


build: build-linux build-osx build-windows

build-linux:
	@echo Building Linux
	@mkdir -p bin/linux/
	@cd gd && $(GODOT) --export linux ../bin/linux/ownwar > /dev/null 2> /dev/null
	@echo Compressing Linux
	@cd bin && zip -r linux/ownwar.zip linux/ -x '*linux/ownwar.zip*' > /dev/null

build-osx:
	@echo Building OS X
	@mkdir -p bin/osx/
	@cd gd && $(GODOT) --export osx ../bin/osx/ownwar.zip > /dev/null 2> /dev/null

build-windows:
	@echo Building Windows
	@mkdir -p bin/windows/
	@cd gd && $(GODOT) --export windows ../bin/windows/ownwar.exe > /dev/null 2> /dev/null
	@echo Compressing Windows
	@cd bin && zip -r windows/ownwar.zip windows/ -x '*windows/ownwar.zip*' > /dev/null


build-gdn: build-gdn-ownwar build-gdn-hterrain


build-gdn-%: gd/lib/
	mkdir -p gd/lib/
	cd gdn/$* && cargo build --release --target $(TARGET_LINUX)
	cd gdn/$* && cargo build --release --target $(TARGET_OSX)
	cd gdn/$* && cargo build --release --target $(TARGET_WINDOWS)
	cp gdn/$*/target/$(TARGET_LINUX)/release/lib$*.so gd/lib/
	cp gdn/$*/target/$(TARGET_OSX)/release/lib$*.dylib gd/lib/
	cp gdn/$*/target/$(TARGET_WINDOWS)/release/$*.dll gd/lib/
	strip gd/lib/lib$*.so
	strip gd/lib/$*.dll


build-lobby:
	cd lobby && cargo build --release
