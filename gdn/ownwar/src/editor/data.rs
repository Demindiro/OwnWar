use crate::block;
use crate::rotation::*;
use crate::util::{convert_vec, AABB};
use fxhash::{FxHashMap, FxHashSet};
use std::convert::TryInto;
use std::mem;
use std::num::NonZeroU16;

type Vec3u8 = euclid::Vector3D<u8, euclid::UnknownUnit>;

const MAX_LAYERS: usize = 255;
const MAX_COLORS: usize = 255;

/// Enum that indicates whether a position is occupied by a block or a mount point of a block
enum BlockOrMount {
	/// It's a block
	Block(Block),
	/// It's a mount point. The position points to the block
	Mount(Vec3u8),
}

impl BlockOrMount {
	/// Return as a block if it is one.
	fn as_block(&self) -> Option<&Block> {
		if let Self::Block(b) = self {
			Some(b)
		} else {
			None
		}
	}

	/// Return as a block if it is one.
	fn as_block_mut(&mut self) -> Option<&mut Block> {
		if let Self::Block(b) = self {
			Some(b)
		} else {
			None
		}
	}

	/// Return as a block if it is one.
	fn into_block(self) -> Option<Block> {
		if let Self::Block(b) = self {
			Some(b)
		} else {
			None
		}
	}

	/// Return as a mount point if it is one.
	fn as_mount(&self) -> Option<&Vec3u8> {
		if let Self::Mount(m) = self {
			Some(m)
		} else {
			None
		}
	}
}

#[derive(Debug)]
pub(crate) struct Block {
	pub id: NonZeroU16,
	pub rotation: Rotation,
	pub color: u8,
}

pub(crate) struct Layer {
	/// Blocks in a **FxHashMap**. The use of a non-cryptographic hash is important for
	/// determinism! (this took me a while to figure out...)
	blocks: FxHashMap<Vec3u8, BlockOrMount>,
	/// The real amount of blocks.
	block_count: u32,
	pub name: String,
}

pub(crate) struct Vehicle {
	layers: Vec<Layer>,
	colors: Vec<Vec3u8>,
	pub name: String,
}

#[derive(Debug)]
pub enum VehicleError {
	ExceededMaxLayers,
	LayerOutOfBounds,
	ColorOutOfBounds,
	BlockOutOfBounds,
	PositionOccupied,
	NoBlocks,
	OnlyColor,
	HasBlocks,
}

#[derive(Debug)]
struct Occupied;

impl Layer {
	fn new() -> Self {
		Self {
			blocks: FxHashMap::default(),
			block_count: 0,
			name: String::new(),
		}
	}

	pub fn has_block_at(&self, position: Vec3u8) -> bool {
		self.blocks.contains_key(&position)
	}

	pub fn get_block(&self, position: Vec3u8) -> Option<(&Block, Vec3u8)> {
		self.blocks.get(&position).map(|b| match b {
			BlockOrMount::Block(blk) => (blk, position),
			BlockOrMount::Mount(pos) => (self.blocks[pos].as_block().unwrap(), *pos),
		})
	}

	fn add_block(
		&mut self,
		position: Vec3u8,
		id: NonZeroU16,
		rotation: Rotation,
		color: u8,
	) -> Result<(), Occupied> {
		let blk = block::Block::get(id).unwrap();

		// Checking first is less efficient but easier
		if self.blocks.contains_key(&position) {
			return Err(Occupied);
		}
		for d in blk.extra_mount_points.iter() {
			// TODO account for rotation
			let p = convert_vec::<_, isize>(position) + convert_vec::<_, isize>(*d);
			let x = p.x.try_into();
			let y = p.y.try_into();
			let z = p.z.try_into();
			if let (Ok(x), Ok(y), Ok(z)) = (x, y, z) {
				if self.blocks.contains_key(&Vec3u8::new(x, y, z)) {
					return Err(Occupied);
				}
			}
		}

		// Insert now that we know the positions aren't occupied.
		self.blocks.insert(
			position,
			BlockOrMount::Block(Block {
				id,
				rotation,
				color,
			}),
		);
		for d in blk.extra_mount_points.iter() {
			// TODO account for rotation
			let p = convert_vec::<_, isize>(position) + convert_vec::<_, isize>(*d);
			let x = p.x.try_into();
			let y = p.y.try_into();
			let z = p.z.try_into();
			if let (Ok(x), Ok(y), Ok(z)) = (x, y, z) {
				self.blocks
					.insert(Vec3u8::new(x, y, z), BlockOrMount::Mount(position));
			}
		}

		self.block_count += 1;

		Ok(())
	}

