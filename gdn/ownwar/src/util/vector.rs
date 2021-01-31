use euclid::{UnknownUnit, Vector3D};
use num_traits::{AsPrimitive, Num};

pub fn convert_vec<T: AsPrimitive<U>, U: Num + Copy + 'static>(
	from: Vector3D<T, UnknownUnit>,
) -> Vector3D<U, UnknownUnit> {
	Vector3D::new(from.x.as_(), from.y.as_(), from.z.as_())
}
