class_name BossArena
extends Area3D
## The deepest room, and what happens when you walk into it.
##
## Four things, in order, and nothing else:
##
##   1. On `_ready`, build the boss -- unless its door says it is already dead,
##      in which case build nothing at all. GDD §5.1: *a boss you have killed
##      stays dead; its door hangs open and the arena is empty forever after.*
##   2. On the player entering, **seal**: the ring comes up out of the floor, the
##      boss wakes, and `Bus.boss_engaged` fires (from the boss -- see below).
##   3. On the boss dying, **release**: the ring drops and the door opens.
##   4. Nothing.
##
## **It never calls `Flow`.** `CLAUDE.md` §6: `Flow` is the only thing in the
## project that changes scenes, and an arena that moved the player to the next
## floor would be the second. What is on the other side of the door is the
## door's placer's business; this node only decides when the door may be used.
##
## **It never emits `Bus.boss_engaged` itself either.** `BossDb`'s executor
## contract §8 puts that emit on the boss, on the first frame of the fight, and
## `Music` is already listening. Two emitters would be two crossfades.
##
## **The one flag lives on the door**, not here. `BossDoor.dead_flag()` names it
## and `BossDoor.unlocked()` reads it, and this node asks the door rather than
## keeping a second copy of the same fact -- a flag that two nodes both write is
## a floor that comes back half-cleared.
##
## ## The seal is a fence, and that is a greybox decision
##
## "The room seals" would ideally bar the room's own doorways, but a generated
## floor hands this node a circle (`BossDb`'s `arena.radius`) and not a list of
## doors. So the seal is a polygonal fence on that circle: it works in any room,
## it is visible, it is one static body, and it says exactly what the arena is.
## When `Dungeon` places these for real it can hand over a room instead; the
## radius is already the thing the table authored.

## Which fight this is. A key into `BossDb.BOSSES`.
@export var boss_id: StringName = &"cistern_warden"
## The `BossDoor` this arena opens. Optional -- an arena with no door is a valid
## test fixture, it simply has nothing to unlock.
@export var door_path: NodePath
## Where the boss stands, relative to this node. Across the room from the way in,
## so it is a silhouette in the far half of the frame when the door shuts.
@export var boss_offset: Vector3 = Vector3(0.0, 0.0, -4.5)

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

var _row: Dictionary = {}
var _boss: CharacterBody3D = null
var _door: Node = null
var _seal: Node3D = null
var _sealed: bool = false
var _spent: bool = false


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
	_build_seal()
	_build_cover()

	_door = get_node_or_null(door_path)
	# Asked of the door, which owns the flag. An arena with no door falls back to
	# the flag's own name so a fixture without one still remembers a kill.
	if _already_dead():
		_spent = true
		_replace_lost_relic()
		return
	_build_boss()
	body_entered.connect(_on_body_entered)


func _already_dead() -> bool:
	if _door != null and _door.has_method(&"unlocked"):
		return bool(_door.call(&"unlocked"))
	return Game.flag(StringName("boss_dead_%s" % boss_id))


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
	RelicPickup.place_anchor(self, Run.level, &"boss",
		global_position + Vector3.UP * 1.0)


# --- Reading the row ----------------------------------------------------------

func radius() -> float:
	var arena: Dictionary = _row.get("arena", {})
	return float(arena.get("radius", 11.0))


func boss() -> CharacterBody3D:
	return _boss


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


## One static body carrying the whole fence, parked a fence-height below the
## floor. Raised by moving the NODE rather than by toggling shapes: a disabled
## shape is one bug away from an invisible wall in an arena you have cleared,
## which is the same reason `LockedDoor` frees its blocker instead of disabling it.
func _build_seal() -> void:
	_seal = Node3D.new()
	_seal.name = "Seal"
	_seal.position = Vector3(0.0, -SEAL_HEIGHT - 0.4, 0.0)
	add_child(_seal)

	var body := StaticBody3D.new()
	body.name = "SealBody"
	body.collision_layer = K.L_WORLD
	body.collision_mask = 0
	_seal.add_child(body)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.19, 0.22)
	mat.roughness = 0.95
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	var r := radius()
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
		_seal.add_child(mi)


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
	_move_seal(0.0)
	Bus.request_sfx.emit(&"door_close", global_position)
	# The boss emits `Bus.boss_engaged` from in here -- contract §8, and `Music`
	# is the thing listening.
	if _boss.has_method(&"wake"):
		_boss.call(&"wake")


func _on_boss_died(_where: Vector3) -> void:
	_spent = true
	_sealed = false
	_move_seal(-SEAL_HEIGHT - 0.4)
	if _door != null and is_instance_valid(_door) and _door.has_method(&"unseal"):
		_door.call(&"unseal")


func _move_seal(to_y: float) -> void:
	if _seal == null:
		return
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_seal, ^"position:y", to_y, SEAL_RISE)
