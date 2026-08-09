class_name KitGeo
extends RefCounted
## Low-poly, hard-edged box geometry — the only mesh primitive the dungeon kit uses.
##
## Every kit piece (wall, slab, doorway, pillar, torch) is built out of axis-aligned
## boxes with FLAT normals and no smoothing. That is not laziness, it is the look:
## Ocarina of Time dungeons are chunky rectangular masonry where every silhouette edge
## is a hard 90 degrees, and a bevelled/smoothed mesh reads as 2010s indie, not N64.
##
## Boxes are emitted face-by-face with an explicit face mask so a wall's hidden back
## faces cost nothing, and UVs are planar-projected per face so `generate_tangents()`
## has a basis to work with (the stone shaders drive NORMAL_MAP from world-space
## derivatives, so the tangent frame is all the UVs are actually for).
##
## Winding is CLOCKWISE when viewed from outside the face — Godot's front-face
## convention. Get it backwards and every room renders inside-out.
##
## Kit pieces build their MeshInstance3D / CollisionShape3D children at runtime and
## deliberately DO NOT set `owner` on them. Setting it would make the editor
## serialise a few thousand generated triangles into whatever room scene the piece
## is instanced in, and the whole point of a parametric kit is that the .tscn stores
## the PARAMETERS, not the output.
##
## ## Every vertex carries baked AO in its COLOR
##
## The critic's word for the shipped dungeon was "large uniform Lego", and the
## reason was not the block SIZE — it was that nothing in the room touched
## anything. A protruding block, the slab behind it, the plinth and the floor all
## returned the same light, so the wall read as a decal of masonry rather than as
## stone stacked on stone. Ambient light does that: it arrives from every
## direction equally, so a crevice is exactly as bright as an open face, which is
## a thing no real room has ever done.
##
## So every vertex this file emits gets a grey in COLOR and the three stone
## shaders multiply ALBEDO by it (`zone_ao_strength`). It is free — no extra
## draw, no screen-space pass, no shadow map — and it is baked at build time from
## geometry the kit already knows: how deep in its slot a block sits, which way a
## face points, and how close to the ground it is. See `Ao`.

const F_PX := 1
const F_NX := 2
const F_PY := 4
const F_NY := 8
const F_PZ := 16
const F_NZ := 32
const F_ALL := 63
## A wall slab: everything except the face buried in the rock behind it.
const F_NO_BACK := F_ALL & ~F_NZ


## How one box shades. Every field is a MULTIPLIER on the vertex grey, and the
## default instance is "fully open stone" — 1.0 everywhere — so a caller that does
## not care about AO passes nothing and gets what it always got.
##
## Not a const Dictionary: a `const` holding a class is not a constant expression
## in GDScript (CLAUDE.md §3), and an untyped dictionary of knobs would make every
## read here a `Variant` that needs annotating. A tiny class is cheaper to read
## and the kit builds a handful of them per room.
class Ao extends RefCounted:
	## Local Y that counts as "the floor" for the contact gradient. Faces below
	## `ground_y + ground_h` darken toward `ground_min` as they approach it.
	var ground_y := 0.0
	## 0 disables the contact gradient entirely.
	var ground_h := 0.0
	var ground_min := 0.45
	## Flat shade for the whole box — how deep in a cavity this box sits.
	var flat := 1.0
	## The direction this box's FINISHED face looks. Vertical faces pointing
	## elsewhere are in the slot beside the block and get `recess`. `Vector3.ZERO`
	## means "no privileged face" (a pillar, a prop) and every side reads the same.
	var open := Vector3.ZERO
	var recess := 1.0
	## -Y faces. The underside of anything is the darkest place on it.
	var down := 1.0
	## +Y faces. Ledges catch what ambient there is, so this is usually >= 1.0 is
	## wrong — it is clamped to 1.0; the value exists to darken, never to add.
	var up := 1.0

	## The grey for one vertex. Kept branch-light: this runs per vertex on a few
	## thousand verts per room, at build time, once.
	func shade(p: Vector3, n: Vector3) -> float:
		var v := flat
		if n.y > 0.5:
			v *= up
		elif n.y < -0.5:
			v *= down
		elif open != Vector3.ZERO and n.dot(open) < 0.5:
			v *= recess
		# Up-facing surfaces are exempt from the contact gradient. The floor slab's
		# own top face sits exactly ON the ground plane, and darkening it would put
		# a shadow over the entire room instead of into the seam at its edge.
		if ground_h > 0.0 and n.y <= 0.5:
			var t: float = clampf((p.y - ground_y) / ground_h, 0.0, 1.0)
			# Squared, not linear: real contact occlusion is tight against the
			# joint and gone within a hand's width. A linear ramp over the same
			# distance reads as a gradient painted on the wall.
			v *= lerpf(ground_min, 1.0, t * t)
		return clampf(v, 0.0, 1.0)


