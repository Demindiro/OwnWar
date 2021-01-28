#!/bin/bash

SRC="$(dirname $(realpath $BASH_SOURCE))"
mkdir -p "$SRC"/callgrind/
cd "$SRC"/bin/linux/
valgrind \
	--tool=callgrind \
	--instr-atstart=no \
	--callgrind-out-file="$SRC"/callgrind/callgrind.out.'%p' \
	-- \
	./godot.x11.opt.64 --main-pack ownwar.pck
