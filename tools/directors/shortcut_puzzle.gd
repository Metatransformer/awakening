extends RefCounted
## `docs/PUZZLES.md` §5.1 — **the shortcut door stops being a check.**
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/shortcut_puzzle.gd \
##     --out=/tmp/shortcut/x.png --warmup=60
##
## `docs/PUZZLES.md` opens by saying why it exists: **a door that opens because
## you own item X is a check, not a puzzle.** The shortcut was the last of §5's
## three shapes still wearing one. So the claim this file makes is not "the door
## opens" — a `LockedDoor` did that — it is the pair of sentences either side of
## it:
##
##   **owning the bow opens nothing, and shooting the eye opens the door.**
##
## Beat C is the first half and it is the whole card. A director that only proved
## the second half would pass identically against the version this replaces.
##
## What it claims, in the order it proves them:
##
##   A  The pool is **exactly tier N** (§1), not "N or above". Floor 1's shortcut
##      draws the eye and nothing else — not the T0 atoms below it and not the
##      hookshot above it — because a seed that could put the hookshot on floor 1
##      silently delays GDD §5.3's ninety seconds by two floors.
##   B  Floor 1's door is a `ShortcutGate` watching one atom, wearing the bow's
##      mark, and keyed on `LockedDoor`'s PERMANENT flag — not `PuzzleGate`'s
##      per-run one. §5.1 and §5.2 want opposite lifetimes and this is the line
##      that says which.
##   C  It refuses by naming **the eye**, not the bow and not LOCKED — and it
##      goes on refusing after the Warden hands the bow over. The check is dead.
##   D  One real arrow into the eye and the door swings **by itself**.
##   E  §5.2's amendment, applied to this shape: behind it are the way down, a
##      chest, and a Votive Court offering three blessings.
##   F  The flag survives `PuzzleAtom.clear_run_flags()`. Rebuild the floor and
##      the door is open with its eye dark again — which is the ninety seconds.
##   G  Floors 2 and 3 draw the other two prefabs — the cracked pillar bracing
##      the door, the hook ring over the lintel — and floor 4 is still a plain
##      `LockedDoor`, because §1 gives the Far Lantern no verb.
##
## ## Why the frames are worth looking at even when every check passes
##
## Two of the three prefabs are placed by arithmetic against a wall whose yaw the
## seed chose, and the two atoms involved are built along **opposite** axes —
## `EyeSwitch` down its own -Z, `HookRing` out its own +Z. `CLAUDE.md` §4 records
## that this project has shipped backwards-facing art three times under a comment
## asserting it faced the right way. An eye in the wall photographs as a wall.

## Forced, so the entrance room's blank wall is the same wall every run. Shared
## with `cistern_floor.gd` on purpose: two directors disagreeing about which
## layout floor 1 has is two floors to reason about.
const SEED := 20260809

## Where the hero is put to read a door: out along the door's own +basis.z, which
## is the side a player stands on (`docs/CONTRACT.md` §2.5). Far enough back that
## the leaves and the atom beside them are both in frame, near enough that
## `LockedDoor`'s 2.9 m interact radius has him.
const READ_AT := 2.5

## The hero's bow muzzle, off `convert_arrow.gd`'s own constant. An arrow launched
## from the floor clips the doorway's sill on the way to a 2.05 m eye.
const MUZZLE_Y := 1.25

## Time scale for the shot, so the arrow is photographable in flight rather than
## a smear between two frames.
const SLOW := 0.25

var out := ""
var _fails := 0


