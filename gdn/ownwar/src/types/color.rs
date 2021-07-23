use core::fmt;
use gdnative::core_types::{Color, ToVariant, Variant};

/// A RGB color type where each component is a byte (`u8`).
#[derive(Clone, Copy, Hash, Eq, PartialEq)]
pub struct RGB8 {
	pub r: u8,
	pub g: u8,
	pub b: u8,
}

impl RGB8 {
	pub const BLACK: Self = Self::new(0, 0, 0);
	pub const WHITE: Self = Self::new(255, 255, 255);

	/// Create a new RGB8 color.
	pub const fn new(r: u8, g: u8, b: u8) -> Self {
		Self { r, g, b }
	}

	/// Perform a lossy conversion from a `Color`
	pub fn lossy_from_color(color: Color) -> Self {
		let Color { r, g, b, a: _ } = color;
		RGB8::new(
			(r * 255.0).round() as u8,
			(g * 255.0).round() as u8,
			(b * 255.0).round() as u8,
		)
	}
}

impl fmt::Debug for RGB8 {
	fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
		write!(f, "(r: {}, g: {}, b: {})", self.r, self.g, self.b)
	}
}

impl fmt::Display for RGB8 {
	fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
		fmt::Debug::fmt(self, f)
	}
}

impl From<RGB8> for Color {
	/// Perform a lossless conversion to a `Color`.
	fn from(rgb: RGB8) -> Color {
		Color::rgb(
			rgb.r as f32 / 255.0,
			rgb.g as f32 / 255.0,
			rgb.b as f32 / 255.0,
		)
	}
}

impl ToVariant for RGB8 {
	fn to_variant(&self) -> Variant {
		Color::from(*self).to_variant()
	}
}
