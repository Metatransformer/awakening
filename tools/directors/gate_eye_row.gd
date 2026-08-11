extends RefCounted
## Cards #27 and #43 — **the gate room's eye row: aimed at, and paid for by the
## room it stands in.**
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/gate_eye_row.gd \
##     --out=/tmp/eyes/x.png --warmup=60 --gate-prefab=eye_row
##
## `Dungeon.GATE_PREFABS` has three entries and the seed picks one, so this file
## forces `eye_row` on the command line for the same reason `--gate-prefab`
## exists at all: a director that photographed whichever prefab its seed drew
## would leave the other two shipping unproven.
##
## `CLAUDE.md` §4 is the reason the first half of this file exists, and its last
## line is the instruction: **render it and look.** This project has shipped art
## facing the wrong way three times — the hero rig, the weapon socket, the entire
## monster roster — and every one of them did it under a code comment asserting
## the facing was already right. So nothing here is asked of the placer's
## arithmetic. Every claim is made against the built node's own
## `global_transform`, or against a ray fired through the world, or against the
## frame.
##
## `docs/PUZZLES.md` §0 rule 2 is the reason the second half exists: *every
## puzzle room is solvable from a cold start with an empty pouch, because the
## urns beside it hold exactly what it needs.* The row is three eyes that only an
## arrow opens, standing **in the doorway the floor continues through**, and it
## shipped with no arrows in the room — the dead end card #29 fixed at the
## shortcut, on a door there is no walk-around for.
##
## **The claim is the empty quiver, and a run that starts with arrows proves
## nothing at all.** `tools/directors/charge_supply.gd` is the model: it grants
## the item and never its ammunition. So does this. `Game.reset()` zeroes
## `arrows`, the Bow is the only thing granted, and **every arrow fired below came
## out of the urn** — there is no `Game.add_arrows` anywhere in this file, and a
## single one would make the rest of it meaningless.
##
## What it claims, in the order it proves them:
##
##   A  Floor 2's gate room drew the eye row: three `EyeSwitch`es, named
##      `GateEye0..2`, all three of them inside the room's own footprint rather
##      than in the masonry at either end of the wall they are spread along.
##   B  Every eye stands at **2.05 m** — `Dungeon.EYE_Y`, the same height the
##      shortcut's eye and `convert_arrow.gd`'s pair use. Above the sword's
##      reach, below the sconces, and where a bow is already aimed. They were
##      at `y = 0`, which is a switch lying on the floor.
##   C  Every pupil looks INTO the room. Measured twice and derived never: the
##      node's own forward (`-basis.z`) against the way to the middle of the
##      room, and a ray fired out of the eye along that forward, which is a
##      metre and a half of clear air when it is right and four centimetres of
##      stone when it is not.
##   D  A hero standing where the puzzle is answered from has an unblocked line
##      to all three (`Dungeon.WALL_STANDOFF` — card #5's lesson: an atom flush
##      to `KitWall` renders perfectly and cannot be hit). **This beat is also
##      what proves the new urn is clear of the firing line**: it runs with the
##      pot already in the world, so a supply parked in front of the row would
##      come back as a blocked line naming `GateUrn`.
##   E  The room brings its own ammunition. A `GateUrn` holding **six** arrows —
##      `Dungeon.EYE_ROW_ARROWS`, two per eye — off the door line and on the near
##      side of the gate.
##   F  Cold start. The quiver is at zero, the Bow is in his hand, and the
##      trigger will not even raise it (`HeroRanged._draw_bow` checks the quiver
##      on the press). Photographed, because that counter reading zero *before*
##      the urn is the whole card.
##   G  **The sword breaks the urn**, from a real swing at real reach, and a
##      bundle falls out. The quiver is still zero: it is a pickup, not a grant.
##      Walking onto it fills it to six.
##   H  A miss costs an arrow. One real shot, aimed a metre and a half under the
##      eye on purpose, spends one and opens nothing — which is what the second
##      arrow per eye is for.
##   I  Three real shots into three eyes wake the key, and the quiver still has
##      something in it afterwards.
##
## ## Why every shot goes through the trigger now
##
## The old beat E built an `Arrow` and called `launch()` on it. That proves the
## geometry and it cannot prove the supply: nothing in that path touches
## `Game.spend_ammo`, so a director written that way would pass identically
## against the version of `_gate_eye_row` that had no urn in it. Every shot below
## is `heavy` pressed and released on the real bow, so the arrows are the room's
## and the count is the game's rather than this file's.
##
## ## Why the counter was missing, and what it was, measured 2026-08-11 (#52)
##
## The card asked for the arrow counter photographed at zero before the urn and
## non-zero after, and the first pair of frames did not have one. This file
## reported that as "the numeral is never drawn" and card #52 was opened against
## `Hud._draw_hands`. **The HUD was innocent.** `hud_lookdev.gd`'s
## `h_13_quiver_empty` / `h_14_quiver_six` show the same numeral at 0 and at 6 at
## a true 1280x720, in `Pal.BONE`, exactly where the code says it is.
##
## What was wrong was HERE. `ArmamentDb.hand_count` answers about the id **in the
## hand**, and the id in the hand was `shield`: this director granted the bow and
## never touched the left hand, whose pool default (`Game.LEFT_POOL`) is the
## shield. The bow got no numeral on purpose -- a bow cell carrying the quiver's
## count would print the same number twice on one row -- so both frames were
## photographs of a shield cell, correctly showing nothing.
##
## **That last clause is what card #53 then closed** (`ArmamentDb`
## `hand_count_beside`): the bow BORROWS the numeral when the arrow cell is not
## up, so a shield-and-bow frame carries the count now and the loadout a player
## actually fights in is no longer the one with no quiver on screen. The double
## print it was guarding against is still impossible -- the borrow stops the
## moment `arrow` is in the other hand, which is the state this director puts it
## in and the reason its own assertions below are untouched by that card.
##
## F3 and G6 asserted `ArmamentDb.hand_count(&"arrow")`, a call on a **string
## literal**, which is true of the table whatever the hero is holding. That is the
## whole lesson: a check that names a constant instead of the live state passes
## while the frame beside it shows something else, and its label ("the cell's
## lookup reads zero") is then read as a claim about the cell. They ask
## `Game.armament(&"left")` now, and the quiver goes in that hand at the top of
## `run` so the claim and the pixels are the same sentence.
##
## The cost of that is the aim, and it is worth knowing about: `HeroRanged`
## builds the shot from **the camera's ray** and aims the muzzle at whatever that
## ray lands on, not down the hero's facing. The chase camera rests pitched at his
## chest, which across the room is well under an eye at 2.05 m — so a director
## that stood him in front of the row and pulled the trigger would put every arrow
## into the masonry below it, and it would look exactly like the facing bug the
## first half of this file is about. `_aim_at` steers the crosshair with the look
## stick until the camera's own ray lands on the eye. See its note.

