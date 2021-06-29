use gdnative::api::ResourceLoader;
use gdnative::prelude::*;

pub(super) fn instance_effect(path: &str) -> Result<TRef<Spatial, Shared>, ()> {
	ResourceLoader::godot_singleton()
		.load(path, "PackedScene", false)
		.and_then(|s| unsafe { s.assume_thread_local().cast::<PackedScene>() })
		.and_then(|s| s.instance(0))
		.and_then(|s| unsafe { s.assume_safe().cast::<Spatial>() })
		.ok_or(())
}
