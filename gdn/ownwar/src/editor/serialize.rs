use super::data::Vehicle;
use crate::rotation::Rotation;
use crate::types::*;
use core::convert::{TryFrom, TryInto};
use core::fmt;
use core::num::NonZeroU16;
use core::str::Utf8Error;
use gdnative::godot_error;

const MAGIC: u32 = 493279249;

#[derive(Debug)]
pub(crate) enum LoadError {
	BadMagic,
	UnknownRevision,
	CorruptDataTruncated,
	InvalidBlockID,
	PositionAlreadyOccupied,
	ParseUtf8Error(Utf8Error),
}

#[derive(Debug)]
pub(crate) struct SaveError();

impl fmt::Display for LoadError {
	fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
		match self {
			Self::BadMagic => "bad magic".fmt(f),
			Self::UnknownRevision => "unknown revision".fmt(f),
			Self::CorruptDataTruncated => "truncated data".fmt(f),
			Self::InvalidBlockID => "invalid block ID".fmt(f),
			Self::PositionAlreadyOccupied => "position already occupied".fmt(f),
			Self::ParseUtf8Error(e) => write!(f, "{}", e),
		}
	}
}

pub(crate) fn load(data: &[u8]) -> Result<Vehicle, LoadError> {
	let (data, magic) = read_u32(data)?;
	if magic != MAGIC {
		return Err(LoadError::BadMagic);
	}

	let (data, revision) = read_u16(data)?;
	// Update as appropriate
	match revision {
		rev_0::REVISION => rev_0::load(data),
		rev_1::REVISION => rev_1::load(data),
		_ => Err(LoadError::UnknownRevision),
	}
}

pub(crate) fn save(vehicle: &Vehicle) -> Result<Vec<u8>, LoadError> {
	// Update to rev_* as appropriate
	use rev_1::*;
	let mut data = Vec::new();
	data.extend_from_slice(&MAGIC.to_le_bytes());
	data.extend_from_slice(&REVISION.to_le_bytes());
	data.append(&mut save(vehicle)?);
	Ok(data)
}

fn read_u8(data: &[u8]) -> Result<(&[u8], u8), LoadError> {
	if let Some(&s) = data.get(0) {
		Ok((&data[1..], s))
	} else {
		Err(LoadError::CorruptDataTruncated)
	}
}

fn read_u16(data: &[u8]) -> Result<(&[u8], u16), LoadError> {
	if let Some(s) = data.get(0..2) {
		Ok((&data[2..], u16::from_le_bytes(s.try_into().unwrap())))
	} else {
		Err(LoadError::CorruptDataTruncated)
	}
}

fn read_u32(data: &[u8]) -> Result<(&[u8], u32), LoadError> {
	if let Some(s) = data.get(0..4) {
		Ok((&data[4..], u32::from_le_bytes(s.try_into().unwrap())))
	} else {
		Err(LoadError::CorruptDataTruncated)
	}
}

fn read_position(data: &[u8]) -> Result<(&[u8], voxel::Position), LoadError> {
	let (data, x) = read_u8(data)?;
	let (data, y) = read_u8(data)?;
	let (data, z) = read_u8(data)?;
	Ok((data, voxel::Position::new(x, y, z)))
}

fn read_color(data: &[u8]) -> Result<(&[u8], color::RGB8), LoadError> {
	let (data, r) = read_u8(data)?;
	let (data, g) = read_u8(data)?;
	let (data, b) = read_u8(data)?;
	Ok((data, color::RGB8::new(r, g, b)))
}

fn read_u8_str(data: &[u8]) -> Result<(&[u8], &str), LoadError> {
	let (data, len) = read_u8(data)?;
	if data.len() < len as usize {
		Err(LoadError::CorruptDataTruncated)
	} else {
		let (string, data) = data.split_at(len as usize);
		match std::str::from_utf8(string) {
			Ok(s) => Ok((data, s)),
			Err(e) => Err(LoadError::ParseUtf8Error(e)),
		}
	}
}

mod rev_1 {

	use super::*;
	use crate::util::iter_3d_inclusive;

	enum Attribute {
		LayerNames,
		AuthorName,
		Description,
		Tags,
	}

