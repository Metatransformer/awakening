class_name Hit
extends RefCounted
## One instance of damage. docs/CONTRACT.md §8 — there is ONE damage path in
## this project and this is its payload. Do not invent a second one.

## Damage in QUARTER hearts (K.QUARTER). 4 == one heart.
var amount: int = K.QUARTER
## World position the blow came FROM. Knockback is applied away from this, so
## it must be the attacker (or the blast centre), never the victim.
var from: Vector3 = Vector3.ZERO
## Metres/sec of knockback pushed away from `from`.
var knockback: float = 0.0
## Seconds the victim is stunned and cannot act.
var stun: float = 0.0
## &"sword" &"arrow" &"bomb" &"contact" &"fire"
var kind: StringName = &"contact"


static func make(amount: int, from: Vector3, kind: StringName = &"sword",
		knockback: float = K.KNOCKBACK_LIGHT, stun: float = 0.15) -> Hit:
	var h := Hit.new()
	h.amount = amount
	h.from = from
	h.kind = kind
	h.knockback = knockback
	h.stun = stun
	return h
