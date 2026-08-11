class_name MapDraw
extends RefCounted
## The dungeon map, drawn. One routine, called at two sizes: the HUD's corner
## minimap and the pause menu's MAP screen.
##
## **It is line art on purpose.** Not a rendered top-down camera, not a
## SubViewport of the real geometry. Three reasons, and only the first is
## aesthetic:
##
##  1. A schematic is what a map IS. Room, corridor, door, and a symbol for the
##     one thing in the room worth walking to. A photograph of the floor from
##     above is a picture of the same walls the player is already looking at.
##  2. **Fog of war is impossible in a rendered minimap.** A camera renders what
##     is there; hiding an unvisited room means culling geometry per viewer,
##     which is a whole second visibility system for a 130 px square.
##  3. It costs nothing. A dozen `draw_rect` calls on a repaint that already
##     happens beats a second viewport rendering the world twice a frame.
##
## **Every glyph is drawn, not baked.** The HUD's item icons are baked renders
## of the real models (`ArmamentDb.ICONS`) and that is right for a 64 px cell of a
## sword you own. A map marker is 6 px on the minimap, so it has to be a SHAPE:
## a gold box with a dark band is a chest at six pixels and a photograph of a
## chest is four brown pixels. The valenfeld world-map token set was the obvious
## place to steal these from and it is the wrong set -- 256 px painterly round
## pins, in a warmer palette than this game has, and with no chest and no stair
## in it, which are the two the player actually asked for.
##
## Colours are `Pal` and nothing else. See docs/STYLEGUIDE.md §2.

## Marker id -> the function that draws it. An id `Atlas` invents without a row
## here draws NOTHING, silently -- which is the failure mode you want on a HUD
## (a missing symbol) rather than the alternative (a "?" box on every map).
const MARK_ORDER: Array[StringName] = [
	&"stairs", &"chest", &"chest_open", &"arrows", &"entrance",
]
## Most markers a room will draw. Rooms hold at most a chest and a bundle today;
## the cap is here so a future anchor cannot quietly turn a room into a row of
## symbols too small to be any of them.
const MARK_MAX := 3

## Room outline weights, in reference px at Pal.REF_H.
const WALL_W := 1.0
## The room the hero is standing in draws heavier and brighter. This is the
## "you are here" that survives at minimap size -- the hero arrow is 5 px and
## reads as a dot from a normal seat, and a lit room outline does not.
const WALL_HERE_W := 2.0
## How far a corridor to an unexplored room pokes out of the wall, as a fraction
## of the gap between two rooms. Short: it is a promise that there is more that
## way, not a claim about what is there.
const STUB := 0.42


## Draw the whole map into `box`, fitted and centred.
##
## `hero` may be null -- the menu screen draws the same map with the world
## paused and the hero perfectly findable, but a lookdev scene has neither.
static func draw_map(ci: CanvasItem, box: Rect2, s_y: float,
		hero: Node3D) -> void:
	if not Atlas.has_floor():
		return
	var b := Atlas.bounds()
	var pitch: float = minf(box.size.x / float(b.size.x),
		box.size.y / float(b.size.y))
	if pitch < 4.0:
		return
	# Centre the fitted grid in the box rather than pinning it to a corner: the
	# floor's aspect changes run to run and a map jammed against one edge reads
	# as a layout bug on every floor that is not square.
	var origin := box.position + (box.size - Vector2(b.size) * pitch) * 0.5

	var room := pitch * Atlas.room_frac
	var line := Pal.px(WALL_W, s_y)
	var line_here := Pal.px(WALL_HERE_W, s_y)
	var here := Atlas.cell_of(hero.global_position) if hero != null \
		else Vector2i(2147483647, 0)

	# Floors first, walls second, symbols last. The order matters: a corridor
	# fill drawn after a room's wall would paint over the doorway edges and the
	# map would lose the thing that makes it read as rooms.
	for cell: Vector2i in Atlas.rooms:
		if not Atlas.is_seen(cell):
			continue
		var c := _centre(origin, pitch, b, cell)
		ci.draw_rect(Rect2(c - Vector2(room, room) * 0.5, Vector2(room, room)),
			Color(Pal.MIDNIGHT, 0.92))
		_draw_corridors(ci, origin, pitch, b, cell, room)

	for cell: Vector2i in Atlas.rooms:
		if not Atlas.is_seen(cell):
			continue
		_draw_walls(ci, origin, pitch, b, cell, room,
			line_here if cell == here else line,
			Pal.BONE if cell == here else Pal.MOTH)

	for cell: Vector2i in Atlas.rooms:
		if not Atlas.is_seen(cell):
			continue
		_draw_marks(ci, _centre(origin, pitch, b, cell), room, s_y,
			Atlas.marks_of(cell))

	if hero != null:
		_draw_hero(ci, origin, pitch, b, hero, room)


