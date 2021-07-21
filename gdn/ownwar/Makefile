TARGET_PATH?=target/debug/libownwar.so
RELEASE_NO_LTO_TARGET_PATH?=target/release_no_lto/libownwar.so
OUTPUT?=../../gd/lib/libownwar.so


install:
	cargo build
	mv $(TARGET_PATH) $(OUTPUT)

install-release:
	cargo build --profile release_no_lto -Z unstable-options
	mv $(RELEASE_NO_LTO_TARGET_PATH) $(OUTPUT)

compile-loop:
	while true; do cargo build --color always 2>&1 | less -R; done

install-loop:
	find src/ -name '*.rs' | entr -c bash -c 'cargo build && cp $(TARGET_PATH) $(OUTPUT)'

test-loop:
	find src/ -name '*.rs' | entr -c bash -c 'cargo test'

clean:
	rm -r target/


objdump:
	objdump -SC target/release/libownwar.so
