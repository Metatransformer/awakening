class_name MapDraw
extends RefCounted
## The active map, drawn. One facade, called at two sizes: the HUD's corner
## minimap and the pause menu's MAP screen. Dungeon rooms and authored exterior
## geometry remain different plan vocabularies, but source selection, framing,
## proof facts, and every call site are shared here.
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

## How much floor a FOLLOWING map shows, in cells across the shorter side of its
## box. The corner minimap scrolls under a hero pinned to the middle of it; the
## MAP screen still fits the whole floor.
##
## The two want opposite things and that is why there are two numbers rather than
## one shared view. A full-floor fit is the right picture when you have stopped
## to read it -- `Atlas.bounds()`'s note is about exactly that, and it still
## holds for the screen you open on purpose. It is the wrong picture at 132 px in
## a corner, where a six-room floor puts every room under 40 px and "where am I"
## has to be answered by finding a 5 px arrow. Following answers it by never
## moving the arrow.
##
## 3.4 rather than 3: at three the room you are in fills the box edge to edge and
## the map stops saying which way the floor continues. The extra fifth of a cell
## on each side is where the corridor stubs live.
const FOLLOW_SPAN := 3.4

## Exterior plans keep the authored line weights and glyph size of the compact
## radar they replaced. The fitted MAP view uses these same primitives at a
## different projection; it does not own a second plan or symbol table.
const SURFACE_PATH_W := 3.0
const SURFACE_SPUR_W := 2.0
const SURFACE_AREA_W := 1.0
const SURFACE_HERO_G := 6.0
const SURFACE_GLYPH_G := 7.0
const SURFACE_BOUNDS_PAD := 3.0

const SURFACE_GLYPHS: Array[StringName] = [
	&"gate", &"entrance", &"hearth", &"service", &"landmark",
	&"dungeon", &"fishing", &"grove",
]


## Draw the map into `box`.
##
## `follow` picks which of the two maps this is. False fits the whole floor into
## the box and centres it there, which is the MAP screen. True holds the hero
## dead centre at a fixed pitch and lets the floor scroll under him, which is the
## corner minimap -- see `FOLLOW_SPAN`. A following map is the only one that
## draws outside its box, so it is also the only one that needs `box` as a clip
## rather than only as a frame; everything below takes it as both.
##
## `hero` may be null -- the menu screen draws the same map with the world
## paused and the hero perfectly findable, but a lookdev scene has neither. A
## following map with no hero has nothing to follow and falls back to the fit.
##
## `zoom` and `pan` belong to the FITTED map and to nothing else -- the MAP
## screen's view, which the player drives with the right stick and the mouse
## (`MenuMapPanel`). `zoom` multiplies the fitted pitch, so `1.0` is the whole
## floor in the box exactly as it has always been drawn, and `pan` is a pixel
## offset on top of that. The following branch never reads either: a minimap that
## the player can push around is a minimap that has stopped answering "where am
## I", which is the only question it is up there to answer. The defaults are what
## `Hud._draw_minimap` passes by not passing them.
static func draw_map(ci: CanvasItem, box: Rect2, s_y: float,
		hero: Node3D, follow: bool = false, zoom: float = 1.0,
		pan: Vector2 = Vector2.ZERO) -> Dictionary:
	if not Atlas.has_map():
		return {}
	match Atlas.map_kind():
		Atlas.KIND_DUNGEON:
			return _draw_dungeon_map(ci, box, s_y, hero, follow, zoom, pan)
		Atlas.KIND_SURFACE:
			return _draw_surface_map(ci, box, s_y, Atlas.surface_plan(), hero,
				follow, zoom, pan)
	return {}


