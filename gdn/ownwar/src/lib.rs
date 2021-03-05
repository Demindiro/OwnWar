#![feature(map_into_keys_values)]

mod util;
mod vehicle;

use gdnative::prelude::*;

// Function that registers all exposed classes to Godot
fn init(handle: InitHandle) {
	godot_print!("Initializing OwnWar native library");
	vehicle::init(handle);
}

// Macro that creates the entry-points of the dynamic library.
godot_init!(init);
