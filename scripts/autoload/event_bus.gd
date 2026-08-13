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
## Temporary health above the real maximum, also in quarter-hearts.
signal temporary_overhealth_changed(quarters: int)
## A blow landed on the hero, and WHERE IT CAME FROM -- the world position of the
## thing that threw it, straight off `Hit.from`.
##
## It exists because the direction is not derivable from anything else on this
## bus: `player_health_changed` has neither a delta nor a bearing, and
## `hit_landed` is emitted by enemies about themselves. `Hud` turns it into the
## damage-direction arc (HUD_PLAN decision 13/29/36), which is what replaced
## `Feel`'s full-screen vignette -- a cue that said "you were hit", which the
## player already knew, for one that says "from behind you, on the left", which
## an over-the-shoulder camera cannot otherwise tell them.
##
## Emitted only for blows that LAND. A parry, a perfect dodge, a block or an
## i-frame all return before this, and an arc for a blow you just answered
## correctly would be the game arguing with the player about what happened.
signal hero_struck(from: Vector3)
## The hero took a blow, with everything the receiving end needs to voice it:
## `force` is `Hit.force` (0..1, continuous), `tier` is a `Hit.Tier` (0 LIGHT,
## 1 HEAVY, 2 KNOCKDOWN), and `at` is where he was standing.
##
## Separate from `hero_struck`, which carries the direction and nothing else and
## is the HUD arc's. Merging them was the obvious move and is wrong: the arc is
## drawn for the blow's BEARING and this is emitted for its WEIGHT, and a
## listener that wanted one would have had to ignore three arguments to get it.
## `tier` is an int rather than a `Hit.Tier` because a signal argument typed on a
## class enum makes every file that connects to the bus load `Hit`.
signal hero_hurt(force: float, tier: int, at: Vector3)
signal magic_changed(magic: int, max_magic: int)
## Fires on every spend and on every regen step, so the HUD never polls for it.
signal stamina_changed(stamina: float, max_stamina: float)
signal ammo_changed(id: StringName, count: int)
signal rupees_changed(count: int)
## D-pad ↓ stepped to a different bottle. `index` is into Game.bottle_contents.
##
## Replaces `quick_slots_changed` and, before that, `c_items_changed` -- both of
## which announced which item was on which BUTTON, a question the game no longer
## asks (see the note on Game.item_selected). Neither is emitted any more and
## neither has a listener; they are gone rather than kept as aliases, because a
## signal nothing emits is a signal the next reader will wire something to.
signal item_selected_changed(index: int)
## An armament changed hands, or the whole set was swapped. `set_index` is which
## loadout is live (0 primary, 1 alternate). See Game.loadout.
signal loadout_changed(set_index: int, right: StringName, left: StringName)
## A kit-wheel binding moved. `slots` is `Game.wheel` itself — eight entries,
## each an armament id, a `bottle_N` token, or `&""`.
##
## It is about the BINDINGS and never about the release. Committing a slot
## already emits `loadout_changed` or `item_selected_changed` through
## `Game.wheel_select`, and a third signal saying the same thing a different way
## is how two listeners end up disagreeing about what the hero is holding —
## which is the exact failure `quick_slots_changed` was deleted for (see
## `item_selected_changed` above).
##
## The array is passed live rather than duplicated: every listener here draws it
## and none of them keeps it.
signal wheel_changed(slots: Array)
signal player_died

# --- Camera and targeting ---------------------------------------------------
signal target_acquired(target: Node3D)
signal target_lost
## Emitted while Z is held with no valid target — the camera recentres.
signal camera_recenter
signal letterbox_requested(on: bool)
signal first_person_changed(on: bool)
## A ranged item is out and the hero is sighting down it: the camera drops to the
## shoulder and the HUD draws a crosshair. Emitted by `HeroRanged`, which is the
## one place that knows what is in his hands — the camera and the HUD both read
## this rather than each deciding for itself what counts as aiming.
signal aim_changed(active: bool)
## The shield is up. Emitted by `HeroCombat`, which owns the decision. The camera
## is the only listener and it uses this for exactly one thing: killing autoswing.
## A raised guard puts the hero in the same stance the bow does — he faces the
## lens — and "drift to behind the hero" plus "the hero faces the camera" is the
## rule pair that corkscrews (see `GameCamera._apply_autoswing`). Unlike
## `aim_changed` this must NOT recentre: snapping the camera behind the hero the
## instant he raises his shield is a yank in the middle of a fight.
signal guard_changed(active: bool)

