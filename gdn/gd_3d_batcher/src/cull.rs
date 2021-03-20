use gdnative::prelude::*;

pub struct Frustum {
	planes: [Plane; 6],
	sign_bits: [u8; 6],
}

impl Frustum {
	pub fn new(planes: [Plane; 6]) -> Self {
		let mut sign_bits = [0; 6];
		for (i, p) in planes.iter().enumerate() {
			let mut b = 0;
			if p.normal.x >= 0.0 {
				b |= 4;
			}
			if p.normal.y >= 0.0 {
				b |= 2;
			}
			if p.normal.z >= 0.0 {
				b |= 1;
			}
			sign_bits[i] = b;
		}

		Self { planes, sign_bits }
	}

	pub fn is_aabb_visible(&self, aabb: Aabb, transform: Transform) -> bool {
		let aabb = AccelAABB::new_transformed(aabb, transform);
		for (i, pl) in self.planes.iter().enumerate() {
			let p = self.sign_bits[i] as usize;
			let n = 0b111 - p;
			let n = aabb.0[n];
			if pl.normal.dot(-n) + pl.d <= 0.0 {
				return false;
			}
		}
		true
	}
}

struct AccelAABB([Vector3; 8]);

impl AccelAABB {
	fn new_transformed(aabb: Aabb, transform: Transform) -> Self {
		let aabb = transform_aabb(aabb, transform);
		let (mut s, mut e) = (aabb.position, aabb.position + aabb.size);
		// idk even...
		if s.x > e.x {
			(s.x, e.x) = (e.x, s.x);
		}
		if s.y > e.y {
			(s.y, e.y) = (e.y, s.y);
		}
		if s.z > e.z {
			(s.z, e.z) = (e.z, s.z);
		}
		let mut arr = [Vector3::zero(); 8];
		for &(i, x) in &[(0, s.x), (4, e.x)] {
			for &(j, y) in &[(0, s.y), (2, e.y)] {
				for &(k, z) in &[(0, s.z), (1, e.z)] {
					arr[i | j | k] = Vector3::new(x, y, z);
				}
			}
		}
		Self(arr)
	}
}

fn transform_aabb(aabb: Aabb, transform: Transform) -> Aabb {
	/* http://dev.theomader.com/transform-bounding-boxes/ */
	let Transform { basis, origin } = transform;
	let min = aabb.position;
	let max = aabb.position + aabb.size;

	let mut tmin = [0.0; 3];
	let mut tmax = [0.0; 3];

	let min = min.to_array();
	let max = max.to_array();
	let origin = origin.to_array();
	let basis = [
		basis.x().to_array(),
		basis.y().to_array(),
		basis.z().to_array(),
	];

	for i in 0..3 {
		tmin[i] = origin[i];
		tmax[i] = origin[i];
		for j in 0..3 {
			let e = basis[i][j] * min[j];
			let f = basis[i][j] * max[j];
			if e < f {
				tmin[i] += e;
				tmax[i] += f;
			} else {
				tmin[i] += f;
				tmax[i] += e;
			}
		}
	}

	Aabb {
		position: Vector3::from(tmin),
		size: Vector3::from(tmax) - Vector3::from(tmin),
	}
}

#[cfg(test)]
mod tests {
	use super::*;
	use lazy_static::lazy_static;

	const AABB_MID: Aabb = Aabb {
		position: Vector3::new(-1.0, -1.0, -1.0),
		size: Vector3::new(2.0, 2.0, 2.0),
	};
	const AABB_LEFT: Aabb = Aabb {
		position: Vector3::new(-500.0, -1.0, -1.0),
		size: Vector3::new(2.0, 2.0, 2.0),
	};
	const TRANSFORM_IDENTITY: Transform = Transform {
		basis: Basis::identity(),
		origin: Vector3::new(0.0, 0.0, 0.0),
	};
	lazy_static! {
		static ref TRANSFORM_ROT_45: Transform = Transform {
			basis: Basis::from_axis_angle(
				&Vector3::new(0.0, 1.0, 0.0),
				std::f32::consts::FRAC_PI_4 * 5.0,
			),
			origin: Vector3::zero(),
		};
	}
	const FRUSTUM_OFFSET_Z: [Plane; 6] = [
		Plane {
			normal: Vector3::new(0.0, 0.0, 1.0),
			d: 5.0,
		},
		Plane {
			normal: Vector3::new(0.0, 0.0, -1.0),
			d: 93.99989,
		},
		Plane {
			normal: Vector3::new(-0.49026135, 0.000000050651842, 0.87157553),
			d: 5.229453,
		},
		Plane {
			normal: Vector3::new(0.00000007305545, 0.7071069, 0.7071067),
			d: 4.2426405,
		},
		Plane {
			normal: Vector3::new(0.49026135, -0.000000050651842, 0.87157553),
			d: 5.229453,
		},
		Plane {
			normal: Vector3::new(-0.00000007305545, -0.7071069, 0.7071067),
			d: 4.2426405,
		},
	];

	#[test]
	fn frustum_cull_inside() {
		let aabb = AABB_MID;
		let frustum = Frustum::new(FRUSTUM_OFFSET_Z);
		assert!(frustum.is_aabb_visible(aabb, TRANSFORM_IDENTITY));
	}

	#[test]
	fn frustum_cull_outside() {
		let aabb = AABB_LEFT;
		let frustum = Frustum::new(FRUSTUM_OFFSET_Z);
		assert!(!frustum.is_aabb_visible(aabb, TRANSFORM_IDENTITY));
	}

	#[test]
	fn aabb_transform_mid_identity() {
		let aabb = AABB_MID;
		let transform = TRANSFORM_IDENTITY;
		assert_eq!(transform_aabb(aabb, transform), aabb);
	}

	#[test]
	fn aabb_transform_mid_rotated_135() {
		assert_eq!(
			transform_aabb(AABB_MID, *TRANSFORM_ROT_45),
			Aabb {
				position: Vector3::new(-1.4142135, -1.0, -1.4142135,),
				size: Vector3::new(2.828427, 2.0, 2.828427,)
			}
		);
	}
}
