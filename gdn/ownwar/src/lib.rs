// TODO remove this later
// This attribute is added because porting the GDScript code
// will inevitably result in some dead code and unused variables

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
