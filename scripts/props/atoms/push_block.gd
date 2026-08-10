class_name PushBlock
extends PuzzleAtom
## Atom 4 of 8 (`docs/PUZZLES.md` §2): the push block. T0 -- your shoulder.
##
## The block is the answer to the plate you cannot stand on and reach the door
## from. That pair -- plate plus block -- is §3's first combinator and the oldest
## nest in the genre, and it only works because `PressurePlate` does NOT latch:
## a plate that stayed pressed would make the block ornamental.
##
## ## What "solved" means here
##
## **Seated on its mark**, not "moved". A block that solved on the first shove
## would be a block with one correct answer and no wrong ones. `mark_offset` is
## where it belongs, in metres from where it was placed, and the chalked square
## on the floor is that same vector drawn -- so the puzzle is legible from the
## doorway without a word of text.
##
## A placer that wants the block as *pure weight* for a plate -- no mark, no
## solve of its own -- sets `armed = false` (`PuzzleAtom`). A gate must then not
## watch it: the plate is the gating atom in that nest, and the block is furniture
## the player moves onto it.
##
## ## The shove
##
## It reads `Hero.wish_dir()`, not the hero's velocity. A `CharacterBody3D` that
## has run into a wall has had its velocity flattened against that wall by
## `move_and_slide` -- so a block that watched velocity would be a block that
## stops registering the push at the exact instant the player starts pushing.
## `wish_dir()` is the stick, and the stick keeps pointing at the block.
##
## It does not read input itself for the reason `CLAUDE.md` §3 records: input in
## this project is polled by the hero and nothing else, and a prop with its own
## `_unhandled_input` is a prop that fights the pause menu.

## Metres per shove. One block-width plus a finger, so a row of them reads as a
## grid rather than as a smear.
const STEP := 1.2
const SIZE := 1.1
const SLIDE_TIME := 0.38
## Seconds of leaning before it gives. Long enough that brushing past does not
## move it, short enough that it never feels ignored.
const PUSH_DELAY := 0.30
## How square the push has to be. cos(40 deg) -- a diagonal lean picks the nearer
## axis rather than refusing, because a block that needs a perfect cardinal stick
## is a block the analogue stick cannot reliably move.
const PUSH_DOT := 0.76
## How close to the mark counts as seated. Generous against float drift over
## several slides; tight enough that the neighbouring cell does not qualify.
const SEAT_TOL := STEP * 0.45

## Where it belongs, in metres from where it was placed. The floor decal is this
## vector drawn. Zero means "no mark" -- see the class note on `armed`.
@export var mark_offset: Vector3 = Vector3(0.0, 0.0, STEP * 2.0)

var _body: AnimatableBody3D
var _probe: Area3D
var _decal: Node3D
var _decal_mat: StandardMaterial3D
var _pusher: Node3D
var _lean: float = 0.0
var _sliding: bool = false
var _home: Vector3 = Vector3.ZERO


func _ready() -> void:
	if atom_id == &"":
		atom_id = PuzzleAtoms.PUSH_BLOCK
	_build()
	super()


# --- The shove ----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _sliding or is_solved() or not armed:
		return
	if _pusher == null or not is_instance_valid(_pusher):
		_lean = 0.0
		return
	var wish := Vector3.ZERO
	if _pusher.has_method(&"wish_dir"):
		wish = _pusher.wish_dir()
	wish.y = 0.0
	if wish.length_squared() < 0.25:
		_lean = 0.0
		return
	var into := _body.global_position - _pusher.global_position
	into.y = 0.0
	if into.length_squared() < 0.0001:
		return
	if wish.normalized().dot(into.normalized()) < PUSH_DOT:
		_lean = 0.0
		return
	_lean += delta
	if _lean >= PUSH_DELAY:
		_lean = 0.0
		push_to(_cardinal(into))


## Snap a heading to the nearer world axis. The grid is what makes a block puzzle
## readable -- a block that could be nudged 30 degrees would be a block the player
## can wedge into a corner they cannot recover it from, and this game has no
## reset-the-room button.
func _cardinal(v: Vector3) -> Vector3:
	if absf(v.x) >= absf(v.z):
		return Vector3(signf(v.x), 0.0, 0.0)
	return Vector3(0.0, 0.0, signf(v.z))


## One step, if the next cell is clear. Public so a director can shove it without
## standing a hero next to it -- proving the SEATING separately from the sensing
## is the whole reason the two halves are separate functions.
func push_to(dir: Vector3) -> bool:
	if _sliding or is_solved() or not armed or dir == Vector3.ZERO:
		return false
	var from := _body.global_position
	var to := from + dir * STEP
	if not _clear(from, to):
		Bus.request_sfx.emit(&"craft_fail", from)
		return false
	_sliding = true
	Bus.request_sfx.emit(&"craft_grind", from)
	var tw := create_tween()
	# Linear, deliberately. Stone dragged over stone does not ease -- an eased
	# slide reads as a thing floating, which is exactly the note
	# `docs/STYLEGUIDE.md` makes about weight.
	tw.tween_property(_body, "global_position", to, SLIDE_TIME)
	tw.tween_callback(_settled)
	return true


