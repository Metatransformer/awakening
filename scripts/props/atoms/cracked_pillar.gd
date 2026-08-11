class_name CrackedPillar
extends PuzzleAtom
## Atom 6 of 8 (`docs/PUZZLES.md` §2): the cracked pillar. **T2 -- a burst.**
##
## **Built at M1, inert until M5, live now** (`docs/SCOPE.md` §3). It stood here
## for a whole milestone with nothing in the game able to crack it, and that was
## the correct order rather than an omission: a prop with no verb is a prop, and
## a verb with no prop is a dead end, and the dead end is the expensive one.
##
## The bet paid. `BurstCast._wake_the_burstable` walks group `&"burstable"`
## inside the blast radius and calls `burst()`, and **nothing in this file
## changed to make that work** -- which is what a public entry point named for
## the verb rather than for the weapon is worth. `armed` starting true is the
## other half: the director could prove the body toppled a milestone before
## anything existed that could topple it.
##
## It does NOT answer `apply_hit`. A pillar that a sword could chip would be a T0
## atom with a T2 label, and `PuzzleAtoms.pool()` would hand the generator a rung
## the player has not climbed. It also has to survive being fought next to: this
## is the one atom most likely to be standing in a room with a goblin in it.
##
## ## What it is FOR
##
## Not a door -- a wall. §3's third combinator is the pillar that holds a slab
## over the way on, and the fall is the opening. So `on_solved()` topples it and
## FREES its collision, which is why the shaft's body is separate from the base.

const HEIGHT := 2.9
const SHAFT_R := 0.42
const BASE_R := 0.58
const FALL_TIME := 0.75

var _shaft: StaticBody3D
var _crack_mat: StandardMaterial3D
var _rubble: Node3D


func _ready() -> void:
	if atom_id == &"":
		atom_id = PuzzleAtoms.CRACKED_PILLAR
	_build()
	super()


## Crack it. **The M5 entry point, and it is live**: `BurstCast` walks group
## `&"burstable"` and calls this on everything inside the blast.
##
## Named for the verb rather than the weapon on purpose, and the naming was
## vindicated exactly as predicted: the weapon that arrived is not a bomb at all
## but a working you CAST (`docs/GDD.md` §5.2), so a method called `bomb()`
## would have needed renaming before its first caller existed.
func burst() -> void:
	if is_solved():
		return
	solve()


# --- The fall -----------------------------------------------------------------

func on_solved() -> void:
	Bus.request_sfx.emit(&"jump_slam", global_position)
	if _shaft != null:
		# Freed, not disabled. `Urn.on_solved` and `LockedDoor._build_blocker` both
		# record why: a shape that is only switched off is an invisible wall one bug
		# away, and this one would be standing in a doorway.
		_shaft.queue_free()
		_shaft = null
	_topple()


## Already down. The rubble, and no noise -- see `PuzzleAtom.restore_solved`.
func restore_solved() -> void:
	if _shaft != null:
		_shaft.queue_free()
		_shaft = null
	# Built, then posed straight into the end of the fall. `_build_rubble` puts the
	# courses where they STOOD -- which is right for `_topple`, and would be a
	# pillar standing back up on a floor the player already cleared.
	var pieces := _build_rubble()
	for i in pieces.size():
		var mi: MeshInstance3D = pieces[i]
		mi.position = _landed(mi.position, i, pieces.size())
		mi.rotation.x = -PI * 0.5


## The shaft goes over, in one piece, away from a lean it has had since it was
## built. A pillar that shatters into a cloud reads as a prop dissolving; a pillar
## that FALLS reads as the roof it was holding coming with it.
func _topple() -> void:
	var pieces := _build_rubble()
	for i in pieces.size():
		var mi: MeshInstance3D = pieces[i]
		var lean := float(i) / maxf(1.0, float(pieces.size() - 1))
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(mi, "position", _landed(mi.position, i, pieces.size()),
			FALL_TIME * (0.55 + lean * 0.45))
		tw.parallel().tween_property(mi, "rotation:x", -PI * 0.5, FALL_TIME)


## Where course `i` of `count` ends up. Downwards and outwards, each course
## further than the one below it -- which is what a column does when its foot
## goes and its head keeps travelling.
##
## Shared by the fall and the restore, so a floor re-entered shows the same heap
## the player watched land. Two copies of this arithmetic is two heaps.
func _landed(from: Vector3, i: int, count: int) -> Vector3:
	var lean := float(i) / maxf(1.0, float(count - 1))
	return Vector3(from.x, SHAFT_R * 0.5, from.z + lean * HEIGHT * 0.72)


# --- Construction -------------------------------------------------------------

func _build() -> void:
	# Group first, so a director (or the blast) can find it whether or not it has
	# finished building.
	add_to_group(&"burstable")

	var stone := _mat(Color(0.34, 0.33, 0.35), 0.96, 0.0)

	# The base stays. It is the thing that says a pillar USED to be here, and a
	# floor with nothing on it is a floor the player never notices changed.
	_cyl(self, _mat(Color(0.28, 0.27, 0.30), 0.95, 0.0), BASE_R, 0.22,
		Vector3(0.0, 0.11, 0.0), 10)

	_shaft = StaticBody3D.new()
	_shaft.name = "Shaft"
	_shaft.collision_layer = K.L_WORLD
	_shaft.collision_mask = 0
	add_child(_shaft)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = SHAFT_R
	cyl.height = HEIGHT
	cs.shape = cyl
	cs.position.y = 0.22 + HEIGHT * 0.5
	_shaft.add_child(cs)

	# Four drums with a course between each. The seams are where the cracks go,
	# and a single tall cylinder has nowhere to put them.
	for i in 4:
		var y := 0.22 + HEIGHT * (float(i) + 0.5) / 4.0
		_cyl(_shaft, stone, SHAFT_R, HEIGHT * 0.25 - 0.03, Vector3(0.0, y, 0.0), 10)

	# The cracks. RUST is damage in this palette (`docs/STYLEGUIDE.md` §2) and that
	# is exactly what this is -- the one atom whose unsolved state should read as
	# a flaw rather than as a cold light waiting to warm.
	_crack_mat = _glow_mat(Pal.RUST, 0.55)
	for i in 7:
		var a := TAU * float(i) / 7.0 + 0.4
		var y := 0.45 + fmod(float(i) * 0.73, 1.0) * (HEIGHT - 0.9)
		_box(_shaft, _crack_mat, Vector3(0.06, 0.34, 0.05),
			Vector3(cos(a) * (SHAFT_R + 0.01), y, sin(a) * (SHAFT_R + 0.01)),
			Vector3(0.0, -a, 0.35 - fmod(float(i) * 0.41, 0.7)))


## The fallen courses, as loose meshes with no collision. Returns them bottom-up
## so `_topple` can lean each one further than the last.
func _build_rubble() -> Array:
	if _rubble != null:
		return []
	_rubble = Node3D.new()
	_rubble.name = "Rubble"
	add_child(_rubble)
	var stone := _mat(Color(0.34, 0.33, 0.35), 0.96, 0.0)
	var out: Array = []
	for i in 4:
		var y := 0.22 + HEIGHT * (float(i) + 0.5) / 4.0
		out.append(_cyl(_rubble, stone, SHAFT_R, HEIGHT * 0.25 - 0.03,
			Vector3(0.0, y, 0.0), 10))
	return out
