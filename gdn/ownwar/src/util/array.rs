pub fn swap_erase<T>(vec: &mut Vec<T>, f: impl Fn(&T) -> bool) -> Result<T, ()> {
	let mut index = None;
	for (i, v) in vec.iter().enumerate() {
		if f(v) {
			index = Some(i);
			break;
		}
	}
	if let Some(index) = index {
		Ok(vec.swap_remove(index))
	} else {
		Err(())
	}
}