	impl Attribute {
		fn to_int(&self) -> u8 {
			use Attribute::*;
			match self {
				LayerNames => 0,
				AuthorName => 1,
				Description => 2,
				Tags => 3,
			}
		}

		fn from_int(value: u8) -> Option<Self> {
			use Attribute::*;
			Some(match value {
				0 => LayerNames,
				1 => AuthorName,
				2 => Description,
				3 => Tags,
				_ => return None,
			})
		}
	}

	pub(super) const REVISION: u16 = 1;

	pub(super) fn load(data: &[u8]) -> Result<Vehicle, LoadError> {
		let (data, _block_data_size) = read_u32(data)?;
		let (data, _editor_data_size) = read_u32(data)?;
		let (data, name) = read_u8_str(data)?;
		let (data, color_count) = read_u8(data)?;
		let (data, layer_count) = read_u8(data)?;

		let mut vehicle = Vehicle::new();
		vehicle.name = String::from(name);
		let mut data = data;

		for _ in 0..color_count {
			let mut color = color::RGB8::BLACK;
			(data, color.r) = read_u8(data)?;
			(data, color.g) = read_u8(data)?;
			(data, color.b) = read_u8(data)?;
			vehicle.add_color(color).expect("Failed to add color");
		}

		for _ in 0..layer_count {
			let layer = vehicle.add_layer().expect("Failed to add layer");
			let (mut s, mut e) = ((0, 0, 0), (0, 0, 0));
			(data, s.0) = read_u8(data)?;
			(data, s.1) = read_u8(data)?;
			(data, s.2) = read_u8(data)?;
			(data, e.0) = read_u8(data)?;
			(data, e.1) = read_u8(data)?;
			(data, e.2) = read_u8(data)?;
			for (x, y, z) in iter_3d_inclusive(s, e) {
				let id;
				(data, id) = read_u16(data)?;
				if let Some(id) = NonZeroU16::new(id) {
					let (rotation, color);
					(data, rotation) = read_u8(data)?;
					(data, color) = read_u8(data)?;
					// TODO don't unwrap, handle the error properly
					let rotation = Rotation::new(rotation).unwrap();
					match vehicle.add_block(
						layer,
						voxel::Position::new(x, y, z),
						id,
						rotation,
						color,
					) {
						Ok(()) => (),
						Err(e) => godot_error!("Failed to add block: {:?}", e),
					}
				}
			}
		}

		let (data, attribute_count) = read_u8(data)?;
		let mut data = data;
		for _ in 0..attribute_count {
			let (attribute, len);
			(data, attribute) = read_u8(data)?;
			(data, len) = read_u16(data)?;
			if data.len() < len as usize {
				return Err(LoadError::CorruptDataTruncated);
			}
			if let Some(attribute) = Attribute::from_int(attribute) {
				use Attribute::*;
				match attribute {
					LayerNames => {
						let mut attr_data;
						(attr_data, data) = data.split_at(len as usize);
						for i in 0..layer_count {
							let name;
							(attr_data, name) = read_u8_str(attr_data)?;
							vehicle.set_layer_name(i, String::from(name)).unwrap();
						}
					}
					AuthorName => {
						// TODO
					}
					Description => {
						// TODO
					}
					Tags => {
						// TODO
					}
				}
			} else {
				// TODO somehow log that an invalid attribute snuck in
				debug_assert!(false, "Invalid attribute");
			}
		}

		Ok(vehicle)
	}