static func _centre(origin: Vector2, pitch: float, b: Rect2i,
		cell: Vector2i) -> Vector2:
	return origin + (Vector2(cell - b.position) + Vector2(0.5, 0.5)) * pitch


# --- Corridors ---------------------------------------------------------------

## The passages out of one room. A corridor to a room you have seen is drawn
## whole; a corridor to a room you have not is a stub that stops short.
##
## Corridors between two SEEN rooms get drawn twice, once from each end, and
## that is deliberate rather than sloppy: the alternative is the generator's
## "only the north/west room builds it" rule, which needs the neighbour to exist
## in `rooms` AND to be seen, and gets it wrong the moment you have seen the
## south room and not the north one. Two identical rects in the same place cost
## nothing and cannot disagree.
static func _draw_corridors(ci: CanvasItem, origin: Vector2, pitch: float,
		b: Rect2i, cell: Vector2i, room: float) -> void:
	var c := _centre(origin, pitch, b, cell)
	var gap := (pitch - room) * 0.5
	var w := room * Atlas.door_frac
	for d: StringName in Atlas.doors_of(cell):
		var step := _step(d)
		var to := cell + step
		var seen: bool = Atlas.is_seen(to)
		var run: float = gap if seen else gap * STUB
		var axis := Vector2(step)
		# From the wall face outward. `axis.abs()` picks which of the two
		# dimensions is the length and which is the width, so one expression
		# covers all four compass directions instead of a match with four arms.
		var from := c + axis * room * 0.5
		var size := axis.abs() * run + Vector2(axis.y, axis.x).abs() * w
		var at := from + Vector2(minf(axis.x, 0.0), minf(axis.y, 0.0)) * run \
			- Vector2(axis.y, axis.x).abs() * w * 0.5
		ci.draw_rect(Rect2(at, size),
			Color(Pal.MIDNIGHT, 0.92) if seen else Color(Pal.ASH, 0.45))


# --- Walls -------------------------------------------------------------------

## The four sides of a room, each cut around its doorway. The cut is what makes
## this read as a floor plan: an unbroken square with a corridor touching it
## reads as a box with a pipe stuck on the side.
static func _draw_walls(ci: CanvasItem, origin: Vector2, pitch: float,
		b: Rect2i, cell: Vector2i, room: float, w: float, col: Color) -> void:
	var c := _centre(origin, pitch, b, cell)
	var half := room * 0.5
	var doors: Array = Atlas.doors_of(cell)
	var gap := room * Atlas.door_frac
	var seg: float = maxf((room - gap) * 0.5, 0.0)

	for d: StringName in [&"n", &"s", &"w", &"e"]:
		var step := Vector2(_step(d))
		# `at` is the wall's midpoint; `along` runs down its length.
		var at := c + step * half
		var along := Vector2(-step.y, step.x)
		if not doors.has(d):
			_line(ci, at - along * half, at + along * half, w, col)
			continue
		if seg <= 0.5:
			continue
		# `s: float`, not a bare `s`. Indexing an untyped literal array yields
		# Variant and `at + along * half * s` then has no inferable type --
		# CLAUDE.md §3's const-Dictionary trap, in its Array clothing.
		for s: float in [-1.0, 1.0]:
			var outer := at + along * half * s
			_line(ci, outer, outer - along * seg * s, w, col)


