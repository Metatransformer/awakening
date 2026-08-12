extends RefCounted
## Card #99. **A chest does not exist until you have beaten the thing guarding it.**
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/room_reward.gd \
##     --out=/tmp/reward/x.png --warmup=60
##
## What it claims, in the order it proves them:
##
##   0  Calibration, both directions. See below -- this beat runs first and the
##      rest are not printed if it fails.
##   D  The two tiers differ IN THE FRAME and not only in a constant. MAJOR builds
##      a shaft of light and a second ring; MINOR builds neither. Measured off
##      live nodes, on two bare probes, so it is a claim about the effect and not
##      about whichever chest the seed happened to produce.
##   E  **A freshly generated floor has no lootable chest anywhere on it.** Every
##      `Chest` in the whole tree -- room chests, the deep chest, the gate room's,
##      the maze's, the shortcut landing's, the treasure chamber's and the
##      vault's, seven of them on this seed -- is invisible and cannot take the
##      interact prompt. This is the beat that catches the generator, which is
##      where the bug was; the per-room beats below only catch one room.
##   A  The room chest starts hidden, and its `RoomWatch` is holding exactly the
##      bodies the generator spawned there.
##   B  Killing all but the last body changes nothing. This separates "the chest
##      waits for the ROOM" from "the chest appears when something dies", which
##      are not the same feature.
##   C  The last kill lands it: visible, `enabled`, a `RewardVfx` under it, and
##      one `Bus.reward_revealed` carrying tier 1.
##   F  The vault's rich chest, end to end, at tier 2 -- the pack across all three
##      of its rooms beaten down, then the shaft.
##   G  The deep chest waits for the BOSS. On an authored floor `deep_chest` and
##      `boss_door` share the deepest cell, the arena is in it, and `_populate`
##      gives that room no pack at all -- so there is no `RoomWatch` there and the
##      richest chest on the floor used to be standing open two metres from the
##      boss door. Checked structurally (hidden, and wired to the body) rather
##      than by fighting: `boss_cistern.gd` owns the boss fight and restating it
##      here would be CLAUDE.md §0's duplication.
##
## ## The instrument is calibrated in both directions (CLAUDE.md §2)
##
## This director's job is mostly to report an ABSENCE -- "there is no chest here
## yet" -- and an absence is the one reading a broken instrument gives for free.
## A director that could not find a chest at all would sail through beat E.
##
## So beat 0 runs both controls before anything else:
##
##   POSITIVE  a hidden node is handed straight to `RewardVfx.land` and the
##             director is asked whether it can see the flash. If it cannot, every
##             "no flash" below is worth nothing. This is `perf_probe --stall=300`
##             's trick: make the instrument measure a known answer.
##   NEGATIVE  the same node, hidden and NOT landed, must read as absent. The
##             `frame_repro` half -- point it at a scene whose honest answer is
##             *nothing* and check that nothing is what it says.
##
## ## One thing this director got wrong about itself, kept as a warning
##
## `_pick` answers with an EMPTY DICTIONARY when a floor has no chest of the tier
## asked for, and the first cut tested it with `!= null`. An empty Dictionary is
## not null, so the "has a tier-2 chest" check passed on a floor that had none,
## the beat silently returned nothing, and three tier-comparison checks then went
## red -- a director reporting a bug in the game that was a bug in the director.
## CLAUDE.md §2: a director reporting a failure is a suspect, not a witness.
##
## `RewardVfx` and `RoomWatch` are named directly here. Both are `class_name`s
## added in the same change as this file, so they are absent from the global
## script class cache until `pnpm run import` has been run once -- and naming one
## before that is a parse error that takes the run down before its first frame
## (`gate_locks.gd` records the lesson). Run the importer first.

## Forced so the floor is the same floor every run -- `cistern_floor`'s constant
## and its reason: the scene seeds itself off the wall clock in `_ready`, so an
## unforced director photographs a different floor every time.
const SEED := 20260811

## How hard the director hits. Twelve quarter-hearts kills a floor-1 body in a
## few blows and cannot one-shot an elite, which matters for beat B: the room has
## to be walked down one corpse at a time.
const SWING_Q := 12
## Give up rather than loop for ever on a body that will not die.
const MAX_SWINGS := 60

