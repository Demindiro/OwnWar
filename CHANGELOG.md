# Changelog


## 0.19


### 0.19.0

* Fix disconnected blocks outlines in the editor not working with batched mesh instances.

* Fix lagspikes in The Pit, add self destruct.

* Detect invalid vehicles before attempting to switch to a map.

* Update center of mass & collider when blocks are destroyed.

* Properly implement multiblocks: multiblocks now have multiple mount points.

* Add bitmap mount sides to only allow connections to certain sides of mount points. Damage propagation accounts for this.

* Add rudders, which act like mini-wings.

* Update the 3D models of the thruster, the laser weapon and the turret blocks.

* Poll for player input to prevent stuck keys.

* Enable damping to prevent excessive velocities & forces.

* Increase the maximum speed of thrusters from 40m/s to 100m/s, make the speed cap directional instead of globally.

* Buff the plasma cannon by increasing projectile velocity from 50m/s to 100m/s & increase the radius from 3 blocks to 7 blocks.

* Fix the 2x2 turret not being centered properly.


## 0.18


### 0.18.1

* Fix the Curse of Turning Right - AI can now manoeuvre properly.

* Fix turret blocks remaining transparent even if they are in the active layer.

* Fix inconsistent coloring of team material due to improper color mapping.

* Fix plasma projectiles ignoring terrain if shot through a vehicle.


### 0.18.0

First public release.
