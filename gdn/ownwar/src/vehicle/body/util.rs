use super::*;
use crate::block;
use crate::util::*;
use std::io;
use gdnative::prelude::Vector3;

impl super::Body {
	#[inline]
	pub(in super::super) fn global_to_voxel_space(
		&self,
		origin: Vector3,
		direction: Vector3,
	) -> (Vector3, Vector3) {
		let node = unsafe { self.node().assume_safe() };
		let local_unscaled_origin = node.to_local(origin);
		let local_origin = local_unscaled_origin / block::SCALE + self.center_of_mass();
		let local_direction = node.to_local(origin + direction) - local_unscaled_origin;
		(local_origin, local_direction)
	}

	#[inline]
	pub(in super::super) fn voxel_to_global_space(
		&self,
		origin: Vector3,
		direction: Vector3,
	) -> (Vector3, Vector3) {
		let node = unsafe { self.node().assume_safe() };
		let local_unscaled_origin = (origin - self.center_of_mass()) * block::SCALE;
		let global_origin = node.to_global(local_unscaled_origin);
		let global_direction = node.to_global(origin + direction) - global_origin;
		(global_origin, global_direction)
	}

	/// Map a local voxel coordinate to a local translation, accounting for center of mass &
	/// scale.
	pub fn voxel_to_translation(&self, coordinate: Voxel) -> Vector3 {
		let coordinate = convert_vec::<_, f32>(coordinate);
		(coordinate - self.center_of_mass - convert_vec(self.offset)) * block::SCALE
	}

	/// Serialize a Vector3
	pub(in super::super) fn serialize_vector3(out: &mut impl io::Write, v: Vector3) -> io::Result<()> {
		out.write_all(&v.x.to_le_bytes())?;
		out.write_all(&v.y.to_le_bytes())?;
		out.write_all(&v.z.to_le_bytes())
	}

	/// Deserialize a Vector3
	pub(in super::super) fn deserialize_vector3(in_: &mut impl io::Read) -> io::Result<Vector3> {
		let mut buf = [0; 4];
		in_.read_exact(&mut buf)?;
		let x = f32::from_le_bytes(buf);
		in_.read_exact(&mut buf)?;
		let y = f32::from_le_bytes(buf);
		in_.read_exact(&mut buf)?;
		let z = f32::from_le_bytes(buf);
		Ok(Vector3::new(x, y, z))
	}

	/// Serialize a `f32`
	pub(in super::super) fn serialize_f32(out: &mut impl io::Write, v: f32) -> io::Result<()> {
		out.write_all(&v.to_le_bytes())
	}

	/// Deserialize a `f32`
	pub(in super::super) fn deserialize_f32(in_: &mut impl io::Read) -> io::Result<f32> {
		let mut buf = [0; 4];
		in_.read_exact(&mut buf)?;
		Ok(f32::from_le_bytes(buf))
	}
}
