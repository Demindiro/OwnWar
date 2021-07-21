use crate::block;
use crate::rotation::*;
use crate::types::*;
use fxhash::{FxHashMap, FxHashSet};
use std::convert::TryInto;
use std::mem;
use std::num::NonZeroU16;

const MAX_LAYERS: usize = 255;
const MAX_COLORS: usize = 255;

/// Enum that indicates whether a position is occupied by a block or a mount point of a block
enum BlockOrMount {
	/// It's a block
	Block(Block),
	/// It's a mount point. The position points to the block
	Mount(voxel::Position),
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
	fn as_mount(&self) -> Option<&voxel::Position> {
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
	blocks: FxHashMap<voxel::Position, BlockOrMount>,
	/// The real amount of blocks.
	block_count: u32,
	pub name: String,
}

pub(crate) struct Vehicle {
	layers: Vec<Layer>,
	colors: Vec<color::RGB8>,
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

	pub fn has_block_at(&self, position: voxel::Position) -> bool {
		self.blocks.contains_key(&position)
	}

	pub fn get_block(&self, position: voxel::Position) -> Option<(&Block, voxel::Position)> {
		self.blocks.get(&position).map(|b| match b {
			BlockOrMount::Block(blk) => (blk, position),
			BlockOrMount::Mount(pos) => (self.blocks[pos].as_block().unwrap(), *pos),
		})
	}

	fn add_block(
		&mut self,
		position: voxel::Position,
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
			let d = voxel::Delta::from(d.position);
			let position = voxel::Position::new(position.x, position.y, position.z);
			if let Ok(pos) = position + rotation * d {
				if self
					.blocks
					.contains_key(&voxel::Position::new(pos.x, pos.y, pos.z))
				{
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
			let d = voxel::Delta::from(d.position);
			let pos = voxel::Position::new(position.x, position.y, position.z);
			if let Ok(pos) = pos + rotation * d {
				let pos = voxel::Position::new(pos.x, pos.y, pos.z);
				self.blocks.insert(pos, BlockOrMount::Mount(position));
			}
		}

		self.block_count += 1;

		Ok(())
	}

	fn remove_block(&mut self, position: voxel::Position) -> Option<(Block, voxel::Position)> {
		let blk_pos = self.blocks.remove(&position).map(|b| match b {
			BlockOrMount::Block(b) => (b, position),
			BlockOrMount::Mount(p) => (self.blocks.remove(&p).unwrap().into_block().unwrap(), p),
		});
		if let Some((blk, pos)) = blk_pos.as_ref() {
			let rot = blk.rotation;
			let blk = block::Block::get(blk.id).unwrap();
			for d in blk.extra_mount_points.iter() {
				let d = voxel::Delta::from(d.position);
				let pos = voxel::Position::new(pos.x, pos.y, pos.z);
				if let Ok(pos) = pos + rot * d {
					let pos = voxel::Position::new(pos.x, pos.y, pos.z);
					self.blocks.remove(&pos).map(|m| {
						m.as_mount().unwrap();
					});
				}
			}
			self.block_count -= 1;
		}
		blk_pos
	}

	pub fn iter_blocks(&self) -> impl Iterator<Item = (&voxel::Position, &Block)> {
		self.blocks
			.iter()
			.filter_map(|(p, b)| b.as_block().map(|b| (p, b)))
	}

	pub fn block_count(&self) -> u32 {
		self.block_count
	}

	pub fn aabb(&self) -> Option<voxel::AABB> {
		let start = if let Some((pos, _)) = self.blocks.iter().next() {
			*pos
		} else {
			return None;
		};
		let mut aabb = voxel::AABB::new(start, start);
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

	pub fn add_color(&mut self, color: color::RGB8) -> Result<u8, VehicleError> {
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

	pub fn change_color(&mut self, index: u8, color: color::RGB8) -> Result<(), VehicleError> {
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

	pub fn iter_colors(&self) -> impl Iterator<Item = &color::RGB8> {
		self.colors.iter()
	}

	pub fn get_color(&self, index: u8) -> Result<color::RGB8, ()> {
		self.colors.get(index as usize).map(|v| *v).ok_or(())
	}

	pub fn iter_layers(&self) -> impl Iterator<Item = &Layer> {
		self.layers.iter()
	}

	pub fn disconnected_blocks(
		&self,
		layer: u8,
	) -> Result<impl Iterator<Item = (&voxel::Position, &Block)>, VehicleError> {
		fn get_connected_blocks(
			start: voxel::Position,
			marks: &mut FxHashSet<voxel::Position>,
			remaining: &mut FxHashSet<voxel::Position>,
		) {
			/* TODO this causes an ICE, report this */
			//let gcb_wrapping = |p: voxel::Position, dx, dy, dz| {
			let gcb_wrapping =
				|p: voxel::Position, dx, dy, dz, marks: &mut _, remaining: &mut _| {
					let vp = voxel::Position::new(
						p.x.wrapping_add(dx),
						p.y.wrapping_add(dy),
						p.z.wrapping_add(dz),
					);
					let vn = voxel::Position::new(
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
			for (&pos, blk) in layer.iter_blocks() {
				remaining.insert(pos);
				let rot = blk.rotation;
				let blk = block::Block::get(blk.id).unwrap();
				for d in blk.extra_mount_points.iter() {
					let d = voxel::Delta::from(d.position);
					if let Ok(pos) = pos + rot * d {
						remaining.insert(pos);
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
		position: voxel::Position,
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
		position: voxel::Position,
	) -> Result<Option<(Block, voxel::Position)>, VehicleError> {
		Ok(self.get_layer_mut(layer)?.remove_block(position))
	}

	pub fn move_all_blocks(&mut self, by: voxel::Delta) -> Result<(), VehicleError> {
		if let Some(aabb) = self.aabb() {
			if let (Ok(_), Ok(_)) = (aabb.start + by, aabb.end + by) {
				for layer in self.layers.iter_mut() {
					let map = mem::replace(&mut layer.blocks, FxHashMap::default());
					for (pos, blk) in map
						.into_iter()
						.filter_map(|(p, b)| b.into_block().map(|b| (p, b)))
					{
						let pos = (pos + by).expect("Failed to move block");
						layer
							.add_block(pos, blk.id, blk.rotation, blk.color)
							.unwrap();
					}
				}
				Ok(())
			} else {
				return Err(VehicleError::BlockOutOfBounds);
			}
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
		position: voxel::Position,
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

	pub fn has_block_at(&self, position: voxel::Position) -> bool {
		for layer in self.layers.iter() {
			if layer.has_block_at(position) {
				return true;
			}
		}
		false
	}

	pub fn aabb(&self) -> Option<voxel::AABB> {
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
