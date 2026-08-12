class_name PuzzleGate
extends LockedDoor
## The door that listens. **`docs/PUZZLES.md` §2: "every one of them is a body
## that emits `solved` and a door that listens."** `PuzzleAtom` is the body; this
## is the door.
##
## ## Why it is a `LockedDoor` and not a new prop
##
## `LockedDoor` already owns eight hundred lines of authored leaves, bars,
## medallion, glyph and passage light, plus the refusal jolt, the one-way flag and
## the `Prompt` arbitration fight that a refusal line requires. A second door would
## be a second answer to every one of those questions -- and `CLAUDE.md` §0 is a
## whole section about what this repo pays when there are two of something.
##
## What actually differs is one method. `LockedDoor.unlocked()` asks `Game.has()`;
## this asks the atoms. Everything else -- the swing, the flag, the plate, the
## sigil -- is inherited unchanged, which is the point.
##
## ## The mark it wears
##
## Off `PuzzleAtoms.TIER_ITEM`, so a T1 gate wears the bow's sigil from
## `LockedDoor.SIGILS` and a T0 gate wears the default. There is no second sigil
## table that could one day disagree with the first, and the door in front of a
## bow puzzle looks like the door the bow opens because it IS that row.
##
## ## Two ways to be shut
##
## `needs_key` is the small-key door: the atoms are the KEY being found (§5.2's
## gate room is a hunt), and the door still has to be walked to and spent at.
## Everything else opens itself the instant the last atom lands -- a switch you
## trip across the room and then have to walk back to and press a button on is a
## door that took the reward off the solve.

## Which puzzle. Every `PuzzleAtom` carrying the same tag is adopted on the frame
## after this door is ready; a placer may also `watch()` one by hand.
@export var puzzle_id: StringName = &""
## Spend a small key to pass, on top of the atoms. The atoms are usually the hunt
## that produced the key.
@export var needs_key: bool = false
## Which rung this gate is on -- only the sigil reads it. See the class note.
@export var mark_tier: int = 0
## Open by itself when the last atom lands. Forced off by `needs_key`: a key door
## that opened itself would never spend the key.
@export var auto_open: bool = true
## **Sequence** (`docs/PUZZLES.md` §3, combinator 2). Atoms of one kind must be
## answered in ascending `PuzzleAtom.index`; one out of turn puts that whole kind
## back to the start. See `_break_the_sequence`.
##
## Off by default and a no-op unless a placer sets distinct indices -- every atom
## in the kit is born at `index = 0`, and a run whose members all share an index
## can never be out of turn. A gate does not become a sequence by accident.
@export var ordered: bool = false

var _atoms: Array[PuzzleAtom] = []
var _key_spent: bool = false
## Has `Bus.puzzle_solved` gone out for this gate yet?
##
## **A puzzle is not solved twice.** Sfx maps that signal to `puzzle_reward`,
## which is a fanfare, and a reversible gate reaches the last line of
## `_on_atom_changed` every time the player steps back onto the plate -- so
## without this the announcement is a machine gun and the fanfare stops meaning
## "you did it". The plate's own `craft_clang` is what says "it took your
## weight"; that one is per press, and should be.
var _announced: bool = false
## Inside `_break_the_sequence`. The re-entrancy guard, and it is not optional:
## `PuzzleAtom.reset()` emits `unsolved`, which is wired to `_on_atom_changed`,
## which is what called the reset -- three atoms would otherwise each re-enter the
## break for the other two.
var _breaking: bool = false


func _ready() -> void:
	# BEFORE `super()`: `LockedDoor._ready` builds the medallion off `key_item` and
	# a mark chosen afterwards would be a mark on a glyph already carved.
	mark_tier = clampi(mark_tier, 0, PuzzleAtoms.TIER_ITEM.size() - 1)
	key_item = PuzzleAtoms.TIER_ITEM[mark_tier]
	if needs_key:
		auto_open = false
	super()
	# The half of adoption an atom cannot do: `PuzzleAtom._offer` finds gates that
	# already exist, and this finds atoms that already exist. Both are deferred and
	# `watch` is idempotent, so a gate and its atoms built in any order end up
	# with the same set. Guessing the order is how a puzzle silently watches
	# nothing, and nothing about the frame looks wrong when it does.
	add_to_group(&"puzzle_gate")
	_adopt.call_deferred()


