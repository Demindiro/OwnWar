GODOT=godot
TARGET_LINUX?=x86_64-unknown-linux-gnu
TARGET_OSX?=x86_64-apple-darwin
TARGET_WINDOWS?=x86_64-pc-windows-gnu


build: bin/ build-gdn build-lobby
	cd gd && $(GODOT) --export-pack Linux ../bin/ownwar.pck


build-debug: bin/ build-gdn-debug build-lobby-debug
	cd gd && $(GODOT) --export-pack Linux ../bin/ownwar.pck


build-gdn: gd/lib/
	cd gdn && cargo build --release --target $(TARGET_LINUX)
	cd gdn && cargo build --release --target $(TARGET_OSX)
	cd gdn && cargo build --release --target $(TARGET_WINDOWS)
	cp gdn/target/$(TARGET_LINUX)/release/libownwar.so gd/lib/
	cp gdn/target/$(TARGET_OSX)/release/libownwar.dylib gd/lib/
	cp gdn/target/$(TARGET_WINDOWS)/release/ownwar.dll gd/lib/
	cp gdn/target/$(TARGET_LINUX)/release/libownwar.so bin/
	cp gdn/target/$(TARGET_OSX)/release/libownwar.dylib bin/
	cp gdn/target/$(TARGET_WINDOWS)/release/ownwar.dll bin/


build-gdn-debug: gd/lib/
	cd gdn && cargo build --target $(TARGET_LINUX)
	cd gdn && cargo build --target $(TARGET_OSX)
	cd gdn && cargo build --target $(TARGET_WINDOWS)
	cp gdn/target/$(TARGET_LINUX)/debug/libownwar.so gd/lib/
	cp gdn/target/$(TARGET_OSX)/debug/libownwar.dylib gd/lib/
	cp gdn/target/$(TARGET_WINDOWS)/debug/ownwar.dll gd/lib/
	cp gdn/target/$(TARGET_LINUX)/release/libownwar.so bin/
	cp gdn/target/$(TARGET_OSX)/release/libownwar.dylib bin/
	cp gdn/target/$(TARGET_WINDOWS)/release/ownwar.dll bin/


build-lobby:
	cd lobby && cargo build --release


build-lobby-debug:
	cd lobby && cargo build


bin/:
	mkdir bin/


gd/lib/:
	mkdir gd/lib/
