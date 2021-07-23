# Own War

_Vehicular combat building game_

In _Own War_ you create vehicles from basic blocks and drive them into battle
against other players.

The game is *libre* software: the AGPLv3 license permits you to do whatever
you want with the source code provided you grant the same permissions to other
people.

It is recommended to read `TUTORIAL.md` to get started.


## Features

* You can create any vehicle using basic blocks. There are quite a few blocks to
  give your creations detail as well as functional blocks such as wheels, weapons,
  ...

* The damage system is voxel-based: vehicles are torn down block-by-block.

* The game supports multiplayer. You can join any server and host your own too.

* Since the game is entirely free (as in [freedom][gnu free sw]) you can modify
  it to any extent. In fact, I highly encourage people to tinker with it and
  experiment with what works & doesn't work.


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

2) Apply the patches in `patch/godot` to the Godot source.

3) Use the `Makefile` in this repository to build the game.


## Downloads

You can find stable releases [here](https://github.com/Demindiro/OwnWar/releases)


## Gallery

![Start menu with the Skunk](https://static.salt-inc.org/own_war/0.19/start_skunk_new.jpg)

![Editor with a tank](https://static.salt-inc.org/own_war/0.19/editor_0.jpg)

![Test map with bomber](https://static.salt-inc.org/own_war/0.19/bomber_0.jpg)

![The Pit with a 4 legged chicken](https://static.salt-inc.org/own_war/0.19/chicken_0.jpg)

![Flying cars because why not?](https://static.salt-inc.org/own_war/0.19/flying_car_0.jpg)


[gnu free sw]: https://www.gnu.org/philosophy/free-sw.en.html