static func _draw_dungeon_map(ci: CanvasItem, box: Rect2, s_y: float,
		hero: Node3D, follow: bool, zoom: float, pan: Vector2) -> Dictionary:
	var facts := _debug_facts(Atlas.KIND_DUNGEON)
	facts[&"room_count"] = Atlas.rooms.size()
	facts[&"explored_count"] = Atlas.explored_count()
	facts[&"player_centered"] = follow and hero != null
	var ordinary_locks := 0
	var boss_locks := 0
	for tag: StringName in Atlas.locks:
		if Atlas.locks[tag]["kind"] == Atlas.LOCK_BOSS:
			boss_locks += 1
		else:
			ordinary_locks += 1
	facts[&"lock_count"] = Atlas.locks.size()
	facts[&"ordinary_lock_count"] = ordinary_locks
	facts[&"boss_lock_count"] = boss_locks
	facts[&"visible_lock_count"] = 0
	facts[&"ordinary_lock_glyph"] = &"bone_padlock"
	facts[&"boss_lock_glyph"] = &"gold_padlock"
	var b := Atlas.bounds()
	var pitch := 0.0
	var origin := Vector2.ZERO
	if follow and hero != null:
		pitch = minf(box.size.x, box.size.y) / FOLLOW_SPAN
		# Solve `_draw_hero`'s own placement for the origin that puts the hero at
		# the middle of the box. Written against that expression and not against a
		# cell centre, because the hero is at a FRACTIONAL cell and a map centred
		# on the room he is in would still slide by half a room as he crossed it.
		origin = box.get_center() - (Atlas.cellf_of(hero.global_position)
			- Vector2(b.position) + Vector2(0.5, 0.5)) * pitch
	else:
		pitch = fit_pitch(box, b) * maxf(zoom, 0.01)
		# Centre the fitted grid in the box rather than pinning it to a corner: the
		# floor's aspect changes run to run and a map jammed against one edge reads
		# as a layout bug on every floor that is not square. `pan` then slides that
		# centred plan under the box; at `zoom == 1.0` there is nothing outside the
		# box to slide to and `MenuMapPanel` clamps it to zero.
		origin = box.position + (box.size - Vector2(b.size) * pitch) * 0.5 + pan
	if pitch < 4.0:
		return facts

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
		_rect(ci, Rect2(c - Vector2(room, room) * 0.5, Vector2(room, room)),
			Color(Pal.MIDNIGHT, 0.92), box)
		_draw_corridors(ci, origin, pitch, b, cell, room, box)
	# An annex hanging off a room still in the fog draws nothing, and it is the
	# host room's fog that says so rather than the annex's own. Unreachable in
	# play -- the only way into one is through its host room -- but a map that
	# would draw a landing floating on its own if it ever were reachable is a map
	# that does not know what it is drawing.
	for a: Dictionary in Atlas.annexes:
		if Atlas.is_seen(a["cell"]):
			_draw_annex_floor(ci, origin, pitch, b, a, box)

	for cell: Vector2i in Atlas.rooms:
		if not Atlas.is_seen(cell):
			continue
		_draw_walls(ci, origin, pitch, b, cell, room,
			line_here if cell == here else line,
			Pal.BONE if cell == here else Pal.MOTH, box)
	# `here` for annexes is an (annex, box) pair rather than a cell, because they
	# do not have cells. Same rule, same weight, same colour.
	var in_annex := _annex_here(hero)
	for a in Atlas.annexes.size():
		if not Atlas.is_seen(Atlas.annexes[a]["cell"]):
			continue
		_draw_annex_walls(ci, origin, pitch, b, Atlas.annexes[a], line,
			line_here, in_annex.y if in_annex.x == a else -1, box)

	# Doorway locks sit over their wall after the wall pass and before room-centre
	# markers. Their host room's fog is authoritative: no seen room, no lock hint.
	var visible_locks := 0
	for cell: Vector2i in Atlas.rooms:
		if not Atlas.is_seen(cell):
			continue
		for record: Dictionary in Atlas.locks_of(cell):
			if _draw_lock_record(ci, _centre(origin, pitch, b, cell), room, s_y,
					record, box):
				visible_locks += 1
	facts[&"visible_lock_count"] = visible_locks

	for cell: Vector2i in Atlas.rooms:
		if not Atlas.is_seen(cell):
			continue
		_draw_marks(ci, _centre(origin, pitch, b, cell), room, s_y,
			Atlas.marks_of(cell), box)

	if hero != null:
		_draw_hero(ci, origin, pitch, b, hero, room, box)
	return facts


## Pixels per cell that puts the whole of `b` inside `box`. This is `zoom == 1.0`
## and it is the number `draw_map`'s fitted branch has always used; it is public
## so the MAP screen's view can be expressed as a multiple of it rather than
## re-deriving the fit and drifting from the map it is scaling.
static func fit_pitch(box: Rect2, b: Rect2i) -> float:
	return minf(box.size.x / float(b.size.x), box.size.y / float(b.size.y))


## How far the fitted plan may be panned, per axis, in pixels. One rule: **the
## pan slides the plan until an edge of it meets the same edge of the box**, and
## `draw_map` centres the plan before adding `pan`, so that distance is half the
## difference between the two rectangles.
##
## `absf`, and that is the whole of the subtlety. The obvious clamp is half the
## OVERFLOW -- `maxf(grid - box, 0)` -- and it reads as the right answer until
## you notice which axis it kills. `fit_pitch` takes the SMALLER ratio, so a
## fitted plan is letterboxed on the other axis, and zooming in grows it past the
## box on one axis long before the other: a 6x7 floor in the MAP screen's 820x394
## well overflows vertically at 1.2x and does not overflow horizontally until
## 2.4x. Under the overflow clamp the player pushes the stick left at the zoom
## the screen opens on and gets NOTHING, which is the exact complaint card #122
## was filed about, arrived at from the other direction.
##
## So on an axis with a letterbox band the pan slides the plan inside that band
## instead. It reveals nothing new there -- there is nothing off-frame to reveal
## -- but it puts the part of the floor you are reading under the middle of your
## eye instead of against an edge, and a control that answers in two directions
## out of four is a broken control however defensible each half is.
##
## Either way the plan cannot be pushed off its frame: at the stop, one edge of
## the plan is exactly on one edge of the box.
static func pan_limit(box: Rect2, b: Rect2i, zoom: float) -> Vector2:
	var grid := Vector2(b.size) * fit_pitch(box, b) * maxf(zoom, 0.01)
	return (grid - box.size).abs() * 0.5