# --- Combat -----------------------------------------------------------------
signal hit_landed(target: Node3D, amount: int, position: Vector3)
signal shield_blocked(position: Vector3, normal: Vector3)
## A blow was PARRIED — caught inside `K.PARRY_WINDOW` rather than merely
## stopped. Separate from `shield_blocked` on purpose: a block is a thing that
## did not hurt you and a parry is a thing you did, and the HUD, the sound and
## the camera all want to say so differently.
##
## `attacker` may be null — the parry works on anything that swings, and not
## everything that swings is a body (see `HeroCombat.on_parried`).
signal parried(position: Vector3, attacker: Node)
## A dodge went through a live blow inside `K.DODGE_GRACE`. The slow-motion and
## the flurry window are `Hero`'s and `HeroCombat`'s; this is for everything
## that only wants to know it happened.
signal perfect_dodge(position: Vector3)
signal enemy_died(enemy: Node3D, position: Vector3)

# --- Dungeon progression ----------------------------------------------------
signal room_entered(room_id: StringName)
## The last body in a room is gone. Emitted by `RoomWatch`, which counts the
## bodies the generator put there rather than scanning the room -- see that
## class for why the two are not the same question, and by `BossArena`, whose
## chamber is not a `rooms[]` cell and so never got a watcher.
##
## `room_id` is the room root's node name, the same string `room_entered`
## carries. They must keep naming a room the same way or nothing can pair them.
##
## `grade` is `RewardVfx.MINOR` (1) for an ordinary room and `RewardVfx.MAJOR`
## (2) for a boss or miniboss chamber -- the same two-tier vocabulary the reward
## flash uses, deliberately, because it is the same distinction being drawn and a
## player should not have to learn two of them.
##
## **Why an argument and not a second signal.** A boss chamber is still a room
## that was beaten, so `BossArena` has to emit this one; if the big cue lived on
## `boss_defeated` instead, a boss kill would fire both and stack two ceremonies
## on one frame, which is the exact thing `Sfx.CUES` is written to prevent.
signal room_cleared(room_id: StringName, grade: int)
## A reward ARRIVED: a chest that was standing hidden until its room was beaten,
## its puzzle solved or its miniboss killed just landed. `tier` is
## `RewardVfx.MINOR` (1) or `RewardVfx.MAJOR` (2) -- boss-grade loot announces
## itself differently, and the two tiers are the whole vocabulary (see that
## class for why there is no third).
##
## Carries a POSITION because the reward is a place in the room and not a thing
## that happened to the player: the sound belongs at the chest, so a player who
## turns away from it can still hear which corner it landed in. `RewardVfx`
## emits this and deliberately names no sound -- `Sfx` owns that choice.
signal reward_revealed(tier: int, position: Vector3)
signal door_opened(door_id: StringName)
signal chest_opened(chest_id: StringName, contents: StringName)
signal key_count_changed(count: int)
signal item_acquired(item_id: StringName)
signal switch_toggled(switch_id: StringName, on: bool)
signal puzzle_solved(puzzle_id: StringName)
## The floor plan the player can see has changed: a room came out of the fog, a
## chest was opened, a bundle was picked up, or the floor was torn down on the
## way to the garrison. `Atlas` is the state; this is the poke.
##
## It carries nothing on purpose. Both listeners -- the HUD's corner minimap and
## the pause menu's MAP screen -- redraw the WHOLE map from `Atlas` when it
## fires, because a map is cheap to redraw and a diff of it is not. A payload
## here would be a second, partial description of a thing that already has a
## complete one.
signal map_changed

# --- Boss -------------------------------------------------------------------
signal boss_engaged(boss: Node3D)
signal boss_phase_changed(phase: int)
signal boss_defeated

