//! Functions to check if a vehicle is valid

use super::*;
use crate::util::*;

impl super::Body {
	/// Check if all blocks are connected.
	///
	/// Returns `true` if yes, `false` otherwise.
	#[must_use]
	pub(super) fn are_all_blocks_connected(&self) -> bool {
		let marks = convert_vec::<_, usize>(self.size) + Vector3D::one();
		let mut marks = BitArray::new(marks.x * marks.y * marks.z);

		// All blocks should be connected to a parent block in some way, so start from there
		for pos in self.parent_anchors.iter().copied() {
			let index = self.get_index(pos).unwrap();
			self.mark_connected_blocks(&mut marks, pos, index, false);
		}

		// Check if any block isn't marked.
		for pos in iter_3d_inclusive((0, 0, 0), self.size.to_tuple()).map(Voxel::from) {
			let index = self.get_index(pos).unwrap();
			if self.health[index as usize].is_some() != marks.get(index as usize).unwrap() {
				return false;
			}
		}

		// Everything is connected.
		return true;
	}
}