## Floor 2 rather than floor 1: the gate room's verb ceiling is tier N-1
## (`Dungeon._gate_tier`), so floor 1's gate is T0 and the eye row cannot appear
## on it at all. Floor 2 is the first floor that draws this prefab.
const LEVEL := 2

## The same floor layout the other dungeon directors force, so all of them are
## describing one dungeon.
const SEED := 20260809

## `Dungeon.EYE_Y`, and the window this file will accept around it. Spelled out
## rather than read off `Dungeon`: this script is loaded with `-s` and a
## `preload` of anything that names an autoload takes the harness down before the
## autoloads exist (`CLAUDE.md` §3).
const EYE_Y := 2.05
const EYE_Y_TOL := 0.05

## Above the sword's reach. The looser bound, and the one that says what the
## height is FOR — `shortcut_puzzle.gd` makes the same check with the same
## number about the same atom.
const BOW_HEIGHT := 1.8

## The hero's bow muzzle, off `convert_arrow.gd`'s constant.
const MUZZLE_Y := 1.30

## How far the ray out of an eye's own forward has to travel before it is
## allowed to hit anything. An eye turned into the wall stops in about four
## centimetres — the standoff is 0.55 m and its own plate reaches 0.20 m forward
## — so a metre is far more than enough to tell the two cases apart and far less
## than the room is deep.
const CLEAR_AHEAD := 1.0

## `Dungeon.EYE_ROW_ARROWS`, spelled out for the reason `EYE_Y` is. Three eyes,
## two arrows each: every required shot may be missed once, which is the ratio
## `ShortcutCache` was given for one pillar (`docs/PUZZLES.md` §5.1).
const SUPPLY := 6
const EYES := 3

## How close the hero stands to swing at the urn. `charge_supply.gd`'s number:
## the blade is an `Area3D` and `HeroCombat._maybe_hit` gates on a 130-degree
## arc, so this is "within a sword's length, facing it" and nothing cleverer.
const SWING_AT := 1.15

## How far back the row is answered from. Far enough that all three eyes are in
## front of him rather than one being 80 degrees off his shoulder, and inside the
## bow's comfortable range: at this distance the drop is about 9 cm against an
## eye plate 0.92 m across.
const SHOOT_FROM := 8.0

## The deliberate miss, in metres below the eye. Well under the plate's own
## half-height (0.46 m) and well above the floor, so it lands on the wall the eye
## is set into — a shot that plainly went at the row and plainly did not open it.
const MISS_DROP := 1.5

var out := ""
var _fails := 0


