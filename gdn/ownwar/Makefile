TARGET_PATH?=target/debug/libownwar.so
OUTPUT?=../../gd/lib/libownwar.so


install:
	cargo build
	cp $(TARGET_PATH) $(OUTPUT)

compile-loop:
	while true; do cargo build --color always 2>&1 | less -R; done

install-loop:
	find src/ -name '*.rs' | entr -c bash -c 'cargo build && cp $(TARGET_PATH) $(OUTPUT)'

test-loop:
	find src/ -name '*.rs' | entr -c bash -c 'cargo test'

clean:
	rm -r target/