var _fails := 0
## Every `Bus.reward_revealed` this run, as `{tier, position}`. Recorded rather
## than sampled: the signal fires inside a kill, and the frame after is too late.
var _revealed: Array[Dictionary] = []


func run(rig) -> void:
	if rig.scene().name != &"DungeonRun":
		rig.fail("room_reward: wrong scene -- pass "
			+ "--scene=res://scenes/rooms/dungeon.tscn")
		return

	Bus.reward_revealed.connect(func(tier: int, pos: Vector3) -> void:
		_revealed.append({"tier": tier, "pos": pos}))

	await _beat_0_calibrate(rig)
	if _fails > 0:
		# An uncalibrated instrument's later readings are noise, and printing six
		# confident lines under a failed control is how a director lies.
		print("REWARD FAIL -- calibration failed; the beats below were not run")
		print("REWARDCHECK fails=%d" % _fails)
		return

	var dungeon := await _rebuild(rig, 1)

	await _beat_e_sweep(rig)
	await _beat_a_to_c(rig, dungeon)
	await _beat_f_vault(rig)
	_beat_g_deep_chest(rig, dungeon)

	if _fails == 0:
		print("REWARD OK -- every check passed")
	print("REWARDCHECK fails=%d" % _fails)


# --- Beat 0: the controls, and beat D on the back of them -------------------------

func _beat_0_calibrate(rig) -> void:
	var stage := Node3D.new()
	stage.name = "CalibrationStage"
	rig.scene().add_child(stage)
	await rig.wait_frames(2)

	# NEGATIVE. Nothing landed, so the honest answer is nothing -- and an
	# instrument that reports a flash here reports one everywhere.
	var quiet := Node3D.new()
	quiet.name = "QuietProbe"
	quiet.visible = false
	stage.add_child(quiet)
	await rig.wait_frames(2)
	_ck("0N nothing landed reads as no flash", _flash_of(quiet) == null)
	_ck("0N nothing landed reads as hidden", not quiet.visible)

	# POSITIVE, once per tier -- which also IS beat D, because two probes landed
	# side by side is the cleanest possible comparison of the two flashes and it
	# does not depend on the seed producing one chest of each.
	var shapes := {}
	for tier: int in [RewardVfx.MINOR, RewardVfx.MAJOR]:
		var probe := Node3D.new()
		probe.name = "LoudProbe%d" % tier
		probe.visible = false
		stage.add_child(probe)
		await rig.wait_frames(2)
		var before := _revealed.size()
		RewardVfx.land(probe, tier)
		await rig.wait_frames(2)
		_ck("0P tier %d: a landed reward reads as visible" % tier, probe.visible)
		var flash := _flash_of(probe)
		_ck("0P tier %d: a landed reward reads as a flash" % tier, flash != null)
		_ck("0P tier %d: one line went on the bus" % tier,
			_revealed.size() == before + 1)
		shapes[tier] = _shape_of(flash)
		# And it goes away again. A flash that never freed itself would leak one per
		# chest and, worse, make every later `_flash_of` read a stale node.
		await rig.wait_seconds(float(RewardVfx.LIFE[tier]) + 0.4)
		_ck("0P tier %d: the flash frees itself" % tier, _flash_of(probe) == null)

	var minor: Dictionary = shapes[RewardVfx.MINOR]
	var major: Dictionary = shapes[RewardVfx.MAJOR]
	_ck("D1 MINOR builds no shaft", not bool(minor.get("shaft", true)))
	_ck("D2 MAJOR builds a shaft", bool(major.get("shaft", false)))
	_ck("D3 MINOR throws one ring", int(minor.get("rings", 0)) == 1)
	_ck("D4 MAJOR throws two rings", int(major.get("rings", 0)) == 2)
	_ck("D5 MAJOR's bloom is the brighter", float(major.get("energy", 0.0))
		> float(minor.get("energy", 0.0)))
	_ck("D6 MAJOR holds the screen longer", float(RewardVfx.LIFE[RewardVfx.MAJOR])
		> float(RewardVfx.LIFE[RewardVfx.MINOR]))

	_revealed.clear()
	stage.queue_free()
	await rig.wait_frames(2)


