class_name ChainRow
extends Node3D
## **A row of atoms that topple each other, with a hole in the middle.**
##
## `docs/PUZZLES.md` §3, combinator 7 -- **chain**. `PuzzleAtom.propagate()` is
## the mechanic; this is the file that makes it a PUZZLE, and the difference
## between the two is the gap.
##
## ## The gap is the whole thing
##
## Without it, chain is a domino topple you watch: one cast at the head of the
## row, five pillars down, nothing asked. Dodongo's Cavern runs a line of bomb
## flowers exactly this way and puts a deliberate hole in the middle, so the
## player has to supply one link themselves -- and that turns the row into the
## one question none of combinators 1-6 asks, which is **where do I stand**.
##
## The arithmetic that makes it a question rather than a walk. Four numbers, and
## they sit in one narrow window:
##
##   `K.BOMB_RADIUS` < `spacing` <= `chain_radius` < `gap` <= 2 * `K.BOMB_RADIUS`
##
## Left to right: one blast is never worth two pillars, a fall carries to its
## neighbour, a fall does NOT carry across the hole -- and **a player standing in
## the hole can reach both lips of it**, which is what "supply the missing link
## yourself" means when the thing you are holding is the Burst-Verse. Drop the
## first and the row is solved by standing in a slot; drop the third and there is
## no gap; drop the fourth and the hole is not a socket you can fill, it is just
## two rows. `problems()` checks all four, because a gap 0.2 m too wide is a room
## that generates, builds, photographs perfectly and has no puzzle in it.
##
## The window is narrow on purpose and it is not arbitrary: `gap` has to be more
## than `chain_radius` and less than a blast across, so the hole is always **less
## than two normal spacings wide**. That is a real readability problem -- a hole
## that subtle reads as five evenly-ish spaced pillars -- and it is the whole
## reason `_build_socket()` exists.
##
## ## What it costs the player, which is the actual design
##
## A row of `count` links with one gap is **two casts**, not `count` casts and
## not one. `casts_needed()` is that number, and a floor that hands the player
## fewer charges than pillars is a floor where the chain is the only way through.
## That is the whole reason the combinator earns a row against a frozen list: it
## changes what the player is thinking about (which two pillars, and from where)
## rather than what they are aiming at.
##
## ## It is not an atom, and the gate does not know it exists
##
## Straight out of `LanternGrid`'s book, and for the same reason: the row builds
## N atoms, hands each **the gate's own `puzzle_id`** and a distinct `index`, and
## gets out of the way. `PuzzleGate` adopts them exactly as it adopts one key,
## counts them, refuses in `PuzzleAtoms`' own plural -- *"3 OF 5 PILLARS STILL
## SHUT"* -- and opens when the last one goes over. No new gate protocol and no
## `is_solved` on this node. A second way for a door to be satisfied is a door
## that one day never opens with nothing visibly wrong.

## Metres between neighbouring links. Wider than `K.BOMB_RADIUS` (1.94 m) with
## room to spare, so a single blast is worth exactly one pillar and the row can
## never be brute-forced by standing in a slot.
const SPACING := 2.6
## How far a fall carries. Clear of `SPACING` rather than equal to it -- a reach
## that only just covers the spacing is a chain that breaks the first time a
## placer nudges a pillar 100 mm off the line.
const REACH := 3.0
## The hole. Wider than the fall carries, and narrower than a blast is across
## (2 x 1.94 m), so a cast put down in the socket reaches BOTH lips of it. 3.7 m
## clears the reach by 0.7 and comes in 0.18 under the blast, which is the middle
## of a window only 0.88 m wide.
const GAP := 3.7

## What the row is made of. Anything in the kit works -- the mechanic is on
## `PuzzleAtom` -- but the pillar is the one it was designed around
## (`docs/PUZZLES.md` §3.1: *the natural home for the T2 cracked pillar, which is
## currently one prop that does one thing*).
##
## Through `PuzzleAtoms`' own constant rather than the literal: a typo'd
## `StringName` here is a row that generates, builds and silently never solves,
## which is the failure mode with no visible symptom (`puzzle_atoms.gd` says so
## at the top of the eight ids).
@export var atom_id: StringName = PuzzleAtoms.CRACKED_PILLAR
## How many links. Five is the shipped shape: three, a hole, and two, which is
## the smallest row where both segments read as segments.
@export var count: int = 5
## The gap sits AFTER this link, 0-based. `-1` means the middle, rounded down.
@export var gap_after: int = -1
## The gate these belong to. Handed to every link, so the door adopts them.
@export var puzzle_id: StringName = &""
## Overrides for the three numbers above, for a placer that wants a longer row or
## a tighter one. Zero means "use the constant".
@export var spacing: float = 0.0
@export var reach: float = 0.0
@export var gap: float = 0.0

## The last link went over. Edge-triggered, like `LanternGrid.lit_out` and for the
## same reason -- a row whose atoms carry a gate's `puzzle_id` does not need it
## (the door counts them itself), and a row that is one half of a NEST does.
signal toppled

var _links: Array[PuzzleAtom] = []
## Where the missing link would have stood. The gap's own address, and the answer
## to "where do I stand" -- read by the director, and by the socket it builds.
var _gap_at: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group(&"chain_row")
	_build()


# --- The row ------------------------------------------------------------------

