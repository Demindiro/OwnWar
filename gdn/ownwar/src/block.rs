#![cfg_attr(feature = "server", allow(dead_code))]

use crate::rotation::*;
use crate::types::*;
use core::fmt;
use core::ops;
use gdnative::api::{Mesh, Resource};
use gdnative::prelude::*;
use lazy_static::lazy_static;
use std::convert::{TryFrom, TryInto};
use std::num::{NonZeroU16, NonZeroU32};
use std::sync::RwLock;

pub const SCALE: f32 = 0.25;
lazy_static! {
	static ref BLOCKS: RwLock<Vec<Option<(&'static Block, Ref<Resource>)>>> =
		RwLock::new(Vec::new());
}

/// A structure to check which sides a mount can connect to.
#[derive(Clone, Copy)]
pub struct MountSides(u8);

impl MountSides {
	/// Create a new MountSides with the default value, which is all ones.
	fn new() -> Self {
		Self(0x3f)
	}

	/// Check whether this block can connect in the given direction.
	///
	/// Two blocks can connect if `a.can_connect(d) == b.can_connect(-d)`.
	#[must_use]
	pub fn can_connect(&self, direction: Direction) -> bool {
		self.0 & (1 << direction.get()) > 0
	}

	/// Set whether this block can connect in the given direction.
	///
	/// Two blocks can connect if `a.can_connect(d) == b.can_connect(-d)`.
	#[must_use]
	#[allow(dead_code)]
	pub fn set_connectable(&mut self, direction: Direction, enable: bool) {
		self.0 &= !(1 << direction.get());
		self.0 |= u8::from(enable) << direction.get();
	}
}

impl fmt::Debug for MountSides {
	fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
		stringify!(MountSides, "(").fmt(f)?;
		let mut insert_comma = false;
		for i in 0..6 {
			if self.0 & (1 << i) > 0 {
				if insert_comma {
					", ".fmt(f)?;
				}
				insert_comma = true;
				Direction::new(i).unwrap().fmt(f)?;
			}
		}
		")".fmt(f)?;
		Ok(())
	}
}

impl Default for MountSides {
	fn default() -> Self {
		Self(0) // No connections makes more sense for certain structures such as a voxel Grid
	}
}

impl ops::Mul<MountSides> for Rotation {
	type Output = MountSides;

	fn mul(self, rhs: MountSides) -> Self::Output {
		let mut pos_p = voxel::Delta::ZERO;
		let mut pos_n = voxel::Delta::ZERO;
		pos_p.y |= i16::from(rhs.0 & 1 > 0);
		pos_n.y |= i16::from(rhs.0 & 2 > 0);
		pos_p.x |= i16::from(rhs.0 & 4 > 0);
		pos_n.x |= i16::from(rhs.0 & 8 > 0);
		pos_p.z |= i16::from(rhs.0 & 16 > 0);
		pos_n.z |= i16::from(rhs.0 & 32 > 0);
		pos_p = self * pos_p;
		pos_n = self * pos_n;
		let mut ms = 0;
		ms |= u8::from(pos_p.y > 0 || pos_n.y < 0) << 0;
		ms |= u8::from(pos_n.y > 0 || pos_p.y < 0) << 1;
		ms |= u8::from(pos_p.x > 0 || pos_n.x < 0) << 2;
		ms |= u8::from(pos_n.x > 0 || pos_p.x < 0) << 3;
		ms |= u8::from(pos_p.z > 0 || pos_n.z < 0) << 4;
		ms |= u8::from(pos_n.z > 0 || pos_p.z < 0) << 5;
		MountSides(ms)
	}
}

/// A structure denoting a mount point for a block.
#[derive(Clone, Copy)]
pub struct MountPoint {
	/// The relative position of the mount point.
	pub position: voxel::SmallDelta,
	/// The sides from which the mount point can be connected to.
	pub sides: MountSides,
}

#[derive(NativeClass)]
#[inherit(Resource)]
#[register_with(Self::register)]
pub struct Block {
	pub id: NonZeroU16,
	#[property]
	pub revision: u8,
	#[property]
	pub human_name: String,
	#[property]
	pub human_category: String,
	mesh: Option<(Ref<Mesh>, MeshArrays)>,

