extends RefCounted
## **The plate's door is open only while something is standing on it** (card
## #116, the owner's playtest of 2026-08-12: *"you can just walk onto the switch
## and then it'll open the door. It should only open the door while you have
## yourself or something on."*).
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/_plate_gate_test.tscn \
##     --director=res://tools/directors/plate_gate.gd \
##     --out=/tmp/plate_gate/x.png --warmup=60
##
## What it claims, in the order it proves them:
##
##   A  The gate adopts the plate by tag, is SHUT, and its refusal names the
##      plate's own verb rather than "LOCKED".
##   B  The hero stands on it: the plate presses and the door OPENS.
##   C  He steps off: the plate rises and the door SHUTS -- the blocker is back,
##      the door is addressable again, and it refuses by name a second time.
##      **Photographed as a pair from one fixed camera** (`01_` / `02_`), because
##      the claim is about a thing that goes back and a single frame of an open
##      door proves the half that already worked.
##   D  Nothing persistent was written. A reversible gate stamps no
##      `atom_door_*` flag at any point in B or C, and the plate stamps none of
##      its own -- `puzzle_atoms.gd` proves that second half about the prop; this
##      proves it about the DOOR, which is where it was actually being written.
##   E  The block is shoved onto the plate: the door opens and STAYS open with
##      the hero free to walk through it. Proved with the hero's own
##      `test_move` -- the blocker is real collision, and "the leaves look open"
##      is what the pre-#116 build already did correctly.
##   F  **Reload.** `Game.flags` is round-tripped exactly as `save_game.gd`
##      writes and reads it, the floor is rebuilt, and the rebuilt door is in the
##      state the rebuilt plate says it is: SHUT, because nothing is standing on
##      it. Before #116 the flag said open and the door came up open over a
##      risen plate.
##   G  **The control, and it runs the other way.** A gate on a LATCHING atom
##      must still persist: it stamps its flag, and it comes back OPEN through
##      the same rebuild F puts the plate gate through. Without this beat the fix
##      would pass just as well if it had turned the flag off for every door in
##      the game, which would silently undo M1's whole first half.
##
## ## What this file does NOT prove
##
## The plate's own verb -- `tools/directors/puzzle_atoms.gd` beat C is that, and
## it landed with M1. What is under test here is the DOOR: that a gate hears an
## atom go back, and that what it saved agrees with what it is showing.

const SEED := 116116
const TAG := &"plate_demo"
## The latching control's tag. A small key, because it is the one T0 latching
## atom the hero can answer by walking onto it.
const LATCH_TAG := &"latch_control"
const FLOOR_Y := 0.02
## Where the plate stands: in the open floor between the hero's spawn and the
## north doorway, so one camera behind the hero holds the plate AND the door.
const PLATE_AT := Vector3(0.0, FLOOR_Y, -4.6)
## Three of `PushBlock.STEP` west of the plate, on the plate's own axis, so a
## whole number of shoves seats it dead centre (`Dungeon._place_puzzle_room`
## makes the same argument about the same constant).
const BLOCK_STEP := 1.2
## Somewhere off the plate and out of the doorway for the hero to stand while a
## check is about the plate being EMPTY.
const OFF_PLATE := Vector3(3.6, FLOOR_Y, -2.0)

var out := ""
var _gate: Node
var _plate: PuzzleAtom
var _block: PuzzleAtom
var _hero: Node3D
var _cam: Camera3D