## The same edge-meets-edge clamp for whichever plan Atlas has made active.
## `pan_limit` remains the dungeon-shaped API existing floor directors use;
## the menu asks this facade and never needs to know whether its units are cells
## or world metres.
static func active_pan_limit(box: Rect2, zoom: float) -> Vector2:
	if not Atlas.has_map():
		return Vector2.ZERO
	if Atlas.map_kind() == Atlas.KIND_DUNGEON:
		return pan_limit(box, Atlas.bounds(), zoom)
	var bounds := surface_bounds(Atlas.surface_plan())
	var plan_size := bounds.size * _surface_fit_pitch(box, bounds) \
		* maxf(zoom, 0.01)
	return (plan_size - box.size).abs() * 0.5


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
		b: Rect2i, cell: Vector2i, room: float, clip: Rect2) -> void:
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
		_rect(ci, Rect2(at, size),
			Color(Pal.MIDNIGHT, 0.92) if seen else Color(Pal.ASH, 0.45), clip)


# --- Annexes -----------------------------------------------------------------
# The landing behind a boss door, the shortcut's landing, the treasure chamber,
# and the vault's three rooms. `Atlas.annexes` carries the reason they are not
# cells; this half only draws them, in the same two passes and the same colours
# the grid gets, so a vault reads as three rooms and not as a second notation.

## The fills. Every box the player has walked into, plus a stub off each end that
## has been walked to -- which is the grid's rule said sideways: a corridor
## between a seen room and an unseen one is a stub growing from the seen end, and
## it is drawn from BOTH ends when both are seen (`_draw_corridors`).
##
## Both ends, and not just the near one. The chain used to stop dead at the first
## fogged box, which drew nothing at all for a room deeper in that the player was
## standing in -- and standing in a room the map has never heard of is the whole
## complaint this file was opened for.
static func _draw_annex_floor(ci: CanvasItem, origin: Vector2, pitch: float,
		b: Rect2i, a: Dictionary, clip: Rect2) -> void:
	var boxes: Array = a["boxes"]
	for i in boxes.size():
		var box: Dictionary = boxes[i]
		if bool(box["seen"]):
			_rect(ci, _annex_rect(origin, pitch, b, a, box),
				Color(Pal.MIDNIGHT, 0.92), clip)
			continue
		# `i == 0`'s neighbour behind is the host room, and the host room being
		# fogged means none of this is drawn anyway.
		if i == 0 or bool(boxes[i - 1]["seen"]):
			_stub(ci, origin, pitch, b, a, box, false, clip)
		if i + 1 < boxes.size() and bool(boxes[i + 1]["seen"]):
			_stub(ci, origin, pitch, b, a, box, true, clip)


## The short promise that a fogged box is there. `back` grows it inward from
## `far` instead of outward from `near` -- the end you are standing at is the end
## it has to come out of, and on a chain that can be entered from either side
## that is not always the near one.
static func _stub(ci: CanvasItem, origin: Vector2, pitch: float, b: Rect2i,
		a: Dictionary, box: Dictionary, back: bool, clip: Rect2) -> void:
	var near: float = box["near"]
	var far: float = box["far"]
	var short := box.duplicate()
	if back:
		short["near"] = far - (far - near) * STUB
	else:
		short["far"] = near + (far - near) * STUB
	_rect(ci, _annex_rect(origin, pitch, b, a, short), Color(Pal.ASH, 0.45),
		clip)


## The outlines. Only the `room` boxes get one -- the links between them are
## corridor, and corridors on this map are a fill and no line.
##
## `here` is the box the hero is standing in, or -1. It gets the heavier, lighter
## outline for the same reason a room does, and it is the only "you are here"
## there is on the MAP screen when the player is three rooms into a vault.
static func _draw_annex_walls(ci: CanvasItem, origin: Vector2, pitch: float,
		b: Rect2i, a: Dictionary, w: float, w_here: float, here: int,
		clip: Rect2) -> void:
	var boxes: Array = a["boxes"]
	var axis := Vector2(Atlas.step_of(a["dir"]))
	var side := Vector2(-axis.y, axis.x)
	for i in boxes.size():
		var box: Dictionary = boxes[i]
		# `continue`, not `return`: a fogged box in the middle of a chain does not
		# hide the rooms past it. See `_draw_annex_floor`.
		if not bool(box["seen"]) or not bool(box["room"]):
			continue
		var c := _centre(origin, pitch, b, a["cell"])
		var mid: float = (float(box["near"]) + float(box["far"])) * 0.5
		var at := c + axis * mid * pitch
		var run: float = (float(box["far"]) - float(box["near"])) * pitch
		var wide: float = float(box["wide"]) * pitch
		var line: float = w_here if i == here else w
		var col: Color = Pal.BONE if i == here else Pal.MOTH

		# The two long sides, whole.
		for s: float in [-1.0, 1.0]:
			_wall_run(ci, at + side * wide * 0.5 * s, axis, run, 0.0, line,
				col, clip)
		# The two ends, each split around whatever joins it there. The chain's
		# last box has nothing beyond it, which is what makes the back of the
		# vault a solid wall and the back of a landing the same.
		var ends := [
			{"s": -1.0, "gap": _link_wide(boxes, i - 1) * pitch},
			{"s": 1.0, "gap": _link_wide(boxes, i + 1) * pitch},
		]
		for e: Dictionary in ends:
			_wall_run(ci, at + axis * run * 0.5 * float(e["s"]), side, wide,
				float(e["gap"]), line, col, clip)


