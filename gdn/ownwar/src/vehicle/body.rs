use super::interpolation_state::InterpolationState;
use super::voxel_body::VoxelBody;
use super::voxel_mesh::VoxelMesh;
use crate::util::{convert_vec, BitArray, AABB};
use euclid::{UnknownUnit, Vector3D};
use gdnative::api::{Resource, Script, Spatial, VehicleBody};
use gdnative::prelude::*;
use num_traits::{AsPrimitive, PrimInt};
use std::collections::{HashMap, HashSet};
use std::convert::TryInto;
use std::num::{NonZeroU16, NonZeroU32};

type Voxel = Vector3D<u8, UnknownUnit>;

const BLOCK_SCALE: f32 = 0.25;
const MAINFRAME_ID: NonZeroU16 = unsafe { NonZeroU16::new_unchecked(76) };
// TODO port Block in Rust so we don't have to do this for performance
static mut BLOCK_COST_CACHE: Vec<Option<CachedBlock>> = Vec::new();

pub(super) struct Body {
	offset: Voxel,
	size: Voxel,
	ids: Box<[Option<NonZeroU16>]>,
	health: Box<[Option<NonZeroU16>]>,
	multi_blocks: Vec<Option<MultiBlock>>,
	count: u32,
	anchors: HashMap<Voxel, Vec<Ref<VehicleBody>>>,
	has_mainframe: bool,
	center_of_mass: Vector3,
	// TODO why is VoxelBody modifying this?
	pub(super) total_mass: f32,
	pub(super) total_cost: u32,
	pub(super) total_health: u32,
	max_cost: u32,
	max_health: u32,
}

#[derive(Debug)]
pub(super) struct MultiBlock {
	health: NonZeroU32,
	// TODO fix borrow stuff
	pub(super) server_node: Ref<Spatial>,
	client_node: Ref<Spatial>,
	reverse_indices: Box<[Voxel]>,
}

pub(super) struct CachedBlock {
	health: NonZeroU32,
	cost: NonZeroU32,
}

#[derive(Debug)]
pub(super) enum Block<'a> {
	Destroyed(NonZeroU16),
	Single(NonZeroU16, NonZeroU16),
	Multi(NonZeroU16, &'a MultiBlock),
}

pub(super) enum DamageState {
	BodyDestroyed,
	BlocksDestroyed(Vec<MultiBlock>),
}

impl Body {
	pub fn new(offset: Voxel, size: Voxel) -> Self {
		use std::iter::repeat;
		let real_size = size.x as usize * size.y as usize * size.z as usize;
		Self {
			offset,
			size,
			ids: repeat(None).take(real_size).collect(),
			health: repeat(None).take(real_size).collect(),
			multi_blocks: Vec::new(),
			anchors: HashMap::new(),
			has_mainframe: false,
			count: 0,
			center_of_mass: Vector3D::zero(),
			total_mass: 0.0,
			total_cost: 0,
			total_health: 0,
			max_cost: 0,
			max_health: 0,
		}
	}