	pub(super) fn save(vehicle: &Vehicle) -> Result<Vec<u8>, LoadError> {
		let mut block_data = Vec::new();
		block_data.push(vehicle.color_count());
		block_data.push(vehicle.layer_count());
		for color in vehicle.iter_colors() {
			block_data.push(color.r);
			block_data.push(color.g);
			block_data.push(color.b);
		}
		for layer in vehicle.iter_layers() {
			if let Some(aabb) = layer.aabb() {
				let (s, e) = (aabb.start, aabb.end);
				block_data.extend(&[s.x, s.y, s.z, e.x, e.y, e.z]);
				for pos in iter_3d_inclusive(s.into(), e.into()).map(voxel::Position::from) {
					if let Some((block, p)) = layer.get_block(pos) {
						// Make sure we don't add a multiblock twice
						if pos == p {
							block_data.extend(&block.id.get().to_le_bytes());
							block_data.push(block.rotation.get());
							block_data.push(block.color);
							continue;
						}
					}
					block_data.extend(&0u16.to_le_bytes());
				}
			} else {
				// Insert a 1x1x1 layer with a None block
				block_data.extend(&[0; 6]);
				block_data.extend(&0u16.to_le_bytes());
			}
		}

		let mut editor_data = Vec::new();
		editor_data.push(4);
		{
			let mut data = Vec::new();
			for layer in vehicle.iter_layers() {
				let name = if layer.name.len() < 256 {
					&layer.name[..]
				} else {
					&layer.name[0..255]
				};
				data.push(name.len() as u8);
				data.extend(name.bytes());
			}
			editor_data.push(Attribute::LayerNames.to_int());
			editor_data.extend(
				&u16::try_from(data.len())
					.expect("Layer names data overflows u16")
					.to_le_bytes(),
			);
			editor_data.append(&mut data);
		}
		{
			editor_data.push(Attribute::Tags.to_int());
			editor_data.extend(&0u16.to_le_bytes());
		}
		{
			editor_data.push(Attribute::AuthorName.to_int());
			editor_data.extend(&0u16.to_le_bytes());
		}
		{
			editor_data.push(Attribute::Description.to_int());
			editor_data.extend(&0u16.to_le_bytes());
		}

		let name = if vehicle.name.len() < 256 {
			&vehicle.name[..]
		} else {
			&vehicle.name[..255]
		};
		let mut data = Vec::new();
		data.extend(
			&u32::try_from(block_data.len())
				.expect("Block data too long")
				.to_le_bytes(),
		);
		data.extend(
			&u32::try_from(editor_data.len())
				.expect("Editor data too long")
				.to_le_bytes(),
		);
		data.push(
			name.len()
				.try_into()
				.expect("Name too long (should be truncated)"),
		);
		data.extend(name.bytes());
		data.append(&mut block_data);
		data.append(&mut editor_data);
		Ok(data)
	}
}

mod rev_0 {

	use super::*;
	use std::collections::HashMap;
	use std::num::NonZeroU16;

	pub(super) const REVISION: u16 = 0;

	pub(super) fn load(data: &[u8]) -> Result<Vehicle, LoadError> {
		let mut vehicle = Vehicle::new();
		let mut color_map = HashMap::new();
		let (mut data, layer_count) = read_u8(data)?;
		for _ in 0..layer_count {
			let (_layer, _start, _end, size);
			(data, _layer) = read_u8(data)?;
			let layer = vehicle.add_layer().unwrap();
			// A name is not necessary, but it's nice to have
			vehicle
				.set_layer_name(layer, format!("Layer {}", layer))
				.unwrap();
			(data, _start) = read_position(data)?;
			(data, _end) = read_position(data)?;
			(data, size) = read_u32(data)?;
			for _ in 0..size {
				let (position, id, rotation, color);
				(data, position) = read_position(data)?;
				(data, id) = read_u16(data)?;
				(data, rotation) = read_u8(data)?;
				(data, color) = read_color(data)?;
				let id = if let Some(id) = NonZeroU16::new(id) {
					id
				} else {
					return Err(LoadError::InvalidBlockID);
				};
				let color = *color_map
					.entry(color)
					// Silently discard extraneous colors to make sure the vehicle still loads
					// Having more than 256 colors is valid in this revision
					.or_insert_with(|| vehicle.add_color(color).unwrap_or(0));
				// TODO don't unwrap
				let rotation = Rotation::new(rotation).unwrap();
				// Note that overlap only refers to overlapping _layers_, not overlap within the same layer
				if vehicle
					.add_block_with_overlap(layer, position, id, rotation, color)
					.is_err()
				{
					// TODO properly detect the actual error
					return Err(LoadError::PositionAlreadyOccupied);
				}
			}
		}
		Ok(vehicle)
	}
}

#[cfg(test)]
mod tests {
	use super::*;
	use crate::util::iter_3d;

