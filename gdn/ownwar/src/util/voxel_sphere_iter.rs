use crate::types::*;
use lazy_static::lazy_static;
use std::collections::BTreeMap;
use std::sync::RwLock;

type Index = u32;
type Radius = i8;

/// Algorithm that returns coordinates in a spherical radius in close to far order
pub struct VoxelSphereIterator {
	origin: voxel::Delta,
	index: Index,
	length: Index,
}

struct Cache {
	points: Vec<(i8, i8, i8)>,
	radius_to_length: Vec<Index>,
}

lazy_static! {
	static ref CACHE: RwLock<Cache> = RwLock::new(Cache {
		points: Vec::new(),
		radius_to_length: Vec::new(),
	});
}

impl VoxelSphereIterator {
	pub fn new(origin: voxel::Delta, radius: Radius) -> Self {
		{
			let radius = radius.abs();
			let cache = CACHE.read().unwrap();
			if cache.radius_to_length.len() <= radius as usize {
				drop(cache);
				calculate_points(radius);
			}
		}
		Self {
			origin,
			index: 0,
			length: CACHE.read().unwrap().radius_to_length[radius as usize],
		}
	}
}

impl Iterator for VoxelSphereIterator {
	type Item = voxel::Delta;

	fn next(&mut self) -> Option<Self::Item> {
		if self.index < self.length {
			let v = CACHE.read().unwrap().points[self.index as usize];
			self.index += 1;
			Some(Self::Item::from(v) + self.origin)
		} else {
			None
		}
	}
}

fn calculate_points(radius: Radius) {
	let radius = radius.abs();
	let cache = CACHE.read().unwrap();
	let inner_radius = cache.radius_to_length.len() as Radius;
	drop(cache);
	let radius_2 = radius as usize * radius as usize;
	let inner_radius_2 = inner_radius as usize * inner_radius as usize;

	let mut radii_map = vec![0; radius as usize + 1];
	for (i, r) in radii_map.iter_mut().enumerate() {
		*r = i * i;
	}
	let radii_map = radii_map;

	let mut btree = BTreeMap::new();
	let mut lengths = vec![0; radius as usize + 1];
	for x in -radius..radius + 1 {
		for y in -radius..radius + 1 {
			for z in -radius..radius + 1 {
				let len_z_2 =
					x as isize * x as isize + y as isize * y as isize + z as isize * z as isize;
				let len_z_2 = len_z_2 as usize;
				// Skip already calculated points (that are closer anyways), skip points outside circle
				if len_z_2 >= inner_radius_2 && len_z_2 <= radius_2 {
					let v = (x as i8, y as i8, z as i8);
					btree.entry(len_z_2).or_insert(Vec::new()).push(v);
					for (i, r2) in radii_map.iter().enumerate().rev() {
						if len_z_2 >= *r2 {
							lengths[i] += 1;
							break;
						}
					}
				}
			}
		}
	}

	let mut cache = CACHE.write().unwrap();
	for a in btree.into_values() {
		for v in a.into_iter() {
			cache.points.push(v);
		}
	}
	cache.radius_to_length.resize(radius as usize + 1, 0);
	let mut sum = 0;
	for (i, v) in lengths.into_iter().enumerate() {
		sum += v;
		cache.radius_to_length[i] += sum;
	}
}