	pub fn add_block(
		&mut self,
		owner: TRef<VehicleBody>,
		voxel_mesh: &mut VoxelMesh,
		position: Voxel,
		rotation: u8,
		block: TRef<Resource>,
		color: Color,
		state: Option<&TypedArray<i32>>,
		is_ally: bool,
	) -> Option<InterpolationState> {
		let index = if let Ok(index) = self.get_index(position) {
			index
		} else {
			godot_error!(
				"Position out of bounds! {:?} outside {:?}",
				position,
				self.size
			);
			return None;
		};
		if let Some(_) = self.ids[index as usize] {
			godot_error!("Position is already occupied! {:?}", position);
			return None;
		}

		let (id, cached) = add_block_to_cache(block);
		let hp = if let Some(state) = state {
			if let Some(hp) = NonZeroU32::new(state.get(index as i32) as u32) {
				hp
			} else {
				return None;
			}
		} else {
			cached.health
		};
		let cost = cached.cost.get();

		voxel_mesh.add_block(block, color, position, rotation);

		let mut bb = InterpolationState::new(block);

		if id == MAINFRAME_ID {
			if self.has_mainframe {
				godot_error!("Body has two mainframes!");
				// Carry on anyways...
			}
			self.has_mainframe = true;
		}
		self.ids[index as usize] = Some(id);
		self.max_health += hp.get();
		self.max_cost += cost;
		self.count += 1;

		if let Some(ref mut bb) = bb {
			let basis = unsafe {
				block
					.call("rotation_to_basis", &[rotation.to_variant()])
					.try_to_basis()
					.unwrap()
			};
			let origin = Vector3::new(
				position.x as f32 + 0.5,
				position.y as f32 + 0.5,
				position.z as f32 + 0.5,
			) * BLOCK_SCALE;
			let server_node = unsafe { bb.server_node.assume_safe() };
			let client_node = unsafe { bb.client_node.assume_safe() };
			server_node.set_name(format!("S {},{},{}", position.x, position.y, position.z));
			client_node.set_name(format!("C {},{},{}", position.x, position.y, position.z));
			server_node.set_transform(Transform { basis, origin });
			client_node.set_transform(Transform { basis, origin });
			if client_node.has_method("set_color") {
				unsafe { client_node.call("set_color", &[color.to_variant()]) };
			}
			client_node.set("server_node", bb.server_node);
			// TODO add a proper way to detect allied vehicles
			client_node.set(
				"team_color",
				if is_ally {
					Color::rgb(0.0, 0.0, 1.0)
				} else {
					Color::rgb(1.0, 0.0, 0.0)
				},
			);
			owner.add_child(bb.server_node, false);
			owner.add_child(bb.client_node, false);
			let args = VariantArray::new();
			args.push(bb.server_node);
			server_node
				.connect(
					"tree_exiting",
					owner,
					"remove_interpolator",
					args.into_shared(),
					0,
				)
				.unwrap();

			self.health[index as usize] =
				Some(NonZeroU16::new(self.multi_blocks.len() as u16 | 0x8000).unwrap());
			self.multi_blocks.push(Some(MultiBlock {
				health: hp,
				server_node: bb.server_node,
				client_node: bb.client_node,
				reverse_indices: vec![position].into_boxed_slice(),
			}));
		} else {
			self.health[index as usize] = Some(hp.try_into().unwrap());
		}

		bb
	}

	pub fn try_get_block<T: PrimInt + AsPrimitive<isize>>(
		&self,
		position: Vector3D<T, UnknownUnit>,
	) -> Result<Option<Block>, ()> {
		self.get_index(position).and_then(|i| {
			let i = i as usize;
			if let Some(id) = self.ids[i] {
				if let Some(hp) = self.health[i] {
					if hp.get() & 0x8000 != 0 {
						let index = (hp.get() & 0x7fff) as usize;
						if let Some(ref block) = self.multi_blocks[index] {
							Ok(Some(Block::Multi(id, block)))
						} else {
							godot_error!("Block is already destroyed!");
							// We can recover from this, move on.
							// This won't leak nodes as long as the vehicle itself is destroyed
							//self.multi_blocks[index] = None; // self is immutable :/
							Ok(Some(Block::Destroyed(id)))
						}
					} else {
						Ok(Some(Block::Single(id, hp)))
					}
				} else {
					Ok(Some(Block::Destroyed(id)))
				}
			} else {
				Ok(None)
			}
		})
	}

	fn get_block_health<T: PrimInt + AsPrimitive<isize>>(
		&self,
		position: Vector3D<T, UnknownUnit>,
	) -> u32 {
		if let Ok(Some(block)) = self.try_get_block(position) {
			block.health()
		} else {
			0
		}
	}

	pub fn iter_multi_blocks(&self) -> impl Iterator<Item = &MultiBlock> {
		self.multi_blocks.iter().filter_map(|s| s.as_ref())
	}