## An axis-aligned segment of thickness `w`, as a rect. `draw_line` at these
## widths lands on half pixels and comes out soft, which is the PSX treatment
## collapsing (docs/STYLEGUIDE.md §1) -- rects land on whole pixels.
static func _line(ci: CanvasItem, a: Vector2, z: Vector2, w: float,
		col: Color) -> void:
	var lo := Vector2(minf(a.x, z.x), minf(a.y, z.y))
	var hi := Vector2(maxf(a.x, z.x), maxf(a.y, z.y))
	ci.draw_rect(Rect2(lo - Vector2(w, w) * 0.5,
		(hi - lo) + Vector2(w, w)), col)


static func _step(d: StringName) -> Vector2i:
	match d:
		&"n": return Vector2i(0, -1)
		&"s": return Vector2i(0, 1)
		&"w": return Vector2i(-1, 0)
	return Vector2i(1, 0)


# --- Markers -----------------------------------------------------------------

## What is in this room, as symbols, laid out in a row across its middle.
##
## Sorted into `MARK_ORDER` rather than into the order they were placed: the
## stair is the most important thing that can be in a room and it should be in
## the same position in every room that has one, so the eye can sweep the map
## for it. Placement order is generator order, which is arbitrary.
static func _draw_marks(ci: CanvasItem, c: Vector2, room: float, s_y: float,
		ids: Array) -> void:
	if ids.is_empty():
		return
	var shown: Array[StringName] = []
	for id in MARK_ORDER:
		if ids.has(id) and shown.size() < MARK_MAX:
			shown.append(id)
	if shown.is_empty():
		return

	var g: float = maxf(room * 0.34, Pal.px(5.0, s_y))
	var step := g * 1.30
	var x := c.x - step * (shown.size() - 1) * 0.5
	# Above the centre line, not on it. The hero marker is drawn at his real
	# position and a room's centre is exactly where he stands when he walks in --
	# so a row of glyphs on the centre line meets the arrow head-on in every room
	# the player is currently in. On the arrival room, where the entrance ring and
	# the spawn point are the same point, the two composited into a keyhole.
	var y := c.y - room * 0.16
	for id in shown:
		_glyph(ci, Vector2(x, y), g, id)
		x += step


## One marker at an arbitrary size, for the MAP screen's key. Public so the
## legend draws the SAME shape the map does: a hand-drawn swatch beside a
## hand-drawn map is two chests that agree until one of them is edited.
static func draw_legend_glyph(ci: CanvasItem, c: Vector2, g: float,
		id: StringName) -> void:
	_glyph(ci, c, g, id)


static func _glyph(ci: CanvasItem, c: Vector2, g: float, id: StringName) -> void:
	match id:
		&"chest": _chest(ci, c, g, Pal.GOLD)
		&"chest_open": _chest(ci, c, g, Color(Pal.MOTH, 0.85))
		&"stairs": _stairs(ci, c, g)
		&"arrows": _arrows(ci, c, g)
		&"entrance": _entrance(ci, c, g)


## A gold box with a dark band across it. The band is doing all the work: a
## plain gold square at 6 px is a gold square, and a gold square with a lid is
## a chest. Drawn as a subtraction rather than as an outline because an outline
## at this size is the whole glyph and there is nothing left inside it.
static func _chest(ci: CanvasItem, c: Vector2, g: float, col: Color) -> void:
	var w := g
	var h := g * 0.78
	var r := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
	ci.draw_rect(r.grow(maxf(g * 0.10, 1.0)), Color(Pal.VOID, 0.9))
	ci.draw_rect(r, col)
	var band: float = maxf(g * 0.14, 1.0)
	ci.draw_rect(Rect2(r.position.x, r.position.y + h * 0.30, w, band),
		Color(Pal.VOID, 0.85))
	# The hasp, centred on the band. One pixel of dark below the lid line is
	# what stops the glyph reading as a crate.
	ci.draw_rect(Rect2(c.x - band * 0.5, r.position.y + h * 0.30,
		band, h * 0.34), Color(Pal.VOID, 0.85))