	fn remove_block(&mut self, position: Vec3u8) -> Option<(Block, Vec3u8)> {
		let blk_pos = self.blocks.remove(&position).map(|b| match b {
			BlockOrMount::Block(b) => (b, position),
			BlockOrMount::Mount(p) => (self.blocks.remove(&p).unwrap().into_block().unwrap(), p),
		});
		if let Some((blk, pos)) = blk_pos.as_ref() {
			let blk = block::Block::get(blk.id).unwrap();
			for d in blk.extra_mount_points.iter() {
				// TODO account for rotation
				let p = convert_vec::<_, isize>(*pos) + convert_vec::<_, isize>(*d);
				let x = p.x.try_into();
				let y = p.y.try_into();
				let z = p.z.try_into();
				if let (Ok(x), Ok(y), Ok(z)) = (x, y, z) {
					self.blocks.remove(&Vec3u8::new(x, y, z)).map(|m| {
						m.as_mount().unwrap();
					});
				}
			}
			self.block_count -= 1;
		}
		blk_pos
	}

	pub fn iter_blocks(&self) -> impl Iterator<Item = (&Vec3u8, &Block)> {
		self.blocks
			.iter()
			.filter_map(|(p, b)| b.as_block().map(|b| (p, b)))
	}

	pub fn block_count(&self) -> u32 {
		self.block_count
	}

	pub fn aabb(&self) -> Option<AABB<u8>> {
		let start = if let Some((pos, _)) = self.blocks.iter().next() {
			*pos
		} else {
			return None;
		};
		let mut aabb = AABB::new(start, Vec3u8::zero());
		for (&position, _) in self.blocks.iter() {
			aabb = aabb.expand(position);
		}
		Some(aabb)
	}
}

impl Vehicle {
	pub fn new() -> Self {
		Self {
			layers: Vec::new(),
			colors: Vec::new(),
			name: String::new(),
		}
	}

	pub fn add_layer(&mut self) -> Result<u8, VehicleError> {
		if self.layers.len() < MAX_LAYERS {
			let index = self.layers.len() as u8;
			self.layers.push(Layer::new());
			Ok(index)
		} else {
			Err(VehicleError::ExceededMaxLayers)
		}
	}

	pub fn remove_layer(&mut self, index: u8, force: bool) -> Result<(), VehicleError> {
		if let Some(layer) = self.layers.get(index as usize) {
			if force || layer.blocks.len() == 0 {
				self.layers.remove(index as usize);
				Ok(())
			} else {
				Err(VehicleError::HasBlocks)
			}
		} else {
			Err(VehicleError::LayerOutOfBounds)
		}
	}

	pub fn get_layer(&self, index: u8) -> Result<&Layer, VehicleError> {
		self.layers
			.get(index as usize)
			.ok_or(VehicleError::LayerOutOfBounds)
	}

	fn get_layer_mut(&mut self, index: u8) -> Result<&mut Layer, VehicleError> {
		self.layers
			.get_mut(index as usize)
			.ok_or(VehicleError::LayerOutOfBounds)
	}

	pub fn set_layer_name<T>(&mut self, index: u8, name: T) -> Result<(), VehicleError>
	where
		T: Into<String>,
	{
		self.get_layer_mut(index)?.name = name.into();
		Ok(())
	}

	pub fn add_color(&mut self, color: Vec3u8) -> Result<u8, VehicleError> {
		if self.colors.len() < MAX_COLORS {
			let index = self.colors.len() as u8;
			self.colors.push(color);
			Ok(index)
		} else {
			Err(VehicleError::ColorOutOfBounds)
		}
	}