	instance: Option<Ref<PackedScene>>,
	pub editor_node: Option<Ref<Spatial>>,
	pub server_node: Option<Ref<Spatial>>,
	pub client_node: Option<Ref<Spatial>>,

	pub health: NonZeroU32,
	#[property]
	pub mass: f32,
	pub cost: NonZeroU16,
	pub aabb: voxel::SmallAABB,

	mirror_rotation_offset: Rotation,
	mirror_block_id: Option<NonZeroU16>,

	mirror_rotation_map: [Rotation; 24],

	pub alternate_rotation_map: Option<[Rotation; 24]>,

	occlusion_info: Option<OcclusionInfo>,

	pub mount_sides: MountSides,
	pub extra_mount_points: Box<[MountPoint]>,
}

#[derive(NativeClass)]
#[inherit(Reference)]
struct BlockManager;

#[derive(Clone, Copy, Debug)]
pub struct MeshPoint {
	pub vertex: Vector3,
	pub normal: Vector3,
	pub uv: Vector2,
}

pub struct MeshArrays {
	data: Vec<Vec<MeshPoint>>,
}

pub struct OcclusionInfo {
	vertices: Box<[([Box<[u16]>; 6], Box<[u16]>)]>,
	solid_faces: u8,
}

macro_rules! add_prop {
	($builder:ident, $name:literal, $get:ident, $set:ident) => {
		$builder
			.add_property($name)
			.with_getter(&Self::$get)
			.with_setter(&Self::$set)
			.done();
	};
	($builder:ident, $name:literal, $get:ident) => {
		$builder.add_property($name).with_getter(&Self::$get).done();
	};
}

#[methods]
impl Block {
	fn register(builder: &ClassBuilder<Self>) {
		add_prop!(builder, "aabb", gd_get_aabb, gd_set_aabb);
		add_prop!(builder, "id", gd_get_id, gd_set_id);
		add_prop!(builder, "health", gd_get_health, gd_set_health);
		add_prop!(builder, "cost", gd_get_cost, gd_set_cost);
		add_prop!(
			builder,
			"__mirror_block_id",
			gd_get_mirror_block_id,
			gd_set_mirror_block_id
		);
		add_prop!(
			builder,
			"mirror_block",
			gd_get_mirror_block,
			gd_set_mirror_block
		);
		add_prop!(builder, "mesh", gd_get_mesh, gd_set_mesh);
		add_prop!(builder, "editor_node", gd_editor_node);
		add_prop!(builder, "server_node", gd_server_node);
		add_prop!(builder, "client_node", gd_client_node);
		add_prop!(builder, "instance", gd_get_instance, gd_set_instance);
		add_prop!(
			builder,
			"mirror_rotation_offset",
			gd_get_mirror_rotation_offset,
			gd_set_mirror_rotation_offset
		);
		add_prop!(
			builder,
			"alternate_rotation_map",
			gd_get_alternate_rotation_map,
			gd_set_alternate_rotation_map
		);
		add_prop!(
			builder,
			"extra_mount_points",
			gd_get_extra_mount_points,
			gd_set_extra_mount_points
		);
		add_prop!(
			builder,
			"extra_mount_sides",
			gd_get_extra_mount_sides,
			gd_set_extra_mount_sides
		);
		add_prop!(
			builder,
			"mount_sides",
			gd_get_mount_sides,
			gd_set_mount_sides
		);
	}

	fn new(owner: TRef<Resource>) -> Self {
		let _ = owner;
		let mut s = Self {
			aabb: voxel::SmallAABB::new(voxel::SmallDelta::ZERO, voxel::SmallDelta::ZERO),
			cost: NonZeroU16::new(1).unwrap(),
			health: NonZeroU32::new(100).unwrap(),
			human_category: String::new(),
			human_name: String::new(),
			id: NonZeroU16::new(65535).unwrap(),

			instance: None,
			editor_node: None,
			server_node: None,
			client_node: None,

			mass: 0.0,
			mesh: None,
			mirror_block_id: None,
			mirror_rotation_offset: Rotation::default(),
			revision: 0,

			mirror_rotation_map: [Rotation::default(); 24],

			alternate_rotation_map: None,

			occlusion_info: None,

			mount_sides: MountSides::new(),
			extra_mount_points: Box::new([]),
		};
		s.gd_set_mirror_rotation_offset(owner, 0);
		s
	}