func run(rig) -> void:
	out = rig.arg("out", "/tmp/plate_gate/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	Game.reset()
	# A run, so the atom flags start clean and `Run.enter`'s own wipe is what put
	# them there rather than a previous session leaking in.
	Run.enter(SEED)

	if rig.scene().name != &"PlateGateTest":
		rig.fail("wrong host scene (%s) -- pass "
			% rig.scene().name
			+ "--scene=res://scenes/rooms/_plate_gate_test.tscn")
		return

	_hero = rig.scene().get_node_or_null(^"Hero") as Node3D
	_gate = rig.scene().get_node_or_null(^"Gate")
	if _hero == null or _gate == null:
		rig.fail("the fixture is missing the hero or the gate")
		return

	await _a_set(rig)
	if _plate == null:
		return
	await _b_press(rig)
	await _c_release(rig)
	_d_flags(rig)
	await _e_block(rig)
	await _f_reload(rig)
	await _g_latching_control(rig)

	print("PLATE done -- %d failed checks" % rig.fails)


func _ok(rig, label: String, cond: bool) -> void:
	if cond:
		print("  ok   %s" % label)
	else:
		rig.fail(label)


# --- A. The set ---------------------------------------------------------------

func _a_set(rig) -> void:
	_plate = PuzzleAtoms.make(PuzzleAtoms.PRESSURE_PLATE, TAG)
	if _plate == null:
		rig.fail("the pressure plate did not build")
		return
	# Transform BEFORE the tree: the plate builds its trigger and its rim in
	# `_ready` and a node moved afterwards has built itself at the origin.
	_plate.position = PLATE_AT
	_plate.name = "Plate"
	rig.scene().add_child(_plate)

	# The camera the whole proof is shot from, and it is ONE camera on purpose:
	# beats B and C are a pair of frames whose only honest difference is the door,
	# and two cameras would make "it shut" a claim about a lens.
	_cam = Camera3D.new()
	_cam.name = "PlateCam"
	_cam.fov = 62.0
	_cam.position = Vector3(0.0, 3.0, 3.4)
	rig.scene().add_child(_cam)
	_cam.look_at(Vector3(0.0, 1.5, -9.6), Vector3.UP)
	_cam.make_current()

	# One deferred frame for `PuzzleAtom._offer` and `PuzzleGate._adopt` to find
	# each other from their two ends.
	await rig.wait_physics_frames(6)

	var watched: Array = _gate.call(&"atoms")
	_ok(rig, "A0 the gate adopted the plate by tag (%d)" % watched.size(),
		watched.size() == 1)
	_ok(rig, "A1 and knows the set can go backwards",
		bool(_gate.call(&"reversible")))
	_ok(rig, "A2 so it will stamp no permanent flag",
		not bool(_gate.call(&"persists_open")))
	var line: String = _gate.call(&"refusal_line")
	_ok(rig, "A3 the refusal names the plate: \"%s\"" % line,
		line == "THE PLATE IS UNPRESSED")
	_ok(rig, "A4 and the gate is shut", not bool(_gate.call(&"is_open")))
	_ok(rig, "A5 with a blocker in the doorway", _blocked())


# --- B. Weight on ------------------------------------------------------------

func _b_press(rig) -> void:
	await _stand_at(rig, PLATE_AT)
	await rig.wait_physics_frames(14)
	_ok(rig, "B0 the plate presses under the hero", bool(_plate.call(&"is_solved")))
	# The swing is 0.85 s plus a 0.22 s delay on the leaves.
	await rig.wait_seconds(1.3)
	_ok(rig, "B1 and the door OPENS", bool(_gate.call(&"is_open")))
	_ok(rig, "B2 with the blocker gone", not _blocked())
	await rig.capture("01_weight_on_door_open.png")


# --- C. Weight off -- the beat that did not exist ----------------------------

func _c_release(rig) -> void:
	await _stand_at(rig, OFF_PLATE)
	await rig.wait_physics_frames(14)
	_ok(rig, "C0 the plate RISES when he steps off",
		not bool(_plate.call(&"is_solved")))
	await rig.wait_seconds(1.3)
	_ok(rig, "C1 and the door SHUTS", not bool(_gate.call(&"is_open")))
	_ok(rig, "C2 the blocker is back in the doorway", _blocked())
	# A shut door is a door you can walk up to and be refused by again. The
	# `enabled` flag is what `Prompt` reads, and `_swing()` drops it -- a door
	# that shut but stayed unaddressable would be a wall.
	_ok(rig, "C3 and it is addressable again", bool(_gate.get(&"enabled")))
	var line: String = _gate.call(&"refusal_line")
	_ok(rig, "C4 refusing by name a second time: \"%s\"" % line,
		line == "THE PLATE IS UNPRESSED")
	await rig.capture("02_weight_off_door_shut.png")


# --- D. What was written -----------------------------------------------------

func _d_flags(rig) -> void:
	var door_flag: StringName = _gate.call(&"flag_id")
	_ok(rig, "D0 the gate wrote no permanent open flag (%s)" % door_flag,
		not Game.flag(door_flag))
	_ok(rig, "D1 nor did the plate", not Game.flag(_plate.call(&"flag_id")))


# --- E. The block ------------------------------------------------------------

func _e_block(rig) -> void:
	_block = PuzzleAtoms.make(PuzzleAtoms.PUSH_BLOCK, &"plate_demo_weight")
	if _block == null:
		rig.fail("E0 the push block did not build")
		return
	_block.name = "Block"
	_block.position = PLATE_AT + Vector3(BLOCK_STEP * 3.0, 0.0, 0.0)
	# Furniture with weight, not one of the gate's atoms -- the same thing
	# `Dungeon._place_puzzle_room` does, and `PushBlock`'s own note is about why.
	_block.set(&"mark_offset", Vector3.ZERO)
	rig.scene().add_child(_block)
	await rig.wait_physics_frames(8)

	# Shoved west, onto the plate. THREE shoves of `PushBlock.STEP`, which is the
	# 3.6 m it was placed out at -- a whole number of steps lands it dead centre,
	# and a fourth walks it 1.2 m past the middle where it holds the plate on the
	# lip of the trigger and the frame photographs as a block beside a plate.
	# `push_to` is the block's own public entry; the shoulder is `push_grip.gd`'s
	# claim, not this file's.
	for i in 3:
		_block.call(&"push_to", Vector3.LEFT)
		await rig.wait_seconds(0.45)
	await rig.wait_physics_frames(10)
	_ok(rig, "E0 the block holds the plate down with the hero off it",
		bool(_plate.call(&"is_solved")))
	await rig.wait_seconds(1.3)
	_ok(rig, "E1 and the door opens", bool(_gate.call(&"is_open")))

	# STAYS open: a second and a half with nothing touching it. The failure this
	# guards is a shut that fires on any `unsolved`, whoever sent it.
	await rig.wait_seconds(1.5)
	_ok(rig, "E2 and stays open with nothing but the block on it",
		bool(_gate.call(&"is_open")))
	_ok(rig, "E3 with the hero free to walk through", not _blocked())

	# Walked, not teleported. `test_move` above is the physics claim; this is the
	# one a player makes, and it is the only thing that proves the doorway is
	# passable rather than merely un-collided at one sampled transform.
	await _stand_at(rig, Vector3(0.0, FLOOR_Y, -7.6))
	await rig.hold([&"move_up"], 150)
	await rig.wait_physics_frames(8)
	_ok(rig, "E4 and he walks through it (z = %.2f)" % _hero.global_position.z,
		_hero.global_position.z < -10.6)
	await rig.capture("03_block_on_hero_through.png")


# --- F. Reload ---------------------------------------------------------------

## Save, reload, rebuild -- and the door has to be in the state the PLATE says.
##
## The round trip is `Game.flags` through JSON, which is exactly what
## `save_game.gd` does with it (`"flags": Game.flags` on the way out, a walk of
## the parsed dictionary re-keyed to `StringName` on the way back). Done here
## rather than through `Saves.save()` because that writes the owner's real
## `user://saves` and `save_load_position.gd`'s header is three paragraphs about
## what it then has to put back; the flags are the entire persisted state either
## way, and this exercises the same serialisation.
func _f_reload(rig) -> void:
	# Off the plate and the block back off it, so the honest answer after the
	# rebuild is SHUT and a door that came up open is unambiguous.
	await _stand_at(rig, OFF_PLATE)
	_block.queue_free()
	_block = null
	await rig.wait_seconds(1.4)
	_ok(rig, "F0 with the block gone the door shuts again",
		not bool(_gate.call(&"is_open")))

	var carried := _round_trip(Game.flags)
	Game.flags = carried
	_ok(rig, "F1 the save carries no open flag for the plate door (%d flags)"
		% carried.size(), not Game.flag(_gate.call(&"flag_id")))

	await _rebuild(rig)
	_ok(rig, "F2 the rebuilt plate comes up unpressed",
		not bool(_plate.call(&"is_solved")))
	_ok(rig, "F3 and the rebuilt door comes up SHUT, agreeing with it",
		not bool(_gate.call(&"is_open")))
	_ok(rig, "F4 with its blocker in place", _blocked())
	await rig.capture("04_after_reload_shut.png")


## `Game.flags` out to JSON and back, exactly as a slot round-trips it.
func _round_trip(flags: Dictionary) -> Dictionary[StringName, bool]:
	var text := JSON.stringify({"flags": flags})
	var read: Dictionary = JSON.parse_string(text)
	var out_flags: Dictionary[StringName, bool] = {}
	for k in (read.get("flags", {}) as Dictionary):
		out_flags[StringName(k)] = true
	return out_flags


## Free the gate and the plate and build both again, which is what a floor
## re-entered inside one run does. The new gate is built in code rather than
## re-instanced from the fixture, so the exports are stated where a reader can
## see them.
func _rebuild(rig) -> void:
	var old_gate := _gate as Node3D
	var at := old_gate.global_position
	var yaw := old_gate.global_rotation.y
	old_gate.queue_free()
	_plate.queue_free()
	await rig.wait_physics_frames(4)

	var gate := PuzzleGate.new()
	gate.name = "GateRebuilt"
	gate.puzzle_id = TAG
	gate.mark_tier = 0
	gate.label = "The Sluice Gate"
	gate.destination = TAG
	gate.position = at
	gate.rotation.y = yaw
	rig.scene().add_child(gate)
	_gate = gate

	_plate = PuzzleAtoms.make(PuzzleAtoms.PRESSURE_PLATE, TAG)
	_plate.position = PLATE_AT
	_plate.name = "PlateRebuilt"
	rig.scene().add_child(_plate)
	await rig.wait_physics_frames(10)
	_cam.make_current()
	await rig.wait_frames(20)


# --- G. The control: a latching gate still remembers -------------------------

## **Pointed at a case whose answer is already known** (CLAUDE.md §2). The fix is
## "a gate that can go backwards writes no flag"; the way to get that wrong in
## the invisible direction is to stop every gate writing one, and every check
## above would still pass. So: a gate on a SMALL KEY -- latching, T0, answered by
## walking onto it -- must stamp its flag and must come back open through the
## same rebuild.
func _g_latching_control(rig) -> void:
	var gate := PuzzleGate.new()
	gate.name = "LatchGate"
	gate.puzzle_id = LATCH_TAG
	gate.destination = LATCH_TAG
	# In the west wall's clear floor, well away from the north doorway so the two
	# doors' blockers cannot be confused for each other.
	gate.position = Vector3(-9.0, 0.0, 0.0)
	gate.rotation.y = PI * 0.5
	rig.scene().add_child(gate)

	var key := PuzzleAtoms.make(PuzzleAtoms.SMALL_KEY, LATCH_TAG)
	key.position = Vector3(-6.0, FLOOR_Y, 2.0)
	key.name = "LatchKey"
	rig.scene().add_child(key)
	await rig.wait_physics_frames(8)

	_ok(rig, "G0 a gate on a latching atom is not reversible",
		not bool(gate.reversible()))
	_ok(rig, "G1 so it WILL stamp its flag", gate.persists_open())

	await _stand_at(rig, key.global_position)
	await rig.wait_seconds(1.4)
	_ok(rig, "G2 taking the key opens it", gate.is_open())
	_ok(rig, "G3 and the flag is written (%s)" % gate.flag_id(),
		Game.flag(gate.flag_id()))

	# Walk away. A latching gate must NOT shut behind the player -- the walk home
	# is the reward for solving it (`PuzzleAtom`'s class note).
	await _stand_at(rig, OFF_PLATE)
	await rig.wait_seconds(1.4)
	_ok(rig, "G4 and it does not shut when he walks away", gate.is_open())

	# The same reload F puts the plate gate through.
	Game.flags = _round_trip(Game.flags)
	gate.queue_free()
	key.queue_free()
	await rig.wait_physics_frames(6)
	var again := PuzzleGate.new()
	again.name = "LatchGateRebuilt"
	again.puzzle_id = LATCH_TAG
	again.destination = LATCH_TAG
	again.position = Vector3(-9.0, 0.0, 0.0)
	again.rotation.y = PI * 0.5
	rig.scene().add_child(again)
	await rig.wait_physics_frames(10)
	_ok(rig, "G5 and it comes back OPEN after the reload", again.is_open())


# --- Instruments -------------------------------------------------------------

## Is the doorway actually stopped up? Asked of the hero's own body against the
## real blocker, not of a node name: `_swing()` frees the blocker and `_shut()`
## builds a new one, so a check on `get_node("Blocker")` would pass on a body
## that had been added to the tree and never given a shape.
##
## Sampled from 1.6 m south of the threshold, moving 2.6 m north through it.
func _blocked() -> bool:
	var body := _hero as CharacterBody3D
	if body == null:
		return false
	var probe := body.global_transform
	probe.origin = Vector3(0.0, FLOOR_Y + 0.05, -8.45)
	return body.test_move(probe, Vector3(0.0, 0.0, -2.6))


## Put the hero on a spot and let the physics settle. Teleported: this director is
## about the DOOR, and four walks across a 20 m chamber is harness time spent
## proving the movement code again. The one walk that matters is E4's, through
## the doorway, and it is driven with the real button.
func _stand_at(rig, at: Vector3) -> void:
	_hero.global_position = Vector3(at.x, at.y + 0.05, at.z)
	_hero.set(&"velocity", Vector3.ZERO)
	await rig.wait_physics_frames(8)