	pub fn add_anchor(&mut self, position: Voxel, body: Ref<VehicleBody>) {
		self.anchors
			.entry(position)
			.and_modify(|e| e.push(body))
			.or_insert_with(|| vec![body]);
	}

	pub fn remove_anchor(&mut self, position: Voxel, body: Ref<VehicleBody>) -> bool {
		let mut empty = false;
		let mut found = false;
		self.anchors.entry(position).and_modify(|e| {
			for (i, b) in e.iter().enumerate() {
				if b == &body {
					e.swap_remove(i);
					empty = e.len() == 0;
					found = true;
					return;
				}
			}
		});
		if empty {
			self.anchors.remove(&position);
		}
		found
	}

	fn remove_all_anchors(&mut self, position: Voxel) -> bool {
		self.anchors.remove(&position).map(|_| Some(())).is_some()
	}

	pub fn remove_anchored_body(
		&mut self,
		owner: Ref<VehicleBody>,
		voxel_mesh: &mut VoxelMesh,
		body: Ref<VehicleBody>,
	) -> Option<DamageState> {
		let mut removed_something = false;
		let mut remove_keys = Vec::new();
		for (k, v) in self.anchors.iter_mut() {
			for i in (0..v.len()).rev() {
				if v[i] == body {
					v.swap_remove(i);
					removed_something = true
				}
			}
			if v.len() == 0 {
				remove_keys.push(*k);
			}
		}
		for k in remove_keys {
			self.anchors.remove(&k).unwrap();
		}
		if removed_something {
			Some(self.destroy_disconnected_blocks(owner, voxel_mesh, Vec::new(), true))
		} else {
			None
		}
	}

	fn get_index<T: PrimInt + AsPrimitive<isize>>(
		&self,
		position: Vector3D<T, UnknownUnit>,
	) -> Result<u32, ()> {
		let position = convert_vec(position);
		let size = convert_vec(self.size);
		if AABB::new(Vector3D::zero(), size - Vector3D::new(1, 1, 1)).has_point(position) {
			Ok(((position.x * size.y + position.y) * size.z + position.z)
				.try_into()
				.unwrap())
		} else {
			Err(())
		}
	}

	pub fn is_valid_voxel<T: PrimInt + AsPrimitive<isize>>(
		&self,
		position: Vector3D<T, UnknownUnit>,
	) -> bool {
		self.get_index(position) != Err(())
	}

	pub fn calculate_mass(
		&mut self,
		ownwar_block_script: &Ref<Script>, /* TODO this is a shitty hack */
	) {
		let mut total_mass = 0.0;
		let mut center_of_mass = Vector3::zero();
		let size = self.size;
		for (x, y, z) in (0..size.x)
			.flat_map(move |x| (0..size.y).map(move |y| (x, y)))
			.flat_map(move |(x, y)| (0..size.z).map(move |z| (x, y, z)))
		{
			let blk = self.try_get_block(Voxel::new(x, y, z)).unwrap();
			if let Some(blk) = blk {
				let mass = unsafe {
					ownwar_block_script
						.assume_safe()
						.call("get_block", &[blk.id().get().to_variant()])
						.try_to_object::<Resource>()
						.unwrap()
						.assume_safe()
						.get("mass")
						.try_to_f64()
						.unwrap() as f32
				};
				center_of_mass += Vector3::new(x as f32, y as f32, z as f32) * mass;
				total_mass += mass;
			}
		}
		self.total_mass = total_mass;
		self.center_of_mass = center_of_mass / total_mass;
	}