## Lay the links out along the row's own **forward**, which is `-basis.z`
## (`docs/CONTRACT.md` §2.5, `CLAUDE.md` §4). A placer orients the row with
## `rotation.y` and reads facing the way everything else in this project reads
## it; a row laid along `+Z` would be one more place where forward means two
## things.
func _build() -> void:
	var step := spacing if spacing > 0.0 else SPACING
	var hole := gap if gap > 0.0 else GAP
	var reach_m := reach if reach > 0.0 else REACH
	var hole_after := gap_after if gap_after >= 0 else (count - 1) / 2

	# Stepped out first and centred after, so the row's origin is its middle. A
	# row that grew forward from its origin would move its own far end every time
	# somebody changed `count`, and every camera aimed at it would need re-aiming.
	var along: Array[float] = []
	var t := 0.0
	for i in count:
		along.append(t)
		t += hole if i == hole_after else step
	var mid := along[count - 1] * 0.5

	for i in count:
		var link := PuzzleAtoms.make(atom_id, puzzle_id) as PuzzleAtom
		if link == null:
			continue
		link.name = "Link%d" % i
		link.index = i
		link.chain_radius = reach_m
		# Named off this node, so two rows in one room are two chains. The default
		# is empty and empty matches empty, which would make them one.
		link.chain_id = StringName("chain_%s_%d" % [name, get_instance_id()])
		# **Before the tree.** An atom reads `global_position` while it builds
		# (`CrackedPillar._build` does), and one placed after `_ready` has already
		# built itself at the origin -- `burst_cast.gd`'s director records the same.
		link.position = Vector3(0.0, 0.0, -(along[i] - mid))
		add_child(link)
		_links.append(link)
		link.solved.connect(_on_link_solved)

	var socket := Vector3(0.0, 0.0, -(along[hole_after] + hole * 0.5 - mid))
	_gap_at = to_global(socket)
	_build_socket(socket)


## **The empty socket, and it is not decoration.** A gap the player cannot see is
## a puzzle with no question printed on it: five pillars with a wider space in
## the middle reads as five pillars, and the room's answer -- *put your own link
## here* -- is invisible until somebody has already failed. So the row leaves the
## base of the pillar that is missing, which is exactly the mark a fallen one
## leaves (`CrackedPillar._build`: *the base stays; it is the thing that says a
## pillar USED to be here*). The gap then says the same sentence the rubble says,
## before the player has toppled anything.
##
## No collision. It is a mark on the floor, and something the player has to walk
## onto to use.
func _build_socket(at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "GapSocket"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.58
	cm.bottom_radius = 0.58
	cm.height = 0.14
	# Faceted like everything else in the kit -- a smooth ring reads as an asset
	# from a different game (`PuzzleAtom._cyl` says the same).
	cm.radial_segments = 10
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	# Darker than the pillar's own base, and matte. It is a socket with nothing in
	# it, so it should read as a hole rather than as a short pillar.
	m.albedo_color = Color(0.19, 0.18, 0.20)
	m.roughness = 0.97
	m.metallic = 0.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mi.material_override = m
	mi.position = at + Vector3.UP * 0.07
	add_child(mi)


func _on_link_solved(_atom: PuzzleAtom) -> void:
	if standing() == 0:
		toppled.emit()


# --- What a director (or a placer) asks it ------------------------------------

## The links, in row order.
func links() -> Array[PuzzleAtom]:
	return _links.duplicate()


func link(i: int) -> PuzzleAtom:
	return _links[i] if i >= 0 and i < _links.size() else null


func standing() -> int:
	var n := 0
	for l in _links:
		if is_instance_valid(l) and not l.is_solved():
			n += 1
	return n


## Where the missing link would have stood, in world space. **The answer to the
## puzzle**, and the one thing a room planner needs off this node: it is the
## square of floor the player has to reach and put a cast on.
func gap_position() -> Vector3:
	return _gap_at


## The contiguous runs of links -- one more than the number of gaps, and the
## number of casts the row costs. Computed off the LIVE geometry rather than off
## `count` and `gap_after`, so it reports what the row is rather than what it was
## asked for.
func segments() -> Array:
	var out: Array = []
	var run: Array[int] = []
	for i in _links.size():
		if i > 0 and not _reaches(i - 1, i):
			out.append(run)
			run = []
		run.append(i)
	if not run.is_empty():
		out.append(run)
	return out


func casts_needed() -> int:
	return segments().size()


func _reaches(a: int, b: int) -> bool:
	var la := link(a)
	var lb := link(b)
	if la == null or lb == null:
		return false
	return la.global_position.distance_to(lb.global_position) <= la.chain_radius


## The four numbers being wrong, in words. See the class note -- each of these is
## a room that builds, lights and has no puzzle in it, and none of them shows up
## in a frame.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	var step := spacing if spacing > 0.0 else SPACING
	var hole := gap if gap > 0.0 else GAP
	var reach_m := reach if reach > 0.0 else REACH
	if step <= K.BOMB_RADIUS:
		out.append("spacing %.2f m is inside one blast (%.2f m) -- one cast takes two links"
			% [step, K.BOMB_RADIUS])
	if reach_m <= step:
		out.append("reach %.2f m does not carry to a neighbour %.2f m away -- there is no chain"
			% [reach_m, step])
	if hole <= reach_m:
		out.append("the gap %.2f m is inside the reach %.2f m -- the fall crosses it and there is no puzzle"
			% [hole, reach_m])
	if hole > K.BOMB_RADIUS * 2.0:
		out.append("the gap %.2f m is wider than a blast (%.2f m) -- nobody standing in it can bridge it"
			% [hole, K.BOMB_RADIUS * 2.0])
	if count >= 2 and casts_needed() < 2 and not _links.is_empty():
		out.append("the built row is one segment -- the gap did not land")
	return out
