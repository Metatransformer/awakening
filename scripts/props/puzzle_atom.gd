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

var _solved: bool = false


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


## Let go. Only a non-latching atom may -- a latching one that could be un-solved
## would make its flag a lie the next time the floor was built.
func unsolve() -> void:
	if not _solved or latching():
		return
	_solved = false
	on_unsolved()
	Bus.switch_toggled.emit(flag_id(), false)
	unsolved.emit(self)


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