	pub fn try_damage_block(
		&mut self,
		position: Voxel,
		damage: u32,
	) -> Result<(bool, u32, bool, bool, Option<MultiBlock>), ()> {
		self.get_index(position).and_then(|i| {
			let i = i as usize;
			if let Some(id) = self.ids[i] {
				let is_mainframe = id == MAINFRAME_ID;
				if let Some(hp) = self.health[i] {
					if hp.get() & 0x8000 != 0 {
						let block_index = (hp.get() & 0x7fff) as usize;
						if let Some(ref block) = self.multi_blocks[block_index] {
							let hp = block.health.get();
							if hp <= damage {
								let block = self.multi_blocks[block_index].take().unwrap();
								let damage = damage - hp;
								self.count -= 1;
								self.total_health -= hp;
								self.total_cost -= get_cached_block(id).cost.get();
								let mut anchor_destroyed = false;
								for &pos in block.reverse_indices.iter() {
									self.health[self.get_index(pos).unwrap() as usize] = None;
									anchor_destroyed |= self.remove_all_anchors(pos);
								}
								self.multi_blocks[block_index] = None;
								Ok((true, damage, anchor_destroyed, is_mainframe, Some(block)))
							} else {
								self.multi_blocks[block_index].as_mut().unwrap().health =
									NonZeroU32::new(block.health.get() - damage).unwrap();
								self.total_health -= damage;
								Ok((false, 0, false, is_mainframe, None))
							}
						} else {
							godot_error!("Block was already destroyed!");
							// Try to carry on anyways, we can recover from this
							self.health[i] = None;
							Ok((false, damage, false, is_mainframe, None))
						}
					} else {
						let hp = hp.get() as u32;
						if hp <= damage {
							let damage = damage - hp;
							self.health[i] = None;
							self.count -= 1;
							self.total_health -= hp;
							self.total_cost -= get_cached_block(id).cost.get();
							let anchor_destroyed = self.remove_all_anchors(position);
							Ok((true, damage, anchor_destroyed, is_mainframe, None))
						} else {
							self.total_health -= damage;
							// unwrap() may seem silly, but the check is worth it
							self.health[i] = Some(NonZeroU16::new((hp - damage) as u16).unwrap());
							Ok((false, 0, false, is_mainframe, None))
						}
					}
				} else {
					Ok((false, damage, false, is_mainframe, None))
				}
			} else {
				Ok((false, damage, false, false, None))
			}
		})
	}

	#[profiled]
	pub fn destroy_disconnected_blocks(
		&mut self,
		vehicle: Ref<VehicleBody>,
		voxel_mesh: &mut VoxelMesh,
		destroyed_blocks: Vec<Voxel>,
		block_anchor_destroyed: bool,
	) -> DamageState {
		if !self.has_mainframe {
			if self.anchors.len() == 0 {
				return DamageState::BodyDestroyed;
			} else if block_anchor_destroyed {
				if !self.is_connected_to_mainframe(&mut HashSet::new(), vehicle) {
					return DamageState::BodyDestroyed;
				}
			}
		}

		const X: Voxel = Voxel::new(1, 0, 0);
		const Y: Voxel = Voxel::new(0, 1, 0);
		const Z: Voxel = Voxel::new(0, 0, 1);

		let mut destroy_blocks_list = Vec::new();
		let mut marks =
			BitArray::new(self.size.x as usize * self.size.y as usize * self.size.z as usize);
		for voxel in destroyed_blocks {
			let mut connections = Vec::new();
			let mut add_conn_fn = |direction| {
				let voxel = convert_vec(voxel.to_i32() + direction);
				if self.get_block_health(voxel) > 0 {
					connections.push(voxel);
				}
			};
			add_conn_fn(X.to_i32());
			add_conn_fn(-X.to_i32());
			add_conn_fn(Y.to_i32());
			add_conn_fn(-Y.to_i32());
			add_conn_fn(Z.to_i32());
			add_conn_fn(-Z.to_i32());
			while let Some(side_voxel) = connections.pop() {
				let index = self.get_index(side_voxel).unwrap();
				if marks
					.get(self.get_index(side_voxel).unwrap() as usize)
					.unwrap()
				{
					continue;
				}
				let anchor_found = self.mark_connected_blocks(&mut marks, side_voxel, index, false);
				if anchor_found {
					while let Some(side_voxel) = connections.pop() {
						if !marks
							.get(self.get_index(side_voxel).unwrap() as usize)
							.unwrap()
						{
							connections.push(side_voxel);
							break;
						}
					}
				} else {
					self.destroy_connected_blocks(
						&mut Some(voxel_mesh),
						side_voxel,
						index,
						&mut destroy_blocks_list,
					);
				}
			}
		}
		DamageState::BlocksDestroyed(destroy_blocks_list)
	}