# --- The run: bag, extraction, economy --------------------------------------
## A run began. `run_seed` is recorded so it can be replayed.
signal run_started(run_seed: int)
## A run ended. `extracted` false means the player died and the bag is gone.
##
## `contents` is what was in the bag AS THE RUN ENDED -- on an extraction that
## means components included, before `Run.bank_components` sorts them out to the
## bench. The fuller picture (the fee, the kill count, the floor, what killed you)
## is on `Run.summary`, which `RunEndScreen` reads; this signal stays three
## arguments because everything else that listens only wants to know THAT a run
## ended.
signal run_ended(extracted: bool, contents: Dictionary, value: int)
## The carried bag changed. `value` is what the vendor would pay for it.
signal bag_changed(bag: Dictionary, value: int)
signal loot_gained(item_id: StringName, count: int)
signal bag_full
signal gold_changed(gold: int)
signal items_sold(sold: Dictionary, paid: int)
## Manual recipe pins changed, or a reset/load replaced the saved set. No
## payload: listeners recompute current ingredients from the live catalogues.
signal wishlist_changed
## Deleted 2026-08-09: `extract_refused`. It meant "you tried to leave and could
## not afford the fee", and no code can reach that state any more -- the fee is
## capped at the purse (`Run.extract_charge`), so the rope always works. It is
## named here rather than silently removed because a signal that cannot fire is
## worse than none: the next reader takes it as evidence of a failure state the
## game still has.
##
## The Escape Rope was used from the menu. The hero's rope node picks this
## up and starts the channel — the menu deliberately does not reach into the
## hero, because the menu exists in scenes that have no hero at all.
signal escape_rope_used
## Something hit him on the way out. The run continues.
signal escape_rope_broken
signal depth_changed(depth: int)
## You took the stair down. `level` is the floor you are now standing on, 1-based
## and endless. Everything that gets harder or richer with depth reads this
## through `Prog` -- see scripts/core/progression.gd.
signal level_changed(level: int)
## You are STANDING on that floor and can see it. Emitted by `Flow` on the frame
## the loading card starts lifting, once for every arrival in the dungeon --
## walking in and taking the stair both.
##
## A second signal beside `level_changed` rather than a reuse of it, because the
## two fire a full transition apart. `Run.enter()` and `Run.descend_floor()` both
## emit `level_changed` BEFORE the fade, which is the right moment for anything
## that has to be correct when the new floor builds (the generator, the HUD's
## numbers) and the wrong one for anything the player is supposed to read: an
## announcement started there spends its whole life behind a black screen. This
## is the arrival, and the HUD's floor card is what waits for it.
signal floor_arrived(level: int)
## The workbench stock changed: a run banked components on the way home, or the
## forge ate some. `stock` is `Game.components` -- id -> count. Emitted rather
## than polled because the forge screen and the pouch both draw it and neither
## should be asking every frame.
signal components_changed(stock: Dictionary)
## A run reached home and its components moved to the workbench. `moved` is
## id -> count. The arrival report says so; nothing else needs to care.
signal components_banked(moved: Dictionary)
## A forge rung was bought. `track` is a Game.FORGE_* id, `level` the new rung.
## The gear does not listen -- it reads Game on spawn -- but the smith screen and
## anything that wants to celebrate do.
signal gear_forged(track: StringName, level: int)
## Something went into or came out of the footlocker in the hero's quarters.
## `stock` is `Game.stash` -- id -> count. Same contract as `components_changed`:
## the shelf is drawn by a screen and by nothing that should poll it.
signal stash_changed(stock: Dictionary)
## The hero slept. Fired after the heal and the save, on the frame the world
## comes back, so a listener that wants to say something says it to a screen the
## player can see. `slot` is where the rest was written, or -1 if all three slots
## were spoken for and the autosave declined (`Saves.autosave`).
signal rested(slot: int)

# --- Bottles and draughts (docs/METAGAME.md §6.6) ---------------------------
## A bottle was blown, filled or drunk. `contents` is `Game.bottle_contents` --
## the whole array, because its SIZE is how many bottles there are and a signal
## that carried only the changed index would make every listener keep a count of
## its own.
signal bottles_changed(contents: Array)
## A draught went down. `potion` is a PotionDb id. Fired for all three, lasting
## or not, so the feel layer has one thing to listen to.
signal potion_drunk(potion: StringName)
## A lasting draught started, or ran out (`seconds_left` 0.0). NOT emitted every
## frame while it runs -- the HUD reads `Game.draught_left()` as it draws, the
## same way it reads health.
signal draught_changed(potion: StringName, seconds_left: float)

