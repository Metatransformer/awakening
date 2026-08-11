class_name PuzzleAtom
extends Node3D
## The base body of the atom kit. **A body that emits `solved`, and nothing
## else** -- `docs/PUZZLES.md` §2, verbatim.
##
## Every subclass in `scripts/props/atoms/` answers one verb of §1's ladder and
## calls `solve()` when it has been answered. None of them knows what opens, none
## of them moves the player, and none of them calls `Flow`. The door is a
## `PuzzleGate` and it LISTENS -- which is the same shape `LockedDoor` already
## has, where the door emits `opened` and the placer decides what the tag means.
##
## **Why the state is here and not in each prop.** Eight props each keeping a
## `_done` bool is eight chances to emit `solved` twice, and a gate counting
## unsolved atoms off a doubled signal opens early. `solve()` is idempotent, it
## is the only thing that emits, and the subclasses do not own the flag.
##
## ## Latching, and the one atom that does not
##
## Seven of the eight stick: a smashed urn does not reassemble and a cracked
## pillar does not stand back up. The pressure plate is the exception -- step off
## and it rises -- which is why `latching` is a row in `PuzzleAtoms.ATOMS` and a
## real `unsolved` signal exists. `docs/PUZZLES.md` §4 makes the way home the
## REWARD for solving the gate room, and a cycle that closed itself behind you
## because you walked off a plate would take that reward back.
##
## ## The flag, and floors you come back to
##
## A latching atom writes a one-way world flag exactly as `LockedDoor` does, so a
## floor re-entered inside one run comes up with its puzzle already solved.
## `flag_id()` is keyed on `puzzle_id` + `atom_id` + `index`, because two eyes in
## one gate room must not share a flag -- and the whole set is cleared by
## `Run.enter()` per run, not per floor, so a NEW run gets a fresh puzzle.
## See `clear_run_flags()`.
##
## ## Chain lives here, and that is the whole of combinator 7
##
## `docs/PUZZLES.md` §3's seventh combinator is one solve carrying to the next
## along a line of sight. It is `propagate()` below and nothing else: no chain
## prop, no manager, no second signal -- the atoms already emit `solved`, and a
## combinator that arrived needing a prop of its own would have stopped being a
## combinator (§8.1). `ChainRow` is the PLACER that switches it on for a row and
## puts the gap in the middle; it is not a thing the base class knows about.

## Solved. `atom` is `self`, so a gate can connect the same handler to all of its
## atoms and still know which one moved.
signal solved(atom: PuzzleAtom)
## Un-solved -- the plate rose, and only the plate can do this.
signal unsolved(atom: PuzzleAtom)

## Which of the eight (`PuzzleAtoms`' ids). Set by `PuzzleAtoms.make`.
@export var atom_id: StringName = &""
## Which puzzle this belongs to. A `PuzzleGate` with the same tag adopts it.
## Empty means "wired by hand" -- a scene fixture, or a placer calling `watch`.
@export var puzzle_id: StringName = &""
## Which one of its kind, within its puzzle. Only the flag reads it, and it has
## to: three eyes in one gate room are three separate one-way facts.
@export var index: int = 0
## Off means the atom is built but cannot be solved yet. The cracked pillar
## spends every run before M5 like this (`docs/SCOPE.md` §3), and a director
## can prove the body works by turning it on.
@export var armed: bool = true

## **Chain** (`docs/PUZZLES.md` §3, combinator 7). Metres this atom's solve
## carries to its neighbours, along a line of sight. `0.0` means it is not a
## link, which is every atom in the game unless a placer says otherwise -- see
## `propagate()` for the whole rule, and `ChainRow` for the thing that sets it.
@export var chain_radius: float = 0.0
## Which chain. Two rows standing within a radius of each other must not set each
## other off, and `puzzle_id` cannot be that key: a gate room's whole point is
## that its atoms share one tag. Empty matches only empty.
@export var chain_id: StringName = &""
## Seconds between one link falling and the next going. **Not a flourish** -- a
## row that topples in a single frame is one prop with five meshes, and the thing
## the player has to read is that the fall TRAVELLED. It is also what turns the
## recursion below into a walk across frames.
@export var chain_delay: float = 0.45

var _solved: bool = false
## Has this link already passed the fall on? The re-entrancy guard: a ring of
## atoms each in reach of the next comes back round to its own starting link, and
## without this the ring re-fires forever (or, at `chain_delay = 0`, recurses
## until the stack goes).
var _chained: bool = false


