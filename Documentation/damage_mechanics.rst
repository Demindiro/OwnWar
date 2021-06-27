================
Damage mechanics
================

Key features & limitations:

* Fully deterministic

* Only works with one mainframe


How damage propagates
~~~~~~~~~~~~~~~~~~~~~

There are 3 types of damage:

* Heat damage, which simply spreads to nearby blocks.

* Explosion damage, which damages all blocks in a radius, starting from the
  closest block (i.e. the center).

* Penetrative damage, which follows a straight path.


Fundamentally, they work in the same way:

* First, all blocks they would damage are damaged and potentially destroyed.

* If any block got destroyed, there is a check to ensure any disconnected
  chunks are also destroyed.

* If an anchor block (e.g. turret) got destroyed, all bodies that are not
  connected to the mainframe via another anchor are destroyed.


Since the damage is entirely deterministic, the server simply sends the type,
location and damage/radius/... of each damage event to all clients.


Limitations
~~~~~~~~~~~


Only one mainframe
''''''''''''''''''

While multiple mainframes is certainly possible, it would require counting
which section has the most blocks alive if they ever get split. This is
obviously a lot more expensive than simply checking whether a body is connected
via an anchor.