	mod save_and_load {
		use super::*;
		#[test]
		fn cube_1x1x1() {
			let name = "Cube";
			let layer_name = "Layer 0";
			let color = voxel::Position::new(255, 255, 255);
			let id = NonZeroU16::new(1).unwrap();
			let rotation = Rotation::default();
			let position = voxel::Position::new(5, 2, 9);

			let mut vehicle = Vehicle::new();
			vehicle.name = String::from(name);
			let layer_id = vehicle.add_layer().unwrap();
			let color_id = vehicle.add_color(color).unwrap();
			vehicle
				.set_layer_name(layer_id, String::from(layer_name))
				.unwrap();
			vehicle
				.add_block(layer_id, position, id, rotation, color_id)
				.unwrap();

			let data = save(&vehicle).unwrap();
			let vehicle = load(&data).unwrap();

			assert_eq!(vehicle.name, name);
			assert_eq!(vehicle.layer_count(), 1);
			assert_eq!(vehicle.color_count(), 1);
			assert_eq!(vehicle.block_count(), 1);
			assert_eq!(vehicle.get_color(0).unwrap(), color);
			let layer = vehicle.iter_layers().next().unwrap();
			let block = layer.get_block(position).unwrap();
			assert_eq!(block.id, id);
			assert_eq!(block.rotation, rotation);
			assert_eq!(layer.name, layer_name);
		}

		#[test]
		fn cube_3x3x3() {
			let name = "Cube";
			let layer_name = "Layer 0";
			let color = color::RGB8::new(255, 255, 255);
			let id = NonZeroU16::new(1).unwrap();
			let rotation = Rotation::default();
			let position = voxel::Position::new(5, 2, 9);

			let mut vehicle = Vehicle::new();
			vehicle.name = String::from(name);
			let layer_id = vehicle.add_layer().unwrap();
			let color_id = vehicle.add_color(color).unwrap();
			vehicle
				.set_layer_name(layer_id, String::from(layer_name))
				.unwrap();
			for (x, y, z) in iter_3d((0, 0, 0), (3, 3, 3)) {
				vehicle
					.add_block(
						layer_id,
						position + voxel::Position::new(x, y, z),
						id,
						rotation,
						color_id,
					)
					.unwrap();
			}

			let data = save(&vehicle).unwrap();
			let vehicle = load(&data).unwrap();

			assert_eq!(vehicle.name, name);
			assert_eq!(vehicle.layer_count(), 1);
			assert_eq!(vehicle.color_count(), 1);
			assert_eq!(vehicle.block_count(), 27);
			assert_eq!(vehicle.get_color(0).unwrap(), color);
			let layer = vehicle.iter_layers().next().unwrap();
			for (x, y, z) in iter_3d((0, 0, 0), (3, 3, 3)) {
				let block = layer
					.get_block(position + voxel::Position::new(x, y, z))
					.unwrap();
				assert_eq!(block.id, id);
				assert_eq!(block.rotation, rotation);
				assert_eq!(layer.name, layer_name);
			}
		}

		#[test]
		fn cube_3x3x3_layered() {
			let name = "Cube";
			let layer_name = "Layer";
			let color = voxel::Position::new(255, 255, 255);
			let id = NonZeroU16::new(1).unwrap();
			let rotation = Rotation::default();
			let position = voxel::Position::new(5, 2, 9);

			let mut vehicle = Vehicle::new();
			vehicle.name = String::from(name);
			let color_id = vehicle.add_color(color).unwrap();
			for (x, y, z) in iter_3d((0, 0, 0), (3, 3, 3)) {
				let layer_id = vehicle.add_layer().unwrap();
				vehicle
					.set_layer_name(layer_id, format!("{} {:?}", layer_name, (x, y, z)))
					.unwrap();
				vehicle
					.add_block(
						layer_id,
						position + voxel::Position::new(x, y, z),
						id,
						rotation,
						color_id,
					)
					.unwrap();
			}

			let data = save(&vehicle).unwrap();
			let vehicle = load(&data).unwrap();

			assert_eq!(vehicle.name, name);
			assert_eq!(vehicle.layer_count(), 27);
			assert_eq!(vehicle.color_count(), 1);
			assert_eq!(vehicle.block_count(), 27);
			assert_eq!(vehicle.get_color(0).unwrap(), color);
			for (x, y, z) in iter_3d((0, 0, 0), (3, 3, 3)) {
				let blocks = vehicle.get_blocks(position + voxel::Position::new(x, y, z));
				assert_eq!(blocks.len(), 1);
				assert_eq!(blocks[0].1.id, id);
				assert_eq!(blocks[0].1.rotation, rotation);
				let layer = vehicle.get_layer(blocks[0].0).unwrap();
				assert_eq!(layer.name, format!("{} {:?}", layer_name, (x, y, z)));
			}
		}