# --- The set ------------------------------------------------------------------

## Adopt every atom tagged with this gate's `puzzle_id`.
func _adopt() -> void:
	if puzzle_id == &"":
		return
	for node in get_tree().get_nodes_in_group(&"puzzle_atom"):
		var atom := node as PuzzleAtom
		if atom != null and atom.puzzle_id == puzzle_id:
			watch(atom)
	_refresh_prompt()


## Watch one atom. Public so a placer can wire a set by hand -- a fixture scene,
## or a gate whose atoms live in a different room and share no tag.
##
## Idempotent: `_adopt` and a hand-wired placer will both reach for the same atom
## and a doubled connection is a gate that counts one solve twice.
func watch(atom: PuzzleAtom) -> void:
	if atom == null or _atoms.has(atom):
		return
	# An open door does not go back to counting. An atom that arrives late -- a
	# room streamed in behind the player, a placer wiring a second set -- would
	# otherwise re-lock a door they have already walked through.
	if is_open():
		return
	_atoms.append(atom)
	atom.solved.connect(_on_atom_changed)
	atom.unsolved.connect(_on_atom_changed)
	_refresh_prompt()


## The one-way flag, keyed **per run** rather than for ever.
##
## `LockedDoor.flag_id()` writes `door_open_<destination>` into `Game.flags`,
## which is permanent and saved -- exactly right for a boss door, and wrong here.
## `PuzzleAtom.clear_run_flags()` wipes every `atom_*` key on `Run.enter()`, so a
## gate keyed the base class's way would come back OPEN on run two standing over
## a puzzle that had just been reset: the gate room reduced to a corridor from
## the second descent onward, which is the precise failure `docs/PUZZLES.md` §5.2
## exists to prevent. The door and its atoms have one lifetime, and this is the
## line that says so.
func flag_id() -> StringName:
	var tag := String(puzzle_id) if puzzle_id != &"" else String(name)
	return StringName("atom_door_%s" % tag)


## **Can this gate's answer be taken back?** True the moment ONE atom in the set
## is non-latching (`PuzzleAtoms.latching()` is the column, and the plate and the
## lantern are the two rows that read false).
##
## Asked of the set rather than declared by the placer, because the placer does
## not choose it: `Dungeon._place_puzzle_room` picks its atom out of
## `PuzzleAtoms.pool()` at generation time, and a floor that drew a plate is a
## reversible gate while the same code drawing an eye is not. An export would be
## a second answer to a question the table already answers.
##
## ONE is the threshold, not all: a mixed set with an eye and a plate is open
## only while the plate is held, so the door can still come back -- and a door
## that stamped a permanent flag because *most* of it latched would be open over
## a risen plate, which is the bug either way.
func reversible() -> bool:
	for a in _atoms:
		if not a.latching():
			return true
	return false


## Overrides `LockedDoor.persists_open()`. **A gate that can shut must not write
## a one-way flag**, and that is the whole of the rule `docs/PUZZLES.md` §2 now
## carries: the atoms ARE the state, they are read every frame by
## `unsolved_count()`, and a saved bool beside them is a second answer that can
## only ever go stale in one direction.
##
## `pressure_plate.gd`'s header wrote this rule down about the plate ("a one-way
## flag on a two-way prop is a plate that comes back pressed with nothing
## standing on it") and the gate above it did it anyway.
func persists_open() -> bool:
	return not reversible()


## The atoms this gate is waiting on. Public because a director has to be able to
## say "the gate adopted three things" separately from "the gate opened" -- a
## puzzle that adopted nothing is `unlocked()` from the first frame, and that is
## the failure mode with no visible symptom.
func atoms() -> Array[PuzzleAtom]:
	return _atoms


func unsolved_count() -> int:
	var n := 0
	for a in _atoms:
		if not a.is_solved():
			n += 1
	return n


## The run of one kind, lowest `index` first. **Sorted here rather than trusted
## from `_atoms`**: adoption order is a race between `_adopt`'s deferred walk of
## the `puzzle_atom` group and a placer's own `watch()` calls, and a sequence
## whose order depended on which won would be a different puzzle on a different
## frame. `index` is the placer's stated intent and it is the only thing read.
func kin(id: StringName) -> Array[PuzzleAtom]:
	var out: Array[PuzzleAtom] = []
	for a in _atoms:
		if a.atom_id == id:
			out.append(a)
	out.sort_custom(func(x: PuzzleAtom, y: PuzzleAtom) -> bool:
		return x.index < y.index)
	return out


