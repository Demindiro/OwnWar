OUTPUT=../../gd/lib/libgd_3d_batcher.so


default:
	cargo build --release
	cp target/release/libgd_3d_batcher.so $(OUTPUT)
	strip $(OUTPUT)


debug:
	cargo build
	cp target/debug/libgd_3d_batcher.so $(OUTPUT)