func _ready() -> void:
	add_to_group(&"puzzle_atom")
	# Restored BEFORE the gate has adopted anything, and deliberately without a
	# signal: `solved` is the moment it happens, and replaying eight of them on
	# every floor rebuild would ring a gate that has been open for ten minutes.
	# `PuzzleGate` reads `is_solved()` when it adopts, which is the same fact
	# asked rather than announced.
	if latching() and Game.flag(flag_id()):
		_solved = true
		restore_solved()
	# Introduce yourself, one frame later. Adoption has to work from BOTH ends:
	# a gate authored in a scene is ready before the generator builds its atoms,
	# and an atom authored in a scene is ready before the gate. Each side reaches
	# for the other and `PuzzleGate.watch` is idempotent, so whichever order the
	# tree happens to produce, the set is the same.
	#
	# Deferred because the other half may be entering the tree on this very frame.
	_offer.call_deferred()


## Tell any gate carrying this atom's `puzzle_id` that it exists.
func _offer() -> void:
	if puzzle_id == &"":
		return
	for node in get_tree().get_nodes_in_group(&"puzzle_gate"):
		if node.get(&"puzzle_id") == puzzle_id:
			node.call(&"watch", self)


# --- The kit's own row --------------------------------------------------------

func latching() -> bool:
	return PuzzleAtoms.latching(atom_id)


func tier() -> int:
	return PuzzleAtoms.tier(atom_id)


## The verb this answers to, in the player's words. The lookdev caption and the
## director's log; nothing branches on it.
func verb() -> String:
	return PuzzleAtoms.verb(atom_id)


## What a gate says while this one is unsolved. Off the table, so eight refusals
## are eight rows (`PuzzleAtoms`' own note on why they do not live on the prop).
func refusal(left: int = 1, total: int = 1) -> String:
	return PuzzleAtoms.refusal_for(atom_id, left, total)


## What an **ordered** gate says while this one is the next of `total` in the run
## (`docs/PUZZLES.md` §3, combinator 2). `at` counts from 1.
##
## A method on the atom rather than a call into the table at the gate, for the
## same reason `refusal()` is one: `EyeSwitch.refusal()` overrides its row for the
## frozen variant, and a line composed from `PuzzleAtoms` at the door would be a
## line no variant could ever change (CLAUDE.md §3's static-dispatch row, and
## §8.1's third unpriced item -- this project has already paid for that once).
func refusal_next(at: int, total: int) -> String:
	return PuzzleAtoms.refusal_next_for(atom_id, at, total)


func is_solved() -> bool:
	return _solved


## The one-way world flag a latching atom writes.
##
## Keyed on all three of puzzle, kind and index. Two eyes sharing a flag is a
## gate that opens on the first arrow, and it is invisible until somebody counts
## the arrows -- which is exactly the class of bug `LockedDoor.flag_id()`'s own
## note is about.
func flag_id() -> StringName:
	var tag := String(puzzle_id) if puzzle_id != &"" else String(name)
	return StringName("atom_%s_%s_%d" % [tag, atom_id, index])


# --- Solving ------------------------------------------------------------------

## Answer the verb. **Idempotent** -- see the class note; a subclass may call it
## from a collision handler that fires several times in one frame.
##
## Not overridden by subclasses. What a subclass overrides is `on_solved()`,
## which is the animation, and `restore_solved()`, which is the same pose with no
## motion and no sound.
func solve() -> void:
	if _solved or not armed:
		return
	_solved = true
	if latching():
		Game.set_flag(flag_id())
	on_solved()
	# Both, and they are not the same announcement. `switch_toggled` is the
	# world's, and `Atlas`/audio/anything ambient may listen; `solved` is the
	# gate's, and it carries the node so one handler can serve a whole set.
	Bus.switch_toggled.emit(flag_id(), true)
	solved.emit(self)
	# **Chain, and it is deliberately the LAST thing.** The gate has counted this
	# link before the next one goes, so a row whose final link finishes the puzzle
	# opens its door once rather than racing the count. `_arm_chain` is a no-op on
	# every atom that is not a link, which is all of them by default.
	_arm_chain()


## Let go. Only a non-latching atom may -- a latching one that could be un-solved
## would make its flag a lie the next time the floor was built.
func unsolve() -> void:
	if not _solved or latching():
		return
	_solved = false
	# Let go of the guard with the state. A non-latching link that could never
	# chain a second time would be a coupled row that works once per floor, and the
	# bug would look like the chain having stopped working rather than like a flag.
	_chained = false
	on_unsolved()
	Bus.switch_toggled.emit(flag_id(), false)
	unsolved.emit(self)