	#[export]
	fn get_basis(&self, _: &Resource, rotation: u8) -> Basis {
		if let Ok(v) = Rotation::new(rotation) {
			v.basis()
		} else {
			godot_error!("Rotation out of bounds");
			Basis::identity()
		}
	}

	#[export]
	fn get_mirror_rotation(&self, _: &Resource, rotation: u8) -> u8 {
		let rotation = if let Ok(v) = Rotation::new(rotation) {
			v
		} else {
			godot_error!("Rotation out of bounds");
			return 0;
		};
		self.mirror_rotation_map[rotation.get() as usize].get()
	}

	#[export]
	fn get_mount_sides_rotated(&self, _: TRef<Resource>, rotation: u8) -> u8 {
		let rotation = if let Ok(v) = Rotation::new(rotation) {
			v
		} else {
			godot_error!("Rotation out of bounds");
			return 0;
		};
		(rotation * self.mount_sides).0
	}

	#[export]
	fn get_solid_faces(&self, _: TRef<Resource>, rotation: u8) -> u8 {
		let rotation = if let Ok(v) = Rotation::new(rotation) {
			v
		} else {
			godot_error!("Rotation out of bounds");
			return 0;
		};
		self.solid_faces_rotated(rotation)
	}
}

/// Methods specifically intended for communication with GDScript
impl Block {
	fn gd_get_aabb(&self, _: TRef<Resource>) -> Aabb {
		Aabb {
			position: self.aabb.start.into(),
			size: self.aabb.size().into(),
		}
	}

	fn gd_set_aabb(&mut self, _: TRef<Resource>, aabb: Aabb) {
		let start = aabb.position.try_into().expect("Failed to convert start");
		let end = (aabb.position + aabb.size - Vector3::one())
			.try_into()
			.expect("Failed to convert end");
		self.aabb = voxel::SmallAABB::new(start, end);
	}

	fn gd_get_id(&self, _: TRef<Resource>) -> u16 {
		self.id.into()
	}

	fn gd_set_id(&mut self, _: TRef<Resource>, id: u16) {
		self.id = id.try_into().unwrap();
	}

	fn gd_get_health(&self, _: TRef<Resource>) -> u32 {
		self.health.into()
	}

	fn gd_set_health(&mut self, _: TRef<Resource>, health: u32) {
		self.health = health.try_into().unwrap();
	}

	fn gd_get_cost(&self, _: TRef<Resource>) -> u16 {
		self.cost.into()
	}

	fn gd_set_cost(&mut self, _: TRef<Resource>, cost: u16) {
		self.cost = cost.try_into().unwrap();
	}

	fn gd_get_mirror_block_id(&self, _: TRef<Resource>) -> Option<u16> {
		self.mirror_block_id.map(|v| v.get())
	}

	fn gd_set_mirror_block_id(&mut self, _: TRef<Resource>, id: Option<u16>) {
		self.mirror_block_id = id.map(NonZeroU16::new).flatten();
	}

	fn gd_get_mirror_block(&self, owner: TRef<Resource>) -> Option<Ref<Resource>> {
		Some(
			self.mirror_block_id
				.map(|id| {
					BLOCKS
						.read()
						.unwrap()
						.get(id.get() as usize - 1)
						.map(|v| v.as_ref().map(|v| v.1.clone()))
				})
				.flatten()
				.flatten()
				.map_or(owner.claim(), |v| v),
		)
	}

	fn gd_set_mirror_block(&mut self, _: TRef<Resource>, block: Option<Ref<Resource>>) {
		unsafe {
			self.mirror_block_id = block.and_then(|block| {
				block
					.cast_instance::<Block>()
					.unwrap()
					.assume_safe()
					.map(|block, _| block.id)
					.ok()
			});
		}
	}

	fn gd_get_mesh(&self, _: TRef<Resource>) -> Option<Ref<Mesh>> {
		self.mesh.as_ref().map(|m| m.0.clone())
	}

	fn gd_set_mesh(&mut self, _: TRef<Resource>, mesh: Option<Ref<Mesh>>) {
		self.mesh = mesh.map(|m| {
			let ma = MeshArrays::from(&m);
			(m, ma)
		});
	}