## The one shared "no occlusion" instance. Handed to every call that does not pass
## its own, so the common path allocates nothing.
static var AO_OPEN := Ao.new()


## Planar UV for a point on a face with the given normal. Metres -> UV units, so a
## 2 m block and a 6 m wall get the same texel density without per-piece UV setup.
static func uv_for(p: Vector3, n: Vector3, s: float) -> Vector2:
	var a := n.abs()
	if a.y >= a.x and a.y >= a.z:
		return Vector2(p.x, p.z) * s
	if a.x >= a.z:
		return Vector2(p.z, p.y) * s
	return Vector2(p.x, p.y) * s


static func quad(
	st: SurfaceTool, n: Vector3, s: float,
	a: Vector3, b: Vector3, c: Vector3, d: Vector3,
	ao: Ao = null
) -> void:
	var f: Ao = ao if ao != null else AO_OPEN
	_vert(st, n, s, a, f)
	_vert(st, n, s, b, f)
	_vert(st, n, s, c, f)
	_vert(st, n, s, a, f)
	_vert(st, n, s, c, f)
	_vert(st, n, s, d, f)


static func _vert(st: SurfaceTool, n: Vector3, s: float, p: Vector3, ao: Ao) -> void:
	st.set_normal(n)
	st.set_uv(uv_for(p, n, s))
	# EVERY vertex gets a colour, including the fully-open ones. SurfaceTool
	# decides which attributes a surface has from the first vertex, so a mesh that
	# sets COLOR on some verts and not others commits garbage into the rest.
	var g := ao.shade(p, n)
	st.set_color(Color(g, g, g, 1.0))
	st.add_vertex(p)


## Add an axis-aligned box spanning `lo`..`hi`. `faces` is a mask of F_* constants.
static func box(
	st: SurfaceTool, lo: Vector3, hi: Vector3, s: float,
	faces: int = F_ALL, ao: Ao = null
) -> void:
	if faces & F_PZ:
		quad(st, Vector3(0, 0, 1), s,
			Vector3(lo.x, hi.y, hi.z), Vector3(hi.x, hi.y, hi.z),
			Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z), ao)
	if faces & F_NZ:
		quad(st, Vector3(0, 0, -1), s,
			Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z),
			Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), ao)
	if faces & F_PX:
		quad(st, Vector3(1, 0, 0), s,
			Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, hi.y, lo.z),
			Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), ao)
	if faces & F_NX:
		quad(st, Vector3(-1, 0, 0), s,
			Vector3(lo.x, hi.y, lo.z), Vector3(lo.x, hi.y, hi.z),
			Vector3(lo.x, lo.y, hi.z), Vector3(lo.x, lo.y, lo.z), ao)
	if faces & F_PY:
		quad(st, Vector3(0, 1, 0), s,
			Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z),
			Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z), ao)
	if faces & F_NY:
		quad(st, Vector3(0, -1, 0), s,
			Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z),
			Vector3(hi.x, lo.y, lo.z), Vector3(lo.x, lo.y, lo.z), ao)