# --- Beat E: the whole floor ------------------------------------------------------

## Every `Chest` in the tree, on a floor nobody has touched. The bug this exists
## for is a generator bug, and a per-room check would only ever catch it in the
## room the seed put a pack in.
func _beat_e_sweep(rig) -> void:
	var chests := _all_chests(rig.scene())
	_ck("E0 the floor has chests to check at all", chests.size() >= 5)
	var loose: Array[String] = []
	for c: Chest in chests:
		var gate := "hidden"
		if c.visible:
			gate = "VISIBLE"
			loose.append("%s under %s" % [c.name, c.get_parent().name])
		elif c.enabled:
			gate = "hidden but PROMPTABLE"
			loose.append("%s under %s (enabled)" % [c.name, c.get_parent().name])
		print("REWARD   %-14s under %-18s %s"
			% [c.name, c.get_parent().name, gate])
	for line: String in loose:
		print("REWARD   lootable on arrival: %s" % line)
	_ck("E1 no chest on a fresh floor is lootable (%d chests)" % chests.size(),
		loose.is_empty())


# --- Beats A to C: a room chest ----------------------------------------------------

func _beat_a_to_c(rig, dungeon: Node) -> void:
	var room := _first_watched_room(dungeon)
	_ck("A0 the floor has a room chest waiting on a pack", not room.is_empty())
	if room.is_empty():
		return
	var chest: Node3D = room["chest"]
	var watch: RoomWatch = room["watch"]
	var foes: Array = room["foes"]
	print("REWARD   room beat: %s in %s, %d bodies"
		% [chest.name, room["cell"], foes.size()])

	_ck("A1 the chest is invisible while the room is alive", not chest.visible)
	_ck("A2 the chest cannot take the prompt", not bool(chest.get(&"enabled")))
	_ck("A3 no flash has fired in this room", _flash_of(chest) == null)
	_ck("A4 the watcher holds every body in the room",
		watch.live_count() == foes.size() and foes.size() >= 2)

	var cam := _look_at(rig, chest)
	await rig.wait_frames(2)
	await rig.capture("%s_01_before.png" % rig.out_base())

	# B. All but the last. The room is not beaten until it is beaten.
	for i in range(foes.size() - 1):
		await _kill(rig, foes[i])
		_ck("B still hidden with %d of %d left"
			% [foes.size() - i - 1, foes.size()], not chest.visible)
	_ck("B the watcher agrees one body is left", watch.live_count() == 1)
	_ck("B the room has not been called clear", not watch.is_clear())

	# C. The last one pays.
	var before := _revealed.size()
	var rest_y := chest.position.y
	await _kill(rig, foes[foes.size() - 1], 0.0)
	# **The chest FALLS IN.** Sampled here, before the captures, because it is the
	# one claim in this director a frame cannot settle: a chest photographed at
	# rest and a chest photographed mid-drop look the same if the drop never
	# happened and the ring is drawn at its feet either way.
	var drop_y := chest.position.y
	# **Everything about the flash is read HERE, on the frame it arrived, and only
	# asserted further down.** The whole effect is 1.1 s of wall clock and writing
	# a single 1280x720 PNG costs a good fraction of that -- with the checks after
	# the captures, `_flash_of` came back null and the director reported that a
	# reward it had just photographed mid-flash had never flashed at all.
	#
	# A BOOLEAN and not the node, and that is not tidiness. In Godot 4 a freed
	# object compares EQUAL to null, so a `flash != null` held across the captures
	# goes false the moment the effect frees itself -- while `shape`, read off the
	# same node a line earlier, still says one ring. The director reported both at
	# once: "the arrival never flashed" and "the arrival threw one ring".
	var flashed := _flash_of(chest) != null
	var shape := _shape_of(_flash_of(chest))
	var lit := chest.visible
	var promptable := bool(chest.get(&"enabled"))
	var cleared := watch.is_clear()
	var lines := _revealed.size()

	# Frames and not seconds, for the reason in `_kill`: the effect runs on the
	# wall clock and the room is frozen, so seconds here would skip most of it.
	await rig.capture("%s_02_falling.png" % rig.out_base())
	var fell := await _await_landing(rig, chest, rest_y)
	_ck("C the chest touched down (%d frames)" % fell, fell >= 0)
	await rig.capture("%s_03_landing.png" % rig.out_base())
	await rig.wait_frames(5)
	await rig.capture("%s_04_settled.png" % rig.out_base())

	_ck("C the chest is still in the air a moment after it arrived (%.2f m)"
		% (drop_y - rest_y), drop_y > rest_y + 0.3)
	_ck("C the room reads as clear", cleared)
	_ck("C the chest is real", lit)
	_ck("C the chest can be opened", promptable)
	_ck("C the arrival flashed", flashed)
	_ck("C exactly one line went on the bus", lines == before + 1)
	if lines > before:
		_ck("C the bus carried tier 1",
			int(_revealed[before]["tier"]) == RewardVfx.MINOR)
	_ck("C a room chest throws one ring and no shaft",
		int(shape.get("rings", 0)) == 1 and not bool(shape.get("shaft", true)))

	await rig.wait_seconds(float(RewardVfx.LIFE[RewardVfx.MINOR]) + 0.3)
	_ck("C the chest is still there when the flash has gone", chest.visible)
	_ck("C the flash cleaned itself up", _flash_of(chest) == null)
	await rig.capture("%s_04_after.png" % rig.out_base())
	cam.queue_free()


