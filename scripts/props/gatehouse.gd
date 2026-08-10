class_name Gatehouse
extends Node3D
## The way down, built as a building.
##
## What it replaced: two 0.55 m posts, a lintel, and a flat cyan quad hung
## between them against the north curtain. From the arrival camera it read as a
## teal poster taped to a wall, and every other frame in the game that involved
## it read the same way, because there was nothing to it -- no thickness, no
## inside, nothing between you and the far side. The single most important door
## in the build was the only piece of architecture in it with no volume.
##
## The fix is depth, in the literal sense: you can see INTO this one. The arch is
## a face on a mass; behind the face is a passage with walls, a vault and a stone
## floor; at the back of the passage a wellhead stands over the shaft with a
## timber headframe across it, and the cold light comes UP out of that. Nothing
## cyan is in the plane of the arch any more, which is the whole change -- the eye
## lands on a hole in the floor of a building rather than on a rectangle of paint.
##
## ```
##          [tower]   crenellated face   [tower]
##             |    ___________________     |
##             |   /                   \    |         y = 9.0 at the merlons
##             |  |   ###  portcullis   |   |
##             |  |    [==headframe==]  |   |         arch springs at 3.2,
##   ==========|  |    | wellhead    |  |   |=======   apex at 5.2
##             |  |____|__(shaft)____|__|   |         curtain wall, 6.0
## ```
##
## **It straddles the curtain wall, and `Garrison` leaves it a hole to straddle.**
## The north wall is built as two runs with `FACE_W` of clear air between them
## (`Garrison._build_yard`), so the gatehouse is *in* the defences rather than
## parked against them. That is what makes it read as the way out of the fort and
## not as a monument standing near a wall.
##
## Geometry only. The prompt, the hold-to-descend, the sign and the cyan mouth's
## light all still belong to `Npc` (role `GATE`), which instances one of these and
## places its own things at the constants below.

## Clear width and height of the opening. The hero is 1.65 m and 0.32 m at the
## shoulder; this is a gate for carts and columns, not for one man, and the
## difference between those two numbers is most of what makes it read as big.
const OPENING_W := 4.0
## Where the semicircle starts. Below this the jambs are vertical.
const SPRING_Y := 3.2

## Width of the face between the two towers. Also the width of the hole
## `Garrison` leaves in the north curtain.
const FACE_W := 8.0
const FACE_H := 7.6
## How far the face stands proud of the wall line, each way. The mass is 1.6 m
## thick at the front, which is what casts the shadow into the arch.
const FACE_T := 0.8

## Depth of the passage BEHIND the face, before the steps begin.
const PASSAGE_D := 3.4

## The shaft at the back of the passage: clear width, clear depth, and where its
## centre sits. `Npc` lays the cold mouth FLAT across this -- see `MOUTH_PITCH`.
const WELL_W := OPENING_W - 0.6
const WELL_D := 1.9
## Where `Npc` hangs the cold mouth: over the shaft, at ankle height, LYING DOWN.
## The old gate hung the same quad vertically in the plane of the arch, which is
## most of why it photographed as a poster; a light you look DOWN into cannot be
## mistaken for a painted wall.
const MOUTH_Z := -(FACE_T + PASSAGE_D - 0.55)
const MOUTH_SIZE := Vector2(WELL_W - 0.12, WELL_D - 0.12)
const MOUTH_Y := 0.09
## Quads face +Z; this turns one to face straight up.
const MOUTH_PITCH := -PI * 0.5

## Where the name plate goes -- on the band above the arch, under the merlons.
const PLATE_Y := 6.4

## Total height to the top of a tower's merlons. The curtain is 6.0 and its
## corner pillars 7.9 (`Garrison._build_yard`), so this is the tallest thing in
## the garrison by a clear metre. It should be: it is the only building in the
## game with somewhere on the other side of it.
const TOWER_H := 9.0
const TOWER_W := 3.0

const MAT_WALL_SUNLIT := preload("res://assets/materials/mat_wall_sunlit.tres")

var _stone: StandardMaterial3D
var _dark: StandardMaterial3D
var _iron: StandardMaterial3D
var _braziers: Array[Dictionary] = []
var _age: float = 0.0


func _ready() -> void:
	_make_materials()
	_build_towers()
	_build_face()
	_build_passage()
	_build_portcullis()
	_build_braziers()
	_build_collision()