## Three treads descending to the right -- a staircase in section, which is the
## one view of a stair that survives being six pixels wide. CYAN because cyan
## is the way out in this game and nothing else (docs/STYLEGUIDE.md §2), and
## the stair down IS the way on.
static func _stairs(ci: CanvasItem, c: Vector2, g: float) -> void:
	var n := 3
	var tw := g / float(n)
	var th: float = maxf(g / float(n), 1.0)
	ci.draw_rect(Rect2(c - Vector2(g, g) * 0.5, Vector2(g, g)).grow(
		maxf(g * 0.10, 1.0)), Color(Pal.VOID, 0.9))
	for i in n:
		# Each tread is wider than the one above it and one step lower, so the
		# shape is a staircase and not a bar chart.
		ci.draw_rect(Rect2(c.x - g * 0.5, c.y - g * 0.5 + th * i,
			tw * float(i + 1), th), Pal.CYAN)


## A broadhead: a triangle over a stem. MOSS is uncommon-green in the rarity
## ramp and arrows are exactly that -- a thing worth stepping aside for and
## never worth crossing the floor for.
static func _arrows(ci: CanvasItem, c: Vector2, g: float) -> void:
	var half := g * 0.5
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(c.x, c.y - half),
		Vector2(c.x - half, c.y + half * 0.1),
		Vector2(c.x + half, c.y + half * 0.1),
	]), Pal.MOSS)
	var w: float = maxf(g * 0.18, 1.0)
	ci.draw_rect(Rect2(c.x - w * 0.5, c.y, w, half), Pal.MOSS)


## The way you came in: a hollow ring. Hollow on purpose -- every other marker
## on this map is something to go and get, and the arrival cell is the one that
## is only a landmark. A filled symbol would put it in the same sentence as the
## chests.
static func _entrance(ci: CanvasItem, c: Vector2, g: float) -> void:
	var w: float = maxf(g * 0.20, 1.0)
	var r := g * 0.42
	ci.draw_arc(c, r, 0.0, TAU, 12, Color(Pal.MOTH, 0.9), w)


# --- The hero ----------------------------------------------------------------

## A triangle at the hero's actual position inside his actual room, pointed the
## way he is actually facing.
##
## Facing is read as `-basis.z` and NOT from `rotation.y`, per
## docs/CONTRACT.md §2.5: the hero's model carries a 180° offset of its own and
## reasoning about yaw here is how this project has already shipped three things
## facing backwards. World +X is map +X and world +Z is map +Y, so the forward
## vector drops straight into map space with no sign to get wrong.
static func _draw_hero(ci: CanvasItem, origin: Vector2, pitch: float,
		b: Rect2i, hero: Node3D, room: float) -> void:
	var f := Atlas.cellf_of(hero.global_position)
	var at := origin + (f - Vector2(b.position) + Vector2(0.5, 0.5)) * pitch
	var fwd3 := -hero.global_transform.basis.z
	var fwd := Vector2(fwd3.x, fwd3.z)
	if fwd.length_squared() < 0.0001:
		fwd = Vector2.UP
	fwd = fwd.normalized()
	var side := Vector2(-fwd.y, fwd.x)
	var g: float = maxf(room * 0.34, 4.0)

	# A dark triangle a little larger, underneath, so the marker survives being
	# over a lit floor fill, over a gold chest glyph, or over the VOID outside
	# the rooms. Same argument as the enemy bars' frame in hud.gd.
	for pass_i in 2:
		var r: float = g * (0.62 if pass_i == 0 else 0.5)
		ci.draw_colored_polygon(PackedVector2Array([
			at + fwd * r,
			at - fwd * r * 0.72 + side * r * 0.62,
			at - fwd * r * 0.72 - side * r * 0.62,
		]), Color(Pal.VOID, 0.95) if pass_i == 0 else Pal.BONE)
