extends RefCounted
## M4, the second half: **the whole puzzle spine, proven once** (`docs/SCOPE.md`
## §3). `tools/directors/cistern_floor.gd` says floor 1 is the manifest's floor;
## this says floor 1 has a puzzle in it.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/puzzle_loop.gd \
##     --out=/tmp/puzzle/x.png --warmup=60
##
## What it claims, in the order it proves them:
##
##   A  The tables are sound. `PuzzleAtoms.validate()`, `EchoDb.validate()` and
##      `BossDb.validate()` -- the last one because M4 added a whole second table
##      to it and a miniboss row is exactly as able to be wrong as a boss row.
##   B  The spine is PLACED. Both new anchors exist, the gate room is on the path
##      to `deepest` and its door is in the doorway that continues that path, and
##      the treasure puzzle is somewhere the critical path does not go.
##   C  The gate room is a **key hunt** (§5.2), and it is a nest (§3): the door
##      refuses by name, the key is dark and inert until the sun socket lights,
##      and the socket is not one of the door's atoms.
##   D  Solving it pays an **Echo** -- three real, distinct, unheld tones on a
##      sounding stone, one taken, two silenced, worth 0 gold and costing a slot.
##   E  The **cycle** exists (§4): one chord edge, ends at least three apart, its
##      far end no shallower than the gate room, barred from the near side only,
##      and the near end nearer the entrance than the far one. That last is the
##      whole point -- the loop is the walk home.
##   F  The **treasure puzzle** (§5.3) is optional, off the critical path, and is
##      the plate/block nest; behind it stand the **Sluice-Keeper**, a rich chest
##      and the floor's second Echo.
##   G  The Sluice-Keeper obeys §7: two beats, drops nothing, and its arena hands
##      out no relic when the chamber is revisited spent.
##
## ## What this director does NOT prove, deliberately
##
## The eight atoms' own verbs. `tools/directors/puzzle_atoms.gd` is that file and
## it landed with M1 -- the shield bounce, the shove, the plate's rise. So the sun
## socket here is solved by calling `solve()`, which is the atom's own public
## entry point and is what its verb would have called. What is under test is the
## WIRING: that the socket's solve wakes a key, that the key's solve satisfies a
## door, that the door's opening lights a stone. Re-proving the bounce here would
## make this file fail for a reason that belongs to another one.

## Forced so the spine is the same spine every run, and the same seed
## `cistern_floor` uses so the two directors describe one floor.
const SEED := 20260809

var out := ""
var _fails := 0


