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

var _atoms: Array[PuzzleAtom] = []
var _key_spent: bool = false


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
	var left := 0
	var id: StringName = &""
	for a in _atoms:
		if a.is_solved():
			continue
		# The FIRST unsolved atom names the line, and only its own kind is counted.
		# A mixed set saying "4 OF 6" when two of the six are plates and four are
		# eyes would be a count of nothing the player can see.
		if id == &"":
			id = a.atom_id
		if a.atom_id == id:
			left += 1
	if id == &"":
		# Solved, and still shut: the door wants the key the hunt produced.
		return PuzzleAtoms.refusal_for(PuzzleAtoms.SMALL_KEY, 1, 1)
	var total := 0
	for a in _atoms:
		if a.atom_id == id:
			total += 1
	return PuzzleAtoms.refusal_for(id, left, total)


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

func _on_atom_changed(_atom: PuzzleAtom) -> void:
	if is_open():
		return
	_refresh_prompt()
	if unsolved_count() > 0:
		# Something went back up. The mark goes cold with it, so a player who
		# stepped off a plate can see from across the room why the door shut.
		_tint_sigil(0.0)
		return
	_tint_sigil(1.0)
	# The world's announcement, and the one `Sfx` already maps to `level_chime`.
	# It fires on the SOLVE, not on the door -- a key hunt whose gate is still
	# waiting to be spent at has still been solved.
	Bus.puzzle_solved.emit(puzzle_id)
	if auto_open:
		# The reward for the last switch is the door moving, now, wherever the
		# player is standing. `_swing()` is `LockedDoor`'s own opening and does
		# everything the button would have.
		_swing()
	elif Prompt.focus == self:
		Bus.prompt_changed.emit("%s TO OPEN" % Glyph.cap(&"interact"))
