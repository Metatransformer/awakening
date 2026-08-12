class_name BossArena
extends Area3D
## The separate boss chamber, and what happens when you walk into it.
##
## Five things, in order, and nothing else:
##
##   1. On `_ready`, build the boss -- unless its kill flag says it is already dead,
##      in which case build nothing at all. A boss you have killed stays dead;
##      the arena is empty forever after and its descent remains available.
##   2. On the player entering, **seal**: the ring comes up out of the floor, the
##      boss wakes, and `Bus.boss_engaged` fires (from the boss -- see below).
##   3. At half health, **turn**: the ROOM escalates, once. See "The turn" below.
##   4. On the boss dying, **release**: the kill flag is set and the ring drops.
##   5. Place the deterministic boss-item great chest. On a spent arena it is
##      rebuilt until its item has actually been claimed.
##
## **It never calls `Flow`.** `CLAUDE.md` §6: `Flow` is the only thing in the
## project that changes scenes, and an arena that moved the player to the next
## floor would be the second. The chamber placer owns the descent; this node
## only records the kill and releases the arena seal.
##
## **It never emits `Bus.boss_engaged` itself either.** `BossDb`'s executor
## contract §8 puts that emit on the boss, on the first frame of the fight, and
## `Music` is already listening. Two emitters would be two crossfades.
##
## `BossDoor.dead_flag()` is the one public name for kill state. The chamber door
## was necessarily opened before this trigger could be crossed and is never
## opened by the fight.
##
## ## The seal is a fence, and that is a greybox decision
##
## "The room seals" would ideally bar the room's own doorways, but a generated
## floor hands this node a circle (`BossDb`'s `arena.radius`) and not a list of
## doors. So the seal is a polygonal fence on that circle: it works in any room,
## it is visible, it is one static body, and it says exactly what the arena is.
## When `Dungeon` places these for real it can hand over a room instead; the
## radius is already the thing the table authored.
##
## ## The turn: one signal, four rooms
##
## `docs/BOSSES.md` §5. Every boss escalates once, at half health, and **the
## escalation is the room** -- `docs/SCOPE.md` §6 caps this game at one phase and
## §5's reading of that cap is that the phase should be the fence, the posts and
## the light rather than a second move set. What a turn may touch is exactly
## those three things and nothing else, ever: not a beat's numbers, not the move
## set, not `pick_beat`, not the health bar, not the tint. Each of those is a
## second phase wearing a room.
##
## It is a `health.damaged` CONNECT and not a `_process`. The fraction only moves
## when something hits it, so a poll here would be a per-frame read of a number
## that changes about twenty times a fight -- and this node has no per-frame work
## of its own to hang one on.
##
## It emits `Bus.boss_phase_changed(1)` on the frame it applies. **That does not
## make the turn a phase.** Nothing listens today and `pick_beat` never sees it;
## the emit exists so a director has an event to photograph either side of
## instead of diffing two screenshots and hoping, and so that a signal declared at
## `event_bus.gd`:90 and emitted by nothing finally has its one emitter.

## Which fight this is. A key into `BossDb.BOSSES`.
@export var boss_id: StringName = &"cistern_warden"
## Retained for scene-fixture compatibility. Boss state no longer routes through
## a door node; `BossDoor.dead_flag()` is read directly.
@export var door_path: NodePath
## Where the boss stands, relative to this node. Across the room from the way in,
## so it is a silhouette in the far half of the frame when the door shuts.
@export var boss_offset: Vector3 = Vector3(0.0, 0.0, -4.5)
## Which `RelicDb` slot this arena's occupant is carrying, for the lost-relic
## replacement below. `&"boss"` for a floor boss; **`&""` for a miniboss**, which
## drops nothing but the chest behind it (`docs/PUZZLES.md` §7) -- and without
## the empty case a spent miniboss chamber would put floor N's BOSS relic on the
## floor, which is the boss's drop handed out behind an optional puzzle.
@export var relic_slot: StringName = &"boss"

