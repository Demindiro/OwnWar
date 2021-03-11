use std::collections::HashMap;
use std::convert::TryInto;
use std::num::NonZeroU16;

type Vec3u8 = euclid::Vector3D<u8, euclid::UnknownUnit>;

const MAX_LAYERS: usize = 255;
const MAX_COLORS: usize = 255;

#[derive(Debug)]
pub(crate) struct Block {
	pub id: NonZeroU16,
	pub rotation: u8,
	pub color: u8,
}

pub(crate) struct Layer {
	blocks: HashMap<Vec3u8, Block>,
	pub name: String,
}

pub(crate) struct Vehicle {
	layers: Vec<Layer>,
	colors: Vec<Vec3u8>,
	pub name: String,
	valid: bool,
}

#[derive(Debug)]
pub struct VehicleError(VehicleErrorKind);

#[derive(Debug)]
enum VehicleErrorKind {
	ExceededMaxLayers,
	LayerOutOfBounds,
	ColorOutOfBounds,
	PositionOccupied,
}

impl Layer {
	fn new() -> Self {
		Self {
			blocks: HashMap::new(),
			name: String::new(),
		}
	}

	fn has_block_at(&self, position: Vec3u8) -> bool {
		self.blocks.contains_key(&position)
	}

	pub fn get_block(&self, position: Vec3u8) -> Option<&Block> {
		self.blocks.get(&position)
	}

	fn set_block(&mut self, position: Vec3u8, id: NonZeroU16, rotation: u8, color: u8) {
		self.blocks.insert(
			position,
			Block {
				id,
				rotation,
				color,
			},
		);
	}

	pub fn iter_blocks(&self) -> impl Iterator<Item = (&Vec3u8, &Block)> {
		self.blocks.iter()
	}

	pub fn aabb(&self) -> Option<crate::util::AABB<u8>> {
		use crate::util::AABB;
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
			valid: false,
		}
	}

	pub fn add_layer(&mut self) -> Result<u8, VehicleError> {
		if self.layers.len() < MAX_LAYERS {
			let index = self.layers.len() as u8;
			self.layers.push(Layer::new());
			Ok(index)
		} else {
			Err(VehicleError(VehicleErrorKind::ExceededMaxLayers))
		}
	}

	pub fn remove_layer(&mut self, index: u8) -> Result<(), VehicleError> {
		if self.layers.len() >= index as usize {
			self.layers.swap_remove(index as usize);
			Ok(())
		} else {
			Err(VehicleError(VehicleErrorKind::LayerOutOfBounds))
		}
	}

	pub fn get_layer(&self, index: u8) -> Result<&Layer, VehicleError> {
		if self.layers.len() > index as usize {
			Ok(&self.layers[index as usize])
		} else {
			Err(VehicleError(VehicleErrorKind::LayerOutOfBounds))
		}
	}


	pub fn set_layer_name(&mut self, index: u8, name: String) -> Result<(), VehicleError> {
		if let Some(layer) = self.layers.get_mut(index as usize) {
			layer.name = name;
			Ok(())
		} else {
			Err(VehicleError(VehicleErrorKind::LayerOutOfBounds))
		}
	}

	pub fn add_color(&mut self, color: Vec3u8) -> Result<u8, VehicleError> {
		if self.colors.len() < MAX_COLORS {
			let index = self.colors.len() as u8;
			self.colors.push(color);
			Ok(index)
		} else {
			Err(VehicleError(VehicleErrorKind::ColorOutOfBounds))
		}
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

	pub fn add_block(
		&mut self,
		layer: u8,
		position: Vec3u8,
		id: NonZeroU16,
		rotation: u8,
		color: u8,
	) -> Result<(), VehicleError> {
		if self.layers.len() <= layer as usize {
			Err(VehicleError(VehicleErrorKind::LayerOutOfBounds))
		} else if self.colors.len() <= color as usize {
			Err(VehicleError(VehicleErrorKind::ColorOutOfBounds))
		} else if self.has_block_at(position) {
			Err(VehicleError(VehicleErrorKind::PositionOccupied))
		} else {
			self.layers[layer as usize].set_block(position, id, rotation, color);
			Ok(())
		}
	}

	pub fn get_block(&self, position: Vec3u8) -> Option<(u8, &Block)> {
		for (i, layer) in self.layers.iter().enumerate() {
			if let Some(block) = layer.get_block(position) {
				return Some((i as u8, block));
			}
		}
		None
	}

	pub fn get_blocks(&self, position: Vec3u8) -> Vec<(u8, &Block)> {
		let mut vec = Vec::new();
		for (i, layer) in self.layers.iter().enumerate() {
			if let Some(block) = layer.get_block(position) {
				vec.push((i as u8, block));
			}
		}
		vec
	}

	pub fn block_count(&self) -> u32 {
		let mut sum = 0;
		for layer in self.layers.iter() {
			sum += layer.blocks.len() as u32;
		}
		sum
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
		rotation: u8,
		color: u8,
	) -> Result<(), VehicleError> {
		if self.layers.len() <= layer as usize {
			Err(VehicleError(VehicleErrorKind::LayerOutOfBounds))
		} else if self.colors.len() <= color as usize {
			Err(VehicleError(VehicleErrorKind::ColorOutOfBounds))
		} else if self.layers[layer as usize].has_block_at(position) {
			Err(VehicleError(VehicleErrorKind::PositionOccupied))
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
}