## **Put it back, whatever the `latching` column says.**
##
## `docs/PUZZLES.md` §3's second combinator -- *sequence* -- needs a third case
## that neither `solve()` nor `unsolve()` covers: an atom that answered its verb
## honestly and should not have, because it was not its turn. `unsolve()` refuses
## a latching atom on purpose (a smashed urn does not reassemble), and that rule
## is right for the world and wrong for a sequence, so this is the door the
## sequence gets rather than a hole knocked in that one. The only caller is
## `PuzzleGate._break_the_sequence`.
##
## **The flag goes with it, and that is not tidiness.** A latching atom writes
## `atom_*` in `solve()` and `PuzzleAtom._ready` restores from it, so an eye left
## flagged after the player watched it go dark would come back LIT the next time
## the floor was rebuilt inside the run -- a row that half-remembers a sequence
## the player has already lost. Erased here, in the same breath, so the flag and
## the frame agree.
func reset() -> void:
	if not _solved:
		return
	_solved = false
	# Same reason `unsolve()` drops it: a link that could never chain again would
	# look like the chain having broken rather than like a flag.
	_chained = false
	if latching():
		Game.flags.erase(flag_id())
	on_unsolved()
	Bus.switch_toggled.emit(flag_id(), false)
	unsolved.emit(self)


# --- Chain (`docs/PUZZLES.md` §3, combinator 7) --------------------------------
#
# The whole combinator, and it is one method: **a radius, a line-of-sight ray and
# a re-entrancy guard.** There is no chain prop, no chain manager and no second
# signal -- the atoms already emit `solved` and this is a second thing that
# listens. `docs/PUZZLES.md` §8.1 priced combinator 7 at exactly this and the
# price held.
#
# ## Why it is delayed rather than immediate
#
# A row that goes over in one frame is a single prop with five meshes. What makes
# chain a combinator is that the fall TRAVELS -- the player bursts one pillar,
# steps back, and watches the answer walk away from them down the row -- and a
# player who cannot see it travel cannot learn that the gap is a gap.
#
# The delay also unrolls the recursion across frames, which is why the guard
# below is belt and braces rather than the only thing holding a ring together.
# It is still needed: `chain_delay` is an export and a placer may set it to zero.

## The height the sight line is drawn at. Chest on a 1.65 m hero, mid-shaft on a
## cracked pillar -- the point of a chain is that the player can SEE it is a
## chain, and a ray along the floor is one that a lip of stair breaks for reasons
## nothing in the frame explains.
const CHAIN_EYE_Y := 1.2


## Schedule the pass-along, once. Called from `solve()` and from nowhere else --
## in particular NOT from the `restore_solved()` path, because a floor re-entered
## inside one run would otherwise re-topple its whole row, with the noise.
func _arm_chain() -> void:
	if chain_radius <= 0.0 or _chained or not is_inside_tree():
		return
	_chained = true
	if chain_delay <= 0.0:
		propagate()
		return
	# Connected rather than awaited. A `SceneTreeTimer` that resumed an `await` on
	# an atom the floor had already freed is an error in a log nobody reads; a
	# connection to a freed object is dropped by the engine.
	get_tree().create_timer(chain_delay).timeout.connect(propagate)


## **Pass the solve to everything this link can reach and see.** Public because a
## director (and a placer proving its own geometry) has to be able to fire one
## link by hand without going through the verb the atom answers to.
##
## Idempotent by way of `solve()`, which is idempotent -- a link woken twice by
## two neighbours in the same wave solves once and chains once.
func propagate() -> void:
	if not is_inside_tree():
		return
	for link in chain_links():
		link.solve()


## Who this link would wake: in the same chain, inside the radius, unsolved, and
## with a clear line of sight. **Separated from `propagate()` on purpose** -- the
## topology is the thing a proof wants to assert, and asserting it by toppling
## the row destroys the row you were asking about.
##
## The group walk is `BurstCast._wake_the_burstable`'s move and for its reason: an
## atom is a marker, not a body, so a shape query would hand this the same
## collider it hands back for a wall.
func chain_links() -> Array[PuzzleAtom]:
	var out: Array[PuzzleAtom] = []
	if chain_radius <= 0.0:
		return out
	var r2 := chain_radius * chain_radius
	for node in get_tree().get_nodes_in_group(&"puzzle_atom"):
		var other := node as PuzzleAtom
		if other == null or other == self or not is_instance_valid(other):
			continue
		# Both ends have to be links, and of the SAME chain. A row that set off the
		# row in the next room would be a puzzle solved from a doorway.
		if other.chain_radius <= 0.0 or other.chain_id != chain_id:
			continue
		if other.is_solved() or not other.armed:
			continue
		if global_position.distance_squared_to(other.global_position) > r2:
			continue
		if not _can_see(other):
			continue
		out.append(other)
	return out