# --- The fence ---------------------------------------------------------------
const SEAL_SEGMENTS := 20
const SEAL_HEIGHT := 3.4
const SEAL_THICK := 0.45
const SEAL_RISE := 0.55  ## seconds

## How far inside the ring the player has to be before it shuts behind them.
## Not the full radius: sealing on the boundary can leave the hero standing in
## the fence, and being pushed out of your own boss fight is a bug that reads as
## a physics glitch rather than as the design it broke.
const TRIGGER_FRACTION := 0.82

## The boss is built by path rather than by naming the class. A `class_name`
## added in the same change as the scene that uses it is not in the global class
## cache until the project is re-imported, and naming it here is a PARSE error
## that takes the whole scene down before its first frame -- which is the lesson
## `tools/directors/gate_locks.gd` records at the bottom of its own file.
const BOSS_SCRIPT := "res://scripts/actors/enemies/boss.gd"

# --- The turn -----------------------------------------------------------------

## How far INSIDE the new fence the annulus guard puts a body down. The hero's
## capsule is 0.3 m and a panel is 0.45 m thick and overlaps its neighbours, so
## 1.2 m clears the whole wall with a body-width to spare -- and it has to clear
## it by the time the ring arrives, not by the time the pull finishes.
const PULL_INSET := 1.2
## Seconds. Short enough that the turn still reads as one event, long enough that
## the hero is seen to be dragged rather than teleported.
const PULL_TIME := 0.30

## Seconds a `topple`d post takes to sink, and how far it goes. `_build_cover`
## builds a 4.2 m box, so 4.6 m puts the top of it under the floor.
const TOPPLE_TIME := 0.55
const TOPPLE_DROP := 4.6

## How far past the fence `douse` will reach for a light, in metres, and how long
## it takes to go out.
##
## The bound is the whole safety of the walk. `douse` starts from `get_parent()`
## -- the ROOM node, because `Dungeon._place_boss` adds the arena and
## `_build_room_torches` adds the sconces to the same room root -- and a fixture
## that parented an arena higher up the tree would otherwise put out the lights
## of the entire floor. A sconce is on the room's own wall, which is at most a
## few metres past a fence sized to the room.
const DOUSE_REACH := 8.0
const DOUSE_TIME := 0.8

## The `keystone` mass: 3 m across at the middle of the arena, where nothing
## stands. The hook anchor rides on top, so the hookshot puts the hero ON it.
const KEYSTONE_SIZE := Vector3(3.0, 2.4, 3.0)

var _row: Dictionary = {}
var _boss: CharacterBody3D = null
var _boss_item_chest: BossItemChest = null
var _seal: Node3D = null
var _sealed: bool = false
var _spent: bool = false

## Latched the frame the turn applies, so it fires exactly once however many
## blows land afterwards. A bool and not a state enum: this node has two states
## and the second one is terminal.
var _turned: bool = false
## The second, smaller fence a `shrink` raises. Null on the other three kinds.
var _seal_in: Node3D = null
## What `shrink` moved the fence to, or `-1.0` while the row still owns it.
## The row is NOT edited -- `BossDb.get_boss` hands back the static Dictionary
## itself, so writing into it would shrink this arena for the rest of the
## process, including the next run, which would then start at 8.5 m with no turn
## having happened. `Boss._arena_radius` is the same trick on the boss's side.
var _radius_override: float = -1.0
## How many sconces `douse` actually reached, and how many bodies the annulus
## guard actually had to pull. Both are read by the director: "the guard ran" and
## "the guard had something to do" are different claims, and a frame where the
## hero happened to be standing in the middle proves neither.
var _doused: int = 0
var _pulled: int = 0


func _ready() -> void:
	_row = BossDb.get_boss(boss_id)
	if _row.is_empty():
		push_error("boss_arena: no row in BossDb for %s" % boss_id)
		return

	collision_layer = 0
	collision_mask = K.L_PLAYER
	monitoring = true
	monitorable = false
	_build_trigger()
	_seal = _make_seal("Seal", radius())
	add_child(_seal)
	_build_cover()

	if _already_dead():
		_spent = true
		_replace_lost_relic()
		_place_boss_item_chest(false)
		return
	_build_boss()
	body_entered.connect(_on_body_entered)