## The one an ordered gate is waiting for: lowest `index` of its kind still
## unsolved. `null` once the run is complete. Public because a director has to be
## able to ask which atom is next separately from whether the door opened.
func next_in(id: StringName) -> PuzzleAtom:
	for a in kin(id):
		if not a.is_solved():
			return a
	return null


# --- The gate -----------------------------------------------------------------

## Every atom answered, and the key spent if one is wanted.
##
## Overrides `LockedDoor.unlocked()`, which asks `Game.has()`. Note what is NOT
## cached: the plate can rise while the player is standing at the door, and a
## bool set once at solve time would be a door that stayed open over an empty
## plate.
func unlocked() -> bool:
	if unsolved_count() > 0:
		return false
	if needs_key and not _key_spent:
		return Game.small_keys > 0
	return true


## What it says while it is shut. Off the atom's own row, so the line names the
## verb -- "THE EYE IS SHUT", not "LOCKED" -- and counts the work left when there
## is more than one of a kind.
func refusal_line() -> String:
	# **An ordered gate speaks for the sequence it is still inside** -- which one
	# is next, not how many are left. The two lines carry the same numbers and mean
	# opposite things (`PuzzleAtoms.refusal_next_for`), and a player being asked for
	# an ORDER who is told a COUNT has been told the wrong fact about their own
	# room. Once the run is complete this falls through to the ordinary line below,
	# which is how the eye row's door goes from naming an eye to naming the key.
	if ordered:
		var next := _the_sequence()
		if next != null:
			var run := kin(next.atom_id)
			# Through the atom, never through the table -- `refusal_next` is
			# overridable for the same reason `refusal` is.
			return next.refusal_next(run.find(next) + 1, run.size())
	var left := 0
	var id: StringName = &""
	var speaker: PuzzleAtom = null
	for a in _atoms:
		if a.is_solved():
			continue
		# The FIRST unsolved atom names the line, and only its own kind is counted.
		# A mixed set saying "4 OF 6" when two of the six are plates and four are
		# eyes would be a count of nothing the player can see.
		if id == &"":
			id = a.atom_id
			speaker = a
		if a.atom_id == id:
			left += 1
	if id == &"":
		# Solved, and still shut: the door wants the key the hunt produced.
		return PuzzleAtoms.refusal_for(PuzzleAtoms.SMALL_KEY, 1, 1)
	var total := 0
	for a in _atoms:
		if a.atom_id == id:
			total += 1
	# **Asked of the ATOM, not of the table**, and the difference is the whole of
	# CLAUDE.md §3's static-dispatch row. `PuzzleAtom.refusal()` IS this same call
	# to `PuzzleAtoms.refusal_for` -- nothing about the eight stock atoms changes
	# -- but a VARIANT that overrides it (`EyeSwitch.frozen`, combinator 8) can
	# only ever be heard through the handle. Written the other way, a door onto a
	# frozen eye said "THE EYE IS SHUT" at a player who had just put an arrow in
	# it: the wrong refusal, silently, which is exactly the failure GDD pillar 3
	# exists to forbid.
	return speaker.refusal(left, total)


## The unfinished run this gate is standing in front of, if there is one.
##
## A kind with only ONE member in the set is not a sequence and is skipped -- the
## gate room's small key is exactly that, so the eye row's door names an eye while
## the row is unfinished and the key once it is not. If two kinds were both runs
## and both unfinished the first in adoption order wins, and no gate in the game
## is built that way; the rule is written down so the next one is deliberate.
func _the_sequence() -> PuzzleAtom:
	var seen: Array[StringName] = []
	for a in _atoms:
		if seen.has(a.atom_id):
			continue
		seen.append(a.atom_id)
		if kin(a.atom_id).size() < 2:
			continue
		var next := next_in(a.atom_id)
		if next != null:
			return next
	return null


## Spend the key here, at the door, and then open as a `LockedDoor` does.
##
## `_key_spent` is what stops `super()`'s own `unlocked()` check failing on the
## line after the spend: the key has left the ring by then, and a gate that
## re-asked `Game.small_keys > 0` would refuse the player it just charged.
func activate(by: Node3D) -> void:
	if is_open():
		return
	if not unlocked():
		_refuse()
		return
	if needs_key and not _key_spent:
		if not Game.spend_key():
			_refuse()
			return
		_key_spent = true
	super(by)


