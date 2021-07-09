use euclid::{UnknownUnit, Vector3D};
use num_traits::AsPrimitive;
use std::ops::{Add, Sub};

#[derive(Debug)]
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

impl<T> AABB<T>
where
	T: Copy + Ord + Add<Output = T> + Sub<Output = T>,
{
	pub fn expand(&self, point: Vector3D<T, UnknownUnit>) -> Self {
		let pos = self.position;
		let end = self.end();
		let pos = Vector3D::new(pos.x.min(point.x), pos.y.min(point.y), pos.z.min(point.z));
		let end = Vector3D::new(end.x.max(point.x), end.y.max(point.y), end.z.max(point.z));
		AABB::new(pos, end - pos)
	}

	pub fn union(&self, other: Self) -> Self {
		let ss = self.position;
		let se = self.end();
		let os = other.position;
		let oe = other.end();
		let pos = Vector3D::new(ss.x.min(os.x), ss.y.min(os.y), ss.z.min(os.z));
		let end = Vector3D::new(se.x.min(oe.x), se.y.min(oe.y), se.z.min(oe.z));
		AABB::new(pos, end - pos)
	}

	pub fn encloses(&self, other: Self) -> bool {
		let ss = self.position;
		let se = self.end();
		let os = other.position;
		let oe = other.end();
		ss.x <= os.x && ss.y <= os.y && ss.z <= os.z && oe.x < se.x && oe.y < se.y && oe.z < se.z
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

impl<T> Clone for AABB<T>
where
	T: Clone,
{
	fn clone(&self) -> Self {
		AABB {
			position: self.position.clone(),
			size: self.size.clone(),
		}
	}
}

impl<T> Copy for AABB<T> where T: Copy {}