	fn gd_editor_node(&self, _: TRef<Resource>) -> Option<Ref<Spatial>> {
		self.editor_node()
	}

	fn gd_server_node(&self, _: TRef<Resource>) -> Option<Ref<Spatial>> {
		self.server_node()
	}

	fn gd_client_node(&self, _: TRef<Resource>) -> Option<Ref<Spatial>> {
		self.client_node()
	}

	fn gd_get_instance(&self, _: TRef<Resource>) -> Option<Ref<PackedScene>> {
		self.instance.clone()
	}

	fn gd_set_instance(&mut self, _: TRef<Resource>, instance: Option<Ref<PackedScene>>) {
		unsafe {
			let f = |p: &mut Option<Ref<Spatial>>| {
				if let Some(n) = p {
					n.assume_safe().queue_free();
					*p = None;
				}
			};
			f(&mut self.editor_node);
			f(&mut self.server_node);
			f(&mut self.client_node);
		}
		self.instance = instance.clone();
		if let Some(instance) = instance {
			unsafe {
				let node = instance.assume_safe().instance(0).unwrap().assume_safe();
				let f = |name| {
					let path = node.get(name).to_node_path();
					if !path.is_empty() {
						Some(
							node.get_node(path)
								.expect(&format!("{} is invalid", name))
								.assume_unique()
								.cast::<Spatial>()
								.unwrap()
								.into_shared(),
						)
					} else {
						None
					}
				};
				self.editor_node = f("editor_node");
				self.server_node = f("server_node");
				self.client_node = f("client_node");
			}
		}
	}

	fn gd_get_mirror_rotation_offset(&self, _: TRef<Resource>) -> u8 {
		self.mirror_rotation_offset.get()
	}

	fn gd_set_mirror_rotation_offset(&mut self, _: TRef<Resource>, offset: u8) {
		let offset = if let Ok(v) = Rotation::new(offset) {
			v
		} else {
			godot_error!("Offset is out of bounds");
			return;
		};
		self.mirror_rotation_map = offset.rotation_map();
		self.mirror_rotation_offset = offset;
	}

	fn gd_get_alternate_rotation_map(&self, _: TRef<Resource>) -> Option<TypedArray<u8>> {
		self.alternate_rotation_map.map(|arr| {
			let mut map = TypedArray::<u8>::new();
			map.resize(24);
			let mut w = map.write();
			for (i, &c) in arr.iter().enumerate() {
				w[i] = c.get();
			}
			drop(w);
			map
		})
	}

	fn gd_set_alternate_rotation_map(&mut self, _: TRef<Resource>, map: Option<TypedArray<u8>>) {
		self.alternate_rotation_map = {
			if let Some(map) = map {
				let r = map.read();
				if r.len() == 0 {
					None
				} else {
					let mut arr = self
						.alternate_rotation_map
						.unwrap_or([Rotation::default(); 24]);
					for (i, &c) in r.iter().enumerate().take(arr.len()) {
						arr[i] = if let Ok(v) = Rotation::new(c) {
							v
						} else {
							godot_error!("Rotation is out of bounds");
							return;
						};
					}
					Some(arr)
				}
			} else {
				None
			}
		};
	}

	fn gd_get_extra_mount_points(&self, _: TRef<Resource>) -> TypedArray<Vector3> {
		let mut arr = TypedArray::new();
		arr.resize(self.extra_mount_points.len() as i32);
		let mut a = arr.write();
		for (i, m) in self.extra_mount_points.iter().copied().enumerate() {
			a[i] = m.position.into();
		}
		drop(a);
		arr
	}

	fn gd_set_extra_mount_points(&mut self, _: TRef<Resource>, mounts: TypedArray<Vector3>) {
		let mut mp = Vec::<MountPoint>::with_capacity(mounts.len() as usize);
		for r in mounts.read().iter().copied() {
			let r = r.try_into().expect("Failed to convert mount point");
			if r != voxel::SmallDelta::ZERO && mp.iter().position(|p| p.position == r).is_none() {
				mp.push(MountPoint {
					position: r,
					sides: MountSides::new(),
				});
			}
		}
		self.extra_mount_points = mp.into_boxed_slice();
	}