func run(rig) -> void:
	out = rig.arg("out", "/tmp/shortcut/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	Game.reset()
	Run.enter(SEED)

	# The host scene, said out loud, because getting it wrong does not look like
	# getting it wrong — this beat ADDS a `Dungeon` to whatever it was pointed at.
	# `cistern_floor.gd` records the hour that cost.
	if rig.scene().name != &"DungeonRun":
		print("SHORTCUT FAIL wrong host scene (%s) -- pass "
			% rig.scene().name + "--scene=res://scenes/rooms/dungeon.tscn")
		return

	_a_the_pool()

	var hero: Node3D = _hero(rig)
	if hero == null:
		print("SHORTCUT FAIL there is no hero in the scene")
		return
	var cam := _game_camera(rig)
	if cam != null:
		cam.make_current()
	await rig.wait_frames(20)

	var d := await _rebuild(rig, 1)
	if d == null:
		print("SHORTCUT FAIL the dungeon did not build")
		return
	_clear_the_floor(d)

	var door: Node3D = d.anchor_node(&"shortcut_door")
	if door == null:
		print("SHORTCUT FAIL floor 1 has no shortcut door")
		return

	_b_the_door(d, door)
	await _c_the_check_is_dead(rig, hero, door)
	await _d_the_arrow(rig, d, hero, door)
	await _e_the_rewards(rig, d, hero, door)
	await _f_the_flag_is_permanent(rig)
	await _g_the_other_floors(rig, hero)

	if _fails == 0:
		print("SHORTCUT ok -- every check passed")
	else:
		print("SHORTCUT FAIL -- %d check(s) failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("SHORTCUT ok %s" % label)
	else:
		_fails += 1
		print("SHORTCUT FAIL %s" % label)


# --- A. Exactly tier N --------------------------------------------------------

## §1: *"The shortcut pool is exactly tier N. Not 'N or above'."*
##
## Asked of the `Dungeon`'s own selection rather than restated here: a director
## that reimplemented the filter would agree with itself for ever. The script is
## instanced OUTSIDE the tree, which is enough — `_shortcut_pool` reads `Run.level`
## and the atom table and touches nothing else.
func _a_the_pool() -> void:
	var script := load("res://scripts/world/dungeon.gd") as GDScript
	var probe: Node = script.new()
	var was := Run.level
	var got := {}
	for level in [1, 2, 3, 4]:
		Run.level = level
		got[level] = probe.call(&"_shortcut_pool")
		print("SHORTCUT floor %d pool -> %s (key %s)"
			% [level, got[level], FloorDb.shortcut_key(level)])
	Run.level = was
	probe.free()

	_ck("A0 floor 1 draws exactly the eye (T1)",
		got[1] == [PuzzleAtoms.EYE_SWITCH])
	_ck("A1 floor 2 draws exactly the cracked pillar (T2)",
		got[2] == [PuzzleAtoms.CRACKED_PILLAR])
	_ck("A2 floor 3 draws exactly the hook ring (T3)",
		got[3] == [PuzzleAtoms.HOOK_RING])
	# The half a `<=` pool would get wrong, and the reason §1 wrote "exactly": a
	# floor-1 shortcut holding the sun socket is one the player opens before they
	# have met the Warden, and one holding the hook ring is one they cannot open
	# for two more floors.
	_ck("A3 and floor 1 draws NOTHING below its tier (the T0 kit is out)",
		not got[1].has(PuzzleAtoms.SUN_SOCKET)
		and not got[1].has(PuzzleAtoms.LANTERN)
		and not got[1].has(PuzzleAtoms.SMALL_KEY))
	_ck("A4 nor anything above it (the hookshot is out)",
		not got[1].has(PuzzleAtoms.HOOK_RING))
	# §1: the Far Lantern has no verb and never gets one.
	_ck("A5 floor 4 draws nothing -- the Far Lantern is a pure lock (§1)",
		(got[4] as Array).is_empty()
		and FloorDb.shortcut_key(4) != &"")


# --- B. The door ---------------------------------------------------------------

func _b_the_door(d: Node, door: Node3D) -> void:
	_ck("B0 the shortcut is still at the entrance",
		d.anchor_cell(&"shortcut_door") == d.entrance)
	_ck("B1 it is a puzzle gate now, not a check (%s)"
		% door.get_script().resource_path.get_file(),
		door.is_in_group(&"puzzle_gate"))

	var atoms: Array = door.call(&"atoms")
	print("SHORTCUT floor 1 gate watches %d atom(s): %s"
		% [atoms.size(), atoms.map(func(a): return a.atom_id)])
	_ck("B2 and it adopted exactly one atom, the eye",
		atoms.size() == 1 and atoms[0].atom_id == PuzzleAtoms.EYE_SWITCH)
	# A gate that adopted nothing is `unlocked()` on its first frame and nothing
	# in the frame looks wrong -- `PuzzleGate.atoms()` exists to make that sayable.
	_ck("B3 so it starts SHUT", not door.call(&"unlocked"))

	# The mark. §5.1's verb is floor 1's own boss item, and `PuzzleAtoms.TIER_ITEM`
	# is the same row `LockedDoor.SIGILS` keys on -- so the door in front of a bow
	# puzzle wears the bow's crescent without a second sigil table.
	_ck("B4 it wears the bow's mark (%s)" % door.get(&"key_item"),
		door.get(&"key_item") == FloorDb.shortcut_key(1))

	# **The lifetime.** §5.2's gate room is a puzzle every run and §5.1's shortcut
	# is opened once for ever, and the two are one string apart. A shortcut wearing
	# `PuzzleGate`'s `atom_door_*` would be re-locked by `Run.enter()` on run two,
	# which is GDD §5.3's ninety seconds deleted.
	var flag: StringName = door.call(&"flag_id")
	print("SHORTCUT flag %s" % flag)
	_ck("B5 its flag is LockedDoor's permanent one, not PuzzleGate's per-run one",
		flag == StringName("door_open_shortcut_1"))
	_ck("B6 and the atom's own flag IS per-run (%s)" % atoms[0].call(&"flag_id"),
		String(atoms[0].call(&"flag_id")).begins_with("atom_"))

	# §0 rule 2, the pot: *every puzzle room is solvable from a cold start with an
	# empty pouch.* A bow puzzle met with no arrows is a dead end.
	var room: Node = d.rooms[d.entrance]["node"]
	var pot: Node = room.get_node_or_null(^"ShortcutUrn")
	_ck("B7 an urn stands beside it (§0 rule 2 -- the room brings the arrows)",
		pot != null and pot.get(&"holds") == &"arrows")


# --- C. The check is dead ------------------------------------------------------

## **The card, in one beat.** Before this change, owning the bow was the whole
## door. After it, owning the bow is worth nothing at all until the bow is USED.
func _c_the_check_is_dead(rig, hero: Node3D, door: Node3D) -> void:
	await _stand_at(rig, hero, door)
	_ck("C0 the door owns the interact button", await _focus(rig, door))

	var cold: String = Hud._prompt
	print("SHORTCUT refusal (no bow) = \"%s\"" % cold)
	_ck("C1 the hero does not own the Bow yet", not Game.has(&"bow"))
	_ck("C2 the refusal NAMES the eye (\"%s\")" % cold, cold.contains("EYE"))
	_ck("C3 not LOCKED (GDD pillar 3)", not cold.contains("LOCKED"))
	await rig.capture(out.path_join("s_01_refuses_no_bow.png"))

	# The Warden dies. Under the old door this was the whole puzzle.
	Game.grant(&"bow")
	Game.add_arrows(12)
	await rig.wait_frames(12)
	var warm: String = Hud._prompt
	print("SHORTCUT refusal (bow owned) = \"%s\"" % warm)
	_ck("C4 the Warden handed the Bow over", Game.has(&"bow"))
	# The three halves of "it is not a check any more".
	_ck("C5 OWNING the bow opened nothing", not door.call(&"is_open"))
	_ck("C6 and the door still refuses (\"%s\")" % warm, not door.call(&"unlocked"))
	# `LockedDoor._on_item_acquired` announces `X TO OPEN` on the frame the key
	# item lands -- right for a check, a promise a puzzle cannot keep, and the
	# reason `ShortcutGate` overrides it.
	_ck("C7 and does not promise TO OPEN over an unshot eye", not warm.contains("TO OPEN"))
	_ck("C8 it is still naming the eye (\"%s\")" % warm, warm.contains("EYE"))
	await rig.capture(out.path_join("s_02_refuses_with_bow.png"))

	await rig.tap(["interact"])
	await rig.wait_frames(24)
	_ck("C9 pressing it with the bow in hand opened nothing",
		not door.call(&"is_open"))


# --- D. One arrow --------------------------------------------------------------

func _d_the_arrow(rig, d: Node, hero: Node3D, door: Node3D) -> void:
	var room: Node = d.rooms[d.entrance]["node"]
	var eye: Node3D = room.get_node_or_null(^"ShortcutEye")
	if eye == null:
		_ck("D0 the eye is in the room", false)
		return
	# The facing check `CLAUDE.md` §4 exists for, made against the geometry rather
	# than against the placer's arithmetic: the eye's forward is -basis.z, and it
	# has to point back at a hero standing on the door's +basis.z side.
	var eye_fwd := -eye.global_transform.basis.z
	var player_side := door.global_transform.basis.z
	print("SHORTCUT eye at %.1f,%.2f,%.1f facing %.2f,%.2f -- player side %.2f,%.2f"
		% [eye.global_position.x, eye.global_position.y, eye.global_position.z,
			eye_fwd.x, eye_fwd.z, player_side.x, player_side.z])
	_ck("D0 the eye looks INTO the room, at the player (dot %.2f)"
		% eye_fwd.dot(player_side), eye_fwd.dot(player_side) > 0.9)
	_ck("D1 and it sits above the sword's reach (%.2f m)" % eye.global_position.y,
		eye.global_position.y > 1.8)

	var opened_with: Array[StringName] = []
	door.connect(&"opened", func(w: StringName) -> void: opened_with.append(w))

	var from := hero.global_position + Vector3.UP * MUZZLE_Y
	# Before anything is fired. An arrow that "missed" is nearly always an arrow
	# that hit something the beat forgot was between the two points, and a failure
	# that only says "the eye is dark" makes you guess which one.
	_ck("D1b and an arrow can actually get to it", _clear_line(hero, eye))

	var arrow := Arrow.new()
	arrow.name = "DirectorArrow"
	# Parented to the SCENE, exactly as `HeroRanged._release_arrow` does it: an
	# arrow under the hero inherits his yaw and his 1.65 scale.
	rig.scene().add_child(arrow)
	arrow.launch(from, (eye.global_position - from).normalized(),
		hero as CollisionObject3D)
	var prev := Engine.time_scale
	Engine.time_scale = SLOW
	await rig.wait_frames(14)
	await rig.capture(out.path_join("s_03_arrow_in_flight.png"))
	Engine.time_scale = prev

	var lit: bool = await rig.until(func() -> bool:
		return bool(eye.call(&"is_solved")), 4.0)
	if not lit:
		print("SHORTCUT arrow ended at %s (eye at %s)"
			% [("gone" if not is_instance_valid(arrow)
				else str(arrow.global_position)), eye.global_position])
	_ck("D2 the arrow opened the eye", lit)
	# Mid-swing, which is what says the door moved rather than having been posed.
	await rig.wait_frames(8)
	await rig.capture(out.path_join("s_04_door_swinging.png"))

	var open: bool = await rig.until(func() -> bool:
		return bool(door.call(&"is_open")), 4.0)
	# **By itself.** §5.2's note: a switch you trip and then have to walk back and
	# press a button on is a door that took the reward off the solve. Nothing in
	# this beat pressed `interact`.
	_ck("D3 and the door swung BY ITSELF -- no second press", open)
	_ck("D4 it told the placer where it goes (%s)" % [opened_with],
		opened_with.size() == 1
		and opened_with[0] == StringName("shortcut_1"))
	await rig.wait_frames(60)
	await rig.capture(out.path_join("s_05_door_open.png"))


# --- E. What it pays -----------------------------------------------------------

## §5.2's amendment is a rule for all three shapes: *a solved puzzle drops
## something you can carry out.* §5.1's row of that table is **the way down, +1
## blessing shrine, and the shortcut chest**, and all three stand in the landing.
func _e_the_rewards(rig, d: Node, hero: Node3D, door: Node3D) -> void:
	var landing: Node = d.get_node_or_null(^"ShortcutLanding")
	if landing == null:
		_ck("E0 there is a landing behind the shortcut", false)
		return
	var stairs: Array = _every(landing, func(n: Node) -> bool: return n is Stairs)
	_ck("E0 the way down is behind it", stairs.size() == 1)

	var chest: Node3D = landing.get_node_or_null(^"ShortcutChest")
	_ck("E1 the shortcut chest is there", chest != null)
	# It ARRIVES on the solve -- `Dungeon._land_prize`, Ocarina's own beat. A chest
	# standing shut in the room before the puzzle is solved is `LockedDoor`'s
	# LOCKED wearing a lid.
	_ck("E2 and it landed when the door opened", chest != null and chest.visible
		and bool(chest.get(&"enabled")))

	var stone: Node3D = landing.get_node_or_null(^"SoundingStone_shortcut")
	_ck("E3 a Votive Court is there", stone != null)
	if stone != null:
		var three: Array = stone.call(&"offered")
		print("SHORTCUT the stone offers %s" % [three])
		# §6: *every blessing is a choice of three*, and the shortcut's row of
		# that table pays exactly one.
		_ck("E4 and it is offering three blessings (%d)" % three.size(),
			three.size() == 3)

	# Through the door, on the hero's own capsule, so the reward is a place the
	# player can reach and not a node in a sealed pocket.
	if not stairs.is_empty():
		var down: Node3D = stairs[0]
		var walked := await _sweep(rig, hero, [
			door.global_position - door.global_transform.basis.z * 3.2
				+ Vector3(0.0, 0.15, 0.0),
			# `Stairs` is authored with the flight descending toward its own -Z,
			# which is the way the player comes in -- so the standing spot is on
			# that side, not behind the pit (`Dungeon._build_landing`'s note).
			down.global_position - down.global_transform.basis.z * 3.4
				+ Vector3(0.0, 0.15, 0.0)])
		_face(hero, down)
		Bus.camera_recenter.emit()
		await rig.wait_frames(30)
		_ck("E5 and all three are reachable through the opened door", walked)
		await rig.capture(out.path_join("s_06_landing_chest_and_blessings.png"))


# --- F. The flag outlives the run ---------------------------------------------

## GDD §5.3's promise, and the only beat that can catch its opposite: *"on your
## fifth run you are at the Choir in ninety seconds."*
##
## `Run.enter()` calls `PuzzleAtom.clear_run_flags()`, which wipes every `atom_*`
## key — so a shortcut gate wearing `PuzzleGate`'s flag comes back SHUT on run two
## over an eye that has been reset. The door's flag is not an `atom_*` key and the
## eye's is, and this beat is those two sentences in one rebuild.
func _f_the_flag_is_permanent(rig) -> void:
	Run.enter(SEED)
	# Counted rather than named: `PuzzleAtom.flag_id()` composes its key out of
	# three fields and a director that spelled one out would pass by agreeing with
	# its own typo. What matters is that nothing of this puzzle's survived.
	var stale := 0
	for key: StringName in Game.flags.keys():
		if String(key).begins_with("atom_shortcut_1"):
			stale += 1
	_ck("F0 a new run wiped the eye's per-run flag (%d left)" % stale, stale == 0)
	_ck("F1 and did NOT wipe the door's",
		Game.flag(StringName("door_open_shortcut_1")))

	var d := await _rebuild(rig, 1)
	if d == null:
		_ck("F2 floor 1 rebuilt", false)
		return
	_clear_the_floor(d)
	var door: Node3D = d.anchor_node(&"shortcut_door")
	if door == null:
		_ck("F2 the rebuilt floor has a shortcut", false)
		return
	_ck("F2 run two finds the shortcut already open", bool(door.call(&"is_open")))
	# `PuzzleGate.watch()` refuses to adopt anything once the door is open, which
	# is what stops a reset eye from re-locking a door already walked through.
	_ck("F3 and it did not re-adopt the reset eye (%d atom(s))"
		% (door.call(&"atoms") as Array).size(),
		(door.call(&"atoms") as Array).is_empty())
	var eye: Node3D = d.rooms[d.entrance]["node"].get_node_or_null(^"ShortcutEye")
	_ck("F4 while the eye itself came back dark -- the atoms are per-run",
		eye != null and not bool(eye.call(&"is_solved")))
	await rig.wait_frames(10)


# --- G. The other three floors -------------------------------------------------

func _g_the_other_floors(rig, hero: Node3D) -> void:
	# Floor 2 -- the pillar, and a Burst thrown at it.
	Run.enter(SEED)
	Game.grant(&"bow")
	Game.grant(&"burst")
	Game.add_charges(3)
	var d2 := await _rebuild(rig, 2)
	if d2 != null:
		_clear_the_floor(d2)
		var door: Node3D = d2.anchor_node(&"shortcut_door")
		var pillar: Node3D = d2.rooms[d2.entrance]["node"] \
			.get_node_or_null(^"ShortcutPillar")
		_ck("G0 floor 2's shortcut draws the cracked pillar", pillar != null)
		if door != null and pillar != null:
			# Standing IN the door's mouth, holding it shut with its body --
			# `CrackedPillar`'s own note, and the reason the fall IS the opening.
			var out_by := (pillar.global_position - door.global_position) \
				.dot(door.global_transform.basis.z)
			print("SHORTCUT floor 2 pillar stands %.2f m out from the door" % out_by)
			_ck("G1 and it braces the door (%.2f m out, on the player's side)"
				% out_by, out_by > 0.6 and out_by < 2.2)
			# Inside `LockedDoor`'s 2.9 m interact radius -- and therefore closer to
			# the door than the pillar is, which is the frame anyway: the thing
			# this beat photographs is a column standing in a doorway.
			await _stand_at(rig, hero, door)
			await _focus(rig, door)
			var said: String = Hud._prompt
			print("SHORTCUT floor 2 refusal = \"%s\"" % said)
			_ck("G2 and the door names the pillar (\"%s\")" % said,
				said.contains("PILLAR"))
			await rig.capture(out.path_join("s_07_floor2_pillar.png"))
			# The real working, thrown from the hero's hand at the pillar's foot.
			BurstCast.cast_from(rig.scene(),
				hero.global_position + Vector3.UP * MUZZLE_Y,
				(pillar.global_position + Vector3.UP * 0.4
					- hero.global_position - Vector3.UP * MUZZLE_Y).normalized(),
				hero as CollisionObject3D)
			var fell: bool = await rig.until(func() -> bool:
				return bool(door.call(&"is_open")), 8.0)
			_ck("G3 bursting it opened the shortcut", fell)
			await rig.wait_frames(50)
			await rig.capture(out.path_join("s_08_floor2_open.png"))

	# Floor 3 -- the ring over the lintel.
	Run.enter(SEED)
	Game.grant(&"hookshot")
	var d3 := await _rebuild(rig, 3)
	if d3 != null:
		_clear_the_floor(d3)
		var door: Node3D = d3.anchor_node(&"shortcut_door")
		var ring: Node3D = d3.rooms[d3.entrance]["node"] \
			.get_node_or_null(^"ShortcutRing")
		_ck("G4 floor 3's shortcut draws the hook ring", ring != null)
		if door != null and ring != null:
			print("SHORTCUT floor 3 ring at y=%.2f" % ring.global_position.y)
			_ck("G5 and it hangs over the lintel (%.2f m, K.DOOR_H is %.1f)"
				% [ring.global_position.y, K.DOOR_H],
				ring.global_position.y > K.DOOR_H)
			# `HookRing` builds its bracket out its own +Z, which is the OPPOSITE
			# axis from the eye. Measured, never assumed (`CLAUDE.md` §4).
			var out_z := ring.global_transform.basis.z
			var side := door.global_transform.basis.z
			_ck("G6 and its bracket runs out into the room (dot %.2f)"
				% out_z.dot(side), out_z.dot(side) > 0.9)
			await _stand_at(rig, hero, door)
			# The check G8 cannot make. Biting the ring by hand proves the WIRING
			# and nothing about whether a chain could ever arrive, and a ring
			# buried in the wall's collider passes that happily -- the eye did,
			# for a whole run, until beat D fired something real at it. So ask
			# the geometry instead (`Dungeon.WALL_STANDOFF`).
			_ck("G6b and a chain can actually reach it", _clear_line(hero, ring))
			await _focus(rig, door)
			var said: String = Hud._prompt
			print("SHORTCUT floor 3 refusal = \"%s\"" % said)
			_ck("G7 and the door names the ring (\"%s\")" % said,
				said.contains("RING"))
			await rig.capture(out.path_join("s_09_floor3_ring.png"))
			# And a step back, because a 3.8 m ring is above the top of the frame
			# from inside the door's own interact radius -- the camera pitches 5
			# degrees (`docs/CONTRACT.md` §1.2) and does not look up.
			await _stand_at(rig, hero, door, 7.5)
			await rig.capture(out.path_join("s_09b_floor3_ring_wide.png"))
			# The chain catches. `HookTarget.on_bitten` is the firer's own entry
			# point -- `HeroRanged._fire_hookshot` calls exactly this, and aiming a
			# scripted stick at a ceiling ring measures the camera boom rather than
			# the puzzle.
			var target: Node = ring.call(&"target")
			if target != null:
				target.call(&"on_bitten", hero)
			var bit: bool = await rig.until(func() -> bool:
				return bool(door.call(&"is_open")), 4.0)
			_ck("G8 biting it opened the shortcut", bit)
			await rig.wait_frames(50)
			await rig.capture(out.path_join("s_10_floor3_open.png"))

	# Floor 4 -- and it is still a check, on purpose (§1).
	Run.enter(SEED)
	var d4 := await _rebuild(rig, 4)
	if d4 != null:
		var door: Node3D = d4.anchor_node(&"shortcut_door")
		_ck("G9 floor 4 still has a shortcut door", door != null)
		if door != null:
			_ck("G10 and it is a plain LOCK -- the Far Lantern has no verb (§1)",
				not door.is_in_group(&"puzzle_gate")
				and door.get(&"key_item") == FloorDb.shortcut_key(4))


# --- Plumbing ------------------------------------------------------------------

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
	# Twelve is `cistern_floor.gd`'s settle, plus the frame `PuzzleGate._adopt`
	# waits for -- adoption is deferred on both sides, so a beat that asked
	# `atoms()` on the build frame would correctly report a gate watching nothing.
	await rig.wait_frames(14)
	return d


## Put the hero where a player reads this door from, and let the physics notice.
##
## Teleported rather than walked. That the entrance room is walkable is
## `cistern_floor.gd`'s beat C and this file must not silently re-make it -- what
## this one is about starts once the hero is standing there. The settle is on the
## PHYSICS clock because `Interactable.player_inside` is set by an `Area3D`, and a
## render-frame guess is the bug `shoot.gd`'s `until` docstring is written about.
func _stand_at(rig, hero: Node3D, door: Node3D, back: float = READ_AT) -> void:
	hero.velocity = Vector3.ZERO
	hero.global_position = door.global_position \
		+ door.global_transform.basis.z * back + Vector3(0.0, 0.15, 0.0)
	_face(hero, door)
	Bus.camera_recenter.emit()
	await rig.wait_physics_frames(6)
	await rig.wait_frames(24)


## Is there daylight between the hero's muzzle and `target`?
##
## **The check a director that pokes props by hand never makes**, and the one
## this beat was missing: an atom flush against `KitWall` renders on the wall,
## answers `apply_hit` the moment anything hands it one, and is unreachable. The
## eye passed every wiring check in this file for a whole run while sitting a
## centimetre inside the room's own collider — see `Dungeon.WALL_STANDOFF`.
##
## Phrased as *what stops the ray first*, not *does the ray find the target*,
## because `HookTarget` has no collider at all (it is a group and a snap radius,
## `hook_target.gd`) — so the ring can only ever be proven by what is NOT in
## front of it. `to` stops at the target, so the wall behind it is out of scope.
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
		print("SHORTCUT line to %s: clear, %.2f m" % [target.name, span])
		return true
	var b := seen["collider"] as Node
	if b == target or target.is_ancestor_of(b):
		print("SHORTCUT line to %s: clear, %.2f m (ray landed on its own body)"
			% [target.name, span])
		return true
	print("SHORTCUT line to %s BLOCKED by %s (%s) %.2f m short of it"
		% [target.name, b.name, b.get_class(),
			(seen["position"] as Vector3).distance_to(target.global_position)])
	return false


func _face(hero: Node3D, at: Node3D) -> void:
	var to := K.flat(at.global_position - hero.global_position)
	if to == Vector3.ZERO:
		return
	hero.facing_yaw = atan2(to.x, to.z)
	hero.rotation.y = hero.facing_yaw + PI


## Wait for `prop` to own the interact button. Polled rather than awaited on a
## signal: `Prompt` hands focus to whatever is nearest and a bare wait breaks
## instantly on the wrong one (`gate_locks.gd` learned this).
func _focus(rig, prop: Node) -> bool:
	for _i in 90:
		if Prompt.focus == prop:
			return true
		await rig.wait_frames(2)
	return false


## Sweep the hero along `route` with his own capsule against the real collision.
## The short version of `cistern_floor.gd`'s: this file only ever walks one room.
func _sweep(rig, hero: Node3D, route: Array[Vector3], tol: float = 0.8) -> bool:
	for target: Vector3 in route:
		var guard := 0
		while guard < 300:
			guard += 1
			# `K.plane`, NOT `K.flat` -- `flat` normalises, so the arrival test
			# would never fire. `cistern_floor.gd` records that as its fourth.
			var to := K.plane(target - hero.global_position)
			if to.length() < tol:
				break
			var step := to.limit_length(0.45)
			hero.velocity = Vector3.ZERO
			if not hero.test_move(hero.global_transform, step):
				hero.global_position += step
			else:
				var side := Vector3(-step.z, 0.0, step.x).normalized() * 0.45
				if not hero.test_move(hero.global_transform, side):
					hero.global_position += side
				elif not hero.test_move(hero.global_transform, -side):
					hero.global_position -= side
				else:
					return false
			if guard % 8 == 0:
				await rig.wait_frames(1)
		if guard >= 300:
			return false
	await rig.wait_frames(2)
	return true


## Free every body on the floor. These beats are about a door and an atom, and a
## goblin that walks into the shot is a measurement of the pack.
func _clear_the_floor(d: Node) -> void:
	var freed := 0
	for e in _every(d, func(n: Node) -> bool: return n is Enemy):
		freed += 1
		e.queue_free()
	if freed > 0:
		print("SHORTCUT cleared %d bodies" % freed)


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
