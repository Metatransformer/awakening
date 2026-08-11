class_name Hit
extends RefCounted
## One blow. docs/CONTRACT.md §8 — there is exactly one damage path and this is
## the thing that travels down it.
##
## Amounts are in QUARTER hearts, like the source material: K.HEART == 4 is one
## heart, and a basic slash is deliberately not a whole one.

## The two kinds a bow can deliver, spelled once.
##
## **`ARROW_FIRE` is the whole of combinator 8** (`docs/PUZZLES.md` §3.1,
## priced in §8.1): an arrow that crossed a lit lantern arrives as something
## else, and the lock on the far side only accepts the something else. It is one
## `StringName` because that is all it is allowed to be -- the moment convert
## needs a prop of its own it has stopped being a combinator.
##
## Spelled HERE rather than on `Arrow` because `kind` is this class's field and
## because the atoms that discriminate on it (`EyeSwitch`) should not have to
## know which projectile script exists. A typo'd StringName is a puzzle that
## builds, generates and silently never solves -- `PuzzleAtoms`' own note.
const ARROW := &"arrow"
const ARROW_FIRE := &"arrow_fire"

## Quarter-hearts of damage. K.QUARTER == 1.
var amount: int = K.QUARTER
## World position the blow came FROM, which is what knockback is measured against.
var from: Vector3 = Vector3.ZERO
## Metres/sec pushed away from `from`.
var knockback: float = 0.0
## Seconds the victim is stunned.
var stun: float = 0.0
## &"sword" &"arrow" &"arrow_fire" &"bomb" &"contact" &"fire"
var kind: StringName = &"sword"
## Who threw it, ready to print: "SKELETON", "ELITE WRAITH".
##
## A NAME and not a node reference, because the only thing that reads it is the
## run-ending screen, and by the time that screen draws the thing that killed you
## is being freed along with the floor it stood on. A `Node3D` here would be a
## field that is valid for one frame and dangling for the one that matters.
##
## Empty means nobody claimed it. The screen says so ("THE DARK") rather than
## inventing an attacker.
var source: StringName = &""


static func make(amount_q: int, from_pos: Vector3, kind_id: StringName = &"sword",
		knock: float = 0.0, stun_time: float = 0.0,
		source_name: StringName = &"") -> Hit:
	var h := Hit.new()
	h.amount = amount_q
	h.from = from_pos
	h.kind = kind_id
	h.knockback = knock
	h.stun = stun_time
	h.source = source_name
	return h