func _already_dead() -> bool:
	return Game.flag(BossDoor.dead_flag(boss_id))


## Put the boss's relic back on a floor whose boss is already dead.
##
## GDD §3: *a relic lost on death goes back where it came from*, and
## `RelicDb.outstanding()`'s own docstring claims this needs no code -- "the
## floor is rebuilt and the room places it again". That is true of the deep chest
## and the vault, which are rebuilt every run. It was NOT true here, and the boss
## relic was the one relic in the game you could lose forever: kill the Warden,
## pick up the Imperium Anvil-Plate, die on the walk out, and the arena comes back
## `_spent` with no boss in it and therefore no `_drop_loot` -- so forge rungs 3
## and 4 were gone for the rest of the save. Two milestones each did their half
## correctly and the hole was between them.
##
## `place_anchor` is the whole guard: it answers null when the floor has no boss
## relic (the Long Descent, the boss test fixture), when it is in the bag, and
## when it is in the ledger. So the only case that places anything is the one
## this exists for.
func _replace_lost_relic() -> void:
	if relic_slot == &"":
		return
	RelicPickup.place_anchor(self, Run.level, relic_slot,
		global_position + Vector3.UP * 1.0)


# --- Reading the row ----------------------------------------------------------

func radius() -> float:
	if _radius_override > 0.0:
		return _radius_override
	var arena: Dictionary = _row.get("arena", {})
	return float(arena.get("radius", 11.0))


func boss() -> CharacterBody3D:
	return _boss


func boss_item_chest() -> BossItemChest:
	return _boss_item_chest if is_instance_valid(_boss_item_chest) else null


func is_sealed() -> bool:
	return _sealed


## True once the fight is over -- or was over before the player arrived.
func is_spent() -> bool:
	return _spent


# --- Construction -------------------------------------------------------------

func _build_trigger() -> void:
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius() * TRIGGER_FRACTION
	cyl.height = 6.0
	cs.shape = cyl
	cs.position = Vector3(0.0, 3.0, 0.0)
	add_child(cs)


## One static body carrying a whole fence at radius `r`, parked a fence-height
## below the floor and NOT yet added to the tree -- the caller places it. Raised
## by moving the NODE rather than by toggling shapes: a disabled shape is one bug
## away from an invisible wall in an arena you have cleared, which is the same
## reason `LockedDoor` frees its blocker instead of disabling it.
##
## **Parameterised because `shrink` builds a SECOND one** (`docs/BOSSES.md` §5,
## the Warden). The obvious alternative -- scaling this ring down to the new
## radius -- is the bug the `face` comment below records having shipped once: the
## panels are a fixed 4.1 m wide, so a ring scaled to 77% is twenty panels of the
## old width on a circle of the new circumference, which is daylight at every
## joint. A second ring authored at the smaller radius has its own chords.
func _make_seal(ring_name: String, r: float) -> Node3D:
	# `ring`, not `seal`: `seal()` is a method on this class and a local of that
	# name shadows it.
	var ring := Node3D.new()
	ring.name = ring_name
	ring.position = Vector3(0.0, -SEAL_HEIGHT - 0.4, 0.0)

	var body := StaticBody3D.new()
	body.name = "SealBody"
	body.collision_layer = K.L_WORLD
	body.collision_mask = 0
	ring.add_child(body)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.19, 0.22)
	mat.roughness = 0.95
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	# 1.2x the chord so neighbouring panels overlap at the joints -- a fence cut
	# to the exact chord has a gap at every post, and a gap in a seal is a hole
	# the hero's 0.3 m capsule finds on the first try.
	var chord := TAU * r / float(SEAL_SEGMENTS) * 1.2
	# `-a - PI/2`, and the quarter turn is load-bearing. A panel is 4.1 m WIDE
	# and 0.45 m THICK, so its local X has to end up tangential to the circle;
	# Godot's Y rotation puts local X at `(cos t, 0, -sin t)`, which is radial
	# for a bare `-a`. That is what this line said first, and the "seal" it built
	# was twenty thin fins pointing outward with three metres of daylight between
	# each pair -- a wall you could stroll out of in the middle of a boss fight,
	# and it photographed as a ring of standing slabs, which is why nothing
	# caught it until somebody looked at the gaps.
	var face := -PI * 0.5
	for i in SEAL_SEGMENTS:
		var a := TAU * float(i) / float(SEAL_SEGMENTS)
		var at := Vector3(cos(a) * r, SEAL_HEIGHT * 0.5, sin(a) * r)

		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(chord, SEAL_HEIGHT, SEAL_THICK)
		cs.shape = box
		cs.position = at
		cs.rotation.y = -a + face
		body.add_child(cs)

		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(chord, SEAL_HEIGHT, SEAL_THICK)
		mi.mesh = bm
		mi.material_override = mat
		mi.position = at
		mi.rotation.y = -a + face
		ring.add_child(mi)

	return ring


