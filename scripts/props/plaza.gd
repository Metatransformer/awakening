class_name Plaza
extends Node3D
## The paved circle in the middle of the garrison, and the reason the yard has a
## middle at all.
##
## Before this the five counters stood where each one's own tuning put them --
## two against the north wall, one against the west, one loose on the east -- and
## every argument for every position was sound on its own terms. What the set of
## them added up to was a field with furniture round the edges. Nothing in the
## yard said *here*; the hero landed on grass, faced grass, and had to be told by
## a floating word where anything was.
##
## A circle fixes that with geometry rather than with signage. Paving reads as
## "people stand here" at any distance and from any angle, a rim gives the eye a
## line to follow round to the next stall, and a centre gives the composition
## somewhere to put the one figure that should be looked at first.
##
## **It is flush with the grass, and that is a rule and not a shortcut.** The
## first cut raised the disc 0.2 m with a kerb round it, which looked right in a
## still and turned the whole middle of the hub into a lip the hero snagged on
## from every direction. The garrison is eight seconds wide (see `Garrison`) and
## has no room to spend on collision the player discovers by getting stuck in it.
## So: the paving sits 3 cm proud, the kerb blocks are DECORATION WITH NO
## COLLIDER, and you can walk onto the plaza from any bearing without the
## controller noticing.
##
## Read as rings, outside in: kerb, outer paving, inner paving, and the roundel
## the statue and the Lanternkeeper stand on. Each ring is a shade apart -- the
## same trick the kit's masonry uses, where the shape carries and the value does
## the separating.

const MAT_STONE := preload("res://assets/materials/mat_flagstone_sunlit.tres")

## Where the paving stops. Everything in `Garrison` that rings the plaza is
## placed off this, so widening the circle moves the shops with it.
@export var radius: float = 5.8:
	set(v):
		radius = v
		_rebuild()

## Bearings, in degrees clockwise from north, where the kerb opens. Four ways in:
## north to the gate, south to the arrival, east and west to the flanking stalls.
## A ring with no gaps reads as a wall you have to find the end of.
@export var openings: PackedFloat32Array = PackedFloat32Array([0.0, 90.0, 180.0, 270.0])

## Half-width of an opening, in degrees. 13 is a shade over three metres of clear
## kerb at the default radius -- a gateway, not a chipped tooth.
const OPENING_HALF := 13.0

## Faceted on purpose. Everything else in this build is N64-era silhouette
## (`ShopBooth`'s coal disc uses 10), and a 64-segment circle is the one thing in
## the yard that would look smooth.
const SEGMENTS := 32


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		c.queue_free()

	# Three discs, each a little smaller, a little higher and a little different
	# in value. Stacking them is what makes the paving read as laid rings rather
	# than as one grey plate: the eye catches the two value steps as joints.
	#
	# The heights are 3, 4 and 5 cm. Nothing here is walked ON in the physics
	# sense (the hero stands on the grass slab underneath, and these have no
	# colliders), so the numbers only have to be big enough to beat z-fighting
	# and small enough that the paving never casts a step-shaped shadow.
	_disc(radius, 0.03, Color(0.86, 0.84, 0.80))
	_disc(radius * 0.66, 0.04, Color(0.98, 0.96, 0.92))
	_disc(radius * 0.30, 0.05, Color(0.74, 0.72, 0.70))

	_kerb()


func _disc(r: float, y: float, tint: Color) -> void:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	# Thin, but not a plane: the rim of the outer disc is the only place the
	# paving has an edge you can see from ground level, and a zero-height disc
	# would have none.
	cm.height = 0.18
	cm.radial_segments = SEGMENTS
	m.mesh = cm
	var mat := MAT_STONE.duplicate() as StandardMaterial3D
	mat.albedo_color = MAT_STONE.albedo_color * tint
	m.material_override = mat
	# The mesh is centred, so the top face lands at `y`.
	m.position.y = y - 0.09
	add_child(m)


## The rim: a ring of set stones, gapped at the four ways in.
##
## **No collider on any of them** -- see the note at the top of the file. They
## are 0.26 m of stone standing on grass, which is exactly the height at which a
## CharacterBody3D either climbs or catches depending on its approach angle, and
## a hub the player circles all day is the worst place in the game to find out
## which.
func _kerb() -> void:
	var mat := MAT_STONE.duplicate() as StandardMaterial3D
	mat.albedo_color = MAT_STONE.albedo_color * Color(0.66, 0.64, 0.62)
	var n := 36
	var rng := RandomNumberGenerator.new()
	rng.seed = 8801
	for i in n:
		var deg := float(i) * 360.0 / float(n)
		if _in_opening(deg):
			continue
		var a := deg_to_rad(deg)
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		# Jittered, like every other run of masonry here -- an even ring of
		# identical blocks reads as a moulded plastic kerb.
		bm.size = Vector3(0.9 * rng.randf_range(0.86, 1.06), 0.26,
			0.34 * rng.randf_range(0.9, 1.15))
		m.mesh = bm
		m.material_override = mat
		var r := radius + 0.22
		m.position = Vector3(sin(a) * r, 0.10, cos(a) * r)
		m.rotation.y = a + deg_to_rad(rng.randf_range(-2.5, 2.5))
		add_child(m)


func _in_opening(deg: float) -> bool:
	for o in openings:
		var d := absf(wrapf(deg - o, -180.0, 180.0))
		if d <= OPENING_HALF:
			return true
	return false
