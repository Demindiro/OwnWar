mod data;
mod serialize;

mod godot {

	use super::data::Vehicle;
	use crate::vehicle::VoxelMesh;
	use gdnative::prelude::*;

	#[derive(NativeClass)]
	#[inherit(Node)]
	struct Editor {
		data: Vehicle,

		meshes: Vec<Instance<VoxelMesh, ThreadLocal>>,
	}

	#[methods]
	impl Editor {
		fn new(_owner: &Node) -> Self {
			Self {
				data: Vehicle::new(),
				meshes: Vec::new(),
			}
		}
	}
}