## `arena.cover` / `cover_count`, straight off the row.
##
## The Warden has none, deliberately -- its own row says a pillar here would
## teach the player to solve beat two by standing behind something, and beat
## two's answer is to walk INTO it. Floors 2 and 4 have cover because those are
## the two fights with a charge, and a charge lane with nothing to break it is a
## fight decided by footspeed. This loop is what makes that a row rather than a
## branch.
func _build_cover() -> void:
	var arena: Dictionary = _row.get("arena", {})
	if not bool(arena.get("cover", false)):
		return
	var count := int(arena.get("cover_count", 0))
	if count <= 0:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.26, 0.25, 0.28)
	mat.roughness = 0.96
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var ring := radius() * 0.55
	for i in count:
		var a := TAU * float(i) / float(count)
		var at := Vector3(cos(a) * ring, 0.0, sin(a) * ring)
		var post := StaticBody3D.new()
		post.name = "Cover%d" % i
		post.collision_layer = K.L_WORLD
		post.collision_mask = 0
		post.position = at
		add_child(post)
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.6, 4.2, 1.6)
		cs.shape = shape
		cs.position = Vector3(0.0, 2.1, 0.0)
		post.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = shape.size
		mi.mesh = bm
		mi.material_override = mat
		mi.position = Vector3(0.0, 2.1, 0.0)
		post.add_child(mi)


func _build_boss() -> void:
	var script := load(BOSS_SCRIPT) as GDScript
	if script == null:
		push_error("boss_arena: cannot load %s" % BOSS_SCRIPT)
		return
	_boss = script.new() as CharacterBody3D
	_boss.name = "Boss"
	_boss.set(&"boss_id", boss_id)
	# Placed BEFORE it enters the tree. `Enemy._ready` records where it woke up
	# (`_anchor`) on the frame it is added, so a body parked at the origin and
	# moved afterwards is a body whose whole idea of home is the arena's pivot.
	_boss.position = boss_offset
	add_child(_boss)
	# Scattered zone discs land inside the ring the player can see, rather than
	# inside a circle drawn round wherever the boss happens to be standing.
	if _boss.has_method(&"set_arena_center"):
		_boss.call(&"set_arena_center", global_position)
	# `died_at` and not `Bus.boss_defeated`: the bus signal carries no argument,
	# so an arena listening to it would release for a boss on any floor. This one
	# is emitted by this one body.
	(_boss as Enemy).died_at.connect(_on_boss_died)

	# The turn watches the health, and it watches it on the SIGNAL. A fraction
	# only moves when something hits it, so a `_process` here would be a per-frame
	# read of a number that changes about twenty times in a fight -- and this node
	# has no per-frame work of its own to hang one on (`docs/BOSSES.md` §5).
	#
	# Connected only when there IS a turn, so a miniboss chamber keeps exactly the
	# code path it had. `BossDb.turn` says why the minibosses have none.
	if not BossDb.turn(boss_id).is_empty():
		var hp := _boss.get(&"health") as HealthComponent
		if hp == null:
			push_error("boss_arena: %s has a turn but no health to watch" % boss_id)
		else:
			hp.damaged.connect(_on_boss_damaged)


