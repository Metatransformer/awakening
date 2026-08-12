class_name Urn
extends PuzzleAtom
## Atom 2 of 8 (`docs/PUZZLES.md` §2): the urn. **This is rule 2.**
##
## > *Every puzzle room is solvable from a cold start with an empty pouch,
## > because the urns beside it hold exactly what it needs.* (§0)
##
## That sentence is the entire reason this prop exists, and it is why the urn is
## the one atom in the kit that **cannot gate a door** (`PuzzleAtoms.ATOMS`'
## `gates: false`). A gate hung on a broken urn would open on the way past, by
## accident, from a stray swing -- and worse, a room that had to be smashed
## before it could be solved would make the ammunition a lock.
##
## What it holds is decided by the PLACER, not rolled here. Puzzle urns remain
## authored supply: arrows, charges or hearts selected to solve the room. An
## ambient caller may instead choose coins or any merchandise id before the
## break. Rolling inside the urn would make rule 2 a probability, and a
## probability is exactly what rule 2 forbids: "the urns beside it hold exactly
## what it needs".
##
## It takes damage through `apply_hit`, the same duck-typed entry point
## `TrainingPost` answers on and the same one `Arrow._damageable` and the sword's
## scan both look for (`docs/CONTRACT.md` §8). Any blow breaks it -- there is no
## health, because an urn with hit points is a fight.

## What comes out. `&"arrows"`, `&"charges"` and `&"hearts"` are authored puzzle
## supply; `&"coins"` is direct gold; any other non-empty ItemDb id is a bag
## mote; `&""` and unknown ids are nothing. The placer chooses before break.
@export var holds: StringName = &"arrows"
## How many arrows, charges, quarter-hearts, coins, or copies of the item.
## Each lane supplies its own small default when this is zero.
@export var amount: int = 0

const CoinPickup := preload("res://scripts/world/coin_pickup.gd")
const HEIGHT := 0.92
const BELLY_R := 0.34
const NECK_R := 0.17
## How far the shards are thrown. Far enough to read as a break, near enough that
## what fell out of it is still where you were standing.
const SHARD_FLING := 1.5
const SHARD_LIFE := 2.4

var _body: StaticBody3D
var _whole: Node3D
var _clay: StandardMaterial3D


func _ready() -> void:
	if atom_id == &"":
		atom_id = PuzzleAtoms.URN
	_build()
	super()


## The damage contract's entry point (`docs/CONTRACT.md` §8). Returns nothing, so
## a caller reading `landed == false` -- which is what the sword and the arrow
## both do -- treats it as a landed blow. That is the same bargain `TrainingPost`
## strikes and the two must not diverge.
##
## `hit` is a `Hit`, and nothing here reads a field off it: an urn does not care
## how hard it was struck or by what. **Any blow breaks it** -- see the class note.
func apply_hit(_hit) -> void:
	if is_solved():
		return
	solve()


# --- The break ----------------------------------------------------------------

func on_solved() -> void:
	if _body != null:
		# Freed, not disabled. A shape that is only disabled is one bug away from
		# an invisible wall where an urn used to be -- `LockedDoor._build_blocker`
		# and `BossArena._build_seal` both record the same rule.
		_body.queue_free()
		_body = null
	if _whole != null:
		_whole.queue_free()
		_whole = null
	Bus.request_sfx.emit(&"container_break", global_position)
	_throw_shards()
	_spill()


## Already smashed this run. No shards, no noise, no spill -- and crucially no
## second helping of arrows, which is what a `restore_solved()` that called
## `on_solved()` would have handed out on every re-entry.
func restore_solved() -> void:
	if _body != null:
		_body.queue_free()
		_body = null
	if _whole != null:
		_whole.queue_free()
		_whole = null