## A box whose horizontal cross-section shrinks with height — the tapered wooden
## torch post in refs/screens/dungeon_torch_01.png is four of these stacked.
static func taper(
	st: SurfaceTool, cx: float, cz: float, y0: float, y1: float,
	half0: float, half1: float, s: float, ao: Ao = null
) -> void:
	var a := Vector3(cx - half0, y0, cz - half0)
	var b := Vector3(cx + half0, y0, cz + half0)
	var c := Vector3(cx - half1, y1, cz - half1)
	var d := Vector3(cx + half1, y1, cz + half1)
	# Sides, each a trapezoid. Flat normal per side; the taper is shallow enough that
	# a true face normal and the axis normal are visually identical, and the axis
	# normal keeps the world-space stone shaders reading the right projection.
	quad(st, Vector3(0, 0, 1), s,
		Vector3(c.x, y1, d.z), Vector3(d.x, y1, d.z), Vector3(b.x, y0, b.z), Vector3(a.x, y0, b.z), ao)
	quad(st, Vector3(0, 0, -1), s,
		Vector3(d.x, y1, c.z), Vector3(c.x, y1, c.z), Vector3(a.x, y0, a.z), Vector3(b.x, y0, a.z), ao)
	quad(st, Vector3(1, 0, 0), s,
		Vector3(d.x, y1, d.z), Vector3(d.x, y1, c.z), Vector3(b.x, y0, a.z), Vector3(b.x, y0, b.z), ao)
	quad(st, Vector3(-1, 0, 0), s,
		Vector3(c.x, y1, c.z), Vector3(c.x, y1, d.z), Vector3(a.x, y0, b.z), Vector3(a.x, y0, a.z), ao)
	quad(st, Vector3(0, 1, 0), s,
		Vector3(c.x, y1, c.z), Vector3(d.x, y1, c.z), Vector3(d.x, y1, d.z), Vector3(c.x, y1, d.z), ao)


## Fill a rectangular wall region with a running-bond field of individually
## protruding blocks. This is what makes a wall read as MASONRY at silhouette level
## rather than as a flat quad wearing a stone texture: each block sticks out a
## different amount, so raking torchlight carves real shadow between the courses.
##
## Blocks are recessed `joint` on every side (the gap between them shows the darker
## backing slab, which is the mortar line) and start slightly BEHIND the slab face
## so no two coplanar surfaces ever z-fight.
##
## `ground` is the wall's own contact gradient — pass the same `Ao` the backing
## slab and plinth got, and the field inherits its floor darkening while adding
## its own per-block cavity term on top.
static func block_field(
	st: SurfaceTool,
	x0: float, x1: float, y0: float, y1: float,
	course_h: float, block_w: float, joint: float,
	relief: float, rng: RandomNumberGenerator, s: float,
	ground: Ao = null
) -> void:
	var ao := Ao.new()
	ao.open = Vector3(0, 0, 1)
	# The four sides of a block face into the joint, where the two neighbouring
	# blocks and the slab behind close most of the sky off. This one number is
	# what turns the running bond from a printed pattern into stacked stone.
	ao.recess = 0.52
	ao.down = 0.44
	ao.up = 0.82
	if ground != null:
		ao.ground_y = ground.ground_y
		ao.ground_h = ground.ground_h
		ao.ground_min = ground.ground_min

	var course := 0
	var y := y0
	while y < y1 - 0.02:
		var top: float = minf(y + course_h, y1)
		if top - y < course_h * 0.35:
			break
		# Running bond: every other course starts half a block over, so vertical
		# joints never stack into a visible grid.
		var x: float = x0 - (block_w * 0.5 if course % 2 == 1 else 0.0)
		while x < x1 - 0.02:
			var w := block_w * rng.randf_range(0.72, 1.34)
			var bx0: float = maxf(x, x0)
			var bx1: float = minf(x + w, x1)
			x += w
			if bx1 - bx0 < 0.3:
				continue
			var p := relief * rng.randf_range(0.25, 1.0)
			# A block that barely stands proud is sunk in its own slot and sees
			# less of the room than one that juts out. Reading the shade off the
			# protrusion the field already randomises means the lighting variation
			# and the silhouette variation agree with each other — which is what a
			# flat per-block brightness hash could never do, and what made the
			# shipped wall read as a patchwork of differently painted bricks.
			ao.flat = lerpf(0.66, 1.0, p / maxf(relief, 0.0001))
			box(st,
				Vector3(bx0 + joint, y + joint * 0.7, -0.08),
				Vector3(bx1 - joint, top - joint * 0.7, p),
				s, F_NO_BACK, ao)
		y = top
		course += 1
