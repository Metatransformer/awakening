class_name Maze
## **The carve, and nothing else.** No nodes, no meshes, no scene tree — a grid
## of cells and the walls between them, so the arithmetic that decides whether a
## room is *solvable* can be checked without standing eighty wall segments up.
##
## `docs/PUZZLES.md` §5.4. Built for `MazeRoom`, which is the half with pixels.
##
## ## A maze on its own is not a puzzle in this game
##
## This project has a minimap. A plain maze is therefore a walking simulator with
## an extra step: the map answers it for you, and the only thing left is the walk.
## What makes a Zelda maze a puzzle is that something **changes it** — so this
## class carves a maze and then, deliberately, *seals the exit*. The room ships
## with `gates`: wall segments that are not part of the carve, each one paired to
## a lantern that opens it and closes another. The player's question stops being
## "where is the exit" (the map knows) and becomes "which configuration reaches
## it" (the map cannot know, because the map shows the maze that is, not the maze
## that will be).
##
## ## The trap this class exists to make checkable
##
## The lights-out grid had one: a board dealt at random is usually unsolvable
## over GF(2), and the failure ships on a seed nobody can predict. A maze has the
## mirror of it, and it is worse because it looks fine in every frame:
##
##   1. **A configuration that is already open.** Every gate closed and the exit
##      still walkable means the lanterns are scenery and the room is a corridor.
##   2. **A configuration that can never open.** No setting of the gates connects
##      the mouth to the exit, and the player's report is "I think it's bugged"
##      about a room that generated, built and lit perfectly.
##
## Both are decided by `reach` below, on plain integers, before a single mesh
## exists. `plan()` refuses to return a layout that fails either, and
## `tools/directors/maze.gd` is the proof that it never does.

## Wall bits, one per cell, for the two walls that cell OWNS: its north and its
## west. Every wall in the grid is some cell's north or west, so two bits per
## cell covers the interior exactly once and there is no second place to write.
const N := 1
const W := 2

## Rows and columns of CELLS. The wall grid is one larger in each direction, and
## the metres per cell live in `MazeRoom` — this file has no units.
var rows: int = 0
var cols: int = 0

## `rows * cols` bytes of `N | W`. A set bit is a wall standing.
var walls: PackedByteArray = PackedByteArray()

## The reconfigurable walls, in the order their lanterns are indexed. Each entry
## is `{"cell": int, "bit": int, "shut": bool}` — one wall segment and whether it
## is standing in the *dealt* configuration. Toggling a gate is the whole verb.
var gates: Array[Dictionary] = []

## Where the player comes in and where they are trying to get to, as cell
## indices. The mouth is the middle of the south edge; the prize is the far
## corner the carve pushed hardest away from it.
var mouth: int = 0
var prize: int = 0


# --- The carve ----------------------------------------------------------------

## Carve a perfect maze — exactly one path between any two cells — by recursive
## backtracking off `rng`.
##
## Recursive backtracker rather than Prim or Kruskal for one reason that is about
## the game and not about the algorithm: it produces **long winding corridors and
## few junctions**, which is a maze you read by walking. Prim's gives short
## stubby branches everywhere, which is a maze you read by looking, and looking
## is what the minimap already does for free.
##
## Iterative, with an explicit stack. The recursive spelling blows the stack on a
## grid this size in GDScript and the failure is a crash inside a room build.
func carve(rng: RandomNumberGenerator, r: int, c: int) -> void:
	rows = maxi(r, 2)
	cols = maxi(c, 2)
	walls = PackedByteArray()
	walls.resize(rows * cols)
	walls.fill(N | W)

	var seen := {}
	var at := 0
	seen[at] = true
	var stack: Array[int] = [at]
	while not stack.is_empty():
		at = stack[stack.size() - 1]
		var open_to: Array[int] = []
		for n in _neighbours(at):
			if not seen.has(n):
				open_to.append(n)
		if open_to.is_empty():
			stack.pop_back()
			continue
		var next: int = open_to[rng.randi_range(0, open_to.size() - 1)]
		_knock(at, next)
		seen[next] = true
		stack.append(next)

	mouth = (rows - 1) * cols + cols / 2
	prize = _farthest(mouth)


## Drop the wall between two ADJACENT cells. Asserts nothing and silently does
## nothing for a non-adjacent pair, which is the safe way round: a carve that
## knocked a hole between two distant cells would produce a maze that is still
## connected and no longer a maze.
func _knock(a: int, b: int) -> void:
	var ar := a / cols
	var ac := a % cols
	var br := b / cols
	var bc := b % cols
	if ar == br and absi(ac - bc) == 1:
		# The west wall belongs to the RIGHT-hand cell of the pair.
		var owner := b if bc > ac else a
		walls[owner] = walls[owner] & ~W
	elif ac == bc and absi(ar - br) == 1:
		# The north wall belongs to the cell whose north FACE it is -- the one in
		# the greater row. Same rule as W, one axis over.
		var owner2 := b if br > ar else a
		walls[owner2] = walls[owner2] & ~N


func _neighbours(at: int) -> Array[int]:
	var r := at / cols
	var c := at % cols
	var out: Array[int] = []
	if r > 0:
		out.append(at - cols)
	if r < rows - 1:
		out.append(at + cols)
	if c > 0:
		out.append(at - 1)
	if c < cols - 1:
		out.append(at + 1)
	return out


# --- Reachability -------------------------------------------------------------