# --- Beat F: the vault, end to end at tier 2 -----------------------------------------

## The vault is one strongbox with three rooms of level+1 bodies and one rich
## chest at the back. The chest used to be standing open to anyone who got
## through the door, so the pack was scenery.
##
## Found by node handle and `has_method`, never by naming `Vault`: it is a
## `class_name` this director does not need and `cistern_floor` records why
## naming it is a hazard.
func _beat_f_vault(rig) -> void:
	var vault := _find_by_method(rig.scene(), &"rich_chest")
	_ck("F0 the floor has a vault", vault != null)
	if vault == null:
		return
	var chest := vault.call(&"rich_chest") as Node3D
	var watch := vault.get_node_or_null(^"RoomWatch") as RoomWatch
	_ck("F1 the vault has a rich chest", chest != null)
	_ck("F2 the vault's pack is watched", watch != null)
	if chest == null or watch == null:
		return
	print("REWARD   vault beat: %d bodies across its rooms" % watch.live_count())
	_ck("F3 the vault chest is hidden while its pack lives", not chest.visible)
	_ck("F4 the vault's pack is a pack", watch.live_count() >= 3)

	var cam := _look_at(rig, chest)
	await rig.wait_frames(2)
	await rig.capture("%s_05_vault_before.png" % rig.out_base())

	var before := _revealed.size()
	var rest_y := chest.position.y
	var pack := _bodies_under(vault)
	for i in range(pack.size()):
		# 0.08 s on the thirteen that are only clearing rooms; the last one trips
		# the reveal and hands back after two frames (see `_kill`).
		await _kill(rig, pack[i], 0.08 if i < pack.size() - 1 else 0.0)
	var drop_y := chest.position.y
	# Sampled on the arrival frame and asserted below -- see beat C, including why
	# this is a boolean rather than the node.
	var flashed := _flash_of(chest) != null
	var shape := _shape_of(_flash_of(chest))
	var lit := chest.visible
	var promptable := bool(chest.get(&"enabled"))
	var cleared := watch.is_clear()
	var lines := _revealed.size()

	await rig.capture("%s_06_vault_falling.png" % rig.out_base())
	var fell := await _await_landing(rig, chest, rest_y)
	_ck("F5b the vault chest touched down (%d frames)" % fell, fell >= 0)
	await rig.capture("%s_07_vault_landing.png" % rig.out_base())
	await rig.wait_frames(6)
	await rig.capture("%s_08_vault_settled.png" % rig.out_base())

	_ck("F5 the vault chest is still falling (%.2f m up)" % (drop_y - rest_y),
		drop_y > rest_y + 0.6)
	_ck("F6 the vault reads as clear", cleared)
	_ck("F7 the vault chest is real", lit)
	_ck("F8 the vault chest can be opened", promptable)
	_ck("F9 the vault's arrival flashed", flashed)
	_ck("F10 it flashed at tier 2", lines > before
		and int(_revealed[before]["tier"]) == RewardVfx.MAJOR)
	_ck("F11 tier 2 in the world throws two rings and a shaft",
		int(shape.get("rings", 0)) == 2 and bool(shape.get("shaft", false)))
	cam.queue_free()


