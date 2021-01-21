use gdnative::prelude::*;


#[derive(NativeClass)]
#[inherit(Node)]
pub struct HelloWorld;


#[methods]
impl HelloWorld {
    /// The "constructor" of the class.
    fn new(_owner: &Node) -> Self {
        HelloWorld
    }

    #[export]
    fn _ready(&self, _owner: &Node) {
        godot_print!("VULKAN LIVES *stomp stomp*");
    }
}


// Function that registers all exposed classes to Godot
fn init(handle: InitHandle) {
    godot_print!("Hello world! I'm a native lib (yay!)");
    handle.add_class::<HelloWorld>();
}


// Macro that creates the entry-points of the dynamic library.
godot_init!(init);