## Which annex box the hero is standing in, as (annex, box), or (-1, -1).
##
## Measured against the boxes themselves rather than by rounding him onto the
## grid, because rounding is the thing annexes exist to not do: the vault's
## second and third rooms both round onto cells nothing stands in.
static func _annex_here(hero: Node3D) -> Vector2i:
	if hero == null:
		return Vector2i(-1, -1)
	var f := Atlas.cellf_of(hero.global_position)
	for a in Atlas.annexes.size():
		var an: Dictionary = Atlas.annexes[a]
		var axis := Vector2(Atlas.step_of(an["dir"]))
		var rel := f - Vector2(an["cell"])
		var along := rel.dot(axis)
		var across := absf(rel.dot(Vector2(-axis.y, axis.x)))
		var boxes: Array = an["boxes"]
		for i in boxes.size():
			var box: Dictionary = boxes[i]
			if along >= float(box["near"]) and along <= float(box["far"]) \
					and across <= float(box["wide"]) * 0.5:
				return Vector2i(a, i)
	return Vector2i(-1, -1)


## How wide the box at `i` is, or zero when there is no box there. Zero is what
## `_wall_run` reads as "no hole in this one".
static func _link_wide(boxes: Array, i: int) -> float:
	if i < 0 or i >= boxes.size():
		return 0.0
	return float(boxes[i]["wide"])


## One annex box as a screen rect. `axis` and `side` are unit compass vectors, so
## the two opposite corners are enough and `abs()` sorts out which way each ran.
static func _annex_rect(origin: Vector2, pitch: float, b: Rect2i,
		a: Dictionary, box: Dictionary) -> Rect2:
	var c := _centre(origin, pitch, b, a["cell"])
	var axis := Vector2(Atlas.step_of(a["dir"]))
	var side := Vector2(-axis.y, axis.x)
	var half: float = float(box["wide"]) * 0.5 * pitch
	var lo := c + axis * float(box["near"]) * pitch - side * half
	var hi := c + axis * float(box["far"]) * pitch + side * half
	return Rect2(Vector2(minf(lo.x, hi.x), minf(lo.y, hi.y)), (hi - lo).abs())


# --- Walls -------------------------------------------------------------------

## The four sides of a room, each cut around its doorway. The cut is what makes
## this read as a floor plan: an unbroken square with a corridor touching it
## reads as a box with a pipe stuck on the side.
##
## An annex's mouth is cut the same way and for the same reason -- see
## `Atlas.annex_dirs_of`. It is the one side of this map that a locked door can
## be behind, and the wall still has a hole in it.
static func _draw_walls(ci: CanvasItem, origin: Vector2, pitch: float,
		b: Rect2i, cell: Vector2i, room: float, w: float, col: Color,
		clip: Rect2) -> void:
	var c := _centre(origin, pitch, b, cell)
	var half := room * 0.5
	var doors: Array = Atlas.doors_of(cell)
	var annexed: Array[StringName] = Atlas.annex_dirs_of(cell)
	var gap := room * Atlas.door_frac

	for d: StringName in [&"n", &"s", &"w", &"e"]:
		var step := Vector2(_step(d))
		# `at` is the wall's midpoint; `along` runs down its length.
		var at := c + step * half
		var along := Vector2(-step.y, step.x)
		var open: bool = doors.has(d) or annexed.has(d)
		_wall_run(ci, at, along, room, gap if open else 0.0, w, col, clip)


## One wall, split around a hole of `gap` in the middle of it. `gap` of zero is a
## solid run. `mid` is the wall's midpoint and `along` the unit vector down its
## length.
static func _wall_run(ci: CanvasItem, mid: Vector2, along: Vector2,
		length: float, gap: float, w: float, col: Color, clip: Rect2) -> void:
	var half := length * 0.5
	if gap <= 0.0:
		_line(ci, mid - along * half, mid + along * half, w, col, clip)
		return
	var seg: float = maxf((length - gap) * 0.5, 0.0)
	if seg <= 0.5:
		return
	# `s: float`, not a bare `s`. Indexing an untyped literal array yields
	# Variant and `mid + along * half * s` then has no inferable type --
	# CLAUDE.md §3's const-Dictionary trap, in its Array clothing.
	for s: float in [-1.0, 1.0]:
		var outer := mid + along * half * s
		_line(ci, outer, outer - along * seg * s, w, col, clip)


## An axis-aligned segment of thickness `w`, as a rect. `draw_line` at these
## widths lands on half pixels and comes out soft, which is the PSX treatment
## collapsing (docs/STYLEGUIDE.md §1) -- rects land on whole pixels.
static func _line(ci: CanvasItem, a: Vector2, z: Vector2, w: float,
		col: Color, clip: Rect2) -> void:
	var lo := Vector2(minf(a.x, z.x), minf(a.y, z.y))
	var hi := Vector2(maxf(a.x, z.x), maxf(a.y, z.y))
	_rect(ci, Rect2(lo - Vector2(w, w) * 0.5, (hi - lo) + Vector2(w, w)),
		col, clip)