# --- Beat G: the deep chest waits for the boss ----------------------------------------

## Structural, and deliberately not a boss fight. What went wrong here was a
## GATE -- the room the deep chest stands in gets no pack, so `_hold_reward`'s
## fail-safe released it -- and a gate is checked by looking at the wiring.
## `boss_cistern.gd` owns "killing the boss opens the door"; restating it here
## would be a second answer to one question (CLAUDE.md §0).
func _beat_g_deep_chest(rig, dungeon: Node) -> void:
	var deep: Node3D = null
	for c: Chest in _all_chests(rig.scene()):
		if c.name == &"DeepChest":
			deep = c
	_ck("G0 the floor has a deep chest", deep != null)
	if deep == null:
		return
	_ck("G1 the deep chest is hidden with the boss still alive", not deep.visible)
	_ck("G2 the deep chest cannot take the prompt",
		not bool(deep.get(&"enabled")))

	# And it is wired to a body, not merely hidden. A chest hidden with nothing
	# able to reveal it is the WORSE bug -- a reward the player can never have --
	# and "invisible" reads identically for both.
	#
	# Asked of the deep chest's OWN room, not of the floor: the miniboss chamber
	# has an arena in it too, and a floor-wide search would answer with whichever
	# one the walk reached first and then check the deep chest against it.
	var arena := deep.get_parent().get_node_or_null(^"Arena")
	_ck("G3 the deep chest's room has an arena in it", arena != null)
	if arena == null:
		return
	var boss := arena.call(&"boss") as Node3D
	_ck("G4 the arena has a live boss", boss != null)
	if boss == null:
		return
	_ck("G5 something is listening for that boss's death",
		boss.get_signal_connection_list(&"died_at").size() >= 1)


# --- Reading the world -----------------------------------------------------------

## The first room on the floor whose chest is waiting on a `RoomWatch`, as
## `{root, chest, watch, foes, cell}`.
##
## Skips the puzzle chests. `GateChest` and `MazeChest` sit in rooms that also
## have packs and watchers, but they land on their PUZZLE (`Dungeon._land_prize`)
## and beating the room does nothing for them -- a beat that picked one would
## fail beat C for a reason that is not a bug.
func _first_watched_room(dungeon: Node) -> Dictionary:
	var rooms: Dictionary = dungeon.get(&"rooms")
	for cell: Vector2i in rooms:
		var root = rooms[cell].get("node")
		if root == null or not is_instance_valid(root):
			continue
		var watch := root.get_node_or_null(^"RoomWatch") as RoomWatch
		if watch == null:
			continue
		var chest: Node3D = null
		var foes: Array = []
		for child in root.get_children():
			if child is Enemy:
				foes.append(child)
			elif child is Chest and child.name == &"RoomChest":
				chest = child
		if chest == null or foes.size() < 2:
			continue
		return {"root": root, "chest": chest, "watch": watch, "foes": foes,
			"cell": cell}
	return {}


func _all_chests(from: Node) -> Array[Chest]:
	var out: Array[Chest] = []
	var stack: Array[Node] = [from]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is Chest:
			out.append(n)
	return out


func _bodies_under(from: Node) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [from]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is Enemy:
			out.append(n)
	return out


func _find_by_method(from: Node, method: StringName) -> Node:
	var stack: Array[Node] = [from]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n.has_method(method):
			return n
	return null


## The live `RewardVfx` under `prize`, or null. The negative half of beat 0 is
## that this returns null when there is nothing there.
func _flash_of(prize: Node) -> Node:
	if prize == null or not is_instance_valid(prize):
		return null
	for child in prize.get_children():
		if child is RewardVfx:
			return child
	return null


