mod body;
mod interpolation_state;
mod voxel_body;
mod voxel_mesh;

pub use voxel_body::VoxelBody;

use gdnative::nativescript::InitHandle;

pub(super) fn init(handle: InitHandle) {
	handle.add_class::<VoxelBody>();
	handle.add_class::<voxel_mesh::VoxelMesh>();
}