## What was inside. Placed into the SCENE rather than under this node, because
## this node's own children are about to be freed and a bundle parented here
## would go with them.
func _spill() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var at := global_position + Vector3.UP * 0.45
	match holds:
		&"arrows":
			var n := amount if amount > 0 else ArrowBundle.FLOOR_COUNT
			ArrowBundle.drop(scene, at, n, Vector3.UP * 0.4)
		&"charges":
			# The same shape as the arrows, for the same rule -- a `ChargeCache`
			# is `ArrowBundle` for the working (`docs/PUZZLES.md` §0 rule 2,
			# `docs/ITEMS.md` §8 D13). NOT a direct `Game.add_charges()` the way
			# the hearts below are: hearts have no pickup prop in this game and
			# inventing one would be a new system, whereas charges are a counted
			# consumable that the bow's supply already showed how to lie on a
			# floor. It also keeps the take REFUSABLE -- a hero who arrives
			# already stocked leaves the cache standing instead of having the
			# overflow clamped away by a grant he never asked for.
			# Flung DOWN, unlike the arrows above, and the difference is measured
			# rather than stylistic: `at` is the pot's mouth at 0.45 m and the
			# arrows' `UP * 0.4` leaves a bundle hanging at 0.85 m, which is
			# chest height on a 1.65 m hero. A `ChargeCache` is a walk-over floor
			# pickup and it has to LIE on the floor -- one that floats reads as a
			# thing the room is presenting rather than a thing that fell out of a
			# broken pot, and the tween is the only gravity either pickup has.
			var c := amount if amount > 0 else ChargeCache.HOLDS
			ChargeCache.drop(scene, at, c, Vector3(0.0, -0.30, 0.0))
		&"hearts":
			# Straight to the hero. There is no heart pickup prop in this game --
			# health comes from rest, potions and this -- and inventing one to
			# serve an urn would be a new system against a frozen manifest
			# (`docs/SCOPE.md` §1). It is a quarter-heart-counted heal and the
			# HUD already draws it.
			Game.heal(amount if amount > 0 else 2 * K.QUARTER)
			Bus.request_sfx.emit(&"buff_apply", global_position)
		&"coins":
			var value := amount if amount > 0 else CoinPickup.DEFAULT_AMOUNT
			CoinPickup.drop(scene, at, value, Vector3(0.42, -0.39, 0.0))
		_:
			# Item ids are authored merchandise. Unknown ids and the explicit empty
			# lane remain no-op, preserving the old empty-pot behavior.
			if holds != &"" and ItemDb.get_def(holds) != null:
				var count := amount if amount > 0 else 1
				LootMote.drop(scene, holds, at,
					Vector3(-0.42, -0.39, 0.0), count)


func _throw_shards() -> void:
	var shard := _mat(Color(0.44, 0.40, 0.33), 0.98, 0.0)
	for i in 7:
		var a := TAU * float(i) / 7.0
		var mi := _box(self, shard, Vector3(0.16, 0.13, 0.05),
			Vector3(cos(a) * BELLY_R * 0.6, 0.30, sin(a) * BELLY_R * 0.6),
			Vector3(randf() * 0.8, a, randf() * 0.8))
		var land := mi.position + Vector3(cos(a), 0.0, sin(a)) * SHARD_FLING
		land.y = 0.06
		var tw := create_tween()
		# Arced, not slid. A shard that travels flat along the floor reads as a
		# thing sliding; the same shard with 0.5 m of hang reads as one thrown.
		var start := mi.position
		tw.tween_method(func(t: float) -> void:
			if is_instance_valid(mi):
				mi.position = start.lerp(land, t) + Vector3.UP * sin(t * PI) * 0.5
				mi.rotation.x += 0.22,
			0.0, 1.0, 0.42).set_ease(Tween.EASE_OUT)
		tw.tween_interval(SHARD_LIFE)
		tw.tween_callback(mi.queue_free)


# --- Construction -------------------------------------------------------------

func _build() -> void:
	_body = StaticBody3D.new()
	_body.name = "Body"
	# `L_INTERACT` as well as `L_WORLD`, and both are load-bearing: the arrow's
	# query masks `L_WORLD | L_ENEMY | L_INTERACT` and the sword's scan looks for
	# the same, so an urn on `L_WORLD` alone is an urn only the sword can break.
	# It is also what stops the hero walking through it.
	_body.collision_layer = K.L_WORLD | K.L_INTERACT
	_body.collision_mask = 0
	add_child(_body)

	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = BELLY_R
	cyl.height = HEIGHT
	cs.shape = cyl
	cs.position.y = HEIGHT * 0.5
	_body.add_child(cs)

	_whole = Node3D.new()
	_whole.name = "Pot"
	add_child(_whole)

	# Fired clay, warm against the Cistern's cold stone. Not `Pal.RUST` -- that
	# is damage (`docs/STYLEGUIDE.md` §2) and a breakable that wears the damage
	# hue is a breakable the player reads as a hazard.
	_clay = _mat(Color(0.46, 0.34, 0.26), 0.98, 0.0)
	var band := _mat(Color(0.34, 0.30, 0.24), 0.96, 0.0)

	# Four stacked courses: foot, belly, shoulder, neck. Faceted cylinders rather
	# than one tapered mesh, because the STEP between courses is what catches
	# torchlight and says "pot" at 8 m -- the same trick `kit_doorway.gd` uses on
	# the surround.
	_cyl(_whole, _clay, BELLY_R * 0.62, 0.14, Vector3(0.0, 0.07, 0.0))
	_cyl(_whole, _clay, BELLY_R, 0.40, Vector3(0.0, 0.34, 0.0))
	_cyl(_whole, _clay, BELLY_R * 0.78, 0.22, Vector3(0.0, 0.65, 0.0))
	_cyl(_whole, band, NECK_R, 0.16, Vector3(0.0, 0.84, 0.0))
	# The mouth: a dark ring, so the pot reads as hollow rather than as a lump.
	var dark := _mat(Pal.VOID, 1.0, 0.0)
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cyl(_whole, dark, NECK_R * 0.82, 0.03, Vector3(0.0, 0.92, 0.0))
