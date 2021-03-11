use euclid::{UnknownUnit, Vector3D};
use num_traits::AsPrimitive;
use std::ops::{Add, Sub};

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

	pub fn expand(&self, point: Vector3D<T, UnknownUnit>) -> Self
	where
		T: Ord + Add<Output = T> + Sub<Output = T>,
	{
		let pos = self.position;
		let end = self.end();
		let pos = Vector3D::new(pos.x.min(point.x), pos.y.min(point.y), pos.z.min(point.z));
		let end = Vector3D::new(end.x.max(point.x), end.y.max(point.y), end.z.max(point.z));
		AABB::new(pos, end - pos)
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

impl<T: Default> AABB<T> {
	pub fn default() -> Self {
		Self {
			position: Vector3D::default(),
			size: Vector3D::default(),
		}
	}
}
