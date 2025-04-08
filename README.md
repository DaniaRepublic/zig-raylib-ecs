Tasks:
  - [x] create node trees (child, parent relationships for nodes)
    - used ecs library to organize entities
  - [x] make objects pickable
    - implemented for guns
  - [ ] create collision system. Options:
   1. mark collided entities, then process them in a separate system.
   2. create a new collider entity for each collision that stores both entities, then process the collision in a separate system.
  - [ ] introduce some record keeping / inventory

Gun mechanics:
  - Guns have limited ammunition, ammo packs lie around the map, pick them to refill guns.
  - Entities have a set of characteristics: freezable, flammable, hypnotisable, slimable etc.
  - Normal guns: cause damage to entities
  - Slime gun: turns a slimable entity into a slime blob
    - Intended use: immobilize a crowd of enemies + synergy with freeze gun
    - Slime blob can encapsulate up to some upgradeable amount of enemy entities
    - Immobilizes entities that are slimed
    - Slime blob can be frozen
  - Freeze gun: turns a freezable entity into an ice block
    - Intended use: immobilize a single entity and block attacks between player and other entities with it
    - Ice block can be damaged and if broken, the entity inside it perishes
    - Frozen entity can be hit by non-player entity attacks that aren't freeze attacks
    - If fired at a slime blob, freezes all entities in it
  - Flame gun: sets entity on fire
    - Intended use: shot crowds to deal perpetual damage to groups
    - Flamed entities get perpetually hit while flamed and cause damage to other flammable entities nearby
    - If flamed entity is slimed, the flame is put off
    - If flamed entity is frozen, puts off the flame
  - Hypnosis tower: hypnotises enemy entities
  - Laser gun: shoots annihilating ray
  - Electro gun: zaps entities in crowd consecutively
   - Slimed entities get zapped all at once (as one)
   - Puts off hypnosis effect

Tower mechanics:
  - To setup tower, you need to be in its vicinity.

Enemy mechanics:
  - Goo monster
    - Spews dark green-brown goo that slows the player down an deletes their acceleration
      - Goo doesn't affect goo monsters

Introduce rebirth mechanic where actions you did earlier are present after rebirth so you can setup traps, completions, shortcuts by thinking ahead.

Levels:
  - Cave that requires exploration like a maze with secrets that has sleeping stone monsters and crystal spikers.
    - One of intended dynamics: managing danger from heavy and deadly monsters and taking smaller damage from crystal rods.
    - If you run, you wake up monsters.
    - However if you don't, spikers shoot thin crystal rods at you and it is hard to dodge them when walking slowly.