## Every fill this file lays down goes through here, because a FOLLOWING map
## draws rooms that are only half inside its frame (`draw_map`) and the other
## half would land on the health bar.
##
## Clipped by intersection rather than by a `clip_contents` Control, because
## there is no Control to set it on: the HUD is one `_draw` surface and the MAP
## screen is another, and turning clipping on for either would clip everything
## else drawn into it. Every shape here is an axis-aligned rect, so an
## intersection is the whole of what a scissor would have done.
static func _rect(ci: CanvasItem, r: Rect2, col: Color, clip: Rect2) -> void:
	var hit := r.intersection(clip)
	if hit.size.x <= 0.0 or hit.size.y <= 0.0:
		return
	ci.draw_rect(hit, col)


static func _step(d: StringName) -> Vector2i:
	return Atlas.step_of(d)


# --- Markers -----------------------------------------------------------------

## What is in this room, as symbols, laid out in a row across its middle.
##
## Sorted into `MARK_ORDER` rather than into the order they were placed: the
## stair is the most important thing that can be in a room and it should be in
## the same position in every room that has one, so the eye can sweep the map
## for it. Placement order is generator order, which is arbitrary.
static func _draw_marks(ci: CanvasItem, c: Vector2, room: float, s_y: float,
		ids: Array, clip: Rect2) -> void:
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
		# Whole or not at all. A glyph is a SHAPE at this size (see the class
		# note) and half a chest is not a smaller chest, it is a gold bar -- so a
		# following map drops the ones its frame would cut rather than clipping
		# them the way it clips the walls.
		if clip.encloses(Rect2(Vector2(x, y) - Vector2(g, g) * 0.75,
				Vector2(g, g) * 1.5)):
			_glyph(ci, Vector2(x, y), g, id)
		x += step


## One marker at an arbitrary size, for the MAP screen's key. Public so the
## legend draws the SAME shape the map does: a hand-drawn swatch beside a
## hand-drawn map is two chests that agree until one of them is edited.
static func draw_legend_glyph(ci: CanvasItem, c: Vector2, g: float,
		id: StringName, kind: StringName = &"") -> void:
	var map_kind := Atlas.map_kind() if kind == &"" else kind
	if map_kind == Atlas.KIND_SURFACE:
		_surface_glyph(ci, c, g, id)
	else:
		_glyph(ci, c, g, id)


static func _glyph(ci: CanvasItem, c: Vector2, g: float, id: StringName) -> void:
	match id:
		&"chest": _chest(ci, c, g, Pal.GOLD)
		&"chest_open": _chest(ci, c, g, Color(Pal.MOTH, 0.85))
		&"stairs": _stairs(ci, c, g)
		&"arrows": _arrows(ci, c, g)
		&"entrance": _entrance(ci, c, g)
		&"lock": _lock(ci, c, g, Pal.BONE)
		&"boss_lock": _lock(ci, c, g, Pal.GOLD)


static func _draw_lock_record(ci: CanvasItem, room_centre: Vector2, room: float,
		s_y: float, record: Dictionary, clip: Rect2) -> bool:
	var axis := Vector2(_step(StringName(record["wall"])))
	var g := maxf(room * 0.24, Pal.px(5.0, s_y))
	var at := room_centre + axis * (room * 0.5 - g * 0.10)
	if not clip.encloses(Rect2(at - Vector2.ONE * g * 0.65,
			Vector2.ONE * g * 1.3)):
		return false
	var col: Color = Pal.GOLD if record["kind"] == Atlas.LOCK_BOSS else Pal.BONE
	_lock(ci, at, g, col)
	return true


## One padlock silhouette shared by the floor, both legends, and the HUD key
## strip. The open centre of the shackle is what keeps it a lock at six pixels;
## a filled arch would read as another room marker.
static func _lock(ci: CanvasItem, c: Vector2, g: float, col: Color) -> void:
	var stroke := maxf(g * 0.14, 1.0)
	var body := Rect2(c + Vector2(-g * 0.38, -g * 0.02),
		Vector2(g * 0.76, g * 0.55))
	ci.draw_rect(body.grow(maxf(g * 0.08, 1.0)), Color(Pal.VOID, 0.92))
	ci.draw_arc(c + Vector2(0.0, -g * 0.04), g * 0.29, PI, TAU, 10,
		Color(Pal.VOID, 0.92), stroke * 2.2)
	ci.draw_arc(c + Vector2(0.0, -g * 0.04), g * 0.29, PI, TAU, 10,
		col, stroke)
	ci.draw_rect(body, col)
	ci.draw_circle(c + Vector2(0.0, g * 0.19), maxf(g * 0.07, 1.0), Pal.VOID)


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
		b: Rect2i, hero: Node3D, room: float, clip: Rect2) -> void:
	var f := Atlas.cellf_of(hero.global_position)
	var at := origin + (f - Vector2(b.position) + Vector2(0.5, 0.5)) * pitch
	# On a following map this is the centre of the box by construction. On a
	# fitted one the whole floor is inside the box already, so the only way to
	# fail this is a hero standing somewhere the floor is not.
	if not clip.has_point(at):
		return
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


