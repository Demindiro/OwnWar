mod body;
mod controller;
#[cfg(not(feature = "server"))]
mod interpolation_state;
mod vehicle;
#[cfg(not(feature = "server"))]
mod voxel_mesh;

pub(crate) use controller::Controller;
#[allow(unused_imports)]
pub(crate) use vehicle::Vehicle;
#[cfg(not(feature = "server"))]
pub(crate) use voxel_mesh::VoxelMesh;

use body::{Body, DamageEvent};
use gdnative::nativescript::InitHandle;

pub(super) fn init(handle: InitHandle) {
	#[cfg(not(feature = "server"))]
	handle.add_class::<voxel_mesh::VoxelMesh>();
	handle.add_class::<vehicle::gd::Vehicle>();
}
