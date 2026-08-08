class_name Hit
extends RefCounted
## One blow. docs/CONTRACT.md §8 — there is exactly one damage path and this is
## the thing that travels down it.
##
## Amounts are in QUARTER hearts, like the source material: K.HEART == 4 is one
## heart, and a basic slash is deliberately not a whole one.

## Quarter-hearts of damage. K.QUARTER == 1.
var amount: int = K.QUARTER
## World position the blow came FROM, which is what knockback is measured against.
var from: Vector3 = Vector3.ZERO
## Metres/sec pushed away from `from`.
var knockback: float = 0.0
## Seconds the victim is stunned.
var stun: float = 0.0
## &"sword" &"arrow" &"bomb" &"contact" &"fire"
var kind: StringName = &"sword"


static func make(amount_q: int, from_pos: Vector3, kind_id: StringName = &"sword",
		knock: float = 0.0, stun_time: float = 0.0) -> Hit:
	var h := Hit.new()
	h.amount = amount_q
	h.from = from_pos
	h.kind = kind_id
	h.knockback = knock
	h.stun = stun_time
	return h