	fn gd_get_extra_mount_sides(&self, _: TRef<Resource>) -> TypedArray<u8> {
		let mut arr = TypedArray::new();
		arr.resize(self.extra_mount_points.len() as i32);
		let mut a = arr.write();
		for (i, m) in self.extra_mount_points.iter().copied().enumerate() {
			a[i] = m.sides.0;
		}
		drop(a);
		arr
	}

	fn gd_set_extra_mount_sides(&mut self, _: TRef<Resource>, sides: TypedArray<u8>) {
		if sides.len() as usize != self.extra_mount_points.len() {
			godot_error!("Amount of sides doesn't match amount of mount points");
		} else {
			for (w, r) in self.extra_mount_points.iter_mut().zip(sides.read().iter()) {
				w.sides = MountSides(*r);
			}
		}
	}

	fn gd_get_mount_sides(&self, _: TRef<Resource>) -> u8 {
		self.mount_sides.0
	}

	fn gd_set_mount_sides(&mut self, _: TRef<Resource>, sides: u8) {
		self.mount_sides.0 = sides;
	}
}

/// Generic helper methods
impl Block {
	pub fn get(id: NonZeroU16) -> Option<&'static Block> {
		BLOCKS
			.read()
			.unwrap()
			.get(id.get() as usize - 1)
			.and_then(|v| v.as_ref().map(|v| v.0))
	}

	pub fn editor_node(&self) -> Option<Ref<Spatial>> {
		self.editor_node.map(|n| n.clone())
	}

	pub fn server_node(&self) -> Option<Ref<Spatial>> {
		self.server_node.map(|n| n.clone())
	}

	pub fn client_node(&self) -> Option<Ref<Spatial>> {
		self.client_node.map(|n| n.clone())
	}

	/// Return whether this is a multi block. It may be a multiblock if:
	///
	/// * It has nodes
	/// * It has more than `u16::MAX` health points (TODO)
	/// * It has multiple connection points (TODO)
	#[must_use]
	pub fn is_multi_block(&self) -> bool {
		self.server_node.is_some()
	}

	/*
	pub fn mesh_arrays(&self) -> Option<&MeshArrays> {
		self.mesh.map(|v| {
			let (_, ref v) = v;
			v
		})
	}
	*/

	pub fn mesh_arrays(&self) -> Option<&(Ref<Mesh>, MeshArrays)> {
		self.mesh.as_ref()
	}

	pub fn mirror_block(&self) -> &Block {
		if let Some(id) = self.mirror_block_id {
			Self::get(id).expect("Invalid mirror block")
		} else {
			self
		}
	}

	pub fn mirror_rotation(&self, rotation: Rotation) -> Rotation {
		self.mirror_rotation_map[rotation.get() as usize]
	}

	/// Returns a bitmask of all solid faces accounting for the rotation
	pub fn solid_faces_rotated(&self, rotation: Rotation) -> u8 {
		let info = self
			.occlusion_info
			.as_ref()
			.expect("Occlusion info is None");
		let mut bits = 0;
		for i in 0..6 {
			let dir = Direction::new(i).unwrap();
			let dir = rotation.transform_direction(dir);
			let k = dir.get();
			bits |= ((info.solid_faces >> i) & 1) << k;
		}
		bits
	}

	/// Returns the vertex indices for a given side and rotation
	pub fn face_vertex_indices(
		&self,
		mesh: u8,
		face: Direction,
		rotation: Rotation,
	) -> &'static Box<[u16]> {
		let face = rotation.transform_direction(face);
		let info = self
			.occlusion_info
			.as_ref()
			.expect("Occlusion info is None");
		let verts = &info.vertices[mesh as usize].0[face.get() as usize];
		// SAFETY: none lol, this code is trash
		unsafe { std::mem::transmute(verts) }
	}

	/// Returns the global vertex indices
	pub fn global_vertex_indices(&self, mesh: u8) -> &'static Box<[u16]> {
		let info = self
			.occlusion_info
			.as_ref()
			.expect("Occlusion info is None");
		let verts = &info.vertices[mesh as usize].1;
		// SAFETY: loooooooooooooooool
		unsafe { std::mem::transmute(verts) }
	}

	/// Generate occlusion info used to optimize VoxelMeshes
	fn generate_occlusion_info(&mut self) {
		let mut surfaces = [0.0; 6];
		let mut vertices = Vec::new();
		for (_, array) in self.mesh_arrays() {
			for array in array.data.iter() {
				let mut face_vertices: [Vec<_>; 6] = Default::default();
				let mut global_vertices = Vec::new();
				let iter = array
					.chunks_exact(3)
					.map(|v| <[MeshPoint; 3]>::try_from(v).expect("Failed to unpack chunks_exact"));
				for (i, [a, b, c]) in iter.enumerate() {
					let (a, b, c) = (a.vertex, b.vertex, c.vertex);
					let (f, g) = (b - a, c - a);
					let cross = f.cross(g);
					let norm = cross.normalize();
					let eq = |x: f32, y: f32, z: f32| {
						(norm.x - x).abs() < 1e-4
							&& (norm.y - y).abs() < 1e-4 && (norm.z - z).abs() < 1e-4
					};
					let cmp3 = |i| {
						let s = SCALE / 2.0;
						let (a, b, c): (f32, f32, f32) =
							(a.to_array()[i], b.to_array()[i], c.to_array()[i]);
						((a - s).abs() < 1e-4 || (a + s).abs() < 1e-4)
							&& (a - b).abs() < 1e-4 && (a - c).abs() < 1e-4
					};
					let i = (i * 3)
						.try_into()
						.expect("Mesh has more than u16::MAX vertices");
					let indices = &[i, i + 1, i + 2];
					let dir = match norm {
						_ if eq(0.0, 1.0, 0.0) && cmp3(1) => 0,
						_ if eq(0.0, -1.0, 0.0) && cmp3(1) => 1,
						_ if eq(1.0, 0.0, 0.0) && cmp3(0) => 2,
						_ if eq(-1.0, 0.0, 0.0) && cmp3(0) => 3,
						_ if eq(0.0, 0.0, 1.0) && cmp3(2) => 4,
						_ if eq(0.0, 0.0, -1.0) && cmp3(2) => 5,
						_ => {
							global_vertices.extend(indices);
							continue;
						}
					};
					surfaces[dir] += cross.length() / 2.0;
					face_vertices[dir].extend(indices);
				}
				// Yikes, but it works
				let face_vertices = Vec::from(face_vertices)
					.into_iter()
					.map(|v| v.into_boxed_slice())
					.collect::<Vec<_>>()
					.try_into()
					.unwrap();
				let global_vertices = global_vertices.into_boxed_slice();
				vertices.push((face_vertices, global_vertices));
			}
		}
		let mut solid_faces = 0;
		for (i, &surface) in surfaces.iter().enumerate() {
			if surface >= 0.99 * (SCALE * SCALE) {
				solid_faces |= 1 << i;
			}
		}
		self.occlusion_info = Some(OcclusionInfo {
			solid_faces,
			vertices: vertices.into_boxed_slice(),
		});
	}

	/// Return all mount points.
	pub fn mount_points<'a>(&'a self) -> impl Iterator<Item = MountPoint> + 'a {
		let position = voxel::SmallDelta::ZERO;
		let sides = self.mount_sides;
		let extra = self.extra_mount_points.iter().copied();
		Some(MountPoint { position, sides }).into_iter().chain(extra)
	}
}

