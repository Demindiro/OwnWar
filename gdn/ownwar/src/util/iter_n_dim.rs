use std::iter::Step;

pub fn iter_2d_inclusive<T>(start: (T, T), end: (T, T)) -> impl Iterator<Item = (T, T)>
where
	T: Copy + Step + 'static,
{
	(start.0..=end.0).flat_map(move |x| (start.1..=end.1).map(move |y| (x, y)))
}

pub fn iter_3d_inclusive<T>(start: (T, T, T), end: (T, T, T)) -> impl Iterator<Item = (T, T, T)>
where
	T: Copy + Step + 'static,
{
	iter_2d_inclusive((start.0, start.1), (end.0, end.1))
		.flat_map(move |(x, y)| (start.2..=end.2).map(move |z| (x, y, z)))
}