# --- Rations and the meal (docs/METAGAME.md §6.4) ---------------------------
## A ration stack changed -- bought, or a mouthful started. `stock` is
## `Game.rations` whole, for `bottles_changed`'s reason: which ids are non-empty
## is what the carry ring is made of, and a listener that had to keep its own
## tally of that would be the second copy of it.
signal rations_changed(stock: Dictionary)
## The hero sat down to eat (`seconds_left` == K.MEAL_TIME), stood up again
## (`ration` `&""`), or crossed a tick.
##
## Emitted per TICK rather than per frame, which is the same bargain
## `draught_changed` strikes: the HUD reads `Game.meal_progress()` as it draws,
## and what a listener actually needs an edge for is the sitting and the standing.
## The hero listens to exactly those two to take the seated pose.
signal meal_changed(ration: StringName, seconds_left: float)

# --- Heat: momentum, and what it is worth -----------------------------------
## The chain moved. `window01` is how much of the current tier's window is left,
## so a listener can draw the countdown without polling Heat every frame.
signal heat_changed(kills: int, tier: int, window01: float)
## The tier stepped. `rising` false means it cooled out or a blow broke it --
## a blow he BLOCKS never gets here, because blocking costs no health and health
## is what Heat watches.
signal heat_tier_changed(tier: int, rising: bool)
## Loot was swept hot: `gold` is what the heat added on top of its base value.
## Already folded into Run.premium by the time this fires.
signal heat_banked(gold: int)

# --- Interaction and screens ------------------------------------------------
## The "(E) OPEN" line, or "" when there is nothing to address. One at a time --
## Prompt decides which.
signal prompt_changed(text: String)
## The focused Interactable's hold, 0..1, and whether the thing in reach wants a
## hold at all. Emitted by `Prompt` on every change INCLUDING the change to zero,
## so a listener never has to poll and never has to guess when a hold ended.
##
## `required` is separate from the number on purpose: the HUD draws an empty
## track the moment something hold-gated is in reach, which is what tells the
## player it is a hold BEFORE they press and fail. See `HoldGauge`.
signal hold_changed(t01: float, required: bool)
## A full-screen UI took or gave back input. `id` is e.g. &"trade".
signal screen_opened(id: StringName)
signal screen_closed(id: StringName)
## The player picked up a pad, or went back to the keyboard. Emitted by
## `Settings`, which watches raw input for it, and only on the CHANGE. Every
## surface that names a button to the player listens: the HUD's key caps, its
## garrison legend, and the interact prompt. Nothing else should be deciding for
## itself what the player is holding.
signal input_device_changed(using_pad: bool)

# --- Presentation -----------------------------------------------------------
## Requests for the feel layer. Emitters do not care who answers.
signal request_hitstop(frames: int)
signal request_shake(strength: float, duration: float)
## A DIRECTIONAL shove of the view, away from `dir` (a world-space unit vector
## pointing from the impact towards the victim). `request_shake` says how hard;
## this says which way, which is the half an over-the-shoulder camera cannot
## give you for free -- see `Feel.punch`.
signal request_punch(dir: Vector3, strength: float, duration: float)
signal request_sfx(id: StringName, position: Vector3)
signal request_message(text: String)
signal item_get_started(item_id: StringName, world_pos: Vector3)
signal item_get_finished(item_id: StringName)

# --- Global audio -----------------------------------------------------------
## A non-positional one-shot that must read at the same level everywhere. Sfx
## owns the pooled AudioStreamPlayer implementation; callers name only the cue.
signal request_global_sfx(id: StringName)

# --- Field Notes ------------------------------------------------------------
signal field_observation_recorded(observation_id: StringName)
signal field_notes_awarded(observation_ids: Array[StringName], balance: int)
signal doctrine_purchased(doctrine_id: StringName, balance: int)
