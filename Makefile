GODOT=godot-headless
TARGET_LINUX?=x86_64-unknown-linux-gnu
TARGET_OSX?=x86_64-apple-darwin
TARGET_WINDOWS?=x86_64-pc-windows-gnu


build: build-linux build-osx build-windows

build-linux: build-gdn-linux
	@echo Building Linux
	@mkdir -p bin/linux/
	@cd gd && $(GODOT) --export linux ../bin/linux/ownwar > /dev/null 2> /dev/null
	@echo Compressing Linux
	@cd bin && tar zcf ownwar-linux.tar.gz linux/

build-osx: build-gdn-osx
	@echo Building OS X
	@mkdir -p bin/osx/
	@cd gd && $(GODOT) --export osx ../bin/ownwar-osx.zip > /dev/null 2> /dev/null

build-windows: build-gdn-windows
	@echo Building Windows
	@mkdir -p bin/windows/
	@cd gd && $(GODOT) --export windows ../bin/windows/ownwar.exe > /dev/null 2> /dev/null
	@echo Compressing Windows
	@cd bin && zip -r ownwar-windows.zip windows/ > /dev/null


build-gdn: build-gdn-ownwar build-gdn-hterrain build-gdn-3d_batcher

build-gdn-%: build-gdn-%-linux build-gdn-%-osx build-gdn-%-windows

build-gdn-linux: build-gdn-ownwar-linux build-gdn-hterrain-linux build-gdn-gd_3d_batcher-linux

build-gdn-osx: build-gdn-ownwar-osx build-gdn-hterrain-osx build-gdn-gd_3d_batcher-osx

build-gdn-windows: build-gdn-ownwar-windows build-gdn-hterrain-windows build-gdn-gd_3d_batcher-windows


build-gdn-%-linux: gd/lib/
	cd gdn/$* && cargo build --release --target $(TARGET_LINUX) --quiet
	cp gdn/$*/target/$(TARGET_LINUX)/release/lib$*.so gd/lib/
	strip gd/lib/lib$*.so

build-gdn-%-osx: gd/lib/
	cd gdn/$* && cargo build --release --target $(TARGET_OSX) --quiet
	cp gdn/$*/target/$(TARGET_OSX)/release/lib$*.dylib gd/lib/

build-gdn-%-windows: gd/lib/
	cd gdn/$* && cargo build --release --target $(TARGET_WINDOWS) --quiet
	cp gdn/$*/target/$(TARGET_WINDOWS)/release/$*.dll gd/lib/
	strip gd/lib/$*.dll


build-lobby:
	cd lobby && cargo build --release


gd/lib/:
	mkdir -p gd/lib/


clean:
	rm -r bin/