	fn mark_connected_blocks(
		&self,
		marks: &mut BitArray,
		voxel: Voxel,
		index: u32,
		mut found: bool,
	) -> bool {
		debug_assert_eq!(index, self.get_index(voxel).unwrap());
		marks.set(index as usize, true).unwrap();
		if !found {
			if self.has_mainframe {
				found = self.ids[index as usize] == Some(MAINFRAME_ID);
			} else {
				found = self.anchors.contains_key(&voxel);
			}
		}
		let size = self.size;
		let cf = |x, y, z, index_offset: i32| {
			let index = index as i32 + index_offset;
			if !marks.get(index as usize).unwrap() && self.health[index as usize] != None {
				let voxel = convert_vec(voxel.to_i32() + Vector3D::new(x, y, z));
				found = self.mark_connected_blocks(marks, voxel, index as u32, found);
			}
		};
		Self::apply_to_all_sides(size, voxel, cf);
		found
	}

	fn destroy_connected_blocks(
		&mut self,
		voxel_mesh: &mut Option<&mut VoxelMesh>,
		voxel: Voxel,
		index: u32,
		destroy_blocks_list: &mut Vec<MultiBlock>,
	) {
		debug_assert_eq!(index, self.get_index(voxel).unwrap());
		debug_assert_ne!(self.health[index as usize], Some(MAINFRAME_ID));
		if let Some(voxel_mesh) = voxel_mesh {
			voxel_mesh.remove_block(voxel);
		}
		self.total_cost -= get_cached_block(self.ids[index as usize].unwrap())
			.cost
			.get();
		if let Some(hp) = self.health[index as usize] {
			let hp = hp.get();
			self.health[index as usize] = None;
			self.count -= 1;
			if hp & 0x8000 != 0 {
				let index = hp & 0x7fff;
				let block = self.multi_blocks[index as usize].take();
				if let Some(block) = block {
					self.total_health -= block.health.get() as u32;
					destroy_blocks_list.push(block)
				} else {
					godot_error!("Multi block is None but HP is not zero!");
				}
			} else {
				self.total_health -= hp as u32;
			}
		}
		let size = self.size;
		let cf = |x, y, z, index_offset: i32| {
			let index = index as i32 + index_offset;
			if self.health[index as usize] != None {
				let voxel = convert_vec(voxel.to_i32() + Vector3D::new(x, y, z));
				self.destroy_connected_blocks(voxel_mesh, voxel, index as u32, destroy_blocks_list)
			}
		};
		Self::apply_to_all_sides(size, voxel, cf);
	}

	fn apply_to_all_sides(size: Voxel, voxel: Voxel, mut f: impl FnMut(i32, i32, i32, i32)) {
		if voxel.x < size.x - 1 {
			f(1, 0, 0, size.y as i32 * size.z as i32);
		}
		if voxel.x > 0 {
			f(-1, 0, 0, -(size.y as i32 * size.z as i32));
		}
		if voxel.y < size.y - 1 {
			f(0, 1, 0, size.z as i32);
		}
		if voxel.y > 0 {
			f(0, -1, 0, -(size.z as i32));
		}
		if voxel.z < size.z - 1 {
			f(0, 0, 1, 1);
		}
		if voxel.z > 0 {
			f(0, 0, -1, -1);
		}
	}

	fn is_connected_to_mainframe(
		&self,
		marks: &mut HashSet<Ref<VehicleBody>>,
		insert: Ref<VehicleBody>,
	) -> bool {
		marks.insert(insert);
		for (_, nodes) in &self.anchors {
			for node in nodes {
				if marks.contains(&node) {
					continue;
				}
				let instance = unsafe { node.assume_safe().cast_instance::<VoxelBody>().unwrap() };
				let mut mainframe_found = false;
				instance
					.map(|s, o| {
						let body = s.body().borrow();
						if body.has_mainframe || body.is_connected_to_mainframe(marks, o.claim()) {
							mainframe_found = true;
						}
					})
					.unwrap();
				if mainframe_found {
					return true;
				}
			}
		}
		false
	}

