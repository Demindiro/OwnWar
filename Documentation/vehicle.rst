=======
Vehicle
=======

A vehicle is a collection of bodies attached to each other. In turn, each body
is made up of multiple blocks ("voxels"). These blocks may be either static or
have a dynamic component.


Basic layout
~~~~~~~~~~~~

A vehicle is internally represented as follows::

  Godot                             |                 Internal

  [Spatial] Vehicle X               |       Vehicle {
    [VehicleBody] Body 0                        bodies: Vec<Option<Body>>,
      [Spatial] Dynamic block 0     |           ...
      [Spatial] Dynamic block 1             }
      [Spatial] Dynamic block 2     |
      ...
    [VehicleBody] Body 1            |       Body {
      ...                                       node: Ref<VehicleBody>,
    [VehicleBody] Body 2            |           mesh: Ref<VoxelMesh>,
      ...                                       dynamic_blocks: Vec<Ref<Spatial>>,
    ...                             |           ...
    [MeshInstance] VoxelMesh 0              }
      [Spatial] Dynamic block 0     |
      [Spatial] Dynamic block 1
      [Spatial] Dynamic block 2     |
      ...
    [MeshInstance] VoxelMesh 1      |       gd::Vehicle {
      ...                                       vehicle_node: Ref<Spatial>,
    [MeshInstance] VoxelMesh 2      |           bodies_nodes: Vec<Ref<VehicleBody>>,
      ...
    ...                             |


Neither ``Vehicle`` nor ``Body`` are ``NativeClass`` es. This is because Godot
is unsafe *by design*, which makes it hard to make a safe ``NativeClass``.
Instead, all operations are performed internally and only visible state is
synchronized with the nodes.

Vehicle state is advanced by the map root, which also manages network
connections. The UI gets the player's vehicle state from the same root.

Dynamic blocks are a special case as they are implemented in GDScript, which is
easier for adding new content at the moment. It may be worth looking into a
more performant and sandboxeable language (e.g. Lua).

The most important methods defined for vehicles are:

* ``step``: this advances the vehicles simulation.

* ``process_input``: apply the given inputs to the controller and update state
  depending on the inputs. It also returns a ``PoolByteArray`` with input data
  that must be sent to the server.

* ``rollback``: rewinds the state by the given amount of steps to the past.

* ``save_state``: saves the current state.

* ``process_packet``: apply the packet data. It returns a boolean indicating
  whether a rollback is needed.

* ``create_packet``: create a packet of state data. This is used by server
  instances.

Dynamic blocks *should* have the following methods:

* ``step``: ditto

* ``save_state``: return a ``VariantArray`` representing state needed for
  rollbacks

* ``restore_state``: set the current state to that of a past state.

Every frame, ``process_packet`` is called, optionally ``rollback`` and
``save_state`` are called too, then ``process_input`` and finally ``step``
are called.

``process_packet`` is called first since in cases of low ping, the packet may
refer to saved state from the frame right before the curret one. Any state
saved by ``step`` cannot possibly be received by the server in the same frame
however.


Order of processing
~~~~~~~~~~~~~~~~~~~

1) ``process_packet`` to update remote vehicles, perform rollback ... Does
   not apply for offline modes such as the test map.

2) (optional) ``process_inputs`` to apply inputs and maybe fire weapons.

3) ``create_packet`` create state packet with current position, inputs ...
   Does not apply for offline modes such as the test map.

4) ``step`` to apply damage, rotate turrets ...



Anchors
~~~~~~~

To connect multiple bodies, "anchors" are used. Internally, an anchor is simply
a marker that indicates whether two bodies are linked in any way. Usually, an
anchor corresponds to a turret block.

A block can register itself as an anchor by having a ``anchor_index`` property.
This property is automatically set and *must not* be changed. When the block
is destroyed, the anchor is automatically removed. Every anchor must also have
a ``anchor_mounts`` property, which is a ``PoolVector3Array`` of connection
points. An anchor may also have a ``anchor_mounts_nodes`` property, which will
be set to an array containing references to the mounted bodies' nodes.

This approach is much easier than using signals which result in pain and
suffering thanks to Godot not having any concept of exclusive (mutable) access
to an object.

When an anchor is destroyed, all connected bodies are destroyed recursively.
Consequently, cyclic anchors are forbidden.


Why "cyclic anchors" are forbidden
''''''''''''''''''''''''''''''''''

There is adifficult situation with multiple (indirect) connections between
bodies: What if a body gets split in two but both have connected anchors?

Since having a realistic & *efficient* solution is very hard cyclic anchors
are simply not allowed for now. This enables some other optimizations too,
such as being able to create a tree structure of bodies instead instead of
an interconnected blob.

Note that the tree optimization causes some unintuitive behaviour where a
body is only attached to one anchor. Eventually, these situations should
be detected before spawning in a vehicle.


Weapons
~~~~~~~

A block can register itself as a weapon by having a ``weapon_index`` property.
This property is automatically set and *must not* be changed. When the block
is destroyed, the weapon is automatically removed.

A weapon must also have a ``weapon_type`` property which can have any of the
following values:

* ``0`` if it is not fireable, e.g. a turret.

* ``1`` if it is a continuous fire weapon, e.g. lasers.

* ``2`` if it is a volley weapon, e.g. plasma cannons.

Weapons are kept track of in the vehicle struct to simplify iteration.

Blocks registered as weapons *may* have ``fire`` and ``aim_at`` functions.


Movement
~~~~~~~~

A block can register itself as a movement part by having a ``movement_index``
property. This property is automatically set and *must not* be changed. When
the block is destroyed, the part is automatically removed.

A movement part *may* have ``move``, ``yaw``, ``pitch`` and ``roll`` functions.
All take a single ``f32`` value ranging between ``-1.0`` and ``1.0`` inclusive.


Saveable blocks
~~~~~~~~~~~~~~~

Blocks with state that is important for rollback must have a ``saveable_index``
property and both ``save_state`` and ``restore_state`` functions.


Applying damage
~~~~~~~~~~~~~~~

Damage is applied in batches: during the ``process_input`` step guns are fired,
some may be hitscan and hit immediately, others fire a projectile that'll hit
later. Each hit events is collected in a ``damage_events``. During ``step``
the events are applied.

This approach has several advantages:

* Checking for disconnected blocks happens only once per frame instead of once
  per event.

* Events can be sent in one big packet in many, much smaller packets.

* Two players shooting each other at the same time will be treated equally, i.e.
  the order in the vehicle list does not matter.

  * For example, with a naive approach if A and B shoot each others gun, then A
    will have an advantage as they will destroy the gun first, preventing B
    from shooting. By delaying the damage event, both A and B shoot, then afer
    the guns are destroyed.
