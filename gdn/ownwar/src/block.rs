use crate::util::{convert_vec, AABB};
use gdnative::api::{Mesh, Resource};
use gdnative::prelude::*;
use lazy_static::lazy_static;
use std::convert::TryInto;
use std::num::{NonZeroU16, NonZeroU32};
use std::sync::RwLock;

pub const SCALE: f32 = 0.25;
lazy_static! {
	static ref BLOCKS: RwLock<Vec<Option<(&'static Block, Ref<Resource>)>>> =
		RwLock::new(Vec::new());
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
	pub aabb: AABB<i8>,

	mirror_rotation_offset: u8,
	mirror_block_id: Option<NonZeroU16>,

	mirror_rotation_map: [u8; 24],
}

#[derive(NativeClass)]
#[inherit(Reference)]
struct BlockManager;

#[derive(Clone, Copy)]
pub struct MeshPoint {
	pub vertex: Vector3,
	pub normal: Vector3,
	pub uv: Vector2,
}

pub struct MeshArrays {
	data: Vec<Vec<MeshPoint>>,
}

#[methods]
impl Block {
	fn register(builder: &ClassBuilder<Self>) {
		builder
			.add_property("aabb")
			.with_getter(&Self::gd_get_aabb)
			.with_setter(&Self::gd_set_aabb)
			.done();
		builder
			.add_property("id")
			.with_getter(&Self::gd_get_id)
			.with_setter(&Self::gd_set_id)
			.done();
		builder
			.add_property("health")
			.with_getter(&Self::gd_get_health)
			.with_setter(&Self::gd_set_health)
			.done();
		builder
			.add_property("cost")
			.with_getter(&Self::gd_get_cost)
			.with_setter(&Self::gd_set_cost)
			.done();
		builder
			.add_property("__mirror_block_id")
			.with_getter(&Self::gd_get_mirror_block_id)
			.with_setter(&Self::gd_set_mirror_block_id)
			.done();
		builder
			.add_property("mirror_block")
			.with_getter(&Self::gd_get_mirror_block)
			.with_setter(&Self::gd_set_mirror_block)
			.done();
		builder
			.add_property("mesh")
			.with_getter(&Self::gd_get_mesh)
			.with_setter(&Self::gd_set_mesh)
			.done();
		builder
			.add_property("editor_node")
			.with_getter(&Self::gd_editor_node)
			.done();
		builder
			.add_property("server_node")
			.with_getter(&Self::gd_server_node)
			.done();
		builder
			.add_property("client_node")
			.with_getter(&Self::gd_client_node)
			.done();
		builder
			.add_property("instance")
			.with_getter(&Self::gd_get_instance)
			.with_setter(&Self::gd_set_instance)
			.done();
		builder
			.add_property("mirror_rotation_offset")
			.with_getter(&Self::gd_get_mirror_rotation_offset)
			.with_setter(&Self::gd_set_mirror_rotation_offset)
			.done();
	}

	fn new(owner: TRef<Resource>) -> Self {
		let _ = owner;
		use euclid::Vector3D;
		let mut s = Self {
			aabb: AABB::new(Vector3D::zero(), Vector3D::new(1, 1, 1)),
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
			mirror_rotation_offset: 0,
			revision: 0,

			mirror_rotation_map: [0; 24],
		};
		s.gd_set_mirror_rotation_offset(owner, 0);
		s
	}

	#[export]
	fn get_basis(&self, _owner: &Resource, rotation: u8) -> Basis {
		Self::rotation_to_basis(rotation)
	}

	#[export]
	fn get_mirror_rotation(&self, _owner: &Resource, rotation: u8) -> u8 {
		self.mirror_rotation_map[rotation as usize]
	}
}

/// Methods specifically intended for communication with GDScript
impl Block {
	fn gd_get_aabb(&self, _owner: TRef<Resource>) -> Aabb {
		Aabb {
			position: convert_vec(self.aabb.position),
			size: convert_vec(self.aabb.size),
		}
	}

	fn gd_set_aabb(&mut self, _owner: TRef<Resource>, aabb: Aabb) {
		self.aabb = AABB {
			position: convert_vec(aabb.position),
			size: convert_vec(aabb.size),
		}
	}

	fn gd_get_id(&self, _owner: TRef<Resource>) -> u16 {
		self.id.into()
	}

	fn gd_set_id(&mut self, _owner: TRef<Resource>, id: u16) {
		//godot_warn!("{}", &self.human_name);
		self.id = id.try_into().unwrap();
	}

	fn gd_get_health(&self, _owner: TRef<Resource>) -> u32 {
		self.health.into()
	}

	fn gd_set_health(&mut self, _owner: TRef<Resource>, health: u32) {
		self.health = health.try_into().unwrap();
	}

	fn gd_get_cost(&self, _owner: TRef<Resource>) -> u16 {
		self.cost.into()
	}

	fn gd_set_cost(&mut self, _owner: TRef<Resource>, cost: u16) {
		self.cost = cost.try_into().unwrap();
	}

	fn gd_get_mirror_block_id(&self, _owner: TRef<Resource>) -> Option<u16> {
		self.mirror_block_id.map(|v| v.get())
	}

	fn gd_set_mirror_block_id(&mut self, _owner: TRef<Resource>, id: Option<u16>) {
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

	fn gd_set_mirror_block(&mut self, _owner: TRef<Resource>, block: Option<Ref<Resource>>) {
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

	fn gd_get_mesh(&self, _owner: TRef<Resource>) -> Option<Ref<Mesh>> {
		self.mesh.as_ref().map(|m| m.0.clone())
	}

	fn gd_set_mesh(&mut self, _owner: TRef<Resource>, mesh: Option<Ref<Mesh>>) {
		self.mesh = mesh.map(|m| {
			let ma = MeshArrays::from(&m);
			(m, ma)
		});
	}

	fn gd_editor_node(&self, _owner: TRef<Resource>) -> Option<Ref<Spatial>> {
		self.editor_node()
	}

	fn gd_server_node(&self, _owner: TRef<Resource>) -> Option<Ref<Spatial>> {
		self.server_node()
	}

	fn gd_client_node(&self, _owner: TRef<Resource>) -> Option<Ref<Spatial>> {
		self.client_node()
	}

	fn gd_get_instance(&self, _owner: TRef<Resource>) -> Option<Ref<PackedScene>> {
		self.instance.clone()
	}

	fn gd_set_instance(&mut self, _owner: TRef<Resource>, instance: Option<Ref<PackedScene>>) {
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

	fn gd_get_mirror_rotation_offset(&self, _owner: TRef<Resource>) -> u8 {
		self.mirror_rotation_offset
	}

	fn gd_set_mirror_rotation_offset(&mut self, _owner: TRef<Resource>, offset: u8) {
		assert!(offset < 4);
		for i in 0..24 {
			let angle = i & 3;
			let direction = i >> 2;

			let angle = if offset % 2 == 0 {
				[0, 3, 2, 1][angle]
			} else {
				[3, 2, 1, 0][angle]
			};
			let direction = match direction {
				3 => 2,
				2 => 3,
				_ => direction,
			};

			self.mirror_rotation_map[i] = ((direction << 2) | angle) as u8;
		}
		self.mirror_rotation_offset = offset;
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

	pub fn rotation_to_basis(rotation: u8) -> Basis {
		use std::f32::consts::{FRAC_PI_2, PI};
		assert!(rotation < 24);
		let angle = rotation & 3;
		let direction = rotation >> 2;
		let f = |x, y, z| Basis::from_euler(Vector3::new(x, y, z));
		let basis = f(0.0, FRAC_PI_2 * angle as f32, 0.0);
		// TODO wtf rust?
		let b2 = match direction {
			0 => Basis::identity(),
			1 => f(0.0, 0.0, PI),
			2 => f(0.0, 0.0, -FRAC_PI_2),
			3 => f(0.0, 0.0, FRAC_PI_2),
			4 => f(FRAC_PI_2, 0.0, 0.0),
			5 => f(0.0, PI, 0.0) * f(FRAC_PI_2, 0.0, 0.0),
			_ => unreachable!(),
		};
		b2 * basis
	}
}

/// Helper class intended for GDScript usage
// TODO find a way to make this a static class
#[methods]
impl BlockManager {
	fn new(_owner: &Reference) -> Self {
		Self
	}

	#[export]
	fn add_block(&self, _owner: &Reference, block: Ref<Resource>) {
		let owner = block.clone();
		unsafe {
			block
				.assume_safe()
				.cast_instance::<Block>()
				.unwrap()
				.map(|block, _| {
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
					}
				})
				.unwrap();
		}
	}

	#[export]
	fn rotation_to_basis(&self, _owner: &Reference, rotation: u8) -> Basis {
		Block::rotation_to_basis(rotation)
	}

	#[export]
	fn get_block(&self, _owner: &Reference, id: u16) -> Option<Ref<Resource>> {
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
	fn get_all_blocks(&self, _owner: &Reference) -> VariantArray {
		let arr = VariantArray::new();
		for b in BLOCKS.read().unwrap().iter() {
			if let Some(b) = b {
				arr.push(b.1.clone());
			}
		}
		arr.into_shared()
	}

	#[export]
	fn axis_to_direction(&self, _owner: &Reference, axis: Vector3) -> u8 {
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