	pub fn serialize_state(&self) -> TypedArray<i32> {
		let size = self.size.to_i32();
		let mut array = TypedArray::new();
		array.resize(size.x * size.y * size.z);
		let mut write = array.write();
		for (i, hp) in self.health.iter().enumerate() {
			if let Some(hp) = hp {
				let hp = hp.get();
				if hp & 0x8000 != 0 {
					if let Some(block) = self.multi_blocks[(hp & 0x7fff) as usize].as_ref() {
						write[i] = block.health.get() as i32;
					} else {
						godot_error!("Block is destroyed but HP is not 0!");
						write[i] = 0;
					}
				} else {
					write[i] = hp as i32;
				}
			} else {
				write[i] = 0;
			}
		}
		drop(write);
		array
	}

	pub fn offset(&self) -> Voxel {
		self.offset
	}

	pub fn size(&self) -> Voxel {
		self.size
	}

	pub fn center_of_mass(&self) -> Vector3 {
		self.center_of_mass
	}

	pub fn count(&self) -> u32 {
		self.count
	}

	pub fn max_cost(&self) -> u32 {
		self.max_cost
	}

	pub fn max_health(&self) -> u32 {
		self.max_health
	}
}

impl Block<'_> {
	pub fn id(&self) -> NonZeroU16 {
		match self {
			Block::Destroyed(id) => *id,
			Block::Single(id, _) => *id,
			Block::Multi(id, _) => *id,
		}
	}

	pub fn health(&self) -> u32 {
		match self {
			Block::Destroyed(_) => 0,
			Block::Single(_, hp) => hp.get() as u32,
			Block::Multi(_, mb) => mb.health.get(),
		}
	}
}

impl MultiBlock {
	pub fn destroy(self) {
		unsafe {
			let sn = self.server_node.assume_safe();
			let cn = self.client_node.assume_safe();
			sn.queue_free();
			cn.queue_free();
			if sn.has_method("destroy") {
				sn.call("destroy", &[]);
			}
		}
	}

	pub fn server_node(&self) -> TRef<Spatial> {
		unsafe { self.server_node.assume_safe() }
	}

	pub fn reverse_indices(&self) -> &Box<[Voxel]> {
		&self.reverse_indices
	}
}

fn add_block_to_cache(block: TRef<Resource>) -> (NonZeroU16, &'static CachedBlock) {
	unsafe {
		//godot_dbg!(block.get("id")); // Uncomment in case of panics, we may be getting a f64
		let id = block.get("id").try_to_u64().unwrap();
		let id = NonZeroU16::new(id as u16).unwrap();
		let index = id.get() as usize - 1;
		if let Some(cached) = BLOCK_COST_CACHE.get(index).and_then(Option::as_ref) {
			(id, cached)
		} else {
			let health = block.get("health").try_to_u64().unwrap() as u32;
			let cost = block.get("cost").try_to_u64().unwrap() as u32;
			let cached = CachedBlock {
				health: NonZeroU32::new(health).unwrap(),
				cost: NonZeroU32::new(cost).unwrap(),
			};
			if BLOCK_COST_CACHE.len() <= index {
				BLOCK_COST_CACHE.resize_with(index + 1, || None);
			}
			BLOCK_COST_CACHE[index] = Some(cached);
			//godot_print!("Cached block {}, cache size: {}", id, BLOCK_COST_CACHE.len());
			(id, BLOCK_COST_CACHE[index].as_ref().unwrap())
		}
	}
}

fn get_cached_block(id: NonZeroU16) -> &'static CachedBlock {
	unsafe { BLOCK_COST_CACHE[id.get() as usize - 1].as_ref().unwrap() }
}
