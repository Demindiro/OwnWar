mod body;
mod controller;
mod interpolation_state;
//mod voxel_body;
mod vehicle;
mod voxel_mesh;

const PAST_STATE_SIZE: usize = 64;

type DynamicBlockState = gdnative::prelude::Variant;
type VehicleData = gdnative::prelude::TypedArray<u8>;
type BodyIndex = u8;
type Voxel = euclid::Vector3D<u8, euclid::UnknownUnit>;
type Color8 = euclid::Vector3D<u8, euclid::UnknownUnit>;

pub(crate) use voxel_mesh::VoxelMesh;
//pub(crate) use vehicle::Vehicle;
pub(crate) use controller::Controller;

use body::{Body, DamageEvent};
use gdnative::nativescript::InitHandle;

pub(super) fn init(handle: InitHandle) {
	handle.add_class::<voxel_mesh::VoxelMesh>();
	handle.add_class::<vehicle::gd::Vehicle>();
}