## Is the next cell free? A ray at knee height along the travel, masked to the
## world layer and excluding the block's own body.
##
## Knee height and not the centre: the centre of a 1.1 m block is above the
## `PressurePlate` rim it is allowed to slide onto, and a centre ray would happily
## walk it through a wall whose lower course was the only thing modelled.
func _clear(from: Vector3, to: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		from + Vector3.UP * 0.35, to + Vector3.UP * 0.35)
	q.collision_mask = K.L_WORLD
	q.exclude = [_body.get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return true
	# A pressure plate's rim is world geometry and the block is MEANT to end up on
	# it -- refusing there would break the one combinator this atom exists for.
	# The group, not the class: the block does not need to know what a plate is,
	# and a class reference here would be one more thing to keep in step.
	var col := hit.get("collider") as Node
	return col != null and col.is_in_group(&"plate_rim")


func _settled() -> void:
	_sliding = false
	if mark_offset == Vector3.ZERO:
		return
	if _body.global_position.distance_to(_mark_world()) <= SEAT_TOL:
		# Snapped, not merely near. Several shoves of float error would otherwise
		# leave it visibly off a decal drawn at the exact spot.
		_body.global_position = _mark_world()
		solve()


func _mark_world() -> Vector3:
	return _home + mark_offset


func _on_entered(b: Node3D) -> void:
	if b.is_in_group(&"player"):
		_pusher = b


func _on_exited(b: Node3D) -> void:
	if b == _pusher:
		_pusher = null
		_lean = 0.0


# --- Seated -------------------------------------------------------------------

func on_solved() -> void:
	Bus.request_sfx.emit(&"craft_clang", _body.global_position)
	var tw := create_tween().set_parallel(true)
	# It drops into the socket. Four centimetres is nothing to look at and
	# everything to feel -- the same trick the plate's cap uses.
	tw.tween_property(_body, "position:y", _body.position.y - 0.04, 0.16)
	if _decal_mat != null:
		tw.tween_property(_decal_mat, "emission", Pal.MOSS, 0.22)
		tw.tween_property(_decal_mat, "emission_energy_multiplier", 2.0, 0.22)


func restore_solved() -> void:
	_body.position = mark_offset - Vector3(0.0, 0.04, 0.0)
	if _decal_mat != null:
		_decal_mat.emission = Pal.MOSS
		_decal_mat.emission_energy_multiplier = 2.0


# --- Construction -------------------------------------------------------------

func _build() -> void:
	_home = global_position

	# `AnimatableBody3D`, not `StaticBody3D`. A code-moved StaticBody does not
	# reliably push a `CharacterBody3D` out of its way, and the one thing a player
	# will certainly do is stand in the cell the block is sliding into.
	_body = AnimatableBody3D.new()
	_body.name = "Block"
	_body.collision_layer = K.L_WORLD
	_body.collision_mask = 0
	_body.sync_to_physics = true
	# The plate reads this group, not the class -- see `PressurePlate._bearing`.
	_body.add_to_group(&"plate_weight")
	add_child(_body)

	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(SIZE, SIZE, SIZE)
	cs.shape = bx
	cs.position.y = SIZE * 0.5
	_body.add_child(cs)

	var stone := _mat(Color(0.33, 0.33, 0.36), 0.96, 0.0)
	var band := _mat(Color(0.26, 0.26, 0.30), 0.94, 0.0)
	_box(_body, stone, Vector3(SIZE, SIZE, SIZE), Vector3(0.0, SIZE * 0.5, 0.0))
	# A chamfered course top and bottom. Two boxes and the cube stops being a
	# programmer cube -- the same cheap trick `kit_doorway.gd` uses on its jambs.
	_box(_body, band, Vector3(SIZE * 1.06, 0.09, SIZE * 1.06), Vector3(0.0, 0.07, 0.0))
	_box(_body, band, Vector3(SIZE * 1.06, 0.09, SIZE * 1.06),
		Vector3(0.0, SIZE - 0.07, 0.0))
	# A shallow dish on each face, so the shove has somewhere to land visually and
	# the block reads as a thing meant to be handled.
	for i in 4:
		var a := TAU * float(i) / 4.0
		_box(_body, band, Vector3(0.42, 0.42, 0.06),
			Vector3(sin(a) * (SIZE * 0.5 + 0.01), SIZE * 0.52, cos(a) * (SIZE * 0.5 + 0.01)),
			Vector3(0.0, a, 0.0))

	if mark_offset != Vector3.ZERO:
		_build_mark()

	_probe = Area3D.new()
	_probe.name = "Probe"
	_probe.collision_layer = 0
	_probe.collision_mask = K.L_PLAYER
	_probe.monitoring = true
	# On the BODY, so the probe travels with the block. A probe left on the root
	# is a block you can keep shoving from where it used to be.
	_body.add_child(_probe)
	var pcs := CollisionShape3D.new()
	var pb := BoxShape3D.new()
	# A 0.5 m shell. The hero's own capsule stops him ~0.4 m from the face, so a
	# probe the size of the block never sees the player who is pressed against it.
	pb.size = Vector3(SIZE + 1.0, SIZE, SIZE + 1.0)
	pcs.shape = pb
	pcs.position.y = SIZE * 0.5
	_probe.add_child(pcs)
	_probe.body_entered.connect(_on_entered)
	_probe.body_exited.connect(_on_exited)


## The chalked square. Drawn on the ROOT and not the body -- it marks the floor,
## and a decal parented to the block would travel with it and mark nothing.
func _build_mark() -> void:
	_decal = Node3D.new()
	_decal.name = "Mark"
	_decal.position = mark_offset
	add_child(_decal)
	# COBALT until it is filled, MOSS once it is. Same two hues as the plate's
	# channel, because they are the same sentence: cold means not yet.
	_decal_mat = _glow_mat(Pal.COBALT, 0.9)
	var half := SIZE * 0.5 + 0.06
	for i in 4:
		var a := TAU * float(i) / 4.0
		_box(_decal, _decal_mat, Vector3(SIZE * 1.12, 0.02, 0.07),
			Vector3(sin(a) * half, 0.012, cos(a) * half), Vector3(0.0, a, 0.0))