		#[test]
		fn cube_3x3x3_colored() {
			let name = "Cube";
			let layer_name = "Layer";
			let id = NonZeroU16::new(1).unwrap();
			let rotation = Rotation::default();
			let position = voxel::Position::new(5, 2, 9);

			let mut vehicle = Vehicle::new();
			vehicle.name = String::from(name);
			let layer_id = vehicle.add_layer().unwrap();
			vehicle
				.set_layer_name(layer_id, String::from(layer_name))
				.unwrap();
			for (x, y, z) in iter_3d((0, 0, 0), (3, 3, 3)) {
				let color_id = vehicle
					.add_color(voxel::Position::new(x * 80, y * 80, z * 80))
					.unwrap();
				vehicle
					.add_block(
						layer_id,
						position + voxel::Position::new(x, y, z),
						id,
						rotation,
						color_id,
					)
					.unwrap();
			}

			let data = save(&vehicle).unwrap();
			let vehicle = load(&data).unwrap();

			assert_eq!(vehicle.name, name);
			assert_eq!(vehicle.layer_count(), 1);
			assert_eq!(vehicle.color_count(), 27);
			assert_eq!(vehicle.block_count(), 27);
			let layer = vehicle.iter_layers().next().unwrap();
			for (x, y, z) in iter_3d((0, 0, 0), (3, 3, 3)) {
				let blocks = vehicle.get_blocks(position + voxel::Position::new(x, y, z));
				assert_eq!(blocks.len(), 1);
				assert_eq!(blocks[0].1.id, id);
				assert_eq!(blocks[0].1.rotation, rotation);
				let color = vehicle.get_color(blocks[0].1.color).unwrap();
				assert_eq!(color, voxel::Position::new(x * 80, y * 80, z * 80));
				assert_eq!(layer.name, layer_name);
			}
		}

		#[test]
		fn cube_3x3x3_checkered() {
			let name = "Cube";
			let layer_name = "Layer";
			let id = NonZeroU16::new(1).unwrap();
			let rotation = Rotation::default();
			let position = voxel::Position::new(5, 2, 9);
			let color = voxel::Position::new(255, 0, 255);

			let mut vehicle = Vehicle::new();
			vehicle.name = String::from(name);
			let layer_id = vehicle.add_layer().unwrap();
			vehicle
				.set_layer_name(layer_id, String::from(layer_name))
				.unwrap();
			let color_id = vehicle.add_color(color).unwrap();
			for (x, y, z) in iter_3d((0, 0, 0), (3, 3, 3)) {
				if (x + y + z) % 2 == 0 {
					continue;
				}
				vehicle
					.add_block(
						layer_id,
						position + voxel::Position::new(x, y, z),
						id,
						rotation,
						color_id,
					)
					.unwrap();
			}

			let data = save(&vehicle).unwrap();
			let vehicle = load(&data).unwrap();

			assert_eq!(vehicle.name, name);
			assert_eq!(vehicle.layer_count(), 1);
			assert_eq!(vehicle.color_count(), 1);
			assert_eq!(vehicle.block_count(), 13); // 4 on each side, 5 in middle = 13
			assert_eq!(vehicle.get_color(0).unwrap(), color);
			let layer = vehicle.iter_layers().next().unwrap();
			assert_eq!(layer.name, layer_name);
			for (x, y, z) in iter_3d((0, 0, 0), (3, 3, 3)) {
				let blocks = vehicle.get_blocks(position + voxel::Position::new(x, y, z));
				if (x + y + z) % 2 == 0 {
					assert_eq!(blocks.len(), 0);
				} else {
					assert_eq!(blocks.len(), 1);
					assert_eq!(blocks[0].1.id, id);
					assert_eq!(blocks[0].1.rotation, rotation);
				}
			}
		}
	}
}