# --- Authored surfaces -------------------------------------------------------

## World X/Z bounds from the plan that is actually active. Paths, polygon or
## rectangular areas, and landmarks all participate so the fitted screen cannot
## crop a spur or symbol that the following minimap can show.
static func surface_bounds(plan: Dictionary) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for value: Variant in plan.get(&"paths", []):
		if value is Dictionary:
			var points_value: Variant = (value as Dictionary).get(&"points", null)
			if points_value is PackedVector3Array:
				for point: Vector3 in points_value as PackedVector3Array:
					lo = lo.min(Vector2(point.x, point.z))
					hi = hi.max(Vector2(point.x, point.z))
	for value: Variant in plan.get(&"areas", []):
		if not value is Dictionary:
			continue
		for point: Vector3 in _surface_area_points(value as Dictionary):
			lo = lo.min(Vector2(point.x, point.z))
			hi = hi.max(Vector2(point.x, point.z))
	for value: Variant in plan.get(&"landmarks", []):
		if value is Dictionary:
			var position_value: Variant = (value as Dictionary).get(&"position", null)
			if position_value is Vector3:
				var point := position_value as Vector3
				lo = lo.min(Vector2(point.x, point.z))
				hi = hi.max(Vector2(point.x, point.z))
	if is_inf(lo.x) or is_inf(lo.y):
		return Rect2(Vector2.ZERO, Vector2.ONE)
	var bounds := Rect2(lo, (hi - lo).max(Vector2.ONE))
	return bounds.grow(SURFACE_BOUNDS_PAD)


static func _surface_fit_pitch(box: Rect2, bounds: Rect2) -> float:
	return minf(box.size.x / maxf(bounds.size.x, 0.001),
		box.size.y / maxf(bounds.size.y, 0.001))


static func _draw_surface_map(ci: CanvasItem, box: Rect2, s_y: float,
		plan: Dictionary, hero: Node3D, follow: bool, zoom: float,
		pan: Vector2) -> Dictionary:
	var following := follow and hero != null and is_instance_valid(hero)
	var paths: Array = plan[&"paths"]
	var areas: Array = plan[&"areas"]
	var landmarks: Array = plan[&"landmarks"]
	var bounds := surface_bounds(plan)
	var pixels_per_metre := 0.0
	var world_center := bounds.get_center()
	var screen_center := box.get_center()
	if following:
		pixels_per_metre = minf(box.size.x, box.size.y) \
			/ float(plan[&"view_range"])
		world_center = Vector2(hero.global_position.x, hero.global_position.z)
	else:
		pixels_per_metre = _surface_fit_pitch(box, bounds) * maxf(zoom, 0.01)
		screen_center += pan
	if pixels_per_metre <= 0.0:
		return {}

	for value: Variant in areas:
		if value is Dictionary:
			_draw_surface_area(ci, box, world_center, screen_center,
				pixels_per_metre, value as Dictionary, s_y)
	for value: Variant in paths:
		if value is Dictionary:
			_draw_surface_path(ci, box, world_center, screen_center,
				pixels_per_metre, value as Dictionary, s_y)
	var drawn_landmarks := 0
	for value: Variant in landmarks:
		if value is Dictionary and _draw_surface_landmark(ci, box, world_center,
				screen_center, pixels_per_metre, value as Dictionary, s_y):
			drawn_landmarks += 1
	if hero != null and is_instance_valid(hero):
		_draw_surface_player(ci, box, world_center, screen_center,
			pixels_per_metre, hero, s_y)

	var facts := _debug_facts(Atlas.KIND_SURFACE)
	facts.merge({
		&"path_count": paths.size(),
		&"area_count": areas.size(),
		&"landmark_count": landmarks.size(),
		&"visible_landmark_count": drawn_landmarks,
		&"view_range": float(plan[&"view_range"]),
		&"player_centered": following,
		&"plan_bounds": bounds,
	})
	return facts


static func _debug_facts(kind: StringName) -> Dictionary:
	return {
		&"kind": kind,
		&"provider_id": Atlas.map_provider_id(),
		&"provider_name": Atlas.map_provider_name(),
		&"title": Atlas.map_title(),
	}


static func _draw_surface_path(ci: CanvasItem, box: Rect2,
		world_center: Vector2, screen_center: Vector2, pixels_per_metre: float,
		entry: Dictionary, s_y: float) -> void:
	var value: Variant = entry.get(&"points", null)
	if not value is PackedVector3Array:
		return
	var points := value as PackedVector3Array
	if points.size() < 2:
		return
	var kind := StringName(entry.get(&"kind", &"path"))
	var width := Pal.px(SURFACE_SPUR_W if kind == &"spur" \
		else SURFACE_PATH_W, s_y)
	var color := Color(Pal.ASH, 0.72) if kind == &"spur" \
		else Color(Pal.MOTH, 0.62)
	var clip := box.grow(-width * 0.5)
	for i in points.size() - 1:
		var a := _surface_project(points[i], world_center, screen_center,
			pixels_per_metre)
		var z := _surface_project(points[i + 1], world_center, screen_center,
			pixels_per_metre)
		var clipped := _clip_segment(a, z, clip)
		if clipped.size() == 2:
			ci.draw_line(clipped[0], clipped[1], color, width)


