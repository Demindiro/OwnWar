# Own War

_Vehicular combat building game_

In _Own War_ you create vehicles from basic blocks and drive them into battle
against other players.

The game is *libre* software: the AGPLv3 license permits you to do whatever
you want with the source code provided you grant the same permissions to other
people.


## Building the game.

There are 3 major tools & libraries needed:

* The Rapier physics engine, which requires the Godot engine to be compiled
  from source (see https://github.com/Demindiro/godot\_rapier3d)

* The source code of Godot 3.3 (https://github.com/godotengine/godot/tree/3.3)

* The **nightly** Rust toolchain to compile the GDNative libraries.

The instructions provided below should work for any platform but have only
been tested for Linux so far.


### Building on Linux

1) Get the source code for Godot & the Rapier module. Follow the instructions
   in the `README` of `godot_rapier3d` to build the engine.

2) Use the `Makefile` in this repository to build the game.