/// Helper class intended for GDScript usage
// TODO find a way to make this a static class
#[methods]
impl BlockManager {
	fn new(_: &Reference) -> Self {
		Self
	}

	#[export]
	fn add_block(&self, _: &Reference, block: Ref<Resource>) {
		let owner = block.clone();
		unsafe {
			block
				.assume_safe()
				.cast_instance::<Block>()
				.unwrap()
				.map_mut(|block, _| {
					if block.mass == 0.0 {
						godot_warn!("Mass of block {} is 0", block.id);
					}
					block.generate_occlusion_info();
					let id = block.id.get();
					let i = id as usize - 1;
					let mut blocks = BLOCKS.write().unwrap();
					if let Some(Some(b)) = blocks.get(i) {
						let (a_hn, b_hn) = (&block.human_name, &b.0.human_name);
						godot_error!("ID {} of {} conflicts with {}", id, a_hn, b_hn);
						panic!("ID {} of {} conflicts with {}", id, a_hn, b_hn);
					} else {
						if blocks.len() <= i {
							blocks.resize(i + 1, None);
						}
						// FIXME make it so _we_ own the value of the block, not Godot
						// This will do for now...
						// FIXME this is such a terrible idea
						blocks[i] = Some((std::mem::transmute(block), owner));
						blocks[i].as_mut().unwrap().0
					}
				})
				.unwrap();
		}
	}