func run(rig) -> void:
	out = rig.arg("out", "/tmp/puzzle/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	Game.reset()
	Run.enter(SEED)

	# Same guard, same reason as `cistern_floor`: this beat ADDS a `Dungeon` to
	# whatever scene it was pointed at, and run against the garrison it generates
	# a floor on top of one and reports a dozen failures that read like a broken
	# level.
	if rig.scene().name != &"DungeonRun":
		print("PUZZLE FAIL wrong host scene (%s) -- pass "
			% rig.scene().name
			+ "--scene=res://scenes/rooms/dungeon.tscn")
		return

	_tables()

	var d := await _rebuild(rig, 1)
	if d == null:
		print("PUZZLE FAIL the dungeon did not build")
		return
	var hero: Node3D = _hero(rig)
	if hero == null:
		print("PUZZLE FAIL there is no hero in the scene")
		return
	var cam := _game_camera(rig)
	if cam != null:
		cam.make_current()
	await rig.wait_frames(20)

	# Off the floor before the beats. A pack that wanders into a puzzle room fights
	# the hero through three measurements, and the one body this file is about --
	# the Sluice-Keeper -- is behind a locked door and cannot be reached by one.
	_clear_the_floor(d)
	await rig.wait_frames(6)

	_placed(d)
	await _the_gate_room(rig, d, hero)
	await _the_echo(rig, d, hero)
	await _the_cycle(rig, d, hero)
	await _the_treasure(rig, d, hero)

	if _fails == 0:
		print("PUZZLE ok -- every check passed")
	else:
		print("PUZZLE FAIL -- %d check(s) failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("PUZZLE ok %s" % label)
	else:
		_fails += 1
		print("PUZZLE FAIL %s" % label)


# --- A. The tables --------------------------------------------------------------

## Fail loudly rather than late. Each of these is a table that a generator reads
## and cannot sanity-check at three in the morning on somebody's machine.
func _tables() -> void:
	for pair in [["the atom kit", PuzzleAtoms.validate()],
			["the twelve Echoes", EchoDb.validate()],
			["the boss and miniboss tables", BossDb.validate()]]:
		var lines: PackedStringArray = pair[1]
		for line in lines:
			print("PUZZLE   %s: %s" % [pair[0], line])
		_ck("A0 %s validates" % pair[0], lines.is_empty())


# --- B. Where the spine sits ----------------------------------------------------

func _placed(d: Node) -> void:
	var gate_cell: Vector2i = d.anchor_cell(&"gate_room")
	var gate: Node = d.anchor_node(&"gate_room")
	_ck("B0 the gate room was placed", gate != null)

	var route: Array[Vector2i] = d.path_to(d.deepest)
	print("PUZZLE gate room %s, route to deepest %s" % [gate_cell, route])
	_ck("B1 it is ON the path to the deepest room (§5.2)",
		route.has(gate_cell))
	_ck("B2 and it is neither end of it",
		gate_cell != d.entrance and gate_cell != d.deepest)

	# The door has to be in the hole the floor CONTINUES through. A gate on a spur
	# wall is a gate the player walks round, and it passes every check that only
	# asks whether the room has one in it.
	if gate != null:
		var i := route.find(gate_cell)
		var onward: Vector2i = route[i + 1] if i >= 0 and i + 1 < route.size() \
			else gate_cell
		var step := onward - gate_cell
		var axis := Vector3(float(step.x), 0.0, float(step.y))
		# `-basis.z` is forward and a door's leaves face INTO the room, so the way
		# on is the door's own `+basis.z` reversed (docs/CONTRACT.md §2.5).
		# Typed: `gate` is a `Node` handle, so its `global_transform` is a Variant
		# and `:=` cannot infer from one (CLAUDE.md §3).
		var out_of: Vector3 = -(gate as Node3D).global_transform.basis.z
		print("PUZZLE gate door faces %.2f,%.2f -- the way on is %.0f,%.0f"
			% [out_of.x, out_of.z, axis.x, axis.z])
		_ck("B3 the gate stands in the doorway the floor continues through",
			out_of.normalized().dot(axis.normalized()) > 0.9)

	var t_cell: Vector2i = d.anchor_cell(&"puzzle_room")
	var t_gate: Node = d.anchor_node(&"puzzle_room")
	_ck("B4 the treasure puzzle was placed", t_gate != null)
	_ck("B5 and it is OFF the critical path (§5.3: optional, always)",
		not route.has(t_cell) or t_cell == d.entrance)


## The gate room's puzzle, whichever prefab was drawn. Named nodes rather than a
## type sweep, because the NAMES are the contract `Dungeon` writes and a sweep
## would happily find a decorative lantern.
func _gate_nest(root: Node) -> Node:
	for n: StringName in [&"GateSocket", &"GateLights", &"GateEye0"]:
		var found := root.get_node_or_null(NodePath(n))
		if found != null:
			return found
	return null


## Answer it. Each prefab has its own verb and that is the entire point of the
## table -- what is common is only that solving it wakes the key.
func _solve_nest(rig, nest: Node) -> void:
	match nest.name:
		&"GateLights":
			# The real presses, through the grid's own solver. `solve()` on nine
			# lanterns would light a board the coupling never produced.
			var grid := nest
			for at: int in (grid.call(&"solution") as Array):
				var lamp: Node = grid.call(&"cell", at)
				lamp.call(&"apply_hit", null)
				await rig.wait_seconds(0.4)
		&"GateEye0":
			var root := nest.get_parent()
			for i in 3:
				var eye := root.get_node_or_null(NodePath("GateEye%d" % i))
				if eye != null:
					eye.call(&"solve")
			await rig.wait_frames(6)
		_:
			nest.call(&"solve")
			await rig.wait_frames(6)


# --- C. The gate room -----------------------------------------------------------

func _the_gate_room(rig, d: Node, hero: Node3D) -> void:
	var gate: Node = d.anchor_node(&"gate_room")
	if gate == null:
		return
	var cell: Vector2i = d.anchor_cell(&"gate_room")
	var root: Node = d.rooms[cell]["node"]
	# **Whichever prefab this seed drew** (`Dungeon.GATE_PREFABS`). The room's
	# puzzle varies; the reward path does not, and that invariant is what the rest
	# of this beat checks. A director pinned to the sun socket would pass on one
	# prefab and fail on the other two for no reason but its own assumption.
	var nest: Node = _gate_nest(root)
	var key: Node = root.get_node_or_null(^"GateKey")
	_ck("C0 the room holds a gate puzzle (%s)" %
		(nest.name if nest != null else "none"), nest != null)
	_ck("C1 and a small key", key != null)
	if nest == null or key == null:
		return

	# The set the door is counting. The socket must NOT be in it -- see
	# `Dungeon._place_gate_room`.
	var watched: Array = gate.call(&"atoms")
	_ck("C2 the door counts exactly one atom, the key", watched.size() == 1
		and watched[0] == key)
	print("PUZZLE gate refusal=\"%s\"" % gate.call(&"refusal_line"))
	_ck("C3 and it refuses by naming it (\"%s\")"
		% gate.call(&"refusal_line"),
		String(gate.call(&"refusal_line")).contains("KEY"))
	_ck("C4 the door is shut", not gate.call(&"is_open"))

	# The key is furniture until the socket lights. Both halves matter: invisible
	# is the picture, disarmed is the rule -- an Area3D collides whether or not
	# anything is drawn, and a key you can walk through in the dark is a key.
	_ck("C5 the key is not there yet", not key.visible)
	_ck("C6 and it cannot be taken", not bool(key.get(&"armed")))
	var keys_before := Game.small_keys
	hero.global_position = key.global_position
	await rig.wait_frames(8)
	_ck("C7 walking through it grants nothing (%d keys)" % Game.small_keys,
		Game.small_keys == keys_before)

	# The spot the player has to be in to answer this prefab. For the socket that
	# is the catch it is aimed at; for the others, in front of the puzzle.
	await _stand_in_front(rig, hero, nest, 5.5)
	await rig.capture(out.path_join("p_01_gate_room.png"))

	await _solve_nest(rig, nest)
	await rig.wait_frames(30)
	_ck("C8 solving it wakes the key", key.visible
		and bool(key.get(&"armed")))
	await rig.capture(out.path_join("p_02_key_woken.png"))

	# Stand on it until it is taken, not for a fixed ten frames. An `Area3D`
	# registers a body that was TELEPORTED into it on the next physics tick that
	# actually resolves the overlap, and how many process frames that takes is a
	# property of the machine, not of the puzzle -- this beat failed about one run
	# in ten with the fixed wait, always here, and the fix is to wait for the fact
	# rather than for a number. The bound is still a real failure: if the key never
	# grants, `_until` gives up and C9 fails, which is the outcome it always had.
	hero.global_position = key.global_position
	await _until(rig, func() -> bool: return Game.small_keys > keys_before, 90)
	_ck("C9 taking it grants a key (%d)" % Game.small_keys,
		Game.small_keys == keys_before + 1)
	_ck("C10 and solves the door's atom", bool(key.call(&"is_solved")))
	_ck("C11 so the door is unlocked", bool(gate.call(&"unlocked")))
	# `needs_key` forces `auto_open` off, and this is the line that says why: the
	# key has to be SPENT, at the door, or the hunt bought nothing.
	_ck("C12 but it has not opened itself (§5.2 is a hunt, not a switch)",
		not bool(gate.call(&"is_open")))

	var prize: Node3D = root.get_node_or_null(^"GateChest")
	_ck("C12a the room's chest is not on offer yet (§5.2: loot, not passage)",
		prize != null and not prize.visible and not bool(prize.get(&"enabled")))

	await _stand(rig, hero, gate, 3.2)
	gate.call(&"activate", hero)
	await rig.wait_frames(50)
	_ck("C13a and the solve landed the chest",
		prize != null and prize.visible and bool(prize.get(&"enabled")))
	_ck("C13 pressing it opens the gate", bool(gate.call(&"is_open")))
	_ck("C14 and spends the key (%d left)" % Game.small_keys,
		Game.small_keys == keys_before)
	await rig.capture(out.path_join("p_03_gate_open.png"))


# --- D. The Echo ----------------------------------------------------------------

func _the_echo(rig, d: Node, hero: Node3D) -> void:
	var cell: Vector2i = d.anchor_cell(&"gate_room")
	var stone := _stone_in(d.rooms[cell]["node"])
	_ck("D0 the gate room has a sounding stone", stone != null)
	if stone == null:
		return
	var offered: Array = stone.call(&"offered")
	print("PUZZLE stone offers %s" % [offered])
	_ck("D1 opening the gate lit it -- three tones (§6)", offered.size() == 3)
	if offered.size() != 3:
		return

	var distinct := {}
	var real := true
	for id: StringName in offered:
		distinct[id] = true
		if EchoDb.row(id).is_empty() or ItemDb.get_def(id) == null:
			real = false
	_ck("D2 all three are distinct", distinct.size() == 3)
	_ck("D3 and all three are real rows in both tables", real)

	# Off to one side. Dead ahead the hero's own shoulders sit exactly where the
	# middle tone is, and the frame that is supposed to show a choice of three
	# shows two.
	# A small step off the axis, not a big one: the three tones stand on a ring,
	# and a sharp angle on a ring foreshortens two of them into each other. Far
	# enough across to clear the hero's own shoulders, near enough to keep the
	# offer readable as three.
	await _stand_in_front(rig, hero, stone, 5.2, 1.9)
	await rig.capture(out.path_join("p_04_echo_offer.png"))

	var motes := _motes_under(stone)
	_ck("D4 three motes are standing on it", motes.size() == 3)
	if motes.is_empty():
		return
	var take: StringName = motes[0].item_id
	var slots_before: int = Run.slots_used()
	var value_before: int = Run.bag_value()
	hero.global_position = motes[0].global_position
	await rig.wait_frames(40)

	_ck("D5 walking into one takes it (%s)" % EchoDb.name_of(take),
		Run.has_echo(take))
	_ck("D6 it costs a bag slot (%d -> %d)" % [slots_before, Run.slots_used()],
		Run.slots_used() == slots_before + 1)
	# §6: worth 0 gold, so it cannot be sold and does not raise the fee. Both
	# fall out of the catalogue row rather than out of a rule anybody wrote.
	_ck("D7 and is worth 0 gold, so the fee does not move (%d)" % Run.bag_value(),
		Run.bag_value() == value_before)

	var left := 0
	for m in _motes_under(stone):
		if is_instance_valid(m):
			left += 1
	_ck("D8 the other two went quiet (%d motes left)" % left, left == 0)
	_ck("D9 and the stone is spent", bool(stone.call(&"is_spent")))
	await rig.capture(out.path_join("p_05_echo_taken.png"))


# --- E. The cycle ---------------------------------------------------------------

func _the_cycle(rig, d: Node, hero: Node3D) -> void:
	var chord: Dictionary = d.chord
	_ck("E0 the floor has a chord edge (§4)", not chord.is_empty())
	if chord.is_empty():
		return
	var near: Vector2i = chord["near"]
	var far: Vector2i = chord["far"]
	var a := int(d.rooms[near]["dist"])
	var b := int(d.rooms[far]["dist"])
	var gate_dist := int(d.rooms[d.anchor_cell(&"gate_room")]["dist"])
	print("PUZZLE chord %s(dist %d) <-> %s(dist %d), gate room at dist %d"
		% [near, a, far, b, gate_dist])
	_ck("E1 its ends are at least 3 apart (%d)" % absi(a - b), absi(a - b) >= 3)
	_ck("E2 the far end is no shallower than the gate room", b >= gate_dist)
	# The sentence the whole feature is for: *the loop comes out near the
	# entrance, so beating the puzzle physically shortens the extraction walk.*
	_ck("E3 and the near end is nearer the way out (%d < %d)" % [a, b], a < b)

	var bars: Node3D = chord["node"]
	_ck("E4 the near end is barred", bars != null)
	if bars == null:
		return

	# From the near room. `out_dir()` points down the corridor, so a metre back
	# along it is the side that must be refused.
	var out_dir: Vector3 = bars.call(&"out_dir")
	hero.global_position = bars.global_position - out_dir * 2.2 \
		+ Vector3(0.0, 0.15, 0.0)
	await rig.wait_frames(6)
	_ck("E5 the hero is on the near side", not bool(
		bars.call(&"on_far_side", hero)))
	bars.call(&"activate", hero)
	await rig.wait_frames(20)
	_ck("E6 and it refuses (§4: blocked from the near side only)",
		not bool(bars.call(&"is_open")))
	await _look_at(rig, hero, bars)
	await rig.capture(out.path_join("p_06_bars_refuse.png"))

	hero.global_position = bars.global_position + out_dir * 2.2 \
		+ Vector3(0.0, 0.15, 0.0)
	await rig.wait_frames(6)
	_ck("E7 the hero is on the far side", bool(bars.call(&"on_far_side", hero)))
	bars.call(&"activate", hero)
	await rig.wait_frames(70)
	_ck("E8 and the bars go up", bool(bars.call(&"is_open")))
	await rig.capture(out.path_join("p_07_bars_lifted.png"))


# --- F/G. The treasure puzzle and the Sluice-Keeper -----------------------------

func _the_treasure(rig, d: Node, hero: Node3D) -> void:
	var gate: Node = d.anchor_node(&"puzzle_room")
	if gate == null:
		return
	var cell: Vector2i = d.anchor_cell(&"puzzle_room")
	var root: Node = d.rooms[cell]["node"]
	var atom: Node3D = root.get_node_or_null(^"TreasureAtom")
	var block: Node3D = root.get_node_or_null(^"TreasureBlock")
	_ck("F0 the mid-ring room has the gating atom", atom != null)
	_ck("F1 and the block that answers it (§3, the nest)", block != null)
	if atom == null or block == null:
		return
	# The block is furniture. A gate watching it would wait for a solve that is
	# never coming, and the symptom is a door that never opens with nothing
	# visibly wrong.
	_ck("F2 the gate counts one atom, not two",
		gate.call(&"atoms").size() == 1)
	print("PUZZLE treasure refusal=\"%s\"" % gate.call(&"refusal_line"))
	_ck("F3 it refuses by naming the verb (\"%s\")" % gate.call(&"refusal_line"),
		not String(gate.call(&"refusal_line")).is_empty())

	await _stand_in_front(rig, hero, atom, 5.0, 1.4)
	await rig.capture(out.path_join("p_08_treasure_puzzle.png"))

	# Shove it home. `push_to` is the block's public half -- proving the SEATING
	# without standing a hero beside it is exactly what that split is for, and the
	# shove itself is `puzzle_atoms.gd`'s beat.
	var toward := (atom.global_position - block.global_position)
	toward.y = 0.0
	var dir := Vector3(signf(toward.x), 0.0, 0.0) if absf(toward.x) >= absf(toward.z) \
		else Vector3(0.0, 0.0, signf(toward.z))
	var shoves := 0
	while shoves < 6 and not bool(atom.call(&"is_solved")):
		if not bool(block.call(&"push_to", dir)):
			break
		shoves += 1
		await rig.wait_seconds(0.55)
	await rig.wait_frames(60)
	_ck("F4 %d shoves put the block on the plate" % shoves,
		bool(atom.call(&"is_solved")))
	# No key here, and no button: everything but a key hunt opens on the last
	# atom, wherever the player is standing.
	_ck("F5 and the gate opened itself", bool(gate.call(&"is_open")))
	# Shot from the DOOR, not from the plate: what "the gate opened itself" looks
	# like is the way through, and the plate is thirty degrees behind the camera.
	# `_stand` here and not `_stand_in_front` -- this one really is a door.
	await _stand(rig, hero, gate, 3.4, 1.6)
	await rig.capture(out.path_join("p_09_treasure_open.png"))

	var chamber: Node = d.get_node_or_null(^"TreasureChamber")
	_ck("G0 there is a chamber behind it", chamber != null)
	if chamber == null:
		return
	var arena: Node = chamber.get_node_or_null(^"MinibossArena")
	var chest: Node = chamber.get_node_or_null(^"TreasureChest")
	var stone := _stone_in(chamber)
	_ck("G1 with the floor's miniboss in it", arena != null)
	_ck("G2 a rich chest", chest != null)
	_ck("G3 and the floor's second Echo", stone != null)
	if arena == null:
		return

	var want := BossDb.miniboss_for(1)
	var row := BossDb.get_boss(want)
	print("PUZZLE miniboss %s -- %s, %d beats, model %s"
		% [want, row.get("title", "?"), (row.get("beats", []) as Array).size(),
			row.get("model", "?")])
	_ck("G4 it is the Sluice-Keeper (%s)" % want, want == &"sluice_keeper")
	_ck("G5 two beats, not three (§7)",
		(row.get("beats", []) as Array).size() == 2)
	_ck("G5a and the boss it stands beside has three",
		(BossDb.get_boss(FloorDb.boss(1)).get("beats", []) as Array).size() == 3)
	# §7: *they drop nothing but the chest behind them.* Both halves -- the row's
	# own drop, and the arena's lost-relic replacement, which would otherwise put
	# floor 1's BOSS relic on the floor of a spent miniboss chamber.
	var drop: Dictionary = row.get("drop", {})
	_ck("G6 it drops nothing",
		StringName(drop.get("item", &"")) == &""
		and StringName(drop.get("relic", &"")) == &"")
	_ck("G7 and its arena carries no relic slot",
		StringName(arena.get(&"relic_slot")) == &"")
	# §7's model rule, checked because it is the reason those four were chosen.
	_ck("G8 its model is not floor 1's boss's (%s vs %s)"
		% [row.get("model", "?"), BossDb.get_boss(FloorDb.boss(1)).get("model", "?")],
		row.get("model", &"") != BossDb.get_boss(FloorDb.boss(1)).get("model", &""))

	var boss: Node = arena.call(&"boss")
	_ck("G9 and it is standing in the chamber", boss != null)
	if boss == null:
		return
	hero.global_position = arena.global_position - Vector3(0.0, 0.0, 4.0) \
		+ Vector3(0.0, 0.15, 0.0)
	await _look_at(rig, hero, boss)
	arena.call(&"seal")
	await rig.wait_frames(40)
	_ck("G10 walking in seals it", bool(arena.call(&"is_sealed")))
	await rig.capture(out.path_join("p_10_sluice_keeper.png"))

	# The same real damage path `cistern_floor` kills the Warden through, paced
	# past the i-frames with the hero healed between blows.
	var swings := 0
	while boss.health.quarters > 0 and swings < 40:
		if boss.health.apply_hit(Hit.make(12, hero.global_position, &"sword",
				0.0, 0.0, &"director")):
			swings += 1
		Game.heal(999)
		await rig.wait_seconds(K.IFRAME_TIME + 0.06)
	await rig.wait_frames(70)
	_ck("G11 the Sluice-Keeper died (%d landed blows)" % swings,
		not is_instance_valid(boss) or boss.health.quarters == 0)
	_ck("G12 the seal came down", not bool(arena.call(&"is_sealed")))

	if stone != null:
		var offered: Array = stone.call(&"offered")
		print("PUZZLE treasure stone offers %s" % [offered])
		# On the KILL, not on the gate: §5.3's reward is miniboss + chest + Echo,
		# and a stone lit by the door would pay before the fight it gated.
		_ck("G13 and the kill lit the second sounding stone", offered.size() == 3)
	# Off the chest's axis, toward the stone: §5.3 pays THREE things and this is
	# the frame that has to show all of them. Dead ahead of the chest the hero
	# stands in front of it and the shot is a lit pedestal and a shadow.
	await _stand(rig, hero, chest if chest != null else arena, 6.0, -3.2)
	await rig.capture(out.path_join("p_11_treasure_won.png"))


# --- Fixture --------------------------------------------------------------------

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
		# Not the miniboss -- it is behind a locked door, it cannot walk into a
		# measurement, and beat G is about to fight it.
		if _under(e, "TreasureChamber") or _under(e, "Vault"):
			continue
		freed += 1
		e.queue_free()
	print("PUZZLE cleared %d bodies" % freed)


## Put the hero `back` metres out from `at` along the prop's own facing side,
## `side` metres across it, and look at it. Teleported rather than walked:
## reachability is `cistern_floor.gd`'s claim and re-making it here would give
## this file a way to fail that has nothing to do with puzzles.
func _stand(rig, hero: Node3D, at: Node3D, back: float,
		side: float = 0.0) -> void:
	if at == null:
		return
	# `+basis.z` is the side a `LockedDoor`'s leaves face out of, which is the
	# side the player stands on (docs/CONTRACT.md §2.5).
	var xf := at.global_transform
	var stop := at.global_position + xf.basis.z * back + xf.basis.x * side
	stop.y = 0.15
	hero.global_position = stop
	await _look_at(rig, hero, at)


## Put the hero `back` metres out along `at`'s own FORWARD, `side` metres across
## it, and look at it.
##
## `_stand` above is a *door*'s convention and it is wrong for everything else in
## this file. A `LockedDoor` shows its leaves to the player, so its player side is
## `+basis.z`; an atom or a pedestal is aimed AT the player, so its player side is
## `-basis.z` -- its forward. Standing a hero on the wrong one of those put the
## camera inside masonry twice (`p_01`, `p_08`), which is a framing bug that no
## check could have caught, because every check passed.
##
## `side` exists for the sounding stone: a hero centred on a three-mote offer
## stands in front of the middle one.
func _stand_in_front(rig, hero: Node3D, at: Node3D, back: float,
		side: float = 0.0) -> void:
	if at == null:
		return
	var xf := at.global_transform
	var stop := at.global_position - xf.basis.z * back + xf.basis.x * side
	stop.y = 0.15
	hero.global_position = stop
	await _look_at(rig, hero, at)


## Wait until `cond` is true, or `frames` have gone by. Returns nothing: the
## CHECK is still the caller's `_ck`, so a condition that never comes true fails
## exactly as loudly as it did with a fixed wait -- this only stops a slow machine
## from failing a beat that a fast one passes.
func _until(rig, cond: Callable, frames: int) -> void:
	for _i in frames:
		if bool(cond.call()):
			return
		await rig.wait_frames(1)


func _look_at(rig, hero: Node3D, at: Node3D) -> void:
	if at != null:
		var to := K.flat(at.global_position - hero.global_position)
		if to != Vector3.ZERO:
			hero.facing_yaw = atan2(to.x, to.z)
			hero.rotation.y = hero.facing_yaw + PI
	Bus.camera_recenter.emit()
	await rig.wait_frames(24)


## The sounding stone under `root`, by group rather than by name -- the placer
## names them after the site and a director that matched on the name would be a
## second copy of that naming rule.
func _stone_in(root: Node) -> Node3D:
	for n in _every(root, func(x: Node) -> bool:
			return x.is_in_group(&"sounding_stone")):
		return n
	return null


func _motes_under(stone: Node) -> Array:
	var found: Array = []
	for n in _every(stone, func(x: Node) -> bool: return x is LootMote):
		found.append(n)
	return found


func _hero(rig) -> Node3D:
	var players: Array = rig.get_nodes_in_group(&"player")
	return players[0] if not players.is_empty() else null


func _game_camera(rig) -> Camera3D:
	for n in _all(rig.scene()):
		if n is GameCamera:
			return n
	return null


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
