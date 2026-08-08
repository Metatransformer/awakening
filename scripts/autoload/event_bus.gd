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
signal rupees_changed(count: int)
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

# --- The run: bag, extraction, economy --------------------------------------
## A run began. `run_seed` is recorded so it can be replayed.
signal run_started(run_seed: int)
## A run ended. `extracted` false means the player died and `lost` is gone.
signal run_ended(extracted: bool, contents: Dictionary, value: int)
## The carried bag changed. `value` is what the vendor would pay for it.
signal bag_changed(bag: Dictionary, value: int)
signal loot_gained(item_id: StringName, count: int)
signal bag_full
signal gold_changed(gold: int)
signal items_sold(sold: Dictionary, paid: int)
## The player tried to teleport out and could not afford the fee.
signal extract_refused(cost: int, gold: int)
signal depth_changed(depth: int)

# --- Interaction and screens ------------------------------------------------
## The "(E) OPEN" line, or "" when there is nothing to address. One at a time --
## Prompt decides which.
signal prompt_changed(text: String)
## A full-screen UI took or gave back input. `id` is e.g. &"trade".
signal screen_opened(id: StringName)
signal screen_closed(id: StringName)

# --- Presentation -----------------------------------------------------------
## Requests for the feel layer. Emitters do not care who answers.
signal request_hitstop(frames: int)
signal request_shake(strength: float, duration: float)
signal request_sfx(id: StringName, position: Vector3)
signal request_message(text: String)
