extends RefCounted
## M4 (docs/SCOPE.md §3). **This is the demo**, and this is the director that says
## whether it exists -- on ANY of the four authored floors, `--level=1..4`.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/cistern_floor.gd \
##     --out=/tmp/floor/x.png --warmup=60 --level=1
##
## `tools/floors.sh` runs all four. **The file is still called `cistern_floor`**
## because it is the Cistern's director that grew a parameter, and renaming it
## would break the twelve places that cite it by name for no gain -- see `_level`.
##
## WHAT WAS ACTUALLY NEW HERE. Every check below already asked `FloorDb` for the
## floor's numbers instead of restating the Cistern's, so floors 2, 3 and 4 were
## one argument away the whole time -- and no director had ever generated them.
## The Foundry, the Hushing Choir and the Chord Gate were table rows. The demo is
## four floors (SCOPE §1) and one of them had a proof.
##
## What it claims, in the order it proves them:
##
##   A  The floor is the MANIFEST'S floor. The room count because `FloorDb` says
##      it, the pack because it defers to `Prog`, and every body in every room
##      drawn from that floor's own roster at that room's distance. `Dungeon` no
##      longer HAS a band table -- the constant is gone, which is checked rather
##      than asserted in prose.
##   B  All four anchors, in the rooms GDD §5.1 names, and the stair is where the
##      GDD moved it: OUT of the deepest room and into the landing behind the
##      boss door.
##   C  Every anchor is REACHABLE -- walked to from the entrance, room by room
##      along the tree, with the hero's own capsule swept through every doorway.
##      A node that exists in a sealed pocket of geometry passes an assertion and
##      fails a player.
##   D  The shortcut refuses by name, goes on refusing after the boss hands its
##      item over, opens on the floor's own verb, and what is behind it is a
##      `Stairs` that skips this floor -- floor N's shortcut lands you at floor
##      N+1's mouth, and floor 4's lands you in the Long Descent.
##
##      This beat used to say "refuses without the Bow, opens WITH it", and card
##      #5 made that sentence false: `docs/PUZZLES.md` §5.1 turned the shortcut
##      from a `LockedDoor` into a `ShortcutGate`, because *a door that opens
##      because you own item X is a check, not a puzzle*. Owning the bow is worth
##      nothing until it is used. The arrow itself belongs to
##      `tools/directors/shortcut_puzzle.gd` and is not restated here (`CLAUDE.md`
##      §0); what this file owns is that the door is REACHABLE, that it TALKS, and
##      that there is a floor behind it you can walk onto.
##   E  The vault refuses without floor N+1's item (GDD §5.3), and behind it are
##      three rooms, a harder pack, one relic and one rich chest. **Skipped with a
##      note on floor 4**, which authors no vault because the boss room is the
##      vault -- `vault_key(4)` is empty on its own, with no branch anywhere.
##   F  The deep chest carries the relic `FloorDb` names for this floor's
##      `deep_chest` slot, as a mote you walk over.
##   G  The boss is awake, the door names it, killing it opens the door and hands
##      over the floor's item. And on `--level=4` only, the Long Descent is
##      untouched: level 5 generates with no anchors, no locked doors, and its
##      stair back in the deepest room.
##
## ## What "walked to" means here, precisely
##
## The hero is swept along the room tree with `CharacterBody3D.test_move` -- his
## real capsule, against the real collision, one 0.45 m step at a time, sliding
## when a chest or a pillar is in the way and FAILING when nothing gets him
## through. That is a claim about geometry, which is what reachability is.
##
## It is deliberately not synthetic stick input. Movement here is
## camera-relative, so an input walk across sixty metres of corridor measures the
## camera boom as much as the floor, and it is the one thing in this beat that
## can fail for a reason that is not the level. The presses that MATTER -- the
## refusals and the opens -- are real `interact` taps at the end of every walk.
##
## `Vault` is never NAMED. It is a `class_name` added in the same change as this
## file, so it is not in the global script class cache until somebody runs
## `--import`, and naming it is a parse error that takes the whole run down
## before its first frame (`tools/directors/gate_locks.gd` records the lesson).
## Everything below goes through node handles and public accessors.

## Forced so the floor is the same floor every run. `Dungeon.seed_override` no
## longer suppresses the manifest, which is the only reason this beat can force a
## layout AND check the room count in the same pass.
const SEED := 20260809

## Which authored floor this run is about. `--level=N`, 1..4.
##
## THE WHOLE FILE USED TO SAY 1. Every check below was already asking `FloorDb`
## rather than restating the Cistern's numbers -- room count, pack, roster, boss
## item, vault key, relics -- so the floor was a parameter in everything but the
## argument. Four floors is what `docs/SCOPE.md` §1 freezes and what the demo is,
## and floors 2, 3 and 4 had never been generated by any director at all: the
## Foundry, the Choir and the Chord Gate were four authored table rows nobody had
## watched build a room.
var _level := 1

## One sweep step. Shorter than the 2.4 m doorway so a diagonal approach still
## fits through it, longer than the slide fallback needs to be useful.
const STEP := 0.45
## Sweep steps per rendered frame. The walk is a geometry test, not a stroll --
## at one step a frame a sixty-metre corridor is four hundred frames of nothing.
const STEPS_PER_FRAME := 8

## `--sabotage=<name>`: break ONE thing on purpose and see whether the check
## whose job it is says so. **`CLAUDE.md` §2 -- a director you have never pointed
## at a known answer has never been tested**, however many times it has passed,
## and card #67 is that section's other half: four checks reported a broken door
## on a floor whose door was fine, because one of them could not fail on its own
## and the other three could not fail at all.
##
## The null case is the ordinary run: no flag, `FLOOR ok` on every one of these.
## These three are the positive controls, one per way the shortcut beat can be
## wrong, and each names the check that MUST go red:
##
##   `stand-off`   Park the hero 6 m further out than `_walk_to` puts him, past
##                 `LockedDoor`'s 2.9 m trigger. **C1 fails, and the beat bails.**
##                 This is the shape card #67 arrived in -- and the bail is the
##                 fix for the half of it that was the instrument: D1/D2/D3 must
##                 NOT run, because a check measured against a null focus is a
##                 check that cannot fail for its own reason.
##   `wrong-line`  Say a line over the HUD that the door never said. **D1 and D2
##                 fail**, C1 stays green -- they read the prompt, and they are
##                 reading it rather than reading `""`.
##   `pre-open`    Solve the gate after the refusal is photographed and before the
##                 button is pressed. **D3 fails**, and D5 fails later for the
##                 same reason -- an open door owns no button.
const SABOTAGE: Array[String] = ["stand-off", "wrong-line", "pre-open"]

var out := ""
var _fails := 0
var _notes: Array[String] = []
var _sabotage := ""