	pub fn remove_color(&mut self, index: u8) -> Result<(), VehicleError> {
		if index as usize >= self.colors.len() {
			Err(VehicleError::ColorOutOfBounds)
		} else if self.colors.len() <= 1 {
			Err(VehicleError::OnlyColor)
		} else {
			self.colors.remove(index as usize);
			for layer in self.layers.iter_mut() {
				for block in layer
					.blocks
					.values_mut()
					.filter_map(BlockOrMount::as_block_mut)
				{
					if block.color == index {
						block.color = 0;
					} else if block.color > index {
						block.color -= 1;
					}
				}
			}
			Ok(())
		}
	}

	pub fn change_color(&mut self, index: u8, color: Vec3u8) -> Result<(), VehicleError> {
		self.colors
			.get_mut(index as usize)
			.map(|v| *v = color)
			.ok_or(VehicleError::ColorOutOfBounds)
	}

	pub fn color_count(&self) -> u8 {
		self.colors
			.len()
			.try_into()
			.expect("colors.len() overflows u8")
	}

	pub fn iter_colors(&self) -> impl Iterator<Item = &Vec3u8> {
		self.colors.iter()
	}

	pub fn get_color(&self, index: u8) -> Result<Vec3u8, ()> {
		self.colors.get(index as usize).map(|v| *v).ok_or(())
	}

	pub fn iter_layers(&self) -> impl Iterator<Item = &Layer> {
		self.layers.iter()
	}

	pub fn disconnected_blocks(
		&self,
		layer: u8,
	) -> Result<impl Iterator<Item = (&Vec3u8, &Block)>, VehicleError> {
		fn get_connected_blocks(
			start: Vec3u8,
			marks: &mut FxHashSet<Vec3u8>,
			remaining: &mut FxHashSet<Vec3u8>,
		) {
			/* TODO this causes an ICE, report this */
			//let gcb_wrapping = |p: Vec3u8, dx, dy, dz| {
			let gcb_wrapping = |p: Vec3u8, dx, dy, dz, marks: &mut _, remaining: &mut _| {
				let vp = Vec3u8::new(
					p.x.wrapping_add(dx),
					p.y.wrapping_add(dy),
					p.z.wrapping_add(dz),
				);
				let vn = Vec3u8::new(
					p.x.wrapping_sub(dx),
					p.y.wrapping_sub(dy),
					p.z.wrapping_sub(dz),
				);
				get_connected_blocks(vp, marks, remaining);
				get_connected_blocks(vn, marks, remaining);
			};
			if remaining.contains(&start) {
				marks.insert(start);
				remaining.remove(&start);
				gcb_wrapping(start, 1, 0, 0, marks, remaining);
				gcb_wrapping(start, 0, 1, 0, marks, remaining);
				gcb_wrapping(start, 0, 0, 1, marks, remaining);
			}
		}
		let layer = self.get_layer(layer)?;
		let marks = if layer.block_count() == 0 {
			FxHashSet::default()
		} else {
			// Make a map with all remaining blocks.
			let mut remaining = FxHashSet::default();
			for (&p, blk) in layer.iter_blocks() {
				remaining.insert(p);
				let blk = block::Block::get(blk.id).unwrap();
				for &d in blk.extra_mount_points.iter() {
					// TODO account for rotation
					let p = convert_vec::<_, isize>(p) + convert_vec::<_, isize>(d);
					let x = p.x.try_into();
					let y = p.y.try_into();
					let z = p.z.try_into();
					if let (Ok(x), Ok(y), Ok(z)) = (x, y, z) {
						remaining.insert(Vec3u8::new(x, y, z));
					}
				}
			}

			let mut marks = Vec::new();
			while remaining.len() > 0 {
				let mut m = FxHashSet::default();
				for &p in remaining.iter() {
					get_connected_blocks(p, &mut m, &mut remaining);
					break;
				}
				marks.push(m);
			}
			let mut m = marks.pop().expect("No elements in marks");
			for e in marks {
				if m.len() < e.len() {
					m = e;
				}
			}
			m
		};

		Ok(layer.iter_blocks().filter(move |(p, _)| !marks.contains(p)))
	}