static func _surface_area_points(entry: Dictionary) -> PackedVector3Array:
	var points_value: Variant = entry.get(&"points", null)
	if points_value is PackedVector3Array:
		return points_value as PackedVector3Array
	var centre_value: Variant = entry.get(&"center", null)
	var size_value: Variant = entry.get(&"size", null)
	if not centre_value is Vector3 or not size_value is Vector2:
		return PackedVector3Array()
	var centre := centre_value as Vector3
	var area_size := size_value as Vector2
	var yaw := float(entry.get(&"yaw", 0.0))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw)) * area_size.x * 0.5
	var down := Vector3(sin(yaw), 0.0, cos(yaw)) * area_size.y * 0.5
	return PackedVector3Array([
		centre - right - down, centre + right - down,
		centre + right + down, centre - right + down,
	])


static func _draw_surface_area(ci: CanvasItem, box: Rect2,
		world_center: Vector2, screen_center: Vector2, pixels_per_metre: float,
		entry: Dictionary, s_y: float) -> void:
	var world_points := _surface_area_points(entry)
	if world_points.size() < 3:
		return
	var projected: Array[Vector2] = []
	for point: Vector3 in world_points:
		projected.append(_surface_project(point, world_center, screen_center,
			pixels_per_metre))
	var clipped := _clip_polygon(projected, box)
	if clipped.size() < 3:
		return
	var kind := StringName(entry.get(&"kind", &"ground"))
	var fill := Color(Pal.MOTH, 0.11)
	if kind == &"footprint":
		fill = Color(Pal.ASH, 0.34)
	elif kind == &"water":
		fill = Color(Pal.ASH, 0.24)
	elif kind == &"grove":
		fill = Color(Pal.MOTH, 0.17)
	ci.draw_colored_polygon(PackedVector2Array(clipped), fill)
	var width := Pal.px(SURFACE_AREA_W, s_y)
	for i in clipped.size():
		ci.draw_line(clipped[i], clipped[(i + 1) % clipped.size()],
			Color(Pal.ASH, 0.62), width)


static func _draw_surface_landmark(ci: CanvasItem, box: Rect2,
		world_center: Vector2, screen_center: Vector2, pixels_per_metre: float,
		entry: Dictionary, s_y: float) -> bool:
	var position_value: Variant = entry.get(&"position", null)
	var glyph := StringName(entry.get(&"glyph", &""))
	if not position_value is Vector3 or not SURFACE_GLYPHS.has(glyph):
		return false
	var at := _surface_project(position_value as Vector3, world_center,
		screen_center, pixels_per_metre)
	var g := Pal.px(SURFACE_GLYPH_G, s_y)
	if not box.encloses(Rect2(at - Vector2.ONE * g, Vector2.ONE * g * 2.0)):
		return false
	_surface_glyph(ci, at, g, glyph)
	return true


static func _surface_glyph(ci: CanvasItem, at: Vector2, g: float,
		glyph: StringName) -> void:
	match glyph:
		&"gate", &"entrance":
			_surface_gate(ci, at, g)
		&"hearth":
			_surface_hearth(ci, at, g)
		&"service":
			_surface_service(ci, at, g)
		&"landmark":
			_surface_landmark_ring(ci, at, g)
		&"dungeon":
			_surface_dungeon(ci, at, g)
		&"fishing":
			_surface_fishing(ci, at, g)
		&"grove":
			_surface_grove(ci, at, g)


static func _surface_gate(ci: CanvasItem, at: Vector2, g: float) -> void:
	var width := maxf(g * 0.16, 1.0)
	ci.draw_line(at + Vector2(-g * 0.46, g * 0.42),
		at + Vector2(-g * 0.46, -g * 0.12), Pal.BONE, width)
	ci.draw_line(at + Vector2(g * 0.46, g * 0.42),
		at + Vector2(g * 0.46, -g * 0.12), Pal.BONE, width)
	ci.draw_arc(at + Vector2(0.0, -g * 0.10), g * 0.46, PI, TAU, 8,
		Pal.BONE, width)


static func _surface_hearth(ci: CanvasItem, at: Vector2, g: float) -> void:
	ci.draw_circle(at + Vector2(0.0, g * 0.18), g * 0.36, Pal.ASH)
	ci.draw_colored_polygon(PackedVector2Array([
		at + Vector2(0.0, -g * 0.52), at + Vector2(-g * 0.32, g * 0.24),
		at + Vector2(g * 0.32, g * 0.24),
	]), Pal.RUST)


static func _surface_service(ci: CanvasItem, at: Vector2, g: float) -> void:
	ci.draw_colored_polygon(PackedVector2Array([
		at + Vector2(0.0, -g * 0.48), at + Vector2(g * 0.48, 0.0),
		at + Vector2(0.0, g * 0.48), at + Vector2(-g * 0.48, 0.0),
	]), Pal.MOTH)
	ci.draw_circle(at, g * 0.13, Pal.VOID)