# --- The fight ----------------------------------------------------------------

func _on_body_entered(body: Node3D) -> void:
	if _sealed or _spent or not body.is_in_group(&"player"):
		return
	seal()


## Shut the room and start the fight. Public so a director can shut it without
## walking a hero across a chamber.
func seal() -> void:
	if _sealed or _spent or _boss == null or not is_instance_valid(_boss):
		return
	_sealed = true
	_move_seal(_seal, 0.0)
	Bus.request_sfx.emit(&"door_close", global_position)
	# The boss emits `Bus.boss_engaged` from in here -- contract §8, and `Music`
	# is the thing listening.
	if _boss.has_method(&"wake"):
		_boss.call(&"wake")


func _on_boss_died(_where: Vector3) -> void:
	# First, before any reward or release listener can rebuild this chamber.
	Game.set_flag(BossDoor.dead_flag(boss_id))
	_spent = true
	_sealed = false
	# BOTH rings. A `shrink`ed arena that dropped only the outer fence would leave
	# an 8.5 m wall standing in a room whose boss is dead -- the player sealed
	# into the middle of a floor he has cleared.
	_move_seal(_seal, -SEAL_HEIGHT - 0.4)
	_move_seal(_seal_in, -SEAL_HEIGHT - 0.4)
	# The rings went up on `door_close` and came down on nothing. A wall the height
	# of the room sinking into the floor in silence is the single biggest thing
	# that happens in a boss chamber and it made no noise at all -- the mirror of
	# the sound in `seal()`, at the same place, for the same event running backward.
	Bus.request_sfx.emit(&"door_open", global_position)
	# This chamber is a room and it has just been beaten. `Bus.room_cleared` is
	# how every other room in the game says so (`RoomWatch`), and the arena is the
	# only thing that can say it here -- the chamber is not a `rooms[]` cell, so
	# the generator never built it a watcher. Named for the arena's own node so a
	# listener can tell which chamber, the same way a room is named for its root.
	Bus.room_cleared.emit(StringName(name))
	_place_boss_item_chest(true)


## A floor boss earns this chest; its permanent item waits for the player to
## open it. The separate relic remains loose on the floor and at bag/death risk.
func _place_boss_item_chest(arrive: bool) -> void:
	if BossDb.is_miniboss(boss_id) or is_instance_valid(_boss_item_chest):
		return
	var drop: Dictionary = _row.get("drop", {})
	var item: StringName = drop.get("item", &"")
	if item == &"" or Game.has(item):
		return

	_boss_item_chest = BossItemChest.new()
	_boss_item_chest.name = "BossItemChest"
	_boss_item_chest.item_id = item
	_boss_item_chest.position = Vector3.ZERO
	_boss_item_chest.visible = false
	_boss_item_chest.enabled = false
	add_child(_boss_item_chest)
	if arrive:
		RewardVfx.land(_boss_item_chest, RewardVfx.MAJOR)
	else:
		RewardVfx.show_now(_boss_item_chest)


func _move_seal(ring: Node3D, to_y: float) -> void:
	if ring == null or not is_instance_valid(ring):
		return
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, ^"position:y", to_y, SEAL_RISE)


# --- The turn -----------------------------------------------------------------

## True once the room has escalated. `docs/BOSSES.md` §5, and it never goes back.
func has_turned() -> bool:
	return _turned


## What kind of turn this arena's row authored, or `&""` for none.
func turn_kind() -> StringName:
	var t := BossDb.turn(boss_id)
	var kind: StringName = t.get("kind", &"")
	return kind