## Is there a wall between these two adjacent cells, given `extra` gates forced
## shut? `extra` is a dictionary of `"cell:bit"` keys, which is how a candidate
## configuration is tested without mutating `walls`.
func blocked(a: int, b: int, extra: Dictionary = {}) -> bool:
	var ar := a / cols
	var ac := a % cols
	var br := b / cols
	var bc := b % cols
	var owner := -1
	var bit := 0
	if ar == br and absi(ac - bc) == 1:
		owner = b if bc > ac else a
		bit = W
	elif ac == bc and absi(ar - br) == 1:
		owner = b if br > ar else a
		bit = N
	else:
		return true
	if extra.get("%d:%d" % [owner, bit], false):
		return true
	return (walls[owner] & bit) != 0


## Flood from `from` and answer whether `to` came out reachable, with `extra`
## walls standing. **This one function decides whether the room is playable**,
## and it runs on integers before anything is built — see the class note.
func reach(from: int, to: int, extra: Dictionary = {}) -> bool:
	var seen := {from: true}
	var queue: Array[int] = [from]
	while not queue.is_empty():
		var at: int = queue.pop_back()
		if at == to:
			return true
		for n in _neighbours(at):
			if seen.has(n) or blocked(at, n, extra):
				continue
			seen[n] = true
			queue.append(n)
	return false


## The cell furthest from `from` by corridor distance, not by straight line. The
## prize wants to be a long walk, and on a carved maze the two are very different
## numbers — the far corner is often three turns from the mouth and the genuinely
## deep cell is somewhere in the middle.
func _farthest(from: int) -> int:
	var dist := {from: 0}
	var queue: Array[int] = [from]
	var best := from
	var best_d := 0
	while not queue.is_empty():
		var at: int = queue.pop_front()
		var d: int = dist[at]
		if d > best_d:
			best_d = d
			best = at
		for n in _neighbours(at):
			if dist.has(n) or blocked(at, n):
				continue
			dist[n] = d + 1
			queue.append(n)
	return best


# --- The gates ----------------------------------------------------------------

## Deal `count` reconfigurable walls, and **refuse to deal a bad room**.
##
## The rule, and it is the whole class: for the layout to be worth building,
##
##   * the prize must be **unreachable as dealt** — otherwise the lanterns are
##     decoration and the room is a corridor with a minimap over it; and
##   * the prize must be reachable in **a configuration the press rule can build**
##     — not merely "with every gate open". `MazeRoom` opens the pressed gate and
##     shuts the next one along, so the player can reach the dealt state and the
##     exactly-one-open states and nothing else. Checking the wrong set is how you
##     ship a room that generates, lights, and refuses forever.
##
## Both are `reach` calls on integers. The candidate is thrown away and re-dealt
## if either fails, and `false` comes back if the grid is too small to admit a
## layout at all, which the caller reads as "build a plain room instead".
##
## Gates are placed ON the carve, not beside it: each one seals a corridor the
## carve had already opened. A gate that stood in a wall the maze never opened
## would be a lantern that visibly does nothing when it is lit.
func plan(rng: RandomNumberGenerator, count: int, tries: int = 40) -> bool:
	gates = []
	if rows * cols < 9:
		return false
	# Every corridor the carve opened, as (cell, bit) pairs. These are the only
	# walls a gate may stand in.
	var open_walls: Array[Vector2i] = []
	for i in rows * cols:
		if i % cols > 0 and (walls[i] & W) == 0:
			open_walls.append(Vector2i(i, W))
		if i / cols > 0 and (walls[i] & N) == 0:
			open_walls.append(Vector2i(i, N))
	if open_walls.size() < count:
		return false

	for _try in tries:
		var pool := open_walls.duplicate()
		var pick: Array[Vector2i] = []
		for _g in count:
			pick.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))

		# The dealt configuration: every gate SHUT. If the prize is still walkable
		# with all of them standing, these gates are not on the path and the room
		# is a corridor. Re-deal.
		var shut := {}
		for g in pick:
			shut["%d:%d" % [g.x, g.y]] = true
		if reach(mouth, prize, shut):
			continue
		# **And it must be solvable through the configurations the PRESS RULE can
		# actually reach**, which is the check this whole file is for and the one
		# that is easy to get subtly wrong. `MazeRoom._on_pressed` opens the
		# pressed gate and shuts the next, so the reachable set is: all shut (the
		# deal) and exactly-one-open. Testing "reachable with every gate open"
		# instead would pass on layouts the player can never build -- a room that
		# generates, lights and refuses, forever.
		var any := false
		for i in pick.size():
			var one := shut.duplicate()
			one.erase("%d:%d" % [pick[i].x, pick[i].y])
			if reach(mouth, prize, one):
				any = true
				break
		if not any:
			continue

		for g in pick:
			gates.append({"cell": int(g.x), "bit": int(g.y), "shut": true})
		return true
	return false


## Open or close gate `i`, and report the state it landed in. `MazeRoom` calls
## this from a lantern and then rebuilds that one segment's visibility — the
## grid is the truth and the meshes follow it, never the other way round.
func set_gate(i: int, shut: bool) -> bool:
	if i < 0 or i >= gates.size():
		return false
	gates[i]["shut"] = shut
	return shut


## The gates currently standing, in `reach`'s `extra` form.
func shut_now() -> Dictionary:
	var out := {}
	for g in gates:
		if bool(g["shut"]):
			out["%d:%d" % [g["cell"], g["bit"]]] = true
	return out


## Can the player walk to the prize right now? The live version of `plan`'s
## check, and what a director asserts after pressing a lantern.
func solved() -> bool:
	return reach(mouth, prize, shut_now())
