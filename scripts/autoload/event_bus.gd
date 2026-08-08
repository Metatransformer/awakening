extends Node
## Autoload `Bus`. Sideways peer-to-peer signals only.
##
## APPEND your signals. Never rename or remove someone else's — several agents
## build against this file at once. Parent->child stays a method call, and
## child->parent stays a local signal; only cross-scene traffic belongs here.

# --- Player state -----------------------------------------------------------
signal player_spawned(player: Node3D)
## Health is in QUARTER hearts. See K.HEART.
signal player_health_changed(quarters: int, max_quarters: int)
signal magic_changed(magic: int, max_magic: int)
signal ammo_changed(id: StringName, count: int)
signal gold_changed(count: int)
signal c_items_changed(slots: Array)
signal player_died

# --- Camera and targeting ---------------------------------------------------
signal target_acquired(target: Node3D)
signal target_lost
## Emitted while Z is held with no valid target — the camera recentres.
signal camera_recenter
signal letterbox_requested(on: bool)
signal first_person_changed(on: bool)

# --- Combat -----------------------------------------------------------------
signal hit_landed(target: Node3D, amount: int, position: Vector3)
signal shield_blocked(position: Vector3, normal: Vector3)
signal enemy_died(enemy: Node3D, position: Vector3)

# --- Dungeon progression ----------------------------------------------------
signal room_entered(room_id: StringName)
signal room_cleared(room_id: StringName)
signal door_opened(door_id: StringName)
signal chest_opened(chest_id: StringName, contents: StringName)
signal key_count_changed(count: int)
signal item_acquired(item_id: StringName)
signal switch_toggled(switch_id: StringName, on: bool)
signal puzzle_solved(puzzle_id: StringName)

# --- Boss -------------------------------------------------------------------
signal boss_engaged(boss: Node3D)
signal boss_phase_changed(phase: int)
signal boss_defeated

# --- Metagame (docs/METAGAME.md) --------------------------------------------
## The dungeon bag or the town stash changed contents.
signal bag_changed
signal stash_changed
## A blade or armour tier was bought. `track` is a Gear.Track.
signal gear_changed(track: int, tier: int)
## Ingredients hit the floor because the bag was full when they dropped.
signal loot_overflowed(id: StringName, count: int)
signal loot_collected(id: StringName, count: int)

## Run lifecycle. `rooms_cleared` is the depth the run reached.
signal run_started
signal run_depth_changed(rooms_cleared: int, band: int)
## `reason` is &"extracted", &"walked_out" or &"died".
signal run_ended(reason: StringName, rooms_cleared: int)

## Paid teleport: begins channelling, aborted by damage or movement, or lands.
signal extraction_started(fee: int)
signal extraction_progress(t01: float)
signal extraction_cancelled(why: StringName)

# --- Presentation -----------------------------------------------------------
## Requests for the feel layer. Emitters do not care who answers.
signal request_hitstop(frames: int)
signal request_shake(strength: float, duration: float)
signal request_sfx(id: StringName, position: Vector3)
signal request_message(text: String)