static func _surface_landmark_ring(ci: CanvasItem, at: Vector2, g: float) -> void:
	ci.draw_arc(at, g * 0.42, 0.0, TAU, 12, Pal.MOTH, maxf(g * 0.15, 1.0))
	ci.draw_circle(at, g * 0.11, Pal.BONE)


static func _surface_dungeon(ci: CanvasItem, at: Vector2, g: float) -> void:
	var step := g / 3.0
	for i in 3:
		ci.draw_rect(Rect2(at.x - g * 0.5, at.y - g * 0.5 + step * i,
			step * float(i + 1), maxf(step * 0.7, 1.0)), Pal.BONE)


static func _surface_fishing(ci: CanvasItem, at: Vector2, g: float) -> void:
	var width := maxf(g * 0.13, 1.0)
	for offset: float in [-0.22, 0.22]:
		ci.draw_arc(at + Vector2(0.0, g * offset), g * 0.45, 0.15, PI - 0.15,
			8, Pal.MOTH, width)


static func _surface_grove(ci: CanvasItem, at: Vector2, g: float) -> void:
	for offset: float in [-0.28, 0.28]:
		ci.draw_colored_polygon(PackedVector2Array([
			at + Vector2(g * offset, -g * 0.48),
			at + Vector2(g * (offset - 0.27), g * 0.30),
			at + Vector2(g * (offset + 0.27), g * 0.30),
		]), Pal.MOTH)


static func _draw_surface_player(ci: CanvasItem, box: Rect2,
		world_center: Vector2, screen_center: Vector2, pixels_per_metre: float,
		hero: Node3D, s_y: float) -> void:
	var at := _surface_project(hero.global_position, world_center, screen_center,
		pixels_per_metre)
	if not box.has_point(at):
		return
	var forward_3d := -hero.global_transform.basis.z
	var forward := Vector2(forward_3d.x, forward_3d.z)
	if forward.length_squared() < 0.0001:
		forward = Vector2.UP
	forward = forward.normalized()
	var side := Vector2(-forward.y, forward.x)
	var g := Pal.px(SURFACE_HERO_G, s_y)
	for pass_i in 2:
		var radius := g * (0.68 if pass_i == 0 else 0.54)
		ci.draw_colored_polygon(PackedVector2Array([
			at + forward * radius,
			at - forward * radius * 0.72 + side * radius * 0.62,
			at - forward * radius * 0.72 - side * radius * 0.62,
		]), Color(Pal.VOID, 0.96) if pass_i == 0 else Pal.BONE)


static func _surface_project(world: Vector3, world_center: Vector2,
		screen_center: Vector2, pixels_per_metre: float) -> Vector2:
	return screen_center + (Vector2(world.x, world.z) - world_center) \
		* pixels_per_metre


static func _clip_segment(a: Vector2, z: Vector2, box: Rect2) -> Array[Vector2]:
	var delta := z - a
	var p := PackedFloat32Array([-delta.x, delta.x, -delta.y, delta.y])
	var q := PackedFloat32Array([
		a.x - box.position.x, box.end.x - a.x,
		a.y - box.position.y, box.end.y - a.y,
	])
	var low := 0.0
	var high := 1.0
	for i in 4:
		if is_zero_approx(p[i]):
			if q[i] < 0.0:
				return []
			continue
		var t := q[i] / p[i]
		if p[i] < 0.0:
			low = maxf(low, t)
		else:
			high = minf(high, t)
		if low > high:
			return []
	return [a + delta * low, a + delta * high]


static func _clip_polygon(points: Array[Vector2], box: Rect2) -> Array[Vector2]:
	var output := points
	for edge in 4:
		output = _clip_polygon_edge(output, box, edge)
		if output.is_empty():
			break
	return output


static func _clip_polygon_edge(points: Array[Vector2], box: Rect2,
		edge: int) -> Array[Vector2]:
	var output: Array[Vector2] = []
	if points.is_empty():
		return output
	var previous := points[-1]
	var previous_inside := _inside_edge(previous, box, edge)
	for current: Vector2 in points:
		var current_inside := _inside_edge(current, box, edge)
		if current_inside != previous_inside:
			output.append(_edge_intersection(previous, current, box, edge))
		if current_inside:
			output.append(current)
		previous = current
		previous_inside = current_inside
	return output


static func _inside_edge(point: Vector2, box: Rect2, edge: int) -> bool:
	match edge:
		0: return point.x >= box.position.x
		1: return point.x <= box.end.x
		2: return point.y >= box.position.y
		_: return point.y <= box.end.y


static func _edge_intersection(a: Vector2, z: Vector2, box: Rect2,
		edge: int) -> Vector2:
	var delta := z - a
	if edge < 2:
		var x := box.position.x if edge == 0 else box.end.x
		var t := (x - a.x) / delta.x if not is_zero_approx(delta.x) else 0.0
		return Vector2(x, a.y + delta.y * t)
	var y := box.position.y if edge == 2 else box.end.y
	var t := (y - a.y) / delta.y if not is_zero_approx(delta.y) else 0.0
	return Vector2(a.x + delta.x * t, y)