func _process(delta: float) -> void:
	_age += delta
	# Same two-wave breath the booth fires use, for the same reason: a regular
	# pulse reads as a machine. Different phases per brazier so the pair never
	# beats together.
	for b in _braziers:
		var l: OmniLight3D = b["light"]
		var ph: float = b["phase"]
		var beat := sin(_age * 2.3 + ph) * 0.14 + sin(_age * 5.9 + ph * 1.6) * 0.07
		l.light_energy = float(b["energy"]) * (1.0 + beat)


# --- Materials --------------------------------------------------------------

func _make_materials() -> void:
	# The gatehouse is the same masonry as the curtain it stands in, at the same
	# daylight albedo. It is a different SHAPE, not a different stone; giving it
	# its own rock would have made it look imported.
	_stone = MAT_WALL_SUNLIT.duplicate() as StandardMaterial3D

	# The inside of the arch, and everything the sun does not reach. Two thirds of
	# the albedo, which is roughly what the curtain's own shadowed face measures
	# -- the passage should look like the same wall seen from inside the shade,
	# because that is what it is.
	_dark = MAT_WALL_SUNLIT.duplicate() as StandardMaterial3D
	_dark.albedo_color = MAT_WALL_SUNLIT.albedo_color * Color(0.34, 0.34, 0.36)

	_iron = StandardMaterial3D.new()
	_iron.albedo_color = Color(0.14, 0.13, 0.15)
	_iron.roughness = 0.8
	_iron.specular_mode = BaseMaterial3D.SPECULAR_DISABLED


