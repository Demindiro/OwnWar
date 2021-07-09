use crate::rotation::*;
use crate::util::{convert_vec, AABB};
use fxhash::{FxHashMap, FxHashSet};
use std::convert::TryInto;
use std::mem;
use std::num::NonZeroU16;

type Vec3u8 = euclid::Vector3D<u8, euclid::UnknownUnit>;

const MAX_LAYERS: usize = 255;
const MAX_COLORS: usize = 255;

#[derive(Debug)]
pub(crate) struct Block {
	pub id: NonZeroU16,
	pub rotation: Rotation,
	pub color: u8,
}

pub(crate) struct Layer {
	/// Blocks in a **FxHashMap**. The use of a non-cryptographic hash is important for
	/// determinism! (this took me a while to figure out...)
	blocks: FxHashMap<Vec3u8, Block>,
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

impl Layer {
	fn new() -> Self {
		Self {
			blocks: FxHashMap::default(),
			name: String::new(),
		}
	}

	pub fn has_block_at(&self, position: Vec3u8) -> bool {
		self.blocks.contains_key(&position)
	}

	pub fn get_block(&self, position: Vec3u8) -> Option<&Block> {
		self.blocks.get(&position)
	}

	fn set_block(&mut self, position: Vec3u8, id: NonZeroU16, rotation: Rotation, color: u8) {
		self.blocks.insert(
			position,
			Block {
				id,
				rotation,
				color,
			},
		);
	}

	fn remove_block(&mut self, position: Vec3u8) -> Option<Block> {
		self.blocks.remove(&position)
	}

	pub fn iter_blocks(&self) -> impl Iterator<Item = (&Vec3u8, &Block)> {
		self.blocks.iter()
	}

	pub fn block_count(&self) -> u32 {
		// Literally can't happen as u8 * 3 < u32 but lets be safe...
		self.blocks
			.len()
			.try_into()
			.expect("blocks.len() overflows u32")
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
				for block in layer.blocks.values_mut() {
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
			let mut remaining = layer
				.iter_blocks()
				.map(|(&p, _)| p)
				.collect::<FxHashSet<_>>();
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
			self.layers[layer as usize].set_block(position, id, rotation, color);
			Ok(())
		}
	}

	pub fn remove_block(
		&mut self,
		layer: u8,
		position: Vec3u8,
	) -> Result<Option<Block>, VehicleError> {
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
				for (position, block) in map {
					let position = convert_vec(position) + by;
					let position = convert_vec(position);
					layer.set_block(position, block.id, block.rotation, block.color);
				}
			}
			Ok(())
		} else {
			Err(VehicleError::NoBlocks)
		}
	}

	// FIXME this can panic if a block is outside the grid_size range
	pub fn rotate_all_blocks(&mut self, grid_size: u8) {
		for layer in self.layers.iter_mut() {
			let map = mem::replace(&mut layer.blocks, FxHashMap::default());
			for (mut position, block) in map {
				(position.x, position.z) = (
					position.z,
					grid_size
						.checked_sub(position.x + 1)
						.expect("Underflow during rotation"),
				);
				let rotation = block.rotation.map_counter_clockwise();
				layer.set_block(position, block.id, rotation, block.color);
			}
		}
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
		} else if self.layers[layer as usize].has_block_at(position) {
			Err(VehicleError::PositionOccupied)
		} else {
			self.layers[layer as usize].set_block(position, id, rotation, color);
			Ok(())
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