	#[export]
	fn rotation_to_basis(&self, _: &Reference, rotation: u8) -> Basis {
		if let Ok(rotation) = Rotation::new(rotation) {
			rotation.basis()
		} else {
			godot_error!("Rotation is out of bounds");
			Basis::identity()
		}
	}

	#[export]
	fn get_block(&self, _: &Reference, id: u16) -> Option<Ref<Resource>> {
		if id == 0 {
			None
		} else {
			BLOCKS
				.read()
				.unwrap()
				.get(id as usize - 1)
				.and_then(|v| v.as_ref().map(|v| v.1.clone()))
		}
	}

	#[export]
	fn get_all_blocks(&self, _: &Reference) -> VariantArray {
		let arr = VariantArray::new();
		for b in BLOCKS.read().unwrap().iter() {
			if let Some(b) = b {
				arr.push(b.1.clone());
			}
		}
		arr.into_shared()
	}

	#[export]
	fn axis_to_direction(&self, _: &Reference, axis: Vector3) -> u8 {
		let axis = axis.round();
		let axis = (axis.x, axis.y, axis.z);
		let d = match axis {
			_ if axis == (0.0, 1.0, 0.0) => 0,
			_ if axis == (0.0, -1.0, 0.0) => 1,
			_ if axis == (1.0, 0.0, 0.0) => 2,
			_ if axis == (-1.0, 0.0, 0.0) => 3,
			_ if axis == (0.0, 0.0, 1.0) => 4,
			_ if axis == (0.0, 0.0, -1.0) => 5,
			_ => panic!("Invalid axis {:?}", axis),
		};
		d << 2
	}
}

impl MeshArrays {
	fn from(mesh: &Ref<Mesh>) -> Self {
		unsafe {
			let mesh = mesh.assume_safe();
			let mut data = Vec::new();
			for i in 0..mesh.get_surface_count() {
				let arr = mesh.surface_get_arrays(i);
				let verts = arr
					.get(Mesh::ARRAY_VERTEX as i32)
					.try_to_vector3_array()
					.expect("No vertices array!");
				let norms = arr
					.get(Mesh::ARRAY_NORMAL as i32)
					.try_to_vector3_array()
					.expect("No normals array!");
				/*
				let uvs = arr
					.get(Mesh::ARRAY_TEX_UV as i32)
					.try_to_vector2_array()
					.expect("No UV array!");
					*/
				let verts = verts.read();
				let norms = norms.read();
				//let uvs = uvs.read();
				if let Some(indices) = arr.get(Mesh::ARRAY_INDEX as i32).try_to_int32_array() {
					let mut array = Vec::with_capacity(indices.len() as usize);
					let indices = indices.read();
					for &i in indices.iter() {
						array.push(MeshPoint {
							vertex: verts[i as usize],
							normal: norms[i as usize],
							uv: Vector2::zero(),
						});
					}
					data.push(array);
				} else {
					let mut array = Vec::with_capacity(verts.len() as usize);
					let verts = verts.iter();
					let norms = norms.iter();
					//let uvs = uvs.iter();
					//for ((&vertex, &normal), &uv) in verts.zip(norms).zip(uvs) {
					//	array.push(MeshPoint { vertex, normal, uv });
					for (&vertex, &normal) in verts.zip(norms) {
						array.push(MeshPoint {
							vertex,
							normal,
							uv: Vector2::zero(),
						});
					}
					data.push(array);
				}
			}
			Self { data }
		}
	}

	pub fn iter(&self) -> impl Iterator<Item = &Vec<MeshPoint>> {
		self.data.iter()
	}
}

pub(super) fn init(handle: InitHandle) {
	handle.add_class::<Block>();
	handle.add_class::<BlockManager>();
}