## How many sconces `douse` reached. Zero on the other three kinds, and zero on a
## `douse` in a room with no lights in reach -- which is a fact a director needs
## to be able to tell apart from "the turn did not fire".
func doused() -> int:
	return _doused


## How many bodies the annulus guard had to pull inside the new fence. §5's guard
## is only proved by a run where this is NOT zero.
func pulled() -> int:
	return _pulled


## One blow, checked against the threshold. Latches, so the turn fires once
## however many blows land after it.
func _on_boss_damaged(_hit: Hit) -> void:
	if _turned or _boss == null or not is_instance_valid(_boss):
		return
	var t := BossDb.turn(boss_id)
	if t.is_empty():
		return
	var hp := _boss.get(&"health") as HealthComponent
	if hp == null or hp.fraction() > float(t.get("at", 0.5)):
		return

	_turned = true
	_apply_turn(t)
	# AFTER the dispatch, so anything that ever does listen sees the room it has
	# been told about. The tweens the turn starts are still running -- this
	# announces the decision, not its arrival, and §5 is explicit that no listener
	# may act on it by changing a beat.
	Bus.boss_phase_changed.emit(1)


func _apply_turn(t: Dictionary) -> void:
	# ANNOTATED, per CLAUDE.md §3: indexing an untyped Dictionary hands back
	# Variant, and a `match` on a Variant against StringName constants is a
	# comparison nobody can read the failure of.
	# `if`/`elif` and not `match`, because a match PATTERN has to be a constant
	# expression and `BossDb.TURN_SHRINK` is another class's const -- the same
	# rule that stops a `const` Dictionary holding a `class_name` (CLAUDE.md §3).
	var kind: StringName = t.get("kind", &"")
	if kind == BossDb.TURN_SHRINK:
		_turn_shrink(float(t.get("to", 8.5)))
	elif kind == BossDb.TURN_TOPPLE:
		_turn_topple(int(t.get("to", 1)))
	elif kind == BossDb.TURN_DOUSE:
		_turn_douse(float(t.get("energy", 0.15)))
	elif kind == BossDb.TURN_KEYSTONE:
		_turn_keystone()
	else:
		# `validate()` catches this in a director; this catches it in a run that
		# never asked. A latched `_turned` with no effect behind it would be a
		# fight that quietly lost its escalation.
		push_error("boss_arena: %s has turn kind %s, which is not one of the four"
			% [boss_id, kind])
	print("boss_arena: %s turned -- %s (r=%.1f, pulled=%d, doused=%d)"
		% [boss_id, kind, radius(), _pulled, _doused])


