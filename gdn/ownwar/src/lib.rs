#![feature(allocator_api)]
#![feature(alloc_layout_extra)]
#![feature(destructuring_assignment)]
#![feature(map_into_keys_values)]
#![feature(map_try_insert)]
#![feature(maybe_uninit_uninit_array)]
#![feature(maybe_uninit_array_assume_init)]
#![feature(maybe_uninit_extra)]
#![feature(new_uninit)]
#![feature(nonnull_slice_from_raw_parts)]
#![feature(slice_ptr_get)]
#![feature(step_trait)]

mod block;
mod constants;
mod editor;
mod rotation;
mod types;
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
	use godot_rapier3d::init;
	godot_gdnative_init!(_ as gd_rapier3d_gdnative_init);
	godot_nativescript_init!(init as gd_rapier3d_nativescript_init);
	godot_gdnative_terminate!(_ as gd_rapier3d_gdnative_terminate);
}