# --- Atoms moving -------------------------------------------------------------

func _on_atom_changed(atom: PuzzleAtom) -> void:
	if _breaking:
		return
	# **The open state has an exit now, and card #116 is that it did not.** This
	# line used to read `if is_open() or _breaking: return`, so a gate that had
	# swung stopped hearing its own atoms for ever: the owner stood on the plate,
	# the door opened, he stepped off, `unsolved` fired, and this returned.
	#
	# Only a REVERSIBLE gate comes back. An eye row that re-locked itself behind
	# the player would be the cycle-home reward taken back (`PuzzleAtom`'s own
	# class note), and no latching atom can reach here with the count non-zero
	# anyway -- `unsolve()` refuses them and `reset()` is the sequence's, which
	# `_breaking` has already returned above.
	if is_open():
		if reversible() and unsolved_count() > 0:
			_shut()
		return
	# **Sequence, and it is the whole of combinator 2.** Checked before anything
	# else looks at the count, because an out-of-turn solve must never be a solve
	# the door counted for even one frame -- `unsolved_count()` reaching zero here
	# is `_swing()`, and a door that opened on the way past would be a sequence
	# that was decoration.
	if ordered and atom != null and atom.is_solved() and _out_of_turn(atom):
		_break_the_sequence(atom)
		return
	_refresh_prompt()
	if unsolved_count() > 0:
		# Something went back up. The mark goes cold with it, so a player who
		# stepped off a plate can see from across the room why the door shut.
		_tint_sigil(0.0)
		return
	_tint_sigil(1.0)
	# The world's announcement, and the one `Sfx` already maps to `puzzle_reward`.
	# It fires on the SOLVE, not on the door -- a key hunt whose gate is still
	# waiting to be spent at has still been solved.
	if not _announced:
		_announced = true
		Bus.puzzle_solved.emit(puzzle_id)
	if auto_open:
		# The reward for the last switch is the door moving, now, wherever the
		# player is standing. `_swing()` is `LockedDoor`'s own opening and does
		# everything the button would have.
		_swing()
	elif Prompt.focus == self:
		Bus.prompt_changed.emit("%s TO OPEN" % Glyph.cap(&"interact"))


# --- Sequence (`docs/PUZZLES.md` §3, combinator 2) -----------------------------
#
# Two short methods and one guard, which is the price §8.1 would have quoted for
# this row: no prop, no manager, no second signal. The atoms already emit
# `solved`, the gate is already listening, and `PuzzleAtom.index` was already
# exported and already set by every placer that builds more than one of a kind --
# it was simply read by nothing but the flag.
#
# **The order is per KIND, not across the whole set.** A gate room's set is three
# eyes AND a small key; a rule that ordered those together would make picking the
# key up out of turn undo the row that produced it. Two runs of different atoms in
# one gate are independent sequences, which is also the only reading of "trip N
# atoms in order" that survives §3's nest sitting on top of it.


## Did this atom answer out of turn? True when something of its own kind, lower
## in the run, is still unsolved.
func _out_of_turn(atom: PuzzleAtom) -> bool:
	for a in _atoms:
		if a.atom_id != atom.atom_id or a == atom:
			continue
		if not a.is_solved() and a.index < atom.index:
			return true
	return false


## **Put the whole run back.** The player watched the row light and watched it go
## out; that is the combinator, and a version that merely refused the offending
## atom would be a lock with a hint rather than a sequence.
##
## `reset()` and not `unsolve()` -- the eye is latching, and the flag has to go
## with the light or the row comes back lit on the next rebuild (see that method).
##
## The noise is the game's one refusal sound, fired ONCE and from the atom that
## was struck rather than from the door: the player is standing at the row with a
## bow, not at the door, and three `craft_fail`s in a frame is a buzzer.
func _break_the_sequence(atom: PuzzleAtom) -> void:
	_breaking = true
	for a in kin(atom.atom_id):
		a.reset()
	_breaking = false
	Bus.request_sfx.emit(&"craft_fail", atom.global_position)
	_tint_sigil(0.0)
	_refresh_prompt()
	# The line is now naming a different atom, so a player standing at the door
	# when the row went out is told so without walking away and back.
	if Prompt.focus == self:
		Bus.prompt_changed.emit(refusal_line())