	pub fn add_block(
		&mut self,
		layer: u8,
		position: Vec3u8,
		id: NonZeroU16,
		rotation: Rotation,
		color: u8,
	) -> Result<(), VehicleError> {
		if self.layer_count() <= layer {
			Err(VehicleError::LayerOutOfBounds)
		} else if self.colors.len() <= color as usize {
			Err(VehicleError::ColorOutOfBounds)
		} else if self.has_block_at(position) {
			Err(VehicleError::PositionOccupied)
		} else {
			self.layers[layer as usize]
				.add_block(position, id, rotation, color)
				.map_err(|_| VehicleError::PositionOccupied)
		}
	}

	pub fn remove_block(
		&mut self,
		layer: u8,
		position: Vec3u8,
	) -> Result<Option<(Block, Vec3u8)>, VehicleError> {
		Ok(self.get_layer_mut(layer)?.remove_block(position))
	}

	pub fn move_all_blocks(
		&mut self,
		by: euclid::Vector3D<i32, euclid::UnknownUnit>,
	) -> Result<(), VehicleError> {
		if let Some(aabb) = self.aabb().map(|v| v.convert()) {
			let (s, e) = (aabb.position, aabb.end());
			let (s, e) = (s + by, e + by);
			if s.x < 0 || s.y < 0 || s.z < 0 || e.x > 255 || e.y > 255 || e.z > 255 {
				return Err(VehicleError::BlockOutOfBounds);
			}
			for layer in self.layers.iter_mut() {
				let map = mem::replace(&mut layer.blocks, FxHashMap::default());
				for (pos, blk) in map
					.into_iter()
					.filter_map(|(p, b)| b.into_block().map(|b| (p, b)))
				{
					let pos = convert_vec(pos) + by;
					let pos = convert_vec(pos);
					layer
						.add_block(pos, blk.id, blk.rotation, blk.color)
						.unwrap();
				}
			}
			Ok(())
		} else {
			Err(VehicleError::NoBlocks)
		}
	}

	// FIXME this can panic if a block is outside the grid_size range
	pub fn rotate_all_blocks(&mut self, grid_size: u8) -> Result<(), VehicleError> {
		// FIXME do an AABB check before rotating
		for layer in self.layers.iter_mut() {
			let map = mem::replace(&mut layer.blocks, FxHashMap::default());
			for (mut position, block) in map
				.into_iter()
				.filter_map(|(p, b)| b.into_block().map(|b| (p, b)))
			{
				(position.x, position.z) = (
					position.z,
					grid_size
						.checked_sub(position.x + 1)
						.expect("Underflow during rotation"),
				);
				let rotation = block.rotation.map_counter_clockwise();
				layer
					.add_block(position, block.id, rotation, block.color)
					.unwrap();
			}
		}

		Ok(())
	}

	pub fn layer_count(&self) -> u8 {
		self.layers
			.len()
			.try_into()
			.expect("layers.len() overflows u8")
	}

	pub fn add_block_with_overlap(
		&mut self,
		layer: u8,
		position: Vec3u8,
		id: NonZeroU16,
		rotation: Rotation,
		color: u8,
	) -> Result<(), VehicleError> {
		if self.layers.len() <= layer as usize {
			Err(VehicleError::LayerOutOfBounds)
		} else if self.colors.len() <= color as usize {
			Err(VehicleError::ColorOutOfBounds)
		} else {
			self.layers[layer as usize]
				.add_block(position, id, rotation, color)
				.map_err(|_| VehicleError::PositionOccupied)
		}
	}

	pub fn has_block_at(&self, position: Vec3u8) -> bool {
		for layer in self.layers.iter() {
			if layer.has_block_at(position) {
				return true;
			}
		}
		false
	}

	pub fn aabb(&self) -> Option<AABB<u8>> {
		let mut aabb = None;
		for layer in self.iter_layers() {
			aabb = layer
				.aabb()
				.map(|v| aabb.map(|u| v.union(u)).or(Some(v)))
				.or(Some(aabb))
				.flatten();
		}
		aabb
	}
}
