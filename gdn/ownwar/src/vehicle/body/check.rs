//! Functions to check if a vehicle is valid

use super::*;
use crate::util::*;

impl super::Body {
	/// Check if all blocks are connected.
	///
	/// Returns `true` if yes, `false` otherwise.
	#[must_use]
	pub(super) fn are_all_blocks_connected(&self) -> bool {
		let mut marks = voxel::BitGrid::new(self.blocks.end());

		// All blocks should be connected to a parent block in some way, so start from there
		for pos in self.parent_anchors.iter().copied() {
			self.mark_connected_blocks(&mut marks, pos, false);
		}

		// Check if any block isn't marked.
		for pos in iter_3d_inclusive((0, 0, 0), self.end().into()).map(voxel::Position::from) {
			if self.blocks[pos].health.is_some() != marks[pos] {
				return false;
			}
		}

		// Everything is connected.
		return true;
	}
}