## The sight line, drawn between the two atoms' eyes and blocked by the world.
##
## Both ends' own colliders are excluded, and they have to be: this one's body may
## be a `queue_free()` that has not landed yet (`CrackedPillar.on_solved` frees
## its shaft the instant it solves, and a freed node is still in the physics
## world until the end of the frame), and the far one's body is the thing the ray
## is aimed AT. What is left in between is the wall, the ledge or the third pillar
## standing in the way -- which is the whole of "along a line of sight", and the
## reason a chain does not go round corners.
func _can_see(other: PuzzleAtom) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(chain_eye(), other.chain_eye(),
		K.L_WORLD, _chain_exclude() + other._chain_exclude())
	q.collide_with_areas = false
	return space.intersect_ray(q).is_empty()


## Where this atom is looked at from and to. Overridable: an atom whose body is
## not around its origin (a ring bolted high on a wall) gets to say so.
func chain_eye() -> Vector3:
	return global_position + Vector3.UP * CHAIN_EYE_Y


## This atom's own collision bodies, for the ray to ignore. Walked rather than
## cached: an atom that has already fallen has freed its shaft, and a cached list
## would hold a RID that no longer means anything.
func _chain_exclude() -> Array[RID]:
	var out: Array[RID] = []
	_gather_rids(self, out)
	return out


func _gather_rids(node: Node, into: Array[RID]) -> void:
	var body := node as CollisionObject3D
	if body != null:
		into.append(body.get_rid())
	for child in node.get_children():
		_gather_rids(child, into)


# --- Overridables -------------------------------------------------------------

## The authored solve: the tween, the light, the noise. Runs once.
func on_solved() -> void:
	pass


## The plate rising again.
func on_unsolved() -> void:
	pass


## The finished pose, with no motion and no sound -- called from `_ready` when
## the flag already says this one is solved. The same split `LockedDoor` makes
## between `_swing()` and `_pose_open()`, and for the same reason: the sound is
## for the moment it happens, and replaying it on every floor build would turn a
## landmark into a jingle.
func restore_solved() -> void:
	on_solved()


# --- Per-run flags ------------------------------------------------------------

## Wipe every atom flag. Called by `Run.enter()`, so a new run gets fresh
## puzzles while a floor re-entered WITHIN a run stays solved.
##
## `Game.flags` is otherwise permanent (a door you opened stays open across
## saves), and that is right for a shortcut and wrong for a plate: the whole of
## `docs/PUZZLES.md` §5.2 is that you solve the gate room on the way down and
## walk the cycle home, once, this run. A puzzle that was still solved on run
## nine would make the gate room a corridor.
##
## Static and on the atom rather than on `Game`, because the naming rule it has
## to agree with is `flag_id()` above -- and that is here.
static func clear_run_flags() -> void:
	for key: StringName in Game.flags.keys():
		if String(key).begins_with("atom_"):
			Game.flags.erase(key)


# --- Small builders -----------------------------------------------------------
# Shared here rather than copied into eight files. `locked_door.gd` grew the same
# pair privately and that was fine for one prop; eight is where it becomes the
# duplication `CLAUDE.md` §0 is about.

## Dead matte unless it is metal, exactly as `LockedDoor._mat` decides it: the
## moving specular highlight is the whole reason iron reads as iron at 8 m, and
## everything else in this kit is stone, clay or timber and should not shine.
func _mat(albedo: Color, rough: float = 0.95, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = rough
	m.metallic = metal
	if is_zero_approx(metal):
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m


## An emissive mark. `energy` is the multiplier, and the albedo is dragged dark
## on purpose: `locked_door.gd` learned twice that a tinted albedo under a nearby
## lamp clips to white and the coloured thing photographs as a white smear.
## Emission is the one channel a lamp cannot bleach.
func _glow_mat(hue: Color, energy: float) -> StandardMaterial3D:
	var m := _mat(hue.darkened(0.80), 0.85, 0.0)
	m.emission_enabled = true
	m.emission = hue
	m.emission_energy_multiplier = energy
	return m


## One decorative box. Nothing built through here collides -- an atom's collision
## is authored deliberately, once, by the atom, for the same reason
## `LockedDoor._box` refuses to: a leaf with its own shape is an invisible wall
## the day something forgets to move it.
func _box(parent: Node, mat: Material, size: Vector3, at: Vector3,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = at
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _cyl(parent: Node, mat: Material, radius: float, height: float,
		at: Vector3, segments: int = 8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	# Faceted, never smooth. The whole kit is hard-edged and a smooth-shaded prop
	# reads as an asset from a different game (`loot_mote.gd` says the same).
	cm.radial_segments = segments
	mi.mesh = cm
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi
