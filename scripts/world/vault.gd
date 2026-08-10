class_name Vault
extends Node3D
## The three rooms behind a vault door. A PREFAB, not a level.
##
## `docs/GDD.md` §5.3: *the vault on floor N is opened by floor N+1's boss item,
## and holds a relic. Three rooms, a harder pack than the floor around it, one
## relic, one rich chest.* That sentence is the whole specification and this file
## is not allowed to be longer than it in spirit.
##
## **The line this file exists to hold** (GDD §5.3, and `docs/SCOPE.md` §2 refuses
## the other side of it by name): *a fork is a door and a three-room prefab. The
## moment a fork wants its own tint, its own roster or its own boss, it has
## stopped being a fork and started being floor 5, and floor 5 is out of scope.*
## So:
##
##   * **No tint.** It is lit by the kit's own sconces and sits inside the
##     dungeon's one `WorldEnvironment`.
##   * **No roster of its own.** The bodies come out of the FLOOR's manifest --
##     `FloorDb.roster(level, DEEP)`, which is that floor's `bands_deep` pool. A
##     vault on the Cistern is full of the Cistern's worst, not of trolls.
##   * **No boss, no second stair, no way on.** The only exit is the door you
##     came through. A vault with an exit is a route, and a route is a floor.
##
## ## "Harder than the floor around it", without a second curve
##
## Three knobs, and every one of them is an existing curve ASKED A DEEPER
## QUESTION rather than a new number (`docs/CONTRACT.md`: `Prog` owns difficulty,
## `FloorDb` owns identity, and neither may be re-derived here):
##
##   * the roster is the floor's `bands_deep`, which is what its own deepest
##     rooms draw from;
##   * the pack is `FloorDb.pack(level)` with one more body at each end;
##   * the bodies are built at `level + 1`, so `Prog` gives them the next floor's
##     health, damage and wind-up -- and the next floor's drop table with it,
##     which is the reward half of the same sentence.
##
## A vault on floor 1 is therefore the Cistern at floor-2 pressure: familiar
## monsters you cannot trade with the way you did upstairs.

## Which floor this vault hangs off. Set by `Dungeon` when it places the prefab;
## everything below is a lookup on it.
@export var level: int = 1
## Stable per-vault seed. Same run seed, same vault.
@export var rng_seed: int = 1

const KIT_FLOOR := preload("res://scenes/kit/floor_slab.tscn")
const KIT_CEIL := preload("res://scenes/kit/ceiling_slab.tscn")
const KIT_WALL := preload("res://scenes/kit/wall_segment.tscn")
const KIT_DOORWAY := preload("res://scenes/kit/doorway.tscn")
const KIT_TORCH := preload("res://scenes/kit/torch.tscn")
const KIT_PILLAR := preload("res://scenes/kit/pillar.tscn")

# --- The shape ----------------------------------------------------------------
## Authored in the vault's OWN space: the mouth is at the origin, in the plane of
## the dungeon room's wall, and everything runs down local +Z. One rotation on
## the placer's side then puts the whole prefab behind any wall on any floor
## (`Dungeon._place_vault`), which is what makes it a prefab rather than a level.

const ROOMS := 3
## Smaller than a dungeon room (16 m) on purpose. Three rooms you fight across in
## a few strides read as a strongbox; three more 16 m halls read as more floor.
const ROOM := 11.0
## The passage from the door to the first room.
const LINK := 4.0
## Between rooms.
const GAP := 4.0
## Ceilings are the corridor's, not the room's -- 5 m rather than 7. A vault is
## somewhere the Vyr put a thing, not somewhere they walked.
const CEIL := K.CEIL_CORRIDOR

## How deep the whole prefab reaches from its mouth. `Dungeon` reads this
## constant off the script to decide how many grid cells to keep clear behind the
## door, so a vault that grows a room cannot end up built through a corridor.
const TOTAL_DEPTH := LINK + float(ROOMS) * ROOM + float(ROOMS - 1) * GAP

## One more body at each end than the floor outside. See the class header.
const PACK_BONUS := 1
## Far enough past the manifest's last band key that `FloorDb.roster` falls
## through to `bands_deep`. Named rather than written as a bare 99 so the reason
## reads as a decision: the vault draws from what this floor keeps at the bottom.
const DEEP_DIST := 99

var _rng := RandomNumberGenerator.new()
var _relic: LootMote = null
var _chest: Chest = null


func _ready() -> void:
	_rng.seed = absi(rng_seed) + 1
	_build_link()
	for i in ROOMS:
		_build_room(i)
		if i > 0:
			_build_gap(i)
	_populate()


# --- Where things are ----------------------------------------------------------

## The centre of room `i`, in local space. Room 0 sits one LINK past the door.
static func room_centre(i: int) -> Vector3:
	return Vector3(0.0, 0.0, LINK + ROOM * 0.5 + float(i) * (ROOM + GAP))


## The relic and the rich chest, both in the last room. Public so a director can
## walk to them without knowing the arithmetic.
func last_room() -> Vector3:
	return room_centre(ROOMS - 1)


## The prize, once the door has been opened. Null before that -- see `reveal()`.
func relic_mote() -> LootMote:
	return _relic


## Put the relic in the last room. `Dungeon` calls this when the vault door
## opens, and again on build if the door is already open, so it is idempotent.
##
## **Why not at `_ready`, like the pack and the chest?** Because a `LootMote` is
## a live pickup with a live trigger, and a relic minted at floor build is one
## lying in a room nobody can enter. Everything in this project that asks the
## world "is there loot near me" -- the Sounding-Rod's hum, which reads exactly
## this slot through `RelicPickup.pending`, a director walking to the nearest
## mote, anything a minimap grows later -- would answer yes through 45 metres of
## masonry and a locked door. `tools/directors/mvp_loop.gd` found it first: it
## teleports the hero onto the first mote in the scene and hauled the vault's
## relic out of a vault it had never opened, and the 200-gold relic toll then
## made the Escape Rope unaffordable.
##
## `RelicPickup`, not `LootMote.drop`: it is the one placer that knows a relic
## already in the bag or already donated must not be minted a second time, and it
## is what makes "lost on death, found again where it lay" cost no code. Placed
## in world space, because `LootMote.drop` sets `global_position`.
func reveal() -> LootMote:
	if _relic != null and is_instance_valid(_relic):
		return _relic
	_relic = RelicPickup.place_anchor(self, level, &"vault",
		to_global(last_room() + Vector3(ROOM * 0.20, 0.75, ROOM * 0.22)))
	return _relic


func rich_chest() -> Chest:
	return _chest


# --- Construction ---------------------------------------------------------------

func _build_link() -> void:
	var w := K.CORRIDOR_W
	_slab(Vector2(w, LINK), Vector3(0.0, 0.0, LINK * 0.5))
	for s: float in [-1.0, 1.0]:
		# A wall's finished face runs down its local +Z (see KitWall), so the run
		# on -X has to look toward +X and vice versa.
		_wall(LINK, Vector3(s * w * 0.5, 0.0, LINK * 0.5), PI * 0.5 * -s, 1)


## One chamber. The near and far walls are punched where a passage meets them --
## the near one always (that is the way in), the far one only when another room
## follows.
func _build_room(i: int) -> void:
	var c := room_centre(i)
	var half := ROOM * 0.5
	_slab(Vector2(ROOM, ROOM), c)

	# Sides.
	for s: float in [-1.0, 1.0]:
		_wall(ROOM, c + Vector3(s * half, 0.0, 0.0), PI * 0.5 * -s, 10 + i * 8
			+ (1 if s > 0.0 else 0))
	# Near wall (looking back the way you came) and far wall.
	_punched(c + Vector3(0.0, 0.0, -half), PI, 20 + i * 8)
	if i < ROOMS - 1:
		_punched(c + Vector3(0.0, 0.0, half), 0.0, 24 + i * 8)
	else:
		_wall(ROOM, c + Vector3(0.0, 0.0, half), 0.0, 28 + i * 8)

	# Two sconces on the side walls, facing in. The last room gets four: it is the
	# one the player has to be able to read a chest, a relic and a pack in at the
	# same time, and legibility is the one thing in scope this round.
	var lamps := 4 if i == ROOMS - 1 else 2
	for n in lamps:
		var s := -1.0 if n % 2 == 0 else 1.0
		var z := (-0.24 if n < 2 else 0.24) * ROOM
		var t := KIT_TORCH.instantiate()
		t.rng_seed = _salt(40 + i * 8 + n)
		t.cast_shadow = n < 2
		t.light_range = 11.0
		t.light_energy = 7.0
		t.position = c + Vector3(s * half, KitStyle.SCONCE_Y, z)
		t.rotation.y = PI * 0.5 * -s
		add_child(t)

	# A pair of posts in the middle room only, so the three rooms are not one
	# room three times. They are cover, which the harder pack needs to be a fight
	# rather than a corner you get surrounded in.
	if i == 1:
		for s: float in [-1.0, 1.0]:
			var p := KIT_PILLAR.instantiate()
			p.height = CEIL
			p.position = c + Vector3(s * ROOM * 0.26, 0.0, 0.0)
			add_child(p)


