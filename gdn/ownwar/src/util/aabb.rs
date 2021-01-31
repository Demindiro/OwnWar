use euclid::{UnknownUnit, Vector3D};
use num_traits::AsPrimitive;
use std::ops::Add;

pub struct AABB<T> {
	pub position: Vector3D<T, UnknownUnit>,
	pub size: Vector3D<T, UnknownUnit>,
}

impl<T: Copy> AABB<T> {
	pub fn new(position: Vector3D<T, UnknownUnit>, size: Vector3D<T, UnknownUnit>) -> Self {
		Self { position, size }
	}

	pub fn convert<U: Copy + 'static>(&self) -> AABB<U>
	where
		T: AsPrimitive<U>,
	{
		AABB::<U> {
			position: Vector3D::<U, UnknownUnit>::new(
				self.position.x.as_(),
				self.position.y.as_(),
				self.position.z.as_(),
			),
			size: Vector3D::<U, UnknownUnit>::new(
				self.size.x.as_(),
				self.size.y.as_(),
				self.size.z.as_(),
			),
		}
	}
}

impl<T: Copy + PartialOrd + Add<Output = T>> AABB<T> {
	pub fn has_point(&self, point: Vector3D<T, UnknownUnit>) -> bool {
		let a = self.position;
		let b = self.end();
		a.x <= point.x
			&& a.y <= point.y
			&& a.z <= point.z
			&& point.x <= b.x
			&& point.y <= b.y
			&& point.z <= b.z
	}
}

impl<T: Copy + Add<Output = T>> AABB<T> {
	pub fn end(&self) -> Vector3D<T, UnknownUnit> {
		self.position + self.size
	}
}