## What the flash is made of, read off the live nodes. Beat D compares two of
## these; nothing here restates a constant from `RewardVfx`.
func _shape_of(flash: Node) -> Dictionary:
	if flash == null:
		return {}
	var rings := 0
	var shaft := false
	var energy := 0.0
	for child in flash.get_children():
		# `begins_with` and not `==`. Both rings are built as `Ring`, and Godot
		# renames the second sibling to `Ring2` on `add_child` -- so an equality
		# test counts one ring on a two-ring flash and reports the tiers as
		# identical. The first cut of beat D4 failed for exactly that.
		if child.name.begins_with("Ring"):
			rings += 1
		elif child.name == &"Shaft":
			shaft = true
		elif child is OmniLight3D:
			energy = maxf(energy, (child as OmniLight3D).light_energy)
	return {"rings": rings, "shaft": shaft, "energy": energy}


# --- Doing things to the world -----------------------------------------------------

## Beat one body down through its own health component and wait until it has
## announced the death.
##
## `apply_hit` and not `queue_free`: the chain under test is
## `Enemy._die -> died_at -> RoomWatch._gone`, and a body deleted out from under
## it exercises only the `tree_exited` backstop -- which passes, and proves the
## wrong thing.
##
## `settle` is how long to hold after the body is down. The default 0.3 s is for
## the kills that are only clearing the room. The kill that TRIPS the reveal
## passes **0.0, which means two FRAMES instead** -- one for `RoomWatch`'s
## deferred confirmation and one to draw.
##
## **Frames and not seconds, because the kill frame is a hit-stop.** `wait_seconds`
## runs on the game clock and the arrival does not: the flash is
## `PROCESS_MODE_ALWAYS` on `Time.get_ticks_msec()` and the drop tween sets
## `ignore_time_scale`, both on purpose, so the whole ceremony plays out in real
## time while the world is frozen. Asked for "0.05 s" the director slept 0.34 s of
## wall clock and sampled a chest that had already finished falling -- 0.13 m off
## the floor of a 1.1 m drop. It photographed the end of the effect twice and
## called it the beginning.
func _kill(rig, foe: Node, settle: float = 0.3) -> void:
	if foe == null or not is_instance_valid(foe):
		return
	var hp = foe.get(&"health")
	if hp == null:
		rig.fail("room_reward: %s has no health to beat down" % foe.name)
		return
	var swings := 0
	while is_instance_valid(foe) and hp.quarters > 0 and swings < MAX_SWINGS:
		hp.apply_hit(Hit.make(SWING_Q, (foe as Node3D).global_position
			+ Vector3(0.0, 0.0, 2.0), &"sword"))
		swings += 1
		await rig.wait_frames(1)
	if swings >= MAX_SWINGS:
		_ck("kill: %s went down in under %d swings" % [foe.name, MAX_SWINGS], false)
	if settle <= 0.0:
		await rig.wait_frames(2)
	else:
		await rig.wait_seconds(settle)


## Hold until the prize first touches down, and answer how many frames that took.
##
## Polled rather than timed, because the two clocks disagree: the drop ignores
## time scale and the room is frozen for the hit-stop, so "wait DROP_TIME" out of
## a director is not the same wait at all (see `_kill`). The tween eases on
## BOUNCE, so the first frame at rest height IS the landing -- the small hops
## after it come back UP.
func _await_landing(rig, prize: Node3D, rest_y: float) -> int:
	for i in 180:
		if prize.position.y <= rest_y + 0.03:
			return i
		await rig.wait_frames(1)
	return -1


## A camera across the room from the chest, low enough that the shaft leaves the
## top of the frame rather than sitting inside it like a prop.
func _look_at(rig, at: Node3D) -> Camera3D:
	var cam := Camera3D.new()
	cam.name = "RewardCam"
	cam.fov = 55.0
	rig.scene().add_child(cam)
	cam.global_position = at.global_position + Vector3(0.0, 3.2, 7.5)
	cam.look_at(at.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)
	cam.make_current()
	return cam


## Replace the scene's `Dungeon` with a seeded one -- `cistern_floor._rebuild`'s
## reason: the scene builds itself in `_ready` off a wall-clock seed, so the floor
## a director photographs would otherwise differ every run.
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


func _ck(what: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % what)
	else:
		_fails += 1
		print("REWARD FAIL %s" % what)