## The corridor between room `i - 1` and room `i`.
func _build_gap(i: int) -> void:
	var w := K.CORRIDOR_W
	var z := room_centre(i).z - ROOM * 0.5 - GAP * 0.5
	_slab(Vector2(w, GAP), Vector3(0.0, 0.0, z))
	for s: float in [-1.0, 1.0]:
		_wall(GAP, Vector3(s * w * 0.5, 0.0, z), PI * 0.5 * -s,
			60 + i * 4 + (1 if s > 0.0 else 0))


## A wall run with the passage's hole in it: two flanking segments and a kit
## doorway, exactly as `Dungeon._build_side` does it.
func _punched(at: Vector3, yaw: float, salt: int) -> void:
	var span := K.CORRIDOR_W + 2.0
	var seg := (ROOM - span) * 0.5
	var along := Vector3(cos(yaw), 0.0, -sin(yaw))
	if seg > 0.4:
		for s: float in [-1.0, 1.0]:
			_wall(seg, at + along * (s * (span + seg) * 0.5), yaw,
				salt + (1 if s > 0.0 else 0))
	var door := KIT_DOORWAY.instantiate()
	door.span = span
	door.height = CEIL
	door.rng_seed = _salt(salt + 2)
	door.position = at
	door.rotation.y = yaw
	add_child(door)


func _slab(size: Vector2, at: Vector3) -> void:
	var f := KIT_FLOOR.instantiate()
	f.size = size
	f.position = at
	add_child(f)
	var c := KIT_CEIL.instantiate()
	c.size = size
	c.position = at + Vector3(0.0, CEIL, 0.0)
	add_child(c)


func _wall(length: float, at: Vector3, yaw: float, salt: int) -> void:
	var w := KIT_WALL.instantiate()
	w.length = length
	w.height = CEIL
	w.rng_seed = _salt(salt)
	w.position = at
	w.rotation.y = yaw
	add_child(w)


func _salt(slot: int) -> int:
	return absi(rng_seed * 31 + slot * 7919) % 100000 + 1


# --- Contents -------------------------------------------------------------------

func _populate() -> void:
	var pool := FloorDb.roster(level, DEEP_DIST)
	var pack := FloorDb.pack(level) + Vector2i(PACK_BONUS, PACK_BONUS)
	var elite := Prog.elite_chance(level + 1)

	for i in ROOMS:
		var c := room_centre(i)
		var count := _rng.randi_range(pack.x, pack.y)
		for n in count:
			var kind: StringName = &"skeleton"
			if not pool.is_empty():
				kind = pool[_rng.randi_range(0, pool.size() - 1)]
			var e := Enemy.new()
			e.kind = kind
			e.drop_seed = _rng.randi()
			# The one number that makes this "harder than the floor around it".
			# `Prog` answers it; nothing here re-derives health or damage.
			e.level = level + 1
			e.elite = n == 0 and _rng.randf() < elite
			e.position = c + _scatter(n, count, ROOM * 0.28)
			add_child(e)

	# The rich chest and the relic, together in the last room. Together on
	# purpose: the vault is one payoff at the end of one walk, and splitting it
	# across three rooms would turn a strongbox into a corridor with prizes in it.
	var c_last := last_room()
	_chest = Chest.new()
	_chest.name = "VaultChest"
	# The deepest-room chest of the floor BELOW, which is what a vault is worth:
	# you came back down here carrying the item that opened it.
	_chest.picks = Prog.chest_picks(level + 1, true)
	_chest.position = c_last + Vector3(-ROOM * 0.20, 0.0, ROOM * 0.22)
	# Facing back down the room, so its fan of motes lands on floor you can walk.
	_chest.rotation.y = PI
	add_child(_chest)

	# The relic is NOT placed here. See `reveal()`.


## Ring-scatter with a jitter, the same rule `Dungeon` uses and for the same
## reason: a uniform scatter stacks two bodies often enough to look like a bug.
func _scatter(i: int, total: int, radius: float) -> Vector3:
	var a := TAU * (float(i) + _rng.randf_range(-0.18, 0.18)) / float(maxi(total, 1))
	var r := radius * _rng.randf_range(0.55, 1.0)
	return Vector3(sin(a) * r, 0.0, cos(a) * r)