func _block(size: Vector3, at: Vector3, mat: StandardMaterial3D,
		yaw: float = 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = mat
	m.position = at
	m.rotation.y = yaw
	add_child(m)
	return m


# --- Construction -----------------------------------------------------------

## The two towers, which are what give the thing a skyline.
##
## They are square and they overhang: a plain box either side would have been
## taller masonry and nothing else. The corbel course near the top -- one block
## wider than the shaft, standing 0.3 m proud all the way round -- is the single
## detail that makes a tower stop looking like a chimney, because it puts a hard
## horizontal shadow under the parapet at the exact height the eye is drawn to.
func _build_towers() -> void:
	var off := OPENING_W * 0.5 + (FACE_W - OPENING_W) * 0.5 + TOWER_W * 0.5 - 0.6
	for sx: float in [-1.0, 1.0]:
		var x := off * sx
		# Battered base: a wider skirt on the bottom two metres, which is how a
		# real tower stands up and how this one stops looking like it was dropped.
		_block(Vector3(TOWER_W + 0.7, 1.6, TOWER_W + 0.7), Vector3(x, 0.8, 0.0), _stone)
		_block(Vector3(TOWER_W, TOWER_H - 2.6, TOWER_W), Vector3(x, (TOWER_H - 2.6) * 0.5 + 1.4, 0.0), _stone)
		# The corbel, and the parapet floor above it.
		_block(Vector3(TOWER_W + 0.6, 0.45, TOWER_W + 0.6),
			Vector3(x, TOWER_H - 1.05, 0.0), _stone)
		_crenellate(Vector3(x, TOWER_H - 0.82, 0.0), TOWER_W + 0.6, TOWER_W + 0.6)
		# An arrow slit facing the yard, high up. One dark 1.2 m sliver is enough
		# to say the tower is hollow and that somebody is in it.
		_block(Vector3(0.22, 1.2, 0.15), Vector3(x, TOWER_H - 3.4, TOWER_W * 0.5 + 0.02), _dark)


## The wall between the towers, with a hole cut in it.
##
## The hole is cut by building AROUND it rather than by subtracting: two jambs,
## an arch of voussoirs, and a spandrel block over the top. That costs a dozen
## boxes and buys the one thing a CSG subtraction would not have given -- the
## arch is made of visible separate stones, radiating, which is the detail that
## says "arch" from across the yard at a resolution where nothing else survives.
func _build_face() -> void:
	var jamb_w := (FACE_W - OPENING_W) * 0.5
	for sx: float in [-1.0, 1.0]:
		_block(Vector3(jamb_w, FACE_H, FACE_T * 2.0),
			Vector3((OPENING_W * 0.5 + jamb_w * 0.5) * sx, FACE_H * 0.5, 0.0), _stone)

	var r := OPENING_W * 0.5
	var apex := SPRING_Y + r
	# The voussoirs. Eleven wedges over a half-circle; each one is a box turned to
	# the tangent, long enough that the inner ends meet and the outer ends open
	# into the wedge gaps a real arch has.
	var n := 11
	for i in n:
		var a := PI * (float(i) + 0.5) / float(n)
		var m := _block(Vector3(0.62, 1.05, FACE_T * 2.0),
			Vector3(-cos(a) * (r + 0.5), SPRING_Y + sin(a) * (r + 0.5), 0.0), _stone)
		# Rotation about Z, not Y: these lean round the arch in the XY plane.
		m.rotation = Vector3(0.0, 0.0, a - PI * 0.5)

	# The spandrel -- the wall above the arch, up to the band the sign hangs on.
	var top := apex + 1.0
	_block(Vector3(FACE_W, FACE_H - top, FACE_T * 2.0),
		Vector3(0.0, (FACE_H + top) * 0.5, 0.0), _stone)
	# A string course under the sign, standing proud. Same job as the tower's
	# corbel: one horizontal shadow across a big flat face.
	_block(Vector3(FACE_W + 0.3, 0.35, FACE_T * 2.0 + 0.35),
		Vector3(0.0, PLATE_Y - 0.55, 0.0), _stone)
	_crenellate(Vector3(0.0, FACE_H + 0.18, 0.0), FACE_W, FACE_T * 2.0)


## Merlons round the top of a rectangle. The gaps are the point -- a solid
## parapet is a box lid, and a broken skyline is a fortification.
func _crenellate(at: Vector3, w: float, d: float) -> void:
	var step := 0.85
	var count := int(w / step)
	if count < 2:
		return
	var first := -w * 0.5 + (w - float(count - 1) * step) * 0.5
	for i in count:
		if i % 2 == 1:
			continue
		_block(Vector3(0.58, 0.85, d), at + Vector3(first + float(i) * step, 0.42, 0.0), _stone)
	# A square tower gets the same treatment down its two sides, so it reads
	# crenellated from three-quarters and not only head-on. The face between the
	# towers is a long thin slab and skips this -- it has no sides worth seeing.
	if absf(d - w) > 0.01:
		return
	var side := int(d / step)
	if side < 2:
		return
	var first_z := -d * 0.5 + (d - float(side - 1) * step) * 0.5
	for i in side:
		if i % 2 == 1:
			continue
		var z := first_z + float(i) * step
		for sx: float in [-1.0, 1.0]:
			_block(Vector3(0.58, 0.85, 0.58),
				at + Vector3(w * 0.5 * sx - 0.29 * sx, 0.42, z), _stone)


## The inside: two walls, a vault, a stone floor, and the wellhead at the back
## of it.
##
## **The first cut of this ran a staircase down and it did not exist**, which is
## the sort of thing only a capture tells you. The yard's ground is ONE 300 m
## grass slab (`Garrison._build_yard`) and it does not stop at the gate; every
## step below y = 0 was drawn correctly and then buried under a field. What the
## frame showed was a handsome arch with a lawn running through it and a teal
## panel hung at the far end -- the exact failure the gatehouse was built to fix,
## reproduced at three times the polygon count.
##
## So the way down is a WELLHEAD, which needs no hole in anything: a stone coping
## ring standing 0.85 m proud of the floor with darkness inside it. It is also the
## more honest object. This is the mouth of a mine and a mine has a headframe over
## it, not a grand staircase -- and the two rails out on the approach
## (`Garrison._build_yard`) have been saying "there is a hole here" since long
## before there was anything to fall down.
##
## The near coping is cut to 0.5 so you can see over it from the passage. Standing
## at the threshold you look down at cold light coming up out of the floor, which
## is the read the flat quad never had: it is UNDER you, and you have to step into
## it.
func _build_passage() -> void:
	var half := OPENING_W * 0.5
	var back := MOUTH_Z
	for sx: float in [-1.0, 1.0]:
		_block(Vector3(0.9, SPRING_Y + 2.4, PASSAGE_D),
			Vector3((half + 0.45) * sx, (SPRING_Y + 2.4) * 0.5, -FACE_T - PASSAGE_D * 0.5), _dark)
	# The vault, flat and low. A real barrel would be twenty more boxes for a
	# curve nobody standing in a doorway ever sees the top of.
	_block(Vector3(OPENING_W + 1.8, 0.7, PASSAGE_D + FACE_T * 2.0),
		Vector3(0.0, SPRING_Y + 1.05, -PASSAGE_D * 0.5), _dark)

	# The floor: dark flagstone laid over the grass, 4 cm proud. Cheap, and it is
	# the single change that stopped the gate reading as a hole in a hedge -- a
	# threshold is a change of ground underfoot before it is anything else.
	_block(Vector3(OPENING_W + 1.8, 0.08, PASSAGE_D + FACE_T * 2.0 + 0.6),
		Vector3(0.0, 0.02, -PASSAGE_D * 0.5 + 0.3), _dark)
	# And the back wall the well is sunk against.
	_block(Vector3(OPENING_W + 1.8, 6.0, 0.7), Vector3(0.0, 3.0, back - WELL_D * 0.5 - 0.35), _dark)

	# The coping. Four runs round a rectangle, the near one half height.
	var wz := back
	var ox := WELL_W * 0.5
	var oz := WELL_D * 0.5
	_block(Vector3(WELL_W + 0.7, 0.85, 0.35), Vector3(0.0, 0.42, wz - oz - 0.17), _stone)
	_block(Vector3(WELL_W + 0.7, 0.50, 0.35), Vector3(0.0, 0.25, wz + oz + 0.17), _stone)
	for sx: float in [-1.0, 1.0]:
		_block(Vector3(0.35, 0.85, WELL_D), Vector3((ox + 0.17) * sx, 0.42, wz), _stone)

	# What is inside it: nothing, painted black, so the cyan plate `Npc` lays on
	# top has something to be a hole in. Unshaded, because a lit surface at the
	# bottom of a shaft is a lie the sun has no business telling.
	var void_mat := StandardMaterial3D.new()
	void_mat.albedo_color = Color(0.02, 0.03, 0.04)
	void_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_block(Vector3(WELL_W, 0.06, WELL_D), Vector3(0.0, 0.03, wz), void_mat)

	# A second, standing plate of the same cold light at the back of the shaft.
	#
	# **This is signposting, and it is here because the capture said the gate had
	# stopped doing any.** Laying the mouth flat fixed the poster problem and cost
	# the thing the poster was good at: from the arrival camera -- eighteen metres
	# back and only a metre and a half up -- a horizontal quad is edge-on and there
	# was NO cyan anywhere in the frame. The one cold thing in a warm courtyard had
	# become invisible from the one place every returning player stands.
	#
	# Standing it up inside the well gets both: from across the yard you see a
	# sliver of cold light in the dark of the arch, and from the threshold you are
	# looking down into a lit hole. Dimmer than the mouth, and set back behind the
	# coping, so it reads as the shaft's far wall catching the glow rather than as
	# a second door.
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(Pal.CYAN, 0.5)
	glow.emission_enabled = true
	glow.emission = Pal.CYAN
	glow.emission_energy_multiplier = 0.42
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_block(Vector3(WELL_W - 0.1, 1.05, 0.06), Vector3(0.0, 0.50, wz - oz + 0.06), glow)

	# The headframe: two legs and a beam over the shaft, with the winding rope
	# hanging down it. Timber rather than stone, and the only wood on the whole
	# building -- which is what makes it read as MACHINERY sitting on the
	# architecture instead of more of the same masonry.
	var timber := StandardMaterial3D.new()
	timber.albedo_color = Color(0.30, 0.22, 0.15)
	timber.roughness = 0.95
	timber.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	for sx: float in [-1.0, 1.0]:
		_block(Vector3(0.24, 2.6, 0.24), Vector3((ox + 0.30) * sx, 1.3, wz), timber)
	_block(Vector3(WELL_W + 1.0, 0.26, 0.30), Vector3(0.0, 2.72, wz), timber)
	_block(Vector3(0.10, 2.0, 0.10), Vector3(0.0, 1.6, wz), timber)


## The portcullis, raised.
##
## Raised and not lowered, because a closed grate would say the way down is shut
## and the way down is the entire loop. What it is doing up there is telling you
## the gate CAN close -- which is a sentence about the garrison rather than about
## the dungeon, and the cheapest way this build has of saying that the hole in
## the ground is something the four people here are frightened of.
func _build_portcullis() -> void:
	var w := OPENING_W - 0.3
	var y := SPRING_Y + 1.55
	var bars := 7
	for i in bars:
		var x := -w * 0.5 + w * float(i) / float(bars - 1)
		_block(Vector3(0.10, 1.5, 0.10), Vector3(x, y, -FACE_T + 0.15), _iron)
	for j in 2:
		_block(Vector3(w + 0.2, 0.12, 0.12),
			Vector3(0.0, y - 0.65 + 1.3 * float(j), -FACE_T + 0.15), _iron)
	# The teeth on the bottom rail, which is the one detail that makes a grid of
	# bars read as a portcullis and not as a window.
	for i in bars:
		var x := -w * 0.5 + w * float(i) / float(bars - 1)
		_block(Vector3(0.10, 0.26, 0.10), Vector3(x, y - 0.84, -FACE_T + 0.15), _iron)


## A fire on each jamb, out at the corners of the face.
##
## Warm light three metres either side of the one cold thing in the game is a
## deliberate risk (STYLEGUIDE §2 gives the gate cyan and means it), and it is
## taken because the mouth is now 4.2 m back down a passage: the amber never
## reaches it, and having it on the OUTSIDE is what makes the passage read as
## darker than the yard rather than as merely unlit. A gate you approach between
## two fires and step into shadow is a threshold. Move these into the arch and
## the whole effect inverts.
func _build_braziers() -> void:
	var bowl := StandardMaterial3D.new()
	bowl.albedo_color = Color(1.0, 0.44, 0.16)
	bowl.emission_enabled = true
	bowl.emission = Color(1.0, 0.44, 0.16)
	bowl.emission_energy_multiplier = 2.6
	bowl.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for sx: float in [-1.0, 1.0]:
		var x := (FACE_W * 0.5 - 0.55) * sx
		var z := FACE_T + 0.9
		_block(Vector3(0.42, 1.05, 0.42), Vector3(x, 0.52, z), _iron)
		_block(Vector3(0.86, 0.30, 0.86), Vector3(x, 1.18, z), _iron)

		var coals := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.30
		cm.bottom_radius = 0.24
		cm.height = 0.10
		cm.radial_segments = 10
		coals.mesh = cm
		coals.material_override = bowl
		coals.position = Vector3(x, 1.34, z)
		add_child(coals)

		var l := OmniLight3D.new()
		l.light_color = KitStyle.FIRE_COLOR
		l.light_energy = 4.0
		l.omni_range = 8.5
		l.omni_attenuation = 1.35
		l.shadow_enabled = false
		l.position = Vector3(x, 1.7, z)
		add_child(l)
		_braziers.append({"light": l, "energy": 4.0, "phase": 2.1 * sx + 1.0})


## Solid everywhere except the way through.
##
## Two jamb boxes and two towers, and nothing across the opening or the passage:
## the player has to be able to walk into the arch, because that is where the
## `Npc` trigger is and because standing under it is the moment the gate is
## supposed to feel like a gate. The steps are decoration -- the hero keeps
## walking on the yard's own floor slab through the whole passage, which is a lie
## the camera never sees and which saves a stair the controller would fight.
func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = K.L_WORLD
	body.collision_mask = 0

	var jamb_w := (FACE_W - OPENING_W) * 0.5
	var boxes := [
		{"size": Vector3(jamb_w, FACE_H, FACE_T * 2.0 + PASSAGE_D),
			"at": Vector3(OPENING_W * 0.5 + jamb_w * 0.5, FACE_H * 0.5, -PASSAGE_D * 0.5)},
		{"size": Vector3(jamb_w, FACE_H, FACE_T * 2.0 + PASSAGE_D),
			"at": Vector3(-(OPENING_W * 0.5 + jamb_w * 0.5), FACE_H * 0.5, -PASSAGE_D * 0.5)},
	]
	var off := OPENING_W * 0.5 + jamb_w + TOWER_W * 0.5 - 0.6
	for sx: float in [-1.0, 1.0]:
		boxes.append({"size": Vector3(TOWER_W + 0.7, TOWER_H, TOWER_W + 0.7),
			"at": Vector3(off * sx, TOWER_H * 0.5, 0.0)})

	for b in boxes:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = b["size"]
		cs.shape = shape
		cs.position = b["at"]
		body.add_child(cs)
	add_child(body)
