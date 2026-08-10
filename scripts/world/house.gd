class_name House
extends Node3D
## The hero's quarters — a billet built into the corner of the garrison, with a
## cot in it and a footlocker at the foot of the cot.
##
## ## Why it is a lean-to and not a building
##
## Three separate constraints all point at the same shape, so it is worth
## writing down which ones, because the obvious "put a house in the garrison" is
## wrong for each of them independently:
##
##  1. **`docs/SCOPE.md` §1 freezes garrison scenes at ONE.** A house you walk into
##     through a door is a second scene and a second load; a house you walk into
##     because there is no door is neither. So this is geometry inside
##     `scenes/rooms/garrison.tscn` and nothing else.
##  2. **`Garrison`'s own note calls the yard "deliberately TINY — about eight
##     seconds corner to corner"** and says every extra metre is a tax on the
##     loop. The billet takes a corner nothing else was using and adds no walking
##     to any existing errand: the counters are all north and east, and this is
##     south-west.
##  3. **The camera.** `GameCamera` pitches about five degrees above the hero's
##     eye and swings around obstructions rather than shortening its boom
##     (game_camera.gd §1.6). A four-walled room five metres across is the one
##     case where no yaw is clear and the boom is forced to `hard_min_distance`,
##     which is the corridor-through-a-doorway shot. An open north face means the
##     rig sits out in the yard and looks in, at the distance it prefers.
##
## **Two of its four walls are the curtain**, and that is not a saving — it is
## what a billet is. The west and south sides of this thing are the garrison's
## own ramparts (`Garrison._build_yard` builds them, blocks protruding to about
## 0.17 m proud of the placement plane), so building walls of its own there would
## be a second slab of masonry inside the first. It builds the two sides that
## face the yard and roofs the lot.
##
## Placed by `Garrison._build_house`. It is authored around the CENTRE OF ITS
## FLOOR with the two closed sides on local -X and +Z, which is exactly the
## south-west corner of the yard and no rotation.

const KIT_FLOOR := preload("res://scenes/kit/floor_slab.tscn")
const KIT_WALL := preload("res://scenes/kit/wall_segment.tscn")
const MAT_WALL_SUNLIT := preload("res://assets/materials/mat_wall_sunlit.tres")
const MAT_FLOOR := preload("res://assets/materials/mat_floor.tres")
const MAT_WOOD := preload("res://assets/materials/mat_wood.tres")

## Interior, wall face to wall face. Big enough for a cot along one side and a
## walk past it, and no bigger — see the camera note above.
@export var room: Vector2 = Vector2(5.2, 5.2)
## The roof's high edge, at the closed (+Z) side. It slopes down to `eave_low` at
## the open front, which is the way a lean-to sheds water and, more usefully
## here, the way it stops being a box.
@export var eave_high: float = 3.4
@export var eave_low: float = 2.7

var bed: Bed
var locker: Footlocker


func _ready() -> void:
	_build_room()
	_build_roof()
	_build_furniture()


func _build_room() -> void:
	var hx := room.x * 0.5
	var hz := room.y * 0.5

	# The floor, and it is **NOT SOLID**. `KitSlab`'s top face sits at local
	# y = 0, which is exactly where the yard's grass slab already is, so a solid
	# one here would be a second collider in the same plane and a visible seam
	# fighting the turf. Instead: no collider at all, lifted 4 mm, so the hero
	# goes on standing on the grass he was standing on and the boards are purely
	# what he is looking at. There is no step at the threshold because there is
	# nothing to step onto.
	var deck := KIT_FLOOR.instantiate()
	deck.size = room
	deck.face_material = MAT_FLOOR
	deck.solid = false
	deck.position.y = 0.004
	add_child(deck)

	# The east wall. `KitWall` runs along local X with its finished face down
	# local +Z (kit_wall.gd), so the -90 degree yaw that gives the yard its east
	# curtain gives this one its east wall — same frame, same line of code,
	# different length. A seed of its own so it is not a copy of the curtain
	# behind it; two walls sharing a seed are visibly identical and the eye
	# catches the mirror.
	var east := KIT_WALL.instantiate()
	east.length = room.y
	east.height = eave_high
	east.rng_seed = 611
	east.material = MAT_WALL_SUNLIT
	east.position = Vector3(hx, 0.0, 0.0)
	east.rotation.y = -PI * 0.5
	add_child(east)

	# A short return across the west end of the open front, so the entrance is a
	# gap in a wall rather than a missing wall. It is also what puts the cot in a
	# recess: from the yard you see the foot of the bed and not the whole of it,
	# which is the difference between a room and a display case.
	var jamb := KIT_WALL.instantiate()
	jamb.length = room.x * 0.32
	jamb.height = eave_high
	jamb.rng_seed = 612
	jamb.material = MAT_WALL_SUNLIT
	jamb.position = Vector3(-hx + room.x * 0.16, 0.0, -hz)
	jamb.rotation.y = PI
	add_child(jamb)

	# The post at the open corner. It carries the low end of the roof, and it is
	# the only reason a five-metre span of timber over an open front reads as
	# built rather than as floating.
	var post := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.24, eave_low, 0.24)
	post.mesh = pm
	post.material_override = MAT_WOOD
	post.position = Vector3(hx - 0.3, eave_low * 0.5, -hz + 0.3)
	add_child(post)


