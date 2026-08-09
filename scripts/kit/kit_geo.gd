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

const F_PX := 1
const F_NX := 2
const F_PY := 4
const F_NY := 8
const F_PZ := 16
const F_NZ := 32
const F_ALL := 63
## A wall slab: everything except the face buried in the rock behind it.
const F_NO_BACK := F_ALL & ~F_NZ


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
	a: Vector3, b: Vector3, c: Vector3, d: Vector3
) -> void:
	_vert(st, n, s, a)
	_vert(st, n, s, b)
	_vert(st, n, s, c)
	_vert(st, n, s, a)
	_vert(st, n, s, c)
	_vert(st, n, s, d)


static func _vert(st: SurfaceTool, n: Vector3, s: float, p: Vector3) -> void:
	st.set_normal(n)
	st.set_uv(uv_for(p, n, s))
	st.add_vertex(p)


## Add an axis-aligned box spanning `lo`..`hi`. `faces` is a mask of F_* constants.
static func box(st: SurfaceTool, lo: Vector3, hi: Vector3, s: float, faces: int = F_ALL) -> void:
	if faces & F_PZ:
		quad(st, Vector3(0, 0, 1), s,
			Vector3(lo.x, hi.y, hi.z), Vector3(hi.x, hi.y, hi.z),
			Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z))
	if faces & F_NZ:
		quad(st, Vector3(0, 0, -1), s,
			Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z),
			Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z))
	if faces & F_PX:
		quad(st, Vector3(1, 0, 0), s,
			Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, hi.y, lo.z),
			Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z))
	if faces & F_NX:
		quad(st, Vector3(-1, 0, 0), s,
			Vector3(lo.x, hi.y, lo.z), Vector3(lo.x, hi.y, hi.z),
			Vector3(lo.x, lo.y, hi.z), Vector3(lo.x, lo.y, lo.z))
	if faces & F_PY:
		quad(st, Vector3(0, 1, 0), s,
			Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z),
			Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z))
	if faces & F_NY:
		quad(st, Vector3(0, -1, 0), s,
			Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z),
			Vector3(hi.x, lo.y, lo.z), Vector3(lo.x, lo.y, lo.z))


## A box whose horizontal cross-section shrinks with height — the tapered wooden
## torch post in refs/screens/dungeon_torch_01.png is four of these stacked.
static func taper(
	st: SurfaceTool, cx: float, cz: float, y0: float, y1: float,
	half0: float, half1: float, s: float
) -> void:
	var a := Vector3(cx - half0, y0, cz - half0)
	var b := Vector3(cx + half0, y0, cz + half0)
	var c := Vector3(cx - half1, y1, cz - half1)
	var d := Vector3(cx + half1, y1, cz + half1)
	# Sides, each a trapezoid. Flat normal per side; the taper is shallow enough that
	# a true face normal and the axis normal are visually identical, and the axis
	# normal keeps the world-space stone shaders reading the right projection.
	quad(st, Vector3(0, 0, 1), s,
		Vector3(c.x, y1, d.z), Vector3(d.x, y1, d.z), Vector3(b.x, y0, b.z), Vector3(a.x, y0, b.z))
	quad(st, Vector3(0, 0, -1), s,
		Vector3(d.x, y1, c.z), Vector3(c.x, y1, c.z), Vector3(a.x, y0, a.z), Vector3(b.x, y0, a.z))
	quad(st, Vector3(1, 0, 0), s,
		Vector3(d.x, y1, d.z), Vector3(d.x, y1, c.z), Vector3(b.x, y0, a.z), Vector3(b.x, y0, b.z))
	quad(st, Vector3(-1, 0, 0), s,
		Vector3(c.x, y1, c.z), Vector3(c.x, y1, d.z), Vector3(a.x, y0, b.z), Vector3(a.x, y0, a.z))
	quad(st, Vector3(0, 1, 0), s,
		Vector3(c.x, y1, c.z), Vector3(d.x, y1, c.z), Vector3(d.x, y1, d.z), Vector3(c.x, y1, d.z))


## Fill a rectangular wall region with a running-bond field of individually
## protruding blocks. This is what makes a wall read as MASONRY at silhouette level
## rather than as a flat quad wearing a stone texture: each block sticks out a
## different amount, so raking torchlight carves real shadow between the courses.
##
## Blocks are recessed `joint` on every side (the gap between them shows the darker
## backing slab, which is the mortar line) and start slightly BEHIND the slab face
## so no two coplanar surfaces ever z-fight.
static func block_field(
	st: SurfaceTool,
	x0: float, x1: float, y0: float, y1: float,
	course_h: float, block_w: float, joint: float,
	relief: float, rng: RandomNumberGenerator, s: float
) -> void:
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
			box(st,
				Vector3(bx0 + joint, y + joint * 0.7, -0.08),
				Vector3(bx1 - joint, top - joint * 0.7, p),
				s, F_NO_BACK)
		y = top
		course += 1