## The fence walks in. `docs/BOSSES.md` §5, the Warden, and the most expensive of
## the four turns because of the two notes it carries.
##
## **Note 1: `Boss.set_arena_radius` follows it.** `_shape_zone` scatters its
## discs inside `arena_radius() - radius` read off the boss, so a fence that moved
## without this call leaves the Warden drowning the floor of the room it used to
## be in -- pools the player can see through a wall he cannot cross.
##
## **Note 2: the annulus guard, and it is the PULL rather than the refusal.** The
## seal is a solid `StaticBody3D` raised by moving a node, so raising a second one
## at 8.5 m while the hero stands at 9-11 m either shuts him into a two-and-a-half
## metre ring he cannot leave or shoves him out through the outer fence. §5 gives
## two guards and picks this one: refusing to raise while the annulus is occupied
## hands a kiting player a way to postpone the turn indefinitely, and a kiting
## player is precisely who this turn exists to punish. Pulled, it reads as the
## water taking him with it, which is also the fiction.
func _turn_shrink(to_r: float) -> void:
	_radius_override = to_r
	if _boss != null and _boss.has_method(&"set_arena_radius"):
		_boss.call(&"set_arena_radius", to_r)

	_seal_in = _make_seal("SealInner", to_r)
	add_child(_seal_in)

	var keep := maxf(to_r - PULL_INSET, 0.5)
	var tw := create_tween()
	tw.set_parallel(true)
	_pulled = 0
	# The `player` group, which is the same test `_on_body_entered` uses to decide
	# the room shuts at all. §5 says "any body in `K.L_PLAYER`"; in this project
	# those are the same one body, and the group is the handle that does not need
	# a physics query in the middle of a signal handler.
	for n in get_tree().get_nodes_in_group(&"player"):
		var body := n as Node3D
		if body == null or not is_instance_valid(body):
			continue
		# `K.plane` and NOT `K.flat`: `flat()` NORMALISES (`consts.gd`:901) and
		# `plane()` is the one that preserves length. Written with `flat` first,
		# every body measured 1.0 m from the middle, nobody was ever outside the
		# new fence, and the guard ran on every shrink and pulled nothing -- a
		# guard that reports success by doing nothing at all.
		var off := K.plane(body.global_position - global_position)
		if off.length() <= keep:
			continue
		# Straight in along the radius, keeping his own y. Moving him sideways as
		# well would be the guard choosing where he fights from, and the turn is
		# allowed to take the far half of the room away -- not to reposition him
		# in what is left.
		var to := global_position + off.normalized() * keep
		to.y = body.global_position.y
		tw.tween_property(body, ^"global_position", to, PULL_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_pulled += 1
	# `chain`, so the ring starts AFTER the last pull has landed and not beside
	# it. A wall that rises while the body is still on its way through the line it
	# rises on is the unguarded version with a tween in front of it.
	tw.chain().tween_callback(func() -> void: _move_seal(_seal_in, 0.0))


## Two of three slag pillars slump. `docs/BOSSES.md` §5, the Slag Ogre: the same
## charge with two thirds of its answer taken away.
##
## Sunk and then freed rather than freed outright. A post that vanishes between
## two frames reads as a missing prop; one that goes down into the slag reads as
## the room giving way, and it costs a tween. The collision goes on the first
## frame either way -- a sinking post the hero can still walk into is a post that
## catches him on the charge the turn just opened up.
func _turn_topple(keep: int) -> void:
	var arena: Dictionary = _row.get("arena", {})
	var count := int(arena.get("cover_count", 0))
	for i in range(maxi(keep, 0), count):
		var post := get_node_or_null(NodePath("Cover%d" % i)) as StaticBody3D
		if post == null:
			continue
		post.collision_layer = 0
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(post, ^"position:y", post.position.y - TOPPLE_DROP,
			TOPPLE_TIME)
		tw.tween_callback(post.queue_free)


## The room's sconces go out. `docs/BOSSES.md` §5, the Bellwake.
##
## **The handle exists, and it is `get_parent()`.** This was the card's one open
## question and it is settled by the tree rather than by argument:
## `Dungeon._place_boss` adds the arena to the room root with
## `root.add_child(arena)`, and `_build_room_torches` adds that room's sconces to
## the same root a few lines earlier -- so the lights are the arena's SIBLINGS and
## a walk down from the parent finds them. Nothing in `dungeon.gd` had to change.
##
## Bounded by `DOUSE_REACH` past the fence anyway, because the walk is only as
## safe as its radius: an arena parented higher up the tree by some future
## fixture would otherwise put out the lights of a whole floor, and that failure
## would look exactly like this one working.
##
## `to` is the fraction of its output each light keeps, and §6.3's row authors it
## at 0.15 rather than 0. A true zero was built and photographed first: the frame
## is black with a health bar in it, and neither the hero nor the floor has an
## edge left. GDD pillar 5 calls that a bug and not atmosphere. What the turn is
## for is taking the room's READING light, so that the beats' unshaded marks are
## the only things in the chamber with edges -- 0.15 is that, and 0.0 is a room
## with nothing in it at all.
func _turn_douse(to: float) -> void:
	var room := get_parent()
	if room == null:
		room = self
	var reach := radius() + DOUSE_REACH
	var lights: Array[Light3D] = []
	_collect_lights(room, lights)
	_doused = 0
	for light in lights:
		# `K.plane`, for the reason `_turn_shrink` spells out: `K.flat` normalises,
		# so this read 1.0 for every light in the project and the bound was not a
		# bound at all.
		if K.plane(light.global_position - global_position).length() > reach:
			continue
		# A `KitTorch` rewrites its OmniLight's energy from its own export EVERY
		# FRAME for the flicker, so a fade written onto the light itself is gone
		# on the next tick -- the room would dim for one frame and come back. Ask
		# the sconce, which owns the knob the flicker multiplies, and which also
		# knows to take the flame quad and the embers with it.
		#
		# **And only a sconce.** A generic `light_energy` fallback for anything
		# else in reach was built first and the census it printed is why it is
		# gone: inside 19 m of the arena it also caught `Env/Fill` (the room's
		# ambient key), `Hero/KeyLight` (the rig that keeps the silhouette
		# readable, GDD pillar 5), the drawn sword's `SpinGlow` and a rope's
		# omni. §5 is explicit about what a turn may touch -- the fence radius,
		# the cover posts, the room's LIGHT -- and the room's light is the
		# sconces, not the lighting rig. A turn that dims the hero's key light
		# is a turn reaching outside its own list.
		var sconce := light.get_parent()
		if sconce == null or not sconce.has_method(&"douse"):
			continue
		sconce.call(&"douse", DOUSE_TIME, to)
		_doused += 1


## Every `Light3D` under `node`, depth first. The same recursive walk
## `tools/directors/perf_probe.gd`'s `_ablate()` does, and for the same reason:
## a light in a generated room is wherever the kit scene that owns it put it.
func _collect_lights(node: Node, into: Array[Light3D]) -> void:
	for child in node.get_children():
		if child is Light3D:
			into.append(child as Light3D)
		_collect_lights(child, into)


## The broken keystone comes down in the middle. `docs/BOSSES.md` §5 and §6.4:
## the only turn of the four that gives the player something, in the fight whose
## boss holds the far side of the room.
##
## No annulus guard needed and that is a fact about the geometry rather than an
## omission: the Riven Knight's arena is 12.5 m and the mass is 3 m across at the
## centre, which is where the boss's own `boss_offset` is measured FROM and where
## nothing stands during a fight about the far side of the room.
##
## `HookTarget` and not `HookRing`: the target is the firer's aim-assist contract
## (`hook_target.gd`), the ring is the puzzle atom that reports being bitten, and
## SCOPE §1's count of nine atoms does not move for this.
func _turn_keystone() -> void:
	var mass := StaticBody3D.new()
	mass.name = "Keystone"
	mass.collision_layer = K.L_WORLD
	mass.collision_mask = 0
	add_child(mass)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.28, 0.26)
	mat.roughness = 0.94
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = KEYSTONE_SIZE
	cs.shape = shape
	cs.position = Vector3(0.0, KEYSTONE_SIZE.y * 0.5, 0.0)
	mass.add_child(cs)

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = KEYSTONE_SIZE
	mi.mesh = bm
	mi.material_override = mat
	mi.position = cs.position
	mass.add_child(mi)

	var hook := HookTarget.new()
	hook.name = "KeystoneHook"
	# On TOP of the mass, with no out-nudge. `pull_point()` offsets along local +Y
	# and local +Z, and +Z on a free-standing block in the middle of a round room
	# points at nothing in particular -- so the out-nudge is zeroed and the hero
	# arrives standing on the keystone rather than beside an arbitrary face of it.
	hook.pull_out = 0.0
	hook.pull_up = 0.5
	hook.position = Vector3(0.0, KEYSTONE_SIZE.y + 0.15, 0.0)
	mass.add_child(hook)

	# Dropped in, not switched on. It falls the height of the room in a third of a
	# second and the arrival is the picture the player is meant to read.
	mass.position.y += 6.0
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(mass, ^"position:y", 0.0, 0.35)
	tw.tween_callback(func() -> void:
		Bus.request_sfx.emit(&"door_close", mass.global_position))