## One sloped slab of timber. A gable would need two and a ridge; a lean-to needs
## one, and `docs/STYLEGUIDE.md` §6's tri budget is not the reason — the reason is
## that the slope is what tells you which wall this thing is leaning on.
func _build_roof() -> void:
	var hz := room.y * 0.5
	var fall := eave_high - eave_low
	var run := room.y
	var pitch := atan2(fall, run)

	var roof := MeshInstance3D.new()
	var rm := BoxMesh.new()
	# Overhung on every side. An eave that stops flush with the wall reads as a
	# lid; 0.3 m of overhang is what casts the shadow line that says "roof".
	rm.size = Vector3(room.x + 0.6, 0.18, sqrt(run * run + fall * fall) + 0.6)
	roof.mesh = rm
	roof.material_override = MAT_WOOD
	roof.position = Vector3(0.0, (eave_high + eave_low) * 0.5, 0.0)
	# NEGATIVE. Rx(+t) sends +Z downward (y' = -z sin t), and the high edge is the
	# +Z one — the side leaning on the south curtain. Get this backwards and the
	# roof slopes into the wall it is supposed to be hung off, which reads as
	# nothing in a still and as a mistake the moment the sun moves.
	roof.rotation.x = -pitch
	add_child(roof)

	# **The room is in its own shade, and it needs a light or it is a black
	# rectangle in a daylit yard.** `Garrison._build_env` runs one directional sun at
	# 1.35 and an ambient of 0.55; under a roof that leaves an interior the camera
	# reads as unlit. Warm, and at the garrison's own gold (`GarrisonLight`,
	# `Npc._lamp`) — the whole garrison is lit in one colour and a second hue in
	# the one room that belongs to the player would read as a different building.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.84, 0.62)
	lamp.light_energy = 4.2
	lamp.omni_range = 7.5
	lamp.omni_attenuation = 1.4
	lamp.position = Vector3(0.0, eave_low - 0.35, -hz * 0.15)
	add_child(lamp)

	# Something for the light to be coming out of. Unshaded, for
	# `GarrisonLight`'s reason: a lit shader on a 0.2 m box in a shadow is a
	# grey box, and what this has to be is the brightest thing in the room.
	var lantern := MeshInstance3D.new()
	var lgm := BoxMesh.new()
	lgm.size = Vector3(0.22, 0.28, 0.22)
	lantern.mesh = lgm
	var lit := StandardMaterial3D.new()
	lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lit.albedo_color = Color(1.0, 0.88, 0.66)
	lantern.material_override = lit
	lantern.position = lamp.position
	add_child(lantern)


## The cot on the closed west side, the locker against the east wall, and a clear
## walk between them.
##
## **They are apart on purpose.** `Prompt` arbitrates nearest-wins from the hero
## (prompt.gd), so two interactables within reach of each other is a legal state
## and it is also the state where a player presses the button and gets the other
## one. Four metres of floor between the cot and the locker means the question
## never comes up.
func _build_furniture() -> void:
	var hx := room.x * 0.5

	bed = Bed.new()
	# Head to the south, against the closed end. `Bed` puts its pillow at local
	# -Z, so the half-turn is what points the head at the back wall instead of at
	# the doorway.
	bed.position = Vector3(-hx + 0.62, 0.0, 0.2)
	bed.rotation.y = PI
	add_child(bed)

	locker = Footlocker.new()
	# Back to the east wall, lid opening west into the room. `Footlocker` hinges
	# on its own local -Z edge, and Ry(-90) is what turns that edge into the one
	# facing the masonry — the other quarter-turn opens the lid into the wall.
	locker.position = Vector3(hx - 0.52, 0.0, 0.4)
	locker.rotation.y = -PI * 0.5
	add_child(locker)
