====================
Networking: movement
====================


Key features & limitations:

* All physics are handled server-side.

* No kinematic bodies -> no flipping of large vehicles, lifting heavy things
  with small, hollow vehicles,

* Collisions models are rough approximations to improve performance at the cost
  of accuracy and "intuitivity".


All physics are handled server-side
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

One of the hardest parts of creating netcode is handling realtime movement
without any input lag. Since ping can be in the tens or even hundreds of
milliseconds it isn't possible to make the client simply copy whatever data
it gets from the server (Quake did it and it wasn't nice).

The easy and obvious solution is to simply trust the client. This is a *very
very very VERY* bad idea: physics **will** break and it's impossible to verify
that the client is trustworthy. No, so-called "anti-cheat" software won't work
and never will because all it takes to bypass it is a process that cannot be
detected (e.g. manipulating packet contents on a hidden process, DMA devices
...). Keeping your code "secret" is also completely ineffective as there are
plenty of people capable of reverse-engineering whatever you create. (Fun fact:
much of the same reasoning applies to DRM and proprietary software "security"
in general).

The alternative is *client-side prediction*: the server is still authoritative,
but the client will also simulate physics and apply corrections occasionally.
The state on the server and the client will be the same most of the time if
the simulation is somewhat deterministic. If the client notices any deviation,
it rewinds the physics state and replays past events until the simulation
matches again.


Determining deviation
'''''''''''''''''''''

The obvious way to determine whether a simulation is out of sync is to make it
entire deterministic and if any value doesn't match up, the client rewinds and
replays from a previous state. However, this prevents the use of certain
hardware features such as AVX2 or target-specific optimizations. Instead, if
a simulation is *mostly* deterministic a deviation can be classified as a value
difference exceeding a certain threshold. Ideally, this threshold is high
enough such that rollbacks are rare yet low enough so players won't notice any
rollbacks.


Implementation
''''''''''''''

Two things are given:

* The player's vehicle is in the "future" (i.e. it is predicting the response
  of the server).
* The other vehicles are in the "present" (i.e. their current state is taken
  from the latest server response).

Given this, there are two rollback mechanisms:

* If the player's vehicle is out of sync, roll back _all_ vehicles, then
  replay. This is necessary because we need to speculate future state.

* If any other vehicle is out of sync, just "teleport" it since we do have
  the current state from the server. This may lead to some glitchy behaviour
  in very rare cases, but the simulation will correct itself eventually
  regardless.


The exact process of rolling back the player's vehicle state is as follows:

1) Collect all state packets received from the server. Keep the one with
   the highest sequence ID and discard the others.

2) Use the sequence ID to determine which ring buffer element corresponds to
   the received packet.

3) Use the position info to determine a "divergence" factor. If the divergence
   factor is below a certain level, go to 6. Continue otherwise.

4) Rewind *all* vehicles' state by a certain amount of steps. The steps is
   the current ring buffer index minus the index of the element corresponding
   to the packet.

5) Replay the simulation. This involves reapplying saved vehicle state and
   advancing the physics once every step.

6) Save the full state of the vehicle every frame to a ring buffer. This
   includes block-specific information such as shot recoil, wheel spin, ...

7) Apply client input (movement, fire weapon ...).

8) Send the client inputs to the server along with a sequence ID, which is
   simply the index of the state ring buffer.


Because Godot never exposed the step function of the physics server, some
issues popped up:

* ``NOTIFICATION_TRANSFORM_CHANGED`` is delayed. This means that if you change
  ``transform`` and then step, the physics server won't use the new positions.
  The only workaround is to set it manually using
  ``PhysicsServer::body_set_state``.

* ``_physics_step`` is not called when the physics server steps. The obvious
  solution is to call it manually, but this may cause unexpected behaviour.
  Instead, a ``process_tick`` function is used which is called by the
  ``Vehicle`` code whenever appropriate.
