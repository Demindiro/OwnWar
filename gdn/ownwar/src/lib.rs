#![feature(map_into_keys_values)]
#![feature(destructuring_assignment)]
#![feature(step_trait)]
// Shuttt the fuckkkkkk upppp please
#![cfg_attr(debug_assertions, allow(dead_code))]

mod block;
mod editor;
mod rotation;
mod util;
mod vehicle;

use gdnative::prelude::*;


fn init(handle: InitHandle) {
	vehicle::init(handle);
	block::init(handle);
	editor::init(handle);
}

godot_init!(init);


mod dummy {
	use gdnative::prelude::*;
	use godot_rapier3d::init as init;
	godot_gdnative_init!(_ as gd_rapier3d_gdnative_init);
	godot_nativescript_init!(init as gd_rapier3d_nativescript_init);
	godot_gdnative_terminate!(_ as gd_rapier3d_gdnative_terminate);
}