func run(rig) -> void:
	out = rig.arg("out", "/tmp/eyes/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if rig.scene().name != &"DungeonRun":
		print("EYES FAIL wrong host scene (%s) -- pass "
			% rig.scene().name
			+ "--scene=res://scenes/rooms/dungeon.tscn")
		return

	# **The cold start, and it is card #43.** `reset` zeroes `arrows`
	# (`game_state.gd:~288`); the only thing granted below is the ITEM, never its
	# ammunition. The Bow is needed because `PuzzleAtoms.pool` takes the minimum
	# of the shape's ceiling and what the player owns (§0 rule 1) -- without it
	# the eye row is not in the pool and the room draws the sun nest instead.
	Game.reset()
	Run.enter(SEED)
	Game.grant(&"bow")
	# **The quiver into the LEFT hand**, which is the cell that counts arrows
	# (`ArmamentDb.hand_count`). Without this the hand holds `Game.LEFT_POOL`'s
	# default shield and there is no counter anywhere on the screen -- which is
	# what card #52 was opened about, against the HUD. See the class note.
	#
	# `arrow` is only owned once the bow is (`Game.armament_owned`), so this has to
	# come after the grant; `cycle_armament` skips what is not owned, which is why
	# it is a loop over the pool and not one step.
	for _i in Game.LEFT_POOL.size():
		if Game.armament(&"left") == &"arrow":
			break
		Game.cycle_armament(&"left")

	var d := await _rebuild(rig, LEVEL)
	if d == null:
		print("EYES FAIL the dungeon did not build")
		return
	var hero: Node3D = _hero(rig)
	var cam := _game_camera(rig)
	if hero == null or cam == null:
		print("EYES FAIL no hero or no GameCamera in the scene")
		return
	cam.make_current()
	_clear_the_floor(d)
	await rig.wait_frames(20)

	var gate: Node = d.anchor_node(&"gate_room")
	_ck("A0 floor %d has a gate room" % LEVEL, gate != null)
	if gate == null:
		return
	var cell: Vector2i = d.anchor_cell(&"gate_room")
	var root: Node3D = d.rooms[cell]["node"]
	var half: float = float(d.size_of(cell)) * 0.5

	var eyes: Array[Node3D] = []
	for i in EYES:
		var e := root.get_node_or_null(NodePath("GateEye%d" % i)) as Node3D
		if e != null:
			eyes.append(e)
	_ck("A1 it drew the eye row -- three eyes (%d)" % eyes.size(),
		eyes.size() == EYES)
	if eyes.size() != EYES:
		print("EYES FAIL pass --gate-prefab=eye_row; this floor drew "
			+ "something else")
		return

	# In the ROOM, not in the wall at either end of it. The row is spread 3.2 m
	# apart along a wall whose half-width is `half`, so a room that ever gets
	# smaller puts the outer two inside the masonry -- and that failure looks
	# exactly like the two facing bugs this file is here about.
	var inside := 0
	for e: Node3D in eyes:
		var local := root.to_local(e.global_position)
		if absf(local.x) < half - 0.5 and absf(local.z) < half - 0.5:
			inside += 1
	_ck("A2 and all three stand inside the room's %.1f m footprint (%d/3)"
		% [half * 2.0, inside], inside == EYES)

	# --- B and C. Height and facing ------------------------------------------
	var high := 0
	var looking := 0
	var clear_ahead := 0
	for i in eyes.size():
		var e: Node3D = eyes[i]
		# The node's own forward, off the transform the renderer uses. Not the
		# yaw the placer wrote, and not a bone rest pose (`CLAUDE.md` §4).
		var fwd := -e.global_transform.basis.z
		# The way from the eye to the middle of the room it is supposed to be
		# watching. `root` sits at the room's centre (`Dungeon._build_room`).
		var into := K.flat(root.global_position - e.global_position).normalized()
		var dot := fwd.dot(into)
		var ahead := _ray(e, e.global_position, fwd * (CLEAR_AHEAD + 0.2))
		print("EYES GateEye%d at %.2f,%.2f,%.2f  fwd %.2f,%.2f  "
			% [i, e.global_position.x, e.global_position.y, e.global_position.z,
				fwd.x, fwd.z]
			+ "into-room %.2f,%.2f  dot %.2f  clear ahead %.2f m"
			% [into.x, into.z, dot, ahead])
		if absf(e.global_position.y - EYE_Y) < EYE_Y_TOL \
				and e.global_position.y > BOW_HEIGHT:
			high += 1
		if dot > 0.9:
			looking += 1
		if ahead >= CLEAR_AHEAD:
			clear_ahead += 1
	_ck("B0 every eye stands at %.2f m, above the sword and at the bow (%d/3)"
		% [EYE_Y, high], high == EYES)
	_ck("C0 every pupil's own forward points into the room (%d/3)" % looking,
		looking == EYES)
	_ck("C1 and there is a clear metre of air in front of each of them, "
		+ "not stone (%d/3)" % clear_ahead, clear_ahead == EYES)

	# The wide shot: the hero standing where the row is answered from, with all
	# three eyes and the gate door in one frame. This is the frame `CLAUDE.md`
	# §4 asks for and no check replaces it -- an eye in the wall photographs as
	# a wall.
	await _stand_off(rig, hero, eyes[1], 7.0)
	await rig.capture(out.path_join("g_01_eye_row.png"))
	await _stand_off(rig, hero, eyes[1], 3.4)
	await rig.capture(out.path_join("g_02_eye_close.png"))

	# --- D. Reachable --------------------------------------------------------
	await _stand_off(rig, hero, eyes[1], SHOOT_FROM)
	var reachable := 0
	for i in eyes.size():
		if _clear_line(hero, eyes[i]):
			reachable += 1
	_ck("D0 an arrow can actually get to all three from one spot (%d/3)"
		% reachable, reachable == EYES)

	# --- E, F, G, H, I. The empty quiver, and what the room does about it -----
	var door: Node3D = root.get_node_or_null(^"GateDoor") as Node3D
	var pot: Node3D = root.get_node_or_null(^"GateUrn") as Node3D
	_e_the_room_brings_it(door, pot, eyes)
	await _f_the_cold_start(rig, hero, eyes[1])
	if pot == null:
		print("EYES FAIL -- there is nothing in the room to break")
		return
	await _g_the_sword_breaks_it(rig, hero, pot, door)
	if Game.arrows <= 0:
		print("EYES FAIL -- the quiver is still empty; nothing below can run")
		return
	await _h_a_miss_costs_an_arrow(rig, hero, cam, eyes[1])
	await _i_three_arrows_three_eyes(rig, hero, cam, root, eyes)

	if _fails == 0:
		print("EYES ok -- every check passed")
	else:
		print("EYES FAIL -- %d check(s) failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("EYES ok %s" % label)
	else:
		_fails += 1
		print("EYES FAIL %s" % label)


# --- E. The room brings its own ammunition ------------------------------------

## Measured off the DOOR's own transform rather than off the placer's `spot`,
## which this file never sees: `gate.rotation.y` is the wall's yaw, so
## `basis.z` is `Dungeon.facing_of(yaw)` (into the room) and `basis.x` is
## `along_of(yaw)` (across the doorway). That is `docs/CONTRACT.md` §2.5 read off
## the node, which is the only way this project is allowed to read a facing.
func _e_the_room_brings_it(door: Node3D, pot: Node3D, eyes: Array[Node3D]) -> void:
	_ck("E0 the gate room places an urn beside the row", pot != null)
	if pot == null or door == null:
		return
	_ck("E1 and the placer decided what is inside (holds=%s)"
		% pot.get(&"holds"), StringName(pot.get(&"holds")) == &"arrows")
	# The sizing, and it is the half of this card that a screenshot cannot show.
	# One arrow per eye is three shots that all have to land; two per eye is the
	# ratio `ShortcutCache` was given for one pillar, applied to a row of three.
	_ck("E2 and it holds two arrows per eye, not one (%d for %d eyes)"
		% [int(pot.get(&"amount")), eyes.size()],
		int(pot.get(&"amount")) == SUPPLY)

	var facing := door.global_transform.basis.z
	var along := door.global_transform.basis.x
	var from_door := pot.global_position - door.global_position
	var side := absf(along.dot(from_door))
	var out_from := facing.dot(from_door)
	print("EYES urn stands %.2f m off the door line and %.2f m out from it"
		% [side, out_from])
	# The doorway is 2.4 m wide and `LockedDoor`'s leaves swing INTO the room, so
	# anything within ~1.2 m of the centre line is either in the opening the floor
	# continues through or under a leaf.
	_ck("E3 and it is off the door line, clear of the leaves (%.2f m)" % side,
		side > 1.4)
	# On the near side: the side the player is standing on when the door refuses
	# him. Behind him is the wall; in front of him, up the room, is the row.
	_ck("E4 on the NEAR side of the gate, where the refusal is read (%.2f m)"
		% out_from, out_from > 0.5 and out_from < 5.0)
	# And well behind the firing line. Beat D already fired a ray from the
	# shooting spot to each eye with this pot in the world, so a supply parked in
	# the middle of the room would have come back as a blocked line naming it --
	# this is the same claim as a distance, so a later room shrink says which.
	var deepest := 0.0
	for e: Node3D in eyes:
		deepest = maxf(deepest, facing.dot(e.global_position - door.global_position))
	_ck("E5 and it sits %.1f m behind the row it supplies, not in front of it"
		% (deepest - out_from), deepest - out_from > 4.0)


# --- F. The cold start ---------------------------------------------------------

## The frame the whole card is about: the counter at **zero**, with the Bow in his
## hand and the row in front of him. Everything after this is the room filling it.
func _f_the_cold_start(rig, hero: Node3D, at: Node3D) -> void:
	_ck("F0 the quiver is EMPTY (%d/%d)" % [Game.arrows, Game.max_arrows],
		Game.arrows == 0)
	var drawn: bool = await rig.draw_weapon(&"bow")
	_ck("F1 and the Bow is still in the right hand -- owning it is not the "
		+ "problem", drawn)
	# The dead end, said by the game rather than by this file. `_draw_bow` checks
	# the quiver ON THE PRESS and plays `craft_fail`, so the bow never even comes
	# up -- which is exactly the state a player was stuck in before this card, in
	# a doorway with no way round it.
	await _stand_off(rig, hero, at, SHOOT_FROM)
	Input.action_press(&"heavy")
	await rig.wait_frames(30)
	var raised := StringName(hero.call(&"aim_item"))
	Input.action_release(&"heavy")
	await rig.wait_frames(12)
	_ck("F2 and the trigger will not raise the bow on an empty quiver (stance=%s)"
		% raised, raised != &"bow")
	# The state, photographed BEFORE the urn. Taken with the bow in hand on
	# purpose: `ArmamentDb.hand_count` puts the arrow count on the left-hand cell
	# of the bow's set, so a frame taken with the sword out would photograph a
	# sword and prove that the checks had run.
	#
	# Asked of `Game.armament(&"left")` -- THE HAND -- and not of the string
	# `&"arrow"`. The literal version of this line passed for a run in which the
	# hero was holding a shield (#52, and the class note).
	var counted := ArmamentDb.hand_count(Game.armament(&"left"))
	_ck("F3 and the cell counts them, at zero (%s hand, %s = %d)"
		% [Game.armament(&"left"), counted, Game.ammo_count(&"arrows")],
		counted == &"arrows" and Game.ammo_count(&"arrows") == 0)
	await rig.capture(out.path_join("g_03_empty_quiver.png"))


# --- G. The sword breaks it ----------------------------------------------------

## Swung, not `apply_hit`ed — `charge_supply.gd` beat C's finding, and it applies
## here word for word: `Urn` was "breakable by arrows only, under a comment
## claiming the opposite" for a release, because nothing had ever swung a blade at
## one. A hero standing in this room with an empty quiver has a sword and nothing
## else, and if the pot cannot be opened with it then rule 2 is still unmet.
func _g_the_sword_breaks_it(rig, hero: Node3D, pot: Node3D,
		door: Node3D) -> void:
	# The ring steps back to the sword first, the way a player would: an item owns
	# both shoulder buttons while it is drawn (`HeroCombat._tick_light_button`),
	# so with the Bow in his right hand there is no sword half to reach.
	var sheathed: bool = await rig.draw_weapon(&"sword")
	_ck("G0 the ring steps back to the sword", sheathed)

	# The frame that says WHERE the supply is: the urn, the gate it stands beside,
	# and the room they are both in, from further up the room looking back. Stood
	# so the door is central and the pot is off to one side of him -- **aimed
	# BESIDE the urn, not at it**, which is `charge_supply.gd` beat C's finding
	# and it cost that file a pass: the chase camera sits on the line behind the
	# hero, so a hero looking straight at a 90 cm pot photographs the back of his
	# own head with the pot behind it. The first version of this frame did exactly
	# that, twice.
	if door != null:
		var facing := door.global_transform.basis.z
		var along := door.global_transform.basis.x
		hero.velocity = Vector3.ZERO
		hero.global_position = pot.global_position + facing * 4.2 \
			+ Vector3(0.0, 0.15, 0.0)
		_face_at(hero, pot.global_position - along * 1.8)
		Bus.camera_recenter.emit()
		await rig.wait_physics_frames(6)
		await rig.wait_frames(28)
		await rig.capture(out.path_join("g_04_urn_in_the_room.png"))

	hero.velocity = Vector3.ZERO
	var away := K.flat(hero.global_position - pot.global_position)
	if away == Vector3.ZERO:
		away = Vector3.FORWARD
	hero.global_position = pot.global_position + away * SWING_AT \
		+ Vector3(0.0, 0.15, 0.0)
	_face_at(hero, pot.global_position)
	Bus.camera_recenter.emit()
	await rig.wait_physics_frames(6)
	await rig.wait_frames(24)

	await rig.tap([&"attack"])
	var broke: bool = await rig.until(func() -> bool:
		return bool(pot.call(&"is_solved")), 4.0)
	_ck("G1 one sword swing breaks the urn", broke)

	# **Step back off the spill before it arms.** A sword's reach is 1.15 m and
	# `ArrowBundle`'s take radius is a 0.8 m sphere against the hero's own
	# capsule, so the man who broke the pot is already standing inside the
	# pickup: the first run of this beat collected the arrows 0.35 s later
	# (`ArrowBundle.ARM_TIME`) without anyone walking anywhere, and `_walk_onto`
	# was handed a freed node. `on_solved` spills on the frame `broke` returns,
	# so there is a third of a second to get clear -- which is also the honest
	# staging, because the claim below is that walking onto it is what fills the
	# quiver.
	hero.global_position = pot.global_position + away * 3.4 \
		+ Vector3(0.0, 0.15, 0.0)
	Bus.camera_recenter.emit()
	await rig.wait_physics_frames(2)

	var bundle := await _find_bundle(rig, 4.0)
	_ck("G2 and a bundle of arrows falls out of it", bundle != null)
	# The distinction the prop exists for. A grant would already have happened; a
	# pickup is a thing on the floor the player has to walk to, which is what
	# makes the PLACEMENT mean anything.
	_ck("G3 and the quiver is still empty -- it is a pickup, not a grant (%d)"
		% Game.arrows, Game.arrows == 0)
	if bundle == null or not is_instance_valid(bundle):
		return
	# Turned wide of the bundle for the same reason the urn frame is, and it is
	# worth the second helper call: three arrows and a cord on the floor are 40 cm
	# across, and the first pass of this frame photographed the hero's back with
	# the pickup's own light glowing round the edge of him.
	var side := Vector3(-away.z, 0.0, away.x).normalized()
	_face_at(hero, bundle.global_position + side * 1.8)
	Bus.camera_recenter.emit()
	await rig.wait_physics_frames(4)
	await rig.wait_frames(34)
	await rig.capture(out.path_join("g_05_bundle_on_the_floor.png"))

	var got: bool = await _walk_onto(rig, hero, bundle)
	_ck("G4 walking over it fills the quiver (%d/%d)"
		% [Game.arrows, Game.max_arrows], got)
	_ck("G5 and the floor gave two per eye, not one -- three misses is not a "
		+ "second dead end (%d)" % Game.arrows, Game.arrows == SUPPLY)
	# Non-zero now, in the same cell and the same stance as F3, so the two frames
	# differ in one thing only. The ring goes back on the bow BEFORE the shutter
	# for that reason.
	var back_on_the_bow: bool = await rig.draw_weapon(&"bow")
	var counted := ArmamentDb.hand_count(Game.armament(&"left"))
	_ck("G6 and the cell counts them, at six (bow in hand=%s, %s hand, %s = %d)"
		% [back_on_the_bow, Game.armament(&"left"), counted,
			Game.ammo_count(&"arrows")],
		back_on_the_bow and counted == &"arrows"
		and Game.ammo_count(&"arrows") == SUPPLY)
	await rig.wait_frames(24)
	await rig.capture(out.path_join("g_06_quiver_filled.png"))


# --- H. A miss costs an arrow --------------------------------------------------

## What the second arrow per eye is for, fired rather than argued.
##
## Aimed a metre and a half UNDER the middle eye, at the wall it is set into: an
## unambiguous miss that plainly went at the row. The check is that it cost one
## arrow and opened nothing — because a supply sized at one per eye would, at this
## point, have left the player with two arrows for two remaining eyes and no
## margin at all.
func _h_a_miss_costs_an_arrow(rig, hero: Node3D, cam: Camera3D,
		eye: Node3D) -> void:
	await _stand_off(rig, hero, eye, SHOOT_FROM)
	var before := Game.arrows
	var at := eye.global_position - Vector3(0.0, MISS_DROP, 0.0)
	var fired := await _loose(rig, hero, cam, at)
	_ck("H0 the bow comes up and looses with arrows in the quiver", fired)
	_ck("H1 the shot went a metre and a half low and opened nothing",
		not bool(eye.call(&"is_solved")))
	_ck("H2 and it cost an arrow all the same (%d -> %d)"
		% [before, Game.arrows], before - Game.arrows == 1)
	# **And a look at where it went, quickly.** `Arrow.LINGER` is 2.5 s, so the
	# shaft in the masonry is gone inside three seconds of landing -- this is the
	# one frame in the file with a clock on it. Stood off to one side of the
	# impact rather than square in front of it, so the arrow is beside his
	# silhouette rather than behind it, and back far enough that the eye it did
	# NOT open is in the same frame as the arrow that did not reach it.
	var fwd := -eye.global_transform.basis.z
	var side := Vector3(-fwd.z, 0.0, fwd.x).normalized()
	hero.velocity = Vector3.ZERO
	# Along the wall, not out from it, and both halves of that took a run to find.
	# Square in front of the impact the arrow is end-on — it flew away from the
	# lens, so 70 cm of shaft is four pixels of nub. From down the wall it is in
	# profile. And the turn is PAST the impact rather than at it, because the
	# chase camera rides the hero's own heading: wherever he is put, the thing he
	# looks at comes back to the middle of the frame with his head in front of it.
	hero.global_position = at + fwd * 2.5 + side * 7.0
	hero.global_position.y = 0.15
	_face_at(hero, at - side * 2.0)
	Bus.camera_recenter.emit()
	await rig.wait_physics_frames(4)
	await rig.wait_frames(16)
	await rig.capture(out.path_join("g_07_the_miss.png"))


# --- I. Three arrows, three eyes -----------------------------------------------

func _i_three_arrows_three_eyes(rig, hero: Node3D, cam: Camera3D,
		root: Node3D, eyes: Array[Node3D]) -> void:
	var key: Node = root.get_node_or_null(^"GateKey")
	_ck("I0 the room has a small key", key != null)
	if key != null:
		_ck("I1 and no eye of three has woken it yet (§3, all of them)",
			not key.visible)

	var spent := 0
	var lit := 0
	for i in eyes.size():
		var e: Node3D = eyes[i]
		if bool(e.call(&"is_solved")):
			lit += 1
			continue
		# Stood off each eye in turn, because the row is 6.4 m wide and the outer
		# two are 40 degrees off the shoulder from the middle one -- a player
		# walks the line rather than pivoting on the spot, and a director that
		# did not would be measuring the camera's yaw limits.
		await _stand_off(rig, hero, e, SHOOT_FROM)
		var before := Game.arrows
		var went := await _loose(rig, hero, cam, e.global_position)
		var opened: bool = await rig.until(func() -> bool:
			return bool(e.call(&"is_solved")), 3.0)
		spent += maxi(0, before - Game.arrows)
		print("EYES shot at GateEye%d: loosed=%s opened=%s quiver %d -> %d"
			% [i, went, opened, before, Game.arrows])
		if opened:
			lit += 1
	_ck("I2 three real shots opened three eyes (%d/3)" % lit, lit == EYES)
	_ck("I3 and they came out of the quiver the urn filled (%d spent)" % spent,
		spent >= EYES)

	await rig.wait_frames(30)
	if key != null:
		_ck("I4 all three lit wakes the key", key.visible
			and bool(key.get(&"armed")))
	# The margin, stated as a number rather than as a feeling: the row cost four
	# arrows including the deliberate miss, out of six.
	_ck("I5 and the room's own six paid for the row with %d left over"
		% Game.arrows, Game.arrows > 0)
	await _stand_off(rig, hero, eyes[1], 7.0)
	await rig.capture(out.path_join("g_08_row_lit.png"))


# --- The shot -----------------------------------------------------------------

## One real bow shot at `at`: raise, aim, loose. Returns whether an arrow left.
##
## `heavy` and not a call into `HeroRanged`, for `charge_supply.gd` beat E's
## reason — what this beat is proving is the QUIVER, and a director that bypassed
## the item would never touch `spend_ammo`, so "it cost an arrow" would be a
## sentence this file wrote rather than one the game did.
func _loose(rig, hero: Node3D, cam: Camera3D, at: Vector3) -> bool:
	var before := Game.arrows
	if not await rig.draw_weapon(&"bow"):
		return false
	Input.action_press(&"heavy")
	# Long enough for the pull to reach full draw and park there
	# (`HeroRanged._tick_bow`), and for the aim stance's camera blend to finish.
	await rig.wait_frames(40)
	var aimed := await _aim_at(rig, hero, cam, at)
	if not aimed:
		print("EYES the crosshair never reached %.2v -- the shot below is not "
			% at + "a measurement of anything")
	Input.action_release(&"heavy")
	return await rig.until(func() -> bool: return Game.arrows < before, 3.0)


## Steer the crosshair onto `at` with the look stick, and stop when the camera's
## own ray lands there.
##
## **This is not a harness convenience, it is the aim model.**
## `HeroRanged._aim_from` casts a ray from the CAMERA along the camera's forward
## and points the muzzle at whatever it hits — so the shot goes where the lens is
## pointed and not where the hero is facing. The chase camera rests pitched at his
## chest (`K.CAM_PITCH`), which across a room is a metre and a half under an eye
## at 2.05 m; every trigger-fired arrow in the first draft of this beat went into
## the masonry below the row.
##
## Driven through `cam_up` / `cam_down` / `cam_left` / `cam_right` rather than by
## writing `GameCamera._pitch`, for two reasons that agree: those are the actions
## a player has, and `GameCamera._apply_look` **polls** them with
## `Input.get_vector` rather than reading events — so `Input.action_press` is the
## honest path here and not the trap `CLAUDE.md` §3 warns about.
##
## The signs are derived from the rig and not guessed. The camera's forward is
## `-_orbit_dir(_yaw, _pitch)`, so `forward.y == -sin(pitch)`: pressing `cam_up`
## drives `_pitch` down and the lens up. Its heading is `atan2(fwd.x, fwd.z)`,
## which equals `_yaw + PI`, and `cam_right` *decreases* `_yaw` — so a target to
## the left of the crosshair wants `cam_left`, and the arithmetic below says so
## rather than a comment claiming it.
##
## The stop is a RAYCAST and not an angle. The stick moves ~2.8 degrees a frame
## at `stick_speed_deg`, which is finer than an eye plate subtends at this range
## (about 3.3 degrees of half-angle at 8 m) but coarse enough that an angular
## tolerance would sit and oscillate. "The crosshair is on the thing" is the
## condition `_aim_from` actually cares about, so it is the one this waits for.
func _aim_at(rig, hero: Node3D, cam: Camera3D, at: Vector3,
		frames: int = 240) -> bool:
	var dead := deg_to_rad(0.8)
	var held := 0
	var ok := false
	for _i in frames:
		var from := cam.global_position
		var fwd := -cam.global_transform.basis.z
		var to := (at - from).normalized()
		var d_pitch := asin(clampf(to.y, -1.0, 1.0)) \
			- asin(clampf(fwd.y, -1.0, 1.0))
		var d_yaw := wrapf(atan2(to.x, to.z) - atan2(fwd.x, fwd.z), -PI, PI)
		_look(&"cam_up", d_pitch > dead)
		_look(&"cam_down", d_pitch < -dead)
		_look(&"cam_left", d_yaw > dead)
		_look(&"cam_right", d_yaw < -dead)
		if _crosshair_reaches(hero, cam, at):
			held += 1
			if held >= 2:
				ok = true
				break
		else:
			held = 0
		await rig.wait_frames(1)
	for a: StringName in [&"cam_up", &"cam_down", &"cam_left", &"cam_right"]:
		Input.action_release(a)
	return ok


func _look(action: StringName, want: bool) -> void:
	if want:
		Input.action_press(action)
	else:
		Input.action_release(action)


## Does the camera's own ray get within a hand's width of `at`?
##
## The same ray `_aim_from` casts, asked the same question: it walks out along the
## lens until something stops it, and the shot is aimed at that point. If the stop
## is close to the point we want, the muzzle-to-point line runs into the eye.
##
## **The hero is excluded, and that is not tidiness.** He stands between the lens
## and the crosshair, so any aim depressed far enough stops on his own back --
## which is exactly what happened the first time this file aimed a metre and a
## half under an eye for beat H: the shot went where it was told and this check
## said the crosshair had never arrived. `_aim_from` excludes him for the same
## reason and in the same words (*"every shot aims at his shoulder blades"*), so
## the two now ask one question.
func _crosshair_reaches(hero: Node3D, cam: Camera3D, at: Vector3) -> bool:
	var fwd := -cam.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.new()
	q.from = cam.global_position
	q.to = cam.global_position + fwd * 60.0
	q.collision_mask = K.L_WORLD | K.L_ENEMY | K.L_INTERACT | K.L_HOOK
	q.collide_with_areas = true
	q.exclude = [(hero as CollisionObject3D).get_rid()]
	var seen := cam.get_world_3d().direct_space_state.intersect_ray(q)
	if seen.is_empty():
		return false
	return (seen["position"] as Vector3).distance_to(at) < 0.30


# --- Rays ---------------------------------------------------------------------

## How far a ray gets out of `at` along `span` before something stops it.
## Returns the full length when nothing does.
func _ray(in_world: Node3D, at: Vector3, span: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.new()
	q.from = at
	q.to = at + span
	q.collision_mask = K.L_WORLD | K.L_INTERACT
	q.collide_with_areas = true
	# The eye's own body is on both of those layers and is 0.28 m thick around
	# the origin this fires from, so without this the answer is always "zero".
	q.exclude = _bodies_under(in_world)
	var seen := in_world.get_world_3d().direct_space_state.intersect_ray(q)
	if seen.is_empty():
		return span.length()
	return at.distance_to(seen["position"] as Vector3)


## Is there daylight between the hero's muzzle and `target`? Lifted from
## `shortcut_puzzle.gd`, and phrased the same way -- as *what stops the ray
## first*, because an atom buried in `KitWall`'s collider answers `apply_hit`
## happily and can never be shot (card #5, `Dungeon.WALL_STANDOFF`).
##
## It is also, since card #43, the check that the room's own urn is not standing
## in the firing line: it runs with the pot in the world and names whatever stops
## the ray.
func _clear_line(hero: Node3D, target: Node3D) -> bool:
	var from := hero.global_position + Vector3.UP * MUZZLE_Y
	var q := PhysicsRayQueryParameters3D.new()
	q.from = from
	q.to = target.global_position
	q.collision_mask = K.L_WORLD | K.L_ENEMY | K.L_INTERACT
	q.collide_with_areas = true
	q.exclude = [(hero as CollisionObject3D).get_rid()]
	var seen := hero.get_world_3d().direct_space_state.intersect_ray(q)
	var span := from.distance_to(target.global_position)
	if seen.is_empty():
		print("EYES line to %s: clear, %.2f m" % [target.name, span])
		return true
	var b := seen["collider"] as Node
	if b == target or target.is_ancestor_of(b):
		print("EYES line to %s: clear, %.2f m (landed on its own body)"
			% [target.name, span])
		return true
	print("EYES line to %s BLOCKED by %s (%s) %.2f m short"
		% [target.name, b.name, b.get_class(),
			(seen["position"] as Vector3).distance_to(target.global_position)])
	return false


func _bodies_under(n: Node) -> Array[RID]:
	var rids: Array[RID] = []
	for b in _every(n, func(x: Node) -> bool: return x is CollisionObject3D):
		rids.append((b as CollisionObject3D).get_rid())
	return rids


# --- Fixture ------------------------------------------------------------------

func _rebuild(rig, level: int) -> Node:
	Run.level = level
	var scene: Node = rig.scene()
	var old := scene.get_node_or_null(^"Dungeon")
	if old != null:
		old.name = "DungeonOld"
		old.queue_free()
		await rig.wait_frames(2)
	var script := load("res://scripts/world/dungeon.gd") as GDScript
	var d: Node = script.new()
	d.name = "Dungeon"
	d.seed_override = SEED
	scene.add_child(d)
	await rig.wait_frames(12)
	return d


func _clear_the_floor(d: Node) -> void:
	var freed := 0
	for e in _every(d, func(n: Node) -> bool: return n is Enemy):
		freed += 1
		e.queue_free()
	print("EYES cleared %d bodies" % freed)


## The spill lands in `get_tree().current_scene`, not under the urn -- the urn is
## about to free its own children. So this looks at the whole scene, and it polls,
## because `_spill` runs inside `on_solved` and the drop tween starts a frame
## later. `charge_supply.gd::_find_cache`, with `ArrowBundle` in the hole.
func _find_bundle(rig, seconds: float) -> Node3D:
	var waited := 0.0
	while waited < seconds:
		for n in _all(rig.scene()):
			if n is ArrowBundle:
				return n as Node3D
		await rig.wait_frames(2)
		waited += 2.0 / 60.0
	return null


## Step the hero onto `bundle` with `test_move` against the real collision, and
## report whether the quiver moved. `charge_supply.gd::_walk_onto`, and it is a
## walk rather than a teleport for that file's reason: `ArrowBundle` is an
## `Area3D` polling `get_overlapping_bodies()` for group `player`, so putting the
## hero on top of it would prove the overlap and not the pickup.
func _walk_onto(rig, hero: Node3D, bundle: Node3D) -> bool:
	var before := Game.arrows
	var target := bundle.global_position
	for _i in 240:
		if not is_instance_valid(bundle):
			break
		if Game.arrows > before:
			break
		# `K.plane`, NOT `K.flat` -- `flat` normalises, so an arrival test written
		# against it never fires (`cistern_floor.gd`'s fourth).
		var to := K.plane(target - hero.global_position)
		if to.length() > 0.25:
			var step := to.limit_length(0.25)
			hero.velocity = Vector3.ZERO
			if not hero.test_move(hero.global_transform, step):
				hero.global_position += step
			else:
				var side := Vector3(-step.z, 0.0, step.x).normalized() * 0.25
				if not hero.test_move(hero.global_transform, side):
					hero.global_position += side
				else:
					hero.global_position -= side
		await rig.wait_frames(2)
	return Game.arrows > before


## Out along the atom's own FORWARD, which is the side an atom aimed at the
## player stands on -- the opposite of a door's convention, and getting the two
## the wrong way round puts the camera inside masonry (`puzzle_loop.gd` has the
## same pair of helpers and the same note).
func _stand_off(rig, hero: Node3D, at: Node3D, back: float) -> void:
	hero.velocity = Vector3.ZERO
	hero.global_position = at.global_position \
		- at.global_transform.basis.z * back
	hero.global_position.y = 0.15
	_face_at(hero, at.global_position)
	Bus.camera_recenter.emit()
	await rig.wait_physics_frames(6)
	await rig.wait_frames(24)


## `rotation.y = heading + PI`, which is `docs/CONTRACT.md` §2.5 and `CLAUDE.md`
## §4: a Node3D's forward is `-basis.z`, so the body is turned half a circle past
## the heading to point down it.
func _face_at(hero: Node3D, at: Vector3) -> void:
	var to := K.flat(at - hero.global_position)
	if to == Vector3.ZERO:
		return
	hero.facing_yaw = atan2(to.x, to.z)
	hero.rotation.y = hero.facing_yaw + PI


func _hero(rig) -> Node3D:
	var players: Array = rig.get_nodes_in_group(&"player")
	return players[0] if not players.is_empty() else null


func _game_camera(rig) -> Camera3D:
	for n in _all(rig.scene()):
		if n is GameCamera:
			return n
	return null


func _all(root: Node) -> Array:
	var found := [root]
	for c in root.get_children():
		found.append_array(_all(c))
	return found


func _every(root: Node, pred: Callable) -> Array:
	var found: Array = []
	for n in _all(root):
		if pred.call(n):
			found.append(n)
	return found