func run(rig) -> void:
	out = rig.arg("out", "/tmp/floor/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_level = clampi(int(rig.arg("level", "1")), 1, 4)
	_sabotage = rig.arg("sabotage", "")
	if _sabotage != "":
		if not SABOTAGE.has(_sabotage):
			print("FLOOR FAIL unknown --sabotage=%s (have %s)" % [_sabotage, SABOTAGE])
			return
		print("FLOOR CALIBRATION --sabotage=%s -- this run is SUPPOSED to fail. "
			% _sabotage
			+ "A green run under a sabotage flag is a broken check, not a pass.")

	Game.reset()
	Run.enter(SEED)

	# The host scene, checked out loud, because getting it wrong does not look
	# like getting it wrong. This beat ADDS a `Dungeon` to whatever scene it was
	# pointed at, so run against garrison.tscn it generates a floor on top of
	# the garrison -- and the garrison's south curtain wall stands across the
	# first corridor at z=10.7. The result is seventeen failures that read
	# exactly like a broken level: unreachable vault, unreachable boss, an
	# unopened chest. One wrong --scene cost an hour of reading level-generation
	# code that was fine. Say it in one line instead.
	if rig.scene().name != &"DungeonRun":
		print("FLOOR FAIL wrong host scene (%s) -- this beat replaces the "
			% rig.scene().name
			+ "'Dungeon' child of res://scenes/rooms/dungeon.tscn. Pass "
			+ "--scene=res://scenes/rooms/dungeon.tscn")
		return

	var d := await _rebuild(rig, _level)
	if d == null:
		print("FLOOR FAIL the dungeon did not build")
		return
	var hero: Node3D = _hero(rig)
	if hero == null:
		print("FLOOR FAIL there is no hero in the scene")
		return
	var cam := _game_camera(rig)
	if cam != null:
		cam.make_current()
	await rig.wait_frames(20)

	_manifest(d)
	_anchors(d)
	# Off the floor before the walks: a pack that follows the hero into the next
	# beat turns a reachability measurement into a fight. The BOSS stays -- it is
	# the one body this beat is about.
	_clear_the_floor(d)
	# And the locks that are not geometry. See the function.
	_unbar_the_puzzles(d)
	await rig.wait_frames(6)

	await _shortcut_refuses(rig, d, hero)
	# FLOOR 4 HAS NO VAULT, AND THE ABSENCE IS THE DESIGN. GDD §5.3: the boss room
	# IS the vault down there, and nothing in `FloorDb` needs a branch to say so --
	# `vault_key(4)` comes out empty on its own because there is no floor 5 to lend
	# it a key. So the E beats are skipped rather than failed, and it is said out
	# loud: a silently-skipped beat reads as a passing one, which is the whole
	# mistake card #72 is about.
	if FloorDb.has_vault(_level):
		await _vault_refuses(rig, d, hero)
	else:
		_notes.append("E skipped: floor %d authors no vault (the boss room is the"
			% _level + " vault, GDD §5.3) -- vault_key(%d) is empty" % _level)
	await _the_boss(rig, d, hero)
	await _deep_chest(rig, d, hero)
	await _way_down(rig, d, hero)
	await _shortcut_opens(rig, d, hero)
	if FloorDb.has_vault(_level):
		await _the_vault(rig, d, hero)
	# The Long Descent is one claim about level 5 and it belongs to the deepest
	# authored floor, not to all four -- four floors each proving the same thing
	# about the same fifth level is three copies of a check (CLAUDE.md §0).
	if _level == 4:
		await _endless(rig, hero)

	for n in _notes:
		print("FLOOR note %s" % n)
	if _fails == 0:
		print("FLOOR ok -- every check passed")
	else:
		print("FLOOR FAIL -- %d check(s) failed" % _fails)


## The title the boss door will put on the HUD, from the same row the door reads.
##
## Not a word this file spells. G4 used to assert `contains("WARDEN")`, which is
## floor 1's boss and would go red on the Slag Ogre for no reason but the floor
## being a different one.
func _boss_title() -> String:
	var row := BossDb.get_boss(FloorDb.boss(_level))
	return String(row.get("title", "")) if not row.is_empty() else ""


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("FLOOR ok %s" % label)
	else:
		_fails += 1
		print("FLOOR FAIL %s" % label)


# --- Fixture ------------------------------------------------------------------

## Replace the scene's `Dungeon` with a seeded one. The scene's own node builds
## in `_ready`, before any director exists, off a run seed taken from the wall
## clock -- so the floor a director photographs would otherwise be a different
## floor every time it ran.
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


func _hero(rig) -> Node3D:
	var players: Array = rig.get_nodes_in_group(&"player")
	return players[0] if not players.is_empty() else null


func _game_camera(rig) -> Camera3D:
	for n in _all(rig.scene()):
		if n is GameCamera:
			return n
	return null


## Is `n` anywhere under a node called `name`?
func _under(n: Node, ancestor: String) -> bool:
	var at := n.get_parent()
	while at != null:
		if at.name == ancestor:
			return true
		at = at.get_parent()
	return false


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


# --- A. The manifest ------------------------------------------------------------

func _manifest(d: Node) -> void:
	var want_rooms := FloorDb.rooms(_level)
	var want_pack := FloorDb.pack(_level)
	print("FLOOR %s -- %d rooms, pack %s, tint %s"
		% [FloorDb.name_of(_level), want_rooms, want_pack, FloorDb.tint_key(_level)])
	_ck("A0 %s is %d rooms and the floor built %d"
		% [FloorDb.name_of(_level), want_rooms, d.rooms.size()],
		d.rooms.size() == want_rooms)
	_ck("A1 the pack is the manifest's %s (%d..%d)"
		% [want_pack, d.enemies_min, d.enemies_max],
		d.enemies_min == want_pack.x and d.enemies_max == want_pack.y)
	# `FloorDb` defers MOST floors' packs to the curve on purpose (floor 1's mouth
	# has to stay easy forever, GDD §7). If a deferring floor and the curve ever
	# disagree, one of them grew a second curve.
	#
	# FLOOR 4 IS THE ONE AUTHORED OVERRIDE and asserting deferral there is wrong:
	# `Prog.pack(4)` is (3, 7), which is correct for seven skeletons and absurd for
	# seven iron knights, so the table cuts it to (2, 4) on purpose. Which floors
	# defer is read off the table's own sentinel rather than listed here -- a list
	# would be a second copy of the decision.
	var defers: bool = FloorDb.get_floor(_level).get("pack", FloorDb.PACK_FROM_PROG) \
		== FloorDb.PACK_FROM_PROG
	if defers:
		_ck("A2 and the manifest deferred it to Prog (%s)" % Prog.pack(_level),
			want_pack == Prog.pack(_level))
	else:
		_ck("A2 the authored pack override is not just the curve restated (%s vs %s)"
			% [want_pack, Prog.pack(_level)], want_pack != Prog.pack(_level))

	# The deletion, checked. `Dungeon.BANDS` and `Dungeon.BAND_DEEP` duplicated
	# `FloorDb.bands()`; CLAUDE.md §0 says delete the loser rather than land both.
	var consts: Dictionary = d.get_script().get_script_constant_map()
	_ck("A3 Dungeon.BANDS is gone", not consts.has("BANDS"))
	_ck("A4 Dungeon.BAND_DEEP is gone", not consts.has("BAND_DEEP"))

	# Every body, against the roster for ITS room's distance. A generator that
	# read the table but keyed it on the wrong number would pass every check
	# above and spawn the entrance room's monsters at the bottom of the floor.
	var wrong := 0
	var seen := 0
	for cell: Vector2i in d.rooms:
		var root: Node = d.rooms[cell].get("node")
		if root == null:
			continue
		var dist := int(d.rooms[cell]["dist"])
		var pool: Array = FloorDb.roster(_level, dist)
		for e in _every(root, func(n: Node) -> bool: return n is Enemy):
			# The Warden is an `Enemy` too, and it is a golem no band of the
			# Cistern has ever heard of -- rightly, because `BossDb` chose it and
			# not the band table. Counted, it read as the generator spawning
			# off-roster bodies at the bottom of the floor.
			if _under(e, "Arena"):
				continue
			seen += 1
			if not pool.has((e as Enemy).kind):
				wrong += 1
				print("FLOOR   %s at dist %d is not in %s"
					% [(e as Enemy).kind, dist, pool])
	_ck("A5 all %d bodies came out of %s's own roster"
		% [seen, FloorDb.name_of(_level)],
		seen > 0 and wrong == 0)


# --- B. The four anchors ---------------------------------------------------------

func _anchors(d: Node) -> void:
	# The layout itself, printed. A reachability failure forty metres in is a
	# question about which room is next to which, and reading it out of the frame
	# is guesswork -- this is four lines and it answers it.
	for cell: Vector2i in d.rooms:
		var r: Dictionary = d.rooms[cell]
		print("FLOOR   room %s dist %d size %.0f doors %s parent %s"
			% [cell, r["dist"], d.size_of(cell), r["doors"], r["parent"]])
	var vault: Node3D = d.get_node_or_null(^"Vault")
	if vault != null:
		print("FLOOR   vault mouth %.1f,%.1f running %.2f,%.2f"
			% [vault.global_position.x, vault.global_position.z,
				vault.global_transform.basis.z.x, vault.global_transform.basis.z.z])
	# `vault_door` is only in this list on a floor that HAS a vault. Floor 4 does
	# not (GDD §5.3, the boss room is the vault), and `Dungeon` rightly places no
	# door -- so demanding one is demanding the generator break the design.
	var wanted: Array[StringName] = [&"boss_door", &"deep_chest", &"shortcut_door"]
	if FloorDb.has_vault(_level):
		wanted.append(&"vault_door")
	for id: StringName in wanted:
		var n: Node = d.anchor_node(id)
		var p: Dictionary = d.placements.get(id, {})
		print("FLOOR anchor %s -> %s in room %s, side %s"
			% [id, n.name if n != null else "MISSING", d.anchor_cell(id),
				p.get("side", &"-")])
		_ck("B0 %s was placed" % id, n != null)

	_ck("B1 the boss door is in the deepest room",
		d.anchor_cell(&"boss_door") == d.deepest)
	_ck("B2 the deep chest is beside it, in the same room",
		d.anchor_cell(&"deep_chest") == d.deepest)
	_ck("B3 the shortcut is at the entrance",
		d.anchor_cell(&"shortcut_door") == d.entrance)
	if FloorDb.has_vault(_level):
		var mid: Vector2i = d.anchor_cell(&"vault_door")
		var mid_dist := int(d.rooms[mid]["dist"])
		var deep_dist := int(d.rooms[d.deepest]["dist"])
		_ck("B4 the vault is in the middle ring (dist %d of %d)"
			% [mid_dist, deep_dist], mid_dist > 0 and mid_dist < deep_dist)
	else:
		_ck("B4 a floor with no vault placed no vault door",
			d.anchor_node(&"vault_door") == null)

	# The two fork rules, off the table so they cannot drift from GDD §5.3.
	var sc: Node = d.anchor_node(&"shortcut_door")
	var vd: Node = d.anchor_node(&"vault_door")
	_ck("B5 the shortcut takes this floor's OWN boss item (%s)"
		% sc.key_item, sc != null and sc.key_item == FloorDb.boss_item(_level))
	if FloorDb.has_vault(_level):
		_ck("B6 the vault takes the floor below's (%s)" % vd.key_item,
			vd != null and vd.key_item == FloorDb.boss_item(_level + 1))

	# GDD §5.1: the boss door REPLACES the stair. Both halves of that.
	var deep_root: Node = d.rooms[d.deepest]["node"]
	var in_room := _every(deep_root, func(n: Node) -> bool: return n is Stairs)
	_ck("B7 there is no stair left in the deepest room (%d)" % in_room.size(),
		in_room.is_empty())
	var landing: Node = d.get_node_or_null(^"BossLanding")
	var behind := _every(landing, func(n: Node) -> bool: return n is Stairs) \
		if landing != null else []
	_ck("B8 the way down is in the landing behind the boss door",
		behind.size() == 1)

	# The arena is the deepest room, so the room had to be built to hold the ring
	# the table authored. A 16 m room and an 11 m radius is a fight through a wall.
	var arena: Node = deep_root.get_node_or_null(^"Arena")
	_ck("B9 the deepest room has the arena in it", arena != null)
	if arena != null:
		var r: float = arena.radius()
		var half: float = d.size_of(d.deepest) * 0.5
		print("FLOOR arena radius %.1f m in a %.1f m chamber" % [r, half * 2.0])
		_ck("B10 the seal ring fits inside the masonry (%.1f < %.1f)" % [r, half],
			r < half)


## Free every ordinary body on the floor. See the call site.
func _clear_the_floor(d: Node) -> void:
	var boss: Node = null
	var deep_root: Node = d.rooms[d.deepest]["node"]
	var arena: Node = deep_root.get_node_or_null(^"Arena")
	if arena != null:
		boss = arena.boss()
	var freed := 0
	for e in _every(d, func(n: Node) -> bool: return n is Enemy):
		# The vault's pack is behind a locked door and cannot walk into a
		# measurement, and beat E is about to count it.
		if e == boss or _under(e, "Vault"):
			continue
		freed += 1
		e.queue_free()
	print("FLOOR cleared %d bodies for the reachability walks" % freed)


## Solve and swing every `PuzzleGate` on the floor, for the same reason the line
## above frees every body: **beats C, F and G are claims about GEOMETRY**, and a
## shut gate is a lock, not a wall you cannot build a way through.
##
## M4's puzzle spine put a `PuzzleGate` in the doorway on the way to the deepest
## room (`docs/PUZZLES.md` §5.2 -- the gate room is on the critical path by
## construction). Without this the reachability sweep rubs along the closed
## leaves for four hundred steps and reports the boss chamber unreachable, which
## is true of a player who has not solved it and says nothing about the floor.
##
## That the gate GATES is `tools/directors/puzzle_loop.gd`'s claim, and it is the
## whole of that file. This one is not allowed to make it and must not silently
## depend on it either way.
##
## ## The shortcut door is HELD SHUT here, and that is card #67
##
## This loop was written when `puzzle_gate` meant one thing: §5.2's gate room, in
## a doorway, on the critical path. Card #5 then made the SHORTCUT a `PuzzleGate`
## too (`ShortcutGate`), so it joined the group -- and this function, running six
## lines before the beat that is about it, solved its eye and swung it open.
##
## `LockedDoor._swing()` sets `enabled = false`, which drops `Prompt`'s focus for
## ever. So beat D walked to a door that was already open, could not acquire the
## interact button (C1), read `Hud._prompt` as `""` (D1), and found the door open
## when it asserted a press had not opened it (D3). Four red checks, on a door
## that `tools/directors/shortcut_puzzle.gd` proves is fine, out of one line of
## fixture code that could not know what it was reaching for.
##
## The rule that keeps it fixed is the one the docstring above already states and
## this loop had outgrown: **unbar what stands between the hero and a ROOM.** The
## shortcut is not on the way to anywhere -- it stands in the entrance room's
## blank wall and opens onto its own landing, which beat D walks after opening it
## deliberately. A fixture is allowed to remove the locks a measurement is not
## about. It is not allowed to remove the lock the measurement IS about.
func _unbar_the_puzzles(d: Node) -> void:
	var opened := 0
	var shut := 0
	# Named rather than "the one in the entrance room": the anchor id is what
	# `Dungeon` placed it under and what beat D asks for it by, so the two cannot
	# drift apart into a fixture holding one door and a beat testing another.
	var mine: Node = d.anchor_node(&"shortcut_door")
	for node in _every(d, func(n: Node) -> bool:
			return n.is_in_group(&"puzzle_gate")):
		if node == mine:
			print("FLOOR held %s shut -- beat D is about it" % node.name)
			continue
		if _solve_gate(node):
			opened += 1
		else:
			shut += 1
			print("FLOOR   a puzzle gate would not open: \"%s\""
				% node.call(&"refusal_line"))
	if shut > 0:
		_ck("C-1 every puzzle gate opened for the reachability walks", false)
	# And the chord's bars, which refuse from the near side by design -- a sweep
	# arriving from the wrong side of a one-way passage is the same measurement
	# problem as a shut gate.
	var bars := 0
	for node in _every(d, func(n: Node) -> bool:
			return n.has_method(&"on_far_side")):
		node.call(&"lift")
		bars += 1
	print("FLOOR opened %d puzzle gate(s) and %d barred passage(s)" % [opened, bars])


## True when a door is `docs/PUZZLES.md` §1's PURE LOCK rather than §5.1's puzzle.
##
## That is floor 4 and only floor 4, and it is design and not an omission: its
## shortcut's key is the Far Lantern, which §1 (and `docs/PUZZLES.md` §5.1's table)
## gives no verb -- *"it is the last door in the game and a pure lock, which is the
## correct shape for a thing that ends Act I."* `Dungeon._shortcut_pool` comes back
## empty there and `_place_shortcut` falls through to a bare `LockedDoor`.
##
## **Asked of the DOOR, never of `_level`.** The level number is what chose the
## door in the first place, so re-deriving the answer from it here would be a second
## opinion that can drift from the one that matters. `atoms()` is `PuzzleGate`'s and
## it is also exactly the method `_solve_gate` needs to exist -- so the predicate
## and the thing it guards cannot disagree, which is the whole reason it is a
## predicate rather than an `if _level == 4`.
static func is_pure_lock(door: Node) -> bool:
	return not door.has_method(&"atoms")


## Answer every atom a gate is watching, and spend a key if it wants one. Returns
## whether the door is open afterwards.
##
## One function because it has two callers with opposite intents and they must not
## drift: the fixture above uses it to REMOVE a lock a measurement is not about,
## and beat D uses it to PERFORM the floor's own verb in front of the door it is
## measuring. Written twice, the day somebody teaches the fixture about a new kind
## of atom is the day beat D stops opening the shortcut.
func _solve_gate(node: Node) -> bool:
	if is_pure_lock(node):
		# There are no atoms to answer, and the loop below would call `atoms()` on a
		# door that does not have it -- which is precisely what happened on floor 4:
		# `SCRIPT ERROR: Nonexistent function 'atoms (via call)' in base 'LockedDoor'`.
		# Owning the key IS the solve here, so the honest fixture is the press.
		node.call(&"activate", null)
		return bool(node.call(&"is_open"))
	for atom in node.call(&"atoms"):
		# ARMED first. The gate room's key is deliberately disarmed until the sun
		# socket lights it (`Dungeon._place_gate_room`), and `PuzzleAtom.solve()`
		# refuses while it is -- so a loop that only called `solve` opened nothing,
		# said it had opened one, and left the reachability sweep rubbing along a
		# shut door for four hundred steps.
		atom.set(&"armed", true)
		atom.call(&"solve")
	# `needs_key` gates spend one at the door. The hunt that produces it is
	# `puzzle_loop`'s beat; here the key is simply given.
	if bool(node.get(&"needs_key")):
		Game.add_key(1)
	# `auto_open` gates have already swung on the last solve; this is the second
	# half of `needs_key`, and a no-op on a door that is open (`PuzzleGate.activate`
	# returns on `is_open()`).
	node.call(&"activate", null)
	return bool(node.call(&"is_open"))


# --- C. Walking it ----------------------------------------------------------------

## Put the hero back where he arrives and walk the tree to `cell`, then stop a
## stride and a half in front of `face` (a door, a chest) looking at it.
func _walk_to(rig, d: Node, hero: Node3D, cell: Vector2i, face: Node3D) -> bool:
	var ok := await _walk_rooms(rig, d, hero, cell)
	if face != null and ok:
		# 1.9 m out along the prop's own facing. A `LockedDoor`'s leaves face into
		# the room down its -basis.z... which is the CONTRACT's forward, so the
		# side the player stands on is +basis.z (docs/CONTRACT.md §2.5).
		var stop := face.global_position + face.global_transform.basis.z * 1.9
		stop.y = 0.15
		ok = await _sweep(rig, hero, [stop])
	if face != null and ok:
		var to := K.flat(face.global_position - hero.global_position)
		if to != Vector3.ZERO:
			hero.facing_yaw = atan2(to.x, to.z)
			hero.rotation.y = hero.facing_yaw + PI
	Bus.camera_recenter.emit()
	await rig.wait_frames(24)
	return ok


## Walk the room tree from the entrance to `cell`, threading each DOORWAY on its
## own axis instead of cutting from room centre to room centre.
##
## The corner-cutting version is why the first honest run of this file called the
## boss chamber unreachable. `door_span` is 6 m but the kit doorway standing in
## the hole narrows it: measured against the hero's own capsule, the gap he fits
## through is about a metre either side of the axis. So the metre of drift he
## picks up walking round one chest is a hero who arrives at the wall BESIDE the
## opening -- and then rubs along it for four hundred steps, because a sweep has
## no eyes and slides the same way every time. A player looks at the door. This
## tells the sweep where it is.
##
## Room centres are deliberately NOT waypoints: the straight line from one
## doorway to the next crosses open floor, and the middle of a room is where the
## furniture is.
func _walk_rooms(rig, d: Node, hero: Node3D, cell: Vector2i) -> bool:
	hero.global_position = d.centre_of(d.entrance) + Vector3(0.0, 0.15, 0.0)
	await rig.wait_frames(2)

	var up := Vector3(0.0, 0.15, 0.0)
	var cells: Array[Vector2i] = d.path_to(cell)
	var route: Array[Vector3] = []
	for i in maxi(cells.size() - 1, 0):
		var a: Vector2i = cells[i]
		var b: Vector2i = cells[i + 1]
		var step: Vector2i = b - a
		var ax := Vector3(float(step.x), 0.0, float(step.y))
		# Measured off each room's OWN half-width. The deepest room is 26 m and
		# its neighbours are 16, so "half the spacing" is wrong on exactly the
		# corridor that matters.
		var face_a: Vector3 = d.centre_of(a) + ax * (d.size_of(a) * 0.5)
		var face_b: Vector3 = d.centre_of(b) - ax * (d.size_of(b) * 0.5)
		route.append(face_a - ax * 1.6 + up)
		route.append((face_a + face_b) * 0.5 + up)
		route.append(face_b + ax * 1.6 + up)
	route.append(d.centre_of(cell) + up)
	# 0.3 m: a gate you thread, not a place you arrive. The last leg relaxes back
	# to a stride (see `_sweep`) because the destination is a room, not a hole.
	return await _sweep(rig, hero, route, 0.3)


## The walk itself: the hero's real capsule, stepped through the real collision.
##
## Two ways it gives up, and they mean different things -- which is why they are
## reported differently. **Walled in** is geometry: nothing in front, nothing to
## either side, the leg is closed. **Sliding** is a hero rubbing along masonry --
## a target he cannot stand on, or a hole he is beside rather than in front of.
## The first run of this file spent 500 steps doing the second and reported it as
## the first; a silent step budget cannot tell you which one you have.
func _sweep(rig, hero: Node3D, route: Array[Vector3], tol: float = 0.7) -> bool:
	var n := 0
	for leg in route.size():
		var target: Vector3 = route[leg]
		# The last waypoint is a destination and the ones before it are gates.
		var near := tol if leg < route.size() - 1 else maxf(tol, 0.7)
		var guard := 0
		# Consecutive steps that went sideways rather than forward.
		var blocked := 0
		var best := INF
		while guard < 400:
			guard += 1
			# `K.plane`, NOT `K.flat`. `flat` normalises -- its own docstring in
			# `consts.gd` says so and counts the three bugs it has already caused
			# -- so `K.flat(target - here).length()` is 1.0 everywhere in the
			# world, the arrival test never fires, and a hero standing 100 mm from
			# the door reports himself a metre short of it. This was the fourth.
			var to := K.plane(target - hero.global_position)
			best = minf(best, to.length())
			if to.length() < near:
				break
			var step := to.limit_length(STEP)
			# Zeroed every step. We are teleporting a `CharacterBody3D` that is
			# still running its own `move_and_slide`, and the velocity it had when
			# it last touched a wall will keep shoving it sideways between our
			# frames -- which reads in the trace as a hero drifting out of a
			# doorway he was already lined up with.
			hero.velocity = Vector3.ZERO
			if not hero.test_move(hero.global_transform, step):
				hero.global_position += step
				blocked = 0
			else:
				# Something small is in the way -- a chest, a pillar, the corner
				# of a doorway reveal. Try either side of it before giving up; a
				# walk that failed on the first chest would report the floor
				# unreachable because it has furniture in it.
				blocked += 1
				var side := Vector3(-step.z, 0.0, step.x).normalized() * STEP
				if not hero.test_move(hero.global_transform, side):
					hero.global_position += side
				elif not hero.test_move(hero.global_transform, -side):
					hero.global_position -= side
				else:
					_leg_failed("walled in", leg, route.size(), hero, target, best,
						step)
					return false
				# Sliding is for getting round furniture. Thirty strides of it in
				# a row is not a detour, it is a hero rubbing along a wall.
				if blocked > 30:
					_leg_failed("sliding, not advancing", leg, route.size(),
						hero, target, best, step)
					return false
			n += 1
			if n % STEPS_PER_FRAME == 0:
				await rig.wait_frames(1)
		if guard >= 400:
			# `to` is the last step this leg wanted, which is the direction the report
			# below should probe -- a hero who has run out of strides is standing
			# against whatever he could not get past.
			_leg_failed("out of steps", leg, route.size(), hero, target, best,
				K.plane(target - hero.global_position).limit_length(STEP))
			return false
	await rig.wait_frames(2)
	return true


## How much empty grid the shortcut's landing was given, against how much it needs.
##
## **Printed on every run, not only on a failure**, because the only way to read
## "run 0 of 1 wanted" as a fault is to have seen a floor that works print "1 of 1".
## `Dungeon._pick_side` asks `_clear_run` for `_reach_for` cells of empty grid and
## takes the best wall it can find **whether or not that wall has them** -- the
## `push_warning` above it only fires when there is no free wall at all. So a
## landing built 13 m out through the room next door (`LAND_STUB` 4 + `LAND_SIZE` 9)
## generates, renders, lights its sconce, and looks exactly like a landing until
## something tries to walk from the door to the stair.
##
## D10 is that something. This line is what tells you whether D10 red means "the
## stair is behind a wall the generator laid on top of it" or "the sweep is bad at
## walking", and those two have opposite fixes.
func _landing_clearance(d: Node) -> void:
	var cell: Vector2i = d.anchor_cell(&"shortcut_door")
	var side: StringName = d.placements[&"shortcut_door"]["side"]
	var want: int = d._reach_for(&"shortcut_door", cell)
	# **`_clear_run` is the wrong question asked after the fact.** It treats a
	# RESERVED cell as occupied, and `_plan_anchors` reserved this very anchor's run
	# before the floor was built -- so it answers 0 on a floor whose landing has all
	# the room in the world. The first version of this line printed
	# "0 clear cell(s) of 1 wanted" on floor 1, which works, and on floor 2, which
	# does not, and looked like a diagnosis. CLAUDE.md §2, from the other side: the
	# instrument invented a fault, and the null case is what caught it.
	#
	# The honest question is whether a ROOM is in the way. `rooms` is what the
	# geometry was actually built from.
	var step: Vector2i = d.DIRS[side]
	var hit := Vector2i.ZERO
	var found := false
	for k in range(1, want + 1):
		var at: Vector2i = cell + step * k
		if d.rooms.has(at):
			hit = at
			found = true
			break
	print("FLOOR landing %.1f m out of the %s wall of %s (wants %d cell(s))"
		% [d.LAND_STUB + d.LAND_SIZE, side, cell, want])
	if not found:
		print("FLOOR   nothing occupies that run -- the landing has the grid to itself")
		return
	# The overlap in METRES, because the cell count cannot say whether a neighbour is
	# a 16 m room 3 m away or a 27 m one that starts inside the stub.
	var gap: float = d.centre_of(hit).distance_to(d.centre_of(cell)) \
		- d.size_of(cell) * 0.5 - d.size_of(hit) * 0.5
	print("FLOOR   ROOM %s (%.0f m wide) is %.1f m past that wall, so the landing is "
		% [hit, d.size_of(hit), gap]
		+ "built %.1f m INSIDE it" % (d.LAND_STUB + d.LAND_SIZE - gap))
	print("FLOOR   `Dungeon._pick_side` took this wall with a clear run of 0 because "
		+ "it was the room's ONLY free wall, and it takes the best it can find "
		+ "whether or not the clearance is there.")


## **NAME THE COLLIDER.** Without this the report is a pair of coordinates and a
## distance, which is enough to know a walk failed and not enough to know whether
## the fault is the floor or the sweep -- floor 2's D10 spent an afternoon being
## blamed on `Dungeon._pick_side` laying the landing through occupied grid, and the
## clearance readout then showed floor 1 doing exactly the same thing and passing.
##
## `move_and_collide(step, true)` is test-only: it moves nothing and returns the
## `KinematicCollision3D`, so the thing in the way can be asked its own name. `y` is
## printed for both ends too, because a step up onto a lip reads in x/z as a hero
## standing still against nothing.
func _leg_failed(why: String, leg: int, legs: int, hero: Node3D, target: Vector3,
		best: float, step: Vector3 = Vector3.ZERO) -> void:
	print("FLOOR   %s on leg %d/%d: at %.1f,%.2f,%.1f, %.1f m short of "
		% [why, leg + 1, legs, hero.global_position.x, hero.global_position.y,
			hero.global_position.z, K.plane(target - hero.global_position).length()]
		+ "%.1f,%.2f,%.1f (closest approach %.1f m)"
		% [target.x, target.y, target.z, best])
	if step == Vector3.ZERO or not (hero is CharacterBody3D):
		return
	# Probed in the wanted direction and then either side of it, which is the same
	# three tries the sweep itself makes -- so the three names below ARE the reason
	# it gave up, not a fourth guess about it.
	var side := Vector3(-step.z, 0.0, step.x).normalized() * step.length()
	for pair in [["ahead", step], ["left", side], ["right", -side]]:
		var hit := (hero as CharacterBody3D).move_and_collide(pair[1], true)
		if hit == null:
			print("FLOOR     %-5s clear" % pair[0])
			continue
		var who := hit.get_collider()
		print("FLOOR     %-5s blocked by %s (%s) at %.1f,%.2f,%.1f" % [pair[0],
			who.name if who != null else "?",
			who.get_class() if who != null else "?",
			hit.get_position().x, hit.get_position().y, hit.get_position().z])


## Wait for `prop` to own the interact button. The hero has usually just left
## another prop's trigger and the exit takes a physics frame or two, during which
## `Prompt.focus` is still the thing he walked away from -- a `focus != null`
## wait breaks instantly on the wrong one (gate_locks.gd learned this).
func _focus(rig, prop: Node) -> bool:
	for _i in 90:
		if Prompt.focus == prop:
			return true
		await rig.wait_frames(2)
	return false


# --- D. The shortcut ---------------------------------------------------------------

## **C1 is a gate on the three checks under it, not a check beside them.**
##
## D1, D2 and D3 all read something that only exists while the door is focused --
## the HUD line it puts up, and the press it answers. Run against a null focus
## they measure nothing: card #67 is four red checks of which exactly one was
## real, and the three passengers made a one-line fixture bug look like a broken
## door. `Hud._prompt` is `""` when nothing is focused, so "the refusal NAMES the
## bow" failed on an empty string; "pressing it opened nothing" is the shape a
## LOCKED door is supposed to have and failed on the door being open already.
## A check that cannot fail for its own reason is not a check, and three of them
## reporting one fault four times is worse than silence -- it is four faults.
##
## So the beat bails, loudly, naming what it did not get to measure. Proven with
## `--sabotage=stand-off`.
func _shortcut_refuses(rig, d: Node, hero: Node3D) -> void:
	var door: Node3D = d.anchor_node(&"shortcut_door")
	if door == null:
		_ck("C0 the shortcut door is reachable", false)
		return
	var walked := await _walk_to(rig, d, hero, d.anchor_cell(&"shortcut_door"), door)
	_ck("C0 the shortcut door is reachable on foot from the entrance", walked)
	if _sabotage == "stand-off":
		# Out along the door's own +basis.z -- the side the player stands on
		# (`docs/CONTRACT.md` §2.5) -- to about 7.9 m, well past the 2.9 m trigger
		# `LockedDoor._ready` sets. Deliberately NOT through the door or into the
		# masonry: the known answer being installed is "the hero is standing too far
		# away", not "the hero is somewhere impossible".
		hero.global_position += door.global_transform.basis.z * 6.0
		await rig.wait_frames(6)
	if not await _focus(rig, door):
		_ck("C1 and it owns the interact button", false)
		print("FLOOR   so D1, D2 and D3 did not run -- they read the prompt and "
			+ "the press, and there is no focused prop to read either from. The "
			+ "hero is at %.1f,%.1f and the door is at %.1f,%.1f (%.1f m, trigger "
			% [hero.global_position.x, hero.global_position.z,
				door.global_position.x, door.global_position.z,
				K.plane(door.global_position - hero.global_position).length()]
			+ "is %.1f m)." % float(door.get(&"radius")))
		return
	_ck("C1 and it owns the interact button", true)

	if _sabotage == "wrong-line":
		# A line the door never said, over the top of the one it did. `Hud._prompt`
		# is whatever came last down `Bus.prompt_changed`, which is exactly the
		# channel D1 and D2 claim to be reading.
		Bus.prompt_changed.emit("LOCKED")
		await rig.wait_frames(2)

	var said: String = Hud._prompt
	# What the door itself would say, asked of the door. Compared rather than
	# matched against a word, because the word moved: this check said
	# `contains("BOW")` when the shortcut was a `LockedDoor` keyed on the bow, and
	# `docs/PUZZLES.md` §5.1 replaced that refusal with the ATOM'S -- "THE EYE IS
	# SHUT". A director carrying floor 1's word would go red on floor 2's pillar
	# for no better reason than that it is a different puzzle.
	#
	# It is not a tautology, and this is the one line in the beat where that has to
	# be argued: `LockedDoor.on_focus` deliberately FIGHTS `Prompt` to get a
	# refusal onto the HUD unformatted (a locked door has no verb, and "E TO NEEDS
	# THE BOW" is nonsense), one frame deferred, against a `_say_prompt()` that is
	# about to overwrite it. That race is what is being measured. It resolves the
	# wrong way as an empty string or as "E TO ...", and both are red here.
	var mouth: String = door.refusal_line()
	print("FLOOR shortcut locked prompt=\"%s\" (the door says \"%s\")" % [said, mouth])
	_ck("D0 the hero does not own %s yet" % FloorDb.boss_item(_level),
		not Game.has(FloorDb.boss_item(_level)))
	_ck("D1 the HUD carries the door's own refusal, verbatim (\"%s\")" % said,
		said != "" and said == mouth)
	_ck("D2 and does not just say LOCKED", not said.contains("LOCKED"))
	await rig.capture(out.path_join("f_01_shortcut_locked.png"))

	if _sabotage == "pre-open":
		# The floor's verb performed by nobody, after the refusal has been read and
		# before the button is pressed. D3 is the only check that may notice.
		_solve_gate(door)
		await rig.wait_frames(12)

	await rig.tap(["interact"])
	await rig.wait_frames(24)
	_ck("D3 pressing it opened nothing", not door.is_open())


## The other half of §5.1: **owning the bow is not using it.**
##
## This beat used to press `interact` and expect the door to swing, which is what
## a `LockedDoor` did. Card #5 deleted that door. The press is D3's, one beat
## above, and it still opens nothing; what opens the shortcut is the atom in front
## of it being answered.
##
## **Two shapes, and the beat has to know which one it is standing in front of.**
## Floors 1-3 get §5.1's `ShortcutGate`; floor 4 gets §1's pure lock, because the
## Far Lantern has no verb. Written for the gate alone, this beat produced three red
## checks and a `SCRIPT ERROR` on floor 4 — `_solve_gate` calling `atoms()` on a
## `LockedDoor` — and every one of them was the director being wrong about a door
## the docs describe twice. See `is_pure_lock`.
##
## The atom is answered here rather than SHOT. `tools/directors/shortcut_puzzle.gd`
## fires a real `Arrow` at the real eye and that is the whole of its beat D; this
## file is not allowed to own that claim twice (`CLAUDE.md` §0). What is left for
## the floor's own director is what a floor is: the door swings, it tells the
## placer where it goes, and there is a way down behind it that the hero can walk
## to.
func _shortcut_opens(rig, d: Node, hero: Node3D) -> void:
	var door: Node3D = d.anchor_node(&"shortcut_door")
	if door == null:
		return
	_ck("D4 the boss's death handed over %s" % FloorDb.boss_item(_level),
		Game.has(FloorDb.boss_item(_level)))
	await _walk_to(rig, d, hero, d.anchor_cell(&"shortcut_door"), door)
	if not await _focus(rig, door):
		_ck("D5 the shortcut door owns the button again", false)
		return
	_ck("D5 the shortcut door owns the button again", true)
	var said: String = Hud._prompt
	print("FLOOR shortcut with %s owned prompt=\"%s\"" % [FloorDb.boss_item(_level), said])
	# `ShortcutGate._on_item_acquired` exists for this line. `LockedDoor` announces
	# "X TO OPEN" on the frame the key item lands, which for a puzzle is a promise
	# the door cannot keep -- the Warden dying while the player stands here must
	# not turn an unshot eye into an invitation.
	# Floor 4's door is §1's pure lock and every clause of D6 inverts on it: there
	# is no unshot eye to make a false promise about, owning the Far Lantern IS the
	# solve, and so the invitation is the CORRECT line and its absence would be the
	# bug. Asserted rather than skipped -- a pure lock that stayed silent while
	# holding its own key is GDD pillar 3's failure, the refusal that says nothing.
	var lock := is_pure_lock(door)
	if lock:
		_ck("D6 owning %s turned the refusal into an invitation (\"%s\")"
			% [FloorDb.boss_item(_level), said],
			not door.is_open() and said.contains("TO OPEN"))
	else:
		_ck("D6 owning it opened nothing and promised nothing (\"%s\")" % said,
			not door.is_open() and not said.contains("TO OPEN"))

	var announced: Array[StringName] = []
	door.opened.connect(func(where: StringName) -> void: announced.append(where))
	if lock:
		# The press, and a REAL one through `rig.tap` -- `LockedDoor.activate` would
		# swing it from here, but the claim being made about a pure lock is that the
		# player's button opens it, and `Input.action_press` is the trap in CLAUDE.md
		# §3 that made three of these beats unreachable.
		await rig.tap(["interact"])
	else:
		_solve_gate(door)
	await rig.wait_frames(9)
	await rig.capture(out.path_join("f_08_shortcut_swinging.png"))
	await rig.wait_frames(90)
	_ck("D7 %s opened it" % ("pressing it with the key owned" if lock
		else "answering the floor's own verb"), door.is_open())
	_ck("D8 and told the placer where it goes (%s)" % [announced],
		announced.size() == 1)

	# Through it, to what is on the other side.
	var landing: Node = d.get_node_or_null(^"ShortcutLanding")
	var stairs: Array = _every(landing, func(n: Node) -> bool: return n is Stairs) \
		if landing != null else []
	_ck("D9 there is a way down behind the shortcut", stairs.size() == 1)
	if stairs.is_empty():
		return
	var down: Node3D = stairs[0]
	_landing_clearance(d)
	var walked := await _sweep(rig, hero, [
		door.global_position - door.global_transform.basis.z * 3.0
			+ Vector3(0.0, 0.15, 0.0),
		down.global_position - down.global_transform.basis.z * 2.6
			+ Vector3(0.0, 0.15, 0.0)])
	Bus.camera_recenter.emit()
	await rig.wait_frames(24)
	_ck("D10 and it is reachable through the opened door", walked)
	_ck("D11 the stair offers itself (\"%s\")" % Hud._prompt,
		await _focus(rig, down))
	await rig.capture(out.path_join("f_09_shortcut_stair.png"))

	# "Skips floor N" is the level going up by one without the rest of the floor
	# being walked. `Stairs.activate` calls `Flow.descend`, which is
	# `Run.descend_floor` and then a scene change -- the scene change would take
	# this director down with it, so the half that carries the CLAIM is called
	# directly and the half that loads a floor is left to Flow (CLAUDE.md §6).
	_ck("D12 the shortcut sits at depth 0, twenty metres from the way in",
		int(d.rooms[d.anchor_cell(&"shortcut_door")]["dist"]) == 0)
	Run.descend_floor()
	print("FLOOR shortcut lands on level %d -- %s"
		% [Run.level, FloorDb.name_of(Run.level)])
	_ck("D13 taking it skips %s and lands on %s"
		% [FloorDb.name_of(_level), FloorDb.name_of(_level + 1)],
		Run.level == _level + 1)
	# Back, because the beats after this one are still about floor 1. Emitted as
	# well as assigned: the HUD's depth card reads the signal, not the field.
	Run.level = _level
	Bus.level_changed.emit(_level)


# --- E. The vault --------------------------------------------------------------------

func _vault_refuses(rig, d: Node, hero: Node3D) -> void:
	var door: Node3D = d.anchor_node(&"vault_door")
	if door == null:
		_ck("E0 the vault door is reachable", false)
		return
	var walked := await _walk_to(rig, d, hero, d.anchor_cell(&"vault_door"), door)
	_ck("E0 the vault door is reachable on foot from the entrance", walked)
	_ck("E1 and it owns the interact button", await _focus(rig, door))

	var key := FloorDb.vault_key(_level)
	var said: String = Hud._prompt
	print("FLOOR vault key=%s locked prompt=\"%s\"" % [key, said])
	_ck("E2 it wants the floor BELOW's item, not this floor's (%s)" % key,
		key == FloorDb.boss_item(_level + 1) and key != FloorDb.boss_item(_level))
	_ck("E3 the hero does not own it", not Game.has(key))
	await rig.tap(["interact"])
	await rig.wait_frames(24)
	_ck("E4 and it stays shut", not door.is_open())
	await rig.capture(out.path_join("f_02_vault_locked.png"))
	# The refusal has to NAME the floor below's boss item, which is the whole of GDD
	# pillar 3 on the one door whose job is to say what is worth going deeper
	# for. It said "A KEY" for a while -- `LockedDoor.SIGILS` had rows for the
	# bow and the hookshot only and everything else fell through to
	# SIGIL_DEFAULT -- and M5 filled the row in, under the name the item
	# actually has now (`docs/GDD.md` §5.2: the satchel is a Verse you cast).
	# Still a NOTE and not a failure: the door was always correct and the table
	# was short, and this line is the tell if it ever goes short again.
	# The word is the KEY ITEM'S, not floor 1's. This used to test for "BURST"
	# literally, so on floors 2 and 3 -- whose vaults want the hookshot and the
	# Far Lantern -- it filed a note saying `SIGILS has no burst row` about a
	# refusal that was perfectly correct. A note that cries wolf on three floors
	# out of four is how a real short row gets scrolled past.
	var word := String(key).to_upper().replace("_", " ")
	if not said.contains(word):
		_notes.append("the vault says \"%s\" and does not name %s -- "
			% [said, word] + "LockedDoor.SIGILS may have no `%s` row, so GDD " % key
			+ "pillar 3's named refusal is one line short. "
			+ "scripts/props/locked_door.gd, not this card.")


func _the_vault(rig, d: Node, hero: Node3D) -> void:
	var door: Node3D = d.anchor_node(&"vault_door")
	var vault: Node = d.get_node_or_null(^"Vault")
	_ck("E5 the prefab is built behind the door", vault != null)
	if vault == null or door == null:
		return

	# Three rooms, and they are the prefab's, not a floor's.
	var floors := _every(vault, func(n: Node) -> bool:
		return n is Node3D and n.name.begins_with("Floor"))
	print("FLOOR vault %d slabs, %.1f m deep" % [floors.size(),
		vault.last_room().z + 5.5])
	_ck("E6 it is three rooms (last room centre %.1f m in)"
		% vault.last_room().z, vault.last_room().z > 30.0)

	var bodies := _every(vault, func(n: Node) -> bool: return n is Enemy)
	var levels: Array[int] = []
	var kinds: Array[StringName] = []
	for b in bodies:
		levels.append((b as Enemy).level)
		if not kinds.has((b as Enemy).kind):
			kinds.append((b as Enemy).kind)
	var floor_max := FloorDb.pack(_level).y
	print("FLOOR vault pack=%d over 3 rooms (floor caps at %d/room), kinds=%s, "
		% [bodies.size(), floor_max, kinds] + "level=%s" % [levels.slice(0, 3)])
	_ck("E7 the vault's bodies are a floor deeper than the floor (%d)"
		% (levels[0] if not levels.is_empty() else 0),
		not levels.is_empty() and levels.min() == _level + 1)
	# Its identity is still the Cistern's. A vault with a roster of its own has
	# become floor 5, and floor 5 is out of scope (SCOPE §2).
	var deep_pool: Array = FloorDb.roster(_level, 99)
	var alien := 0
	for k: StringName in kinds:
		if not deep_pool.has(k):
			alien += 1
	_ck("E8 and they are still %s's own %s" % [FloorDb.name_of(_level), deep_pool],
		alien == 0)

	var chest: Chest = vault.rich_chest()
	var deep: Chest = d.anchor_node(&"deep_chest")
	# It asks the curve the FLOOR BELOW's deepest-chest question, and the honest
	# claim is that and not "more picks". `Prog.chest_picks` steps once every
	# three floors, so on floor 1 the count ties the deep chest at 3 -- the vault
	# is richer because those three picks roll a level-2 table with a level-2
	# `rarity_lift` behind it, and demanding a bigger NUMBER here would be a
	# second curve invented in a director (SCOPE §2).
	var want_picks := Prog.chest_picks(_level + 1, true)
	_ck("E9 the rich chest rolls the floor below's deepest table (%d picks, "
		% (chest.picks if chest != null else -1)
		+ "the deep chest's own is %d)" % (deep.picks if deep != null else -1),
		chest != null and deep != null and chest.picks == want_picks
		and chest.picks >= deep.picks)

	# Nothing is lying in it yet, and that is the point: a `LootMote` is a live
	# pickup, and one minted at floor build sits in a room nobody can enter,
	# answering "is there loot near you" through the door. `Vault.reveal()` has
	# the rest of the reasoning; `mvp_loop.gd` found it by hauling the relic out
	# of a vault it never opened.
	var want := FloorDb.relic_in(_level, &"vault")
	_ck("E10 the prize is not on the floor while the door is shut",
		vault.relic_mote() == null and RelicDb.outstanding(want))

	# Open it and walk in. The Bomb Bag is M5's; granting it here is the same
	# move gate_locks makes with the Bow, and it is the only way to photograph
	# what the door is for.
	Game.grant(FloorDb.vault_key(_level))
	await rig.wait_frames(8)
	await _walk_to(rig, d, hero, d.anchor_cell(&"vault_door"), door)
	_ck("E11 the vault door owns the button with the key in the bag",
		await _focus(rig, door))
	print("FLOOR vault unlocked prompt=\"%s\"" % Hud._prompt)
	await rig.tap(["interact"])
	await rig.wait_frames(100)
	_ck("E12 the vault opened", door.is_open())
	var relic: LootMote = vault.relic_mote()
	_ck("E12a and opening it put %s in the last room" % want,
		relic != null and relic.item_id == want)
	await rig.capture(out.path_join("f_10_vault_open.png"))

	var walked := await _sweep(rig, hero, [
		door.global_position - door.global_transform.basis.z * 4.0
			+ Vector3(0.0, 0.15, 0.0),
		vault.to_global(vault.room_centre(0)) + Vector3(0.0, 0.15, 0.0),
		vault.to_global(vault.room_centre(1)) + Vector3(0.0, 0.15, 0.0),
		vault.to_global(vault.room_centre(2)) + Vector3(0.0, 0.15, 0.0)])
	Bus.camera_recenter.emit()
	await rig.wait_frames(24)
	_ck("E13 all three rooms are reachable through the door", walked)
	await rig.capture(out.path_join("f_11_vault_prize.png"))


# --- The boss, and the way down ------------------------------------------------------

func _the_boss(rig, d: Node, hero: Node3D) -> void:
	var deep_root: Node = d.rooms[d.deepest]["node"]
	var arena: Node = deep_root.get_node_or_null(^"Arena")
	var door: Node3D = d.anchor_node(&"boss_door")
	if arena == null or door == null:
		_ck("G0 the deepest room holds an arena and a boss door", false)
		return

	# Into the room, not up to the door -- the door is outside the seal, which is
	# the whole point of it.
	var walked := await _walk_rooms(rig, d, hero, d.deepest)
	Bus.camera_recenter.emit()
	await rig.wait_frames(30)
	_ck("G0 the deepest room is reachable on foot from the entrance", walked)
	_ck("G1 walking in sealed it", arena.is_sealed())
	var boss: Node = arena.boss()
	_ck("G2 %s is awake" % _boss_title(), boss != null and boss.is_awake())
	await rig.capture(out.path_join("f_03_sealed.png"))

	# The door refuses by naming what is holding it, not by saying LOCKED.
	_ck("G3 the boss door is still shut", not door.is_open())
	print("FLOOR boss door refusal=\"%s\"" % door._seal_line())
	_ck("G4 and it names %s (\"%s\")" % [_boss_title(), door._seal_line()],
		door._seal_line().contains(_boss_title()))

	if boss == null:
		return
	# Killed off the real damage path, paced past the i-frames, with the hero
	# healed between blows -- he is standing in a live boss fight and dying here
	# would end the run in the middle of a measurement.
	var swings := 0
	while boss.health.quarters > 0 and swings < 40:
		if boss.health.apply_hit(Hit.make(12, hero.global_position, &"sword",
				0.0, 0.0, &"director")):
			swings += 1
		Game.heal(999)
		await rig.wait_seconds(K.IFRAME_TIME + 0.06)
	await rig.wait_frames(60)
	_ck("G5 %s died (%d landed blows)" % [_boss_title(), swings],
		boss == null or not is_instance_valid(boss)
		or boss.health.quarters == 0)
	_ck("G6 the seal came down", not arena.is_sealed())
	_ck("G7 the arena is spent", arena.is_spent())
	_ck("G8 the boss door opened", door.is_open())
	_ck("G9 and %s is the hero's (GDD §5.2)" % FloorDb.boss_item(_level),
		Game.has(FloorDb.boss_item(_level)))
	await rig.capture(out.path_join("f_04_boss_dead.png"))


func _deep_chest(rig, d: Node, hero: Node3D) -> void:
	var chest: Node3D = d.anchor_node(&"deep_chest")
	if chest == null:
		return
	var want := FloorDb.relic_in(_level, &"deep_chest")
	_ck("F0 floor %d's deep-chest relic is %s" % [_level, want], want != &"")
	_ck("F1 and it is still down here", RelicDb.outstanding(want))

	# 1.2 m, and a tight arrival, because a `Chest` reaches 1.7 m (`chest.gd`
	# sets it) where a `LockedDoor` reaches 2.9. Standing the usual two metres off
	# put the hero OUTSIDE the only prop on this floor with a short reach: he was
	# beside the chest, in frame with it, and it never offered itself.
	var walked := await _sweep(rig, hero, [
		chest.global_position + chest.global_transform.basis.z * 1.2
			+ Vector3(0.0, 0.15, 0.0)], 0.35)
	var to := K.flat(chest.global_position - hero.global_position)
	if to != Vector3.ZERO:
		hero.facing_yaw = atan2(to.x, to.z)
		hero.rotation.y = hero.facing_yaw + PI
	Bus.camera_recenter.emit()
	await rig.wait_frames(24)
	_ck("F2 the deep chest is reachable, beside the boss door", walked)
	_ck("F3 and it offers itself (\"%s\")" % Hud._prompt,
		await _focus(rig, chest))
	await rig.capture(out.path_join("f_05_deep_chest.png"))

	await rig.tap(["interact"])
	# Polled, and not "wait forty frames then look". The hero is standing inside
	# the mote's own pickup reach, so a relic spat onto the floor is his about a
	# second later -- a fixed wait photographed an empty floor and called the
	# chest empty. This catches it on the frame it lands.
	var motes: Array = []
	for _i in 24:
		motes = _every(rig.scene(), func(n: Node) -> bool:
			return n is LootMote and (n as LootMote).item_id == want)
		if not motes.is_empty():
			break
		await rig.wait_frames(2)
	_ck("F4 opening it put the relic on the floor as a mote", motes.size() == 1)
	await rig.capture(out.path_join("f_06_relic_mote.png"))

	# Walk over it -- if it has not already rolled onto him. He is standing a
	# stride from the chest, which is inside a mote's own pickup reach, so the
	# relic is often his before this line runs; that is the beat happening early,
	# not the beat not happening, and the claim below is about where it ENDED UP.
	if not motes.is_empty() and is_instance_valid(motes[0]):
		var mote: Node3D = motes[0]
		await _sweep(rig, hero, [mote.global_position + Vector3(0.0, 0.15, 0.0)],
			0.35)
	await rig.wait_frames(30)
	# The relic rides in the bag like everything else -- it is not granted
	# (docs/GDD.md §3, and relic_donate.gd proves the rest of that trip).
	_ck("F5 it went into the bag and not into Game.items",
		Run.bag.get(want, 0) == 1 and not Game.items.has(want))

	# One relic, not two. `RelicPickup` refuses to mint a second copy of a unique,
	# and a chest that can be activated twice is how that rule would get broken.
	chest.activate(hero)
	await rig.wait_frames(30)
	var again := _every(rig.scene(), func(n: Node) -> bool:
		return n is LootMote and (n as LootMote).item_id == want)
	_ck("F6 and re-opening the chest mints no second copy (%d loose, %d in the bag)"
		% [again.size(), Run.bag.get(want, 0)],
		again.is_empty() and Run.bag.get(want, 0) == 1)


func _way_down(rig, d: Node, hero: Node3D) -> void:
	var door: Node3D = d.anchor_node(&"boss_door")
	var landing: Node = d.get_node_or_null(^"BossLanding")
	if door == null or landing == null:
		_ck("G10 there is a landing behind the boss door", false)
		return
	var stairs := _every(landing, func(n: Node) -> bool: return n is Stairs)
	if stairs.is_empty():
		_ck("G10 there is a way down behind the boss door", false)
		return
	var down: Node3D = stairs[0]
	var walked := await _sweep(rig, hero, [
		door.global_position + door.global_transform.basis.z * 2.4
			+ Vector3(0.0, 0.15, 0.0),
		door.global_position - door.global_transform.basis.z * 3.0
			+ Vector3(0.0, 0.15, 0.0),
		down.global_position - down.global_transform.basis.z * 2.6
			+ Vector3(0.0, 0.15, 0.0)])
	Bus.camera_recenter.emit()
	await rig.wait_frames(24)
	_ck("G10 the way down is reachable through the opened boss door", walked)
	_ck("G11 the stair offers itself (\"%s\")" % Hud._prompt,
		await _focus(rig, down))
	await rig.capture(out.path_join("f_07_way_down.png"))


# --- G. The Long Descent is untouched ---------------------------------------------

## The endless row authors nothing, so an unauthored floor has to come out of
## this generator exactly as it did before the Descent existed: no anchors, no
## locked doors, and the stair back in the deepest room. A manifest that had
## quietly become mandatory would break the post-credits mode and nothing else
## would say so.
func _endless(rig, hero: Node3D) -> void:
	var d := await _rebuild(rig, 5)
	if d == null:
		return
	hero.global_position = d.centre_of(d.entrance) + Vector3(0.0, 0.15, 0.0)
	Bus.camera_recenter.emit()
	print("FLOOR level 5 -- %s, %d rooms, anchors %s"
		% [FloorDb.name_of(5), d.rooms.size(), d.placements.keys()])
	_ck("H0 level 5 is the Long Descent",
		FloorDb.name_of(5) == "The Long Descent")
	_ck("H1 its length is the curve's, not a manifest's (%d)" % d.rooms.size(),
		d.rooms.size() == Prog.rooms(5))
	_ck("H2 it authors no anchors", d.placements.is_empty())
	_ck("H3 so there are no locked doors on it",
		_every(d, func(n: Node) -> bool: return n is LockedDoor).is_empty())
	var deep_root: Node = d.rooms[d.deepest]["node"]
	_ck("H4 and the stair is back in the deepest room",
		_every(deep_root, func(n: Node) -> bool: return n is Stairs).size() == 1)
	await rig.wait_frames(10)
	await rig.capture(out.path_join("f_12_endless.png"))
