class_name HoldGauge
## The one way this game draws "keep holding". Two shapes, one rule.
##
## **The rule: a hold the player can fail must show its progress, and it must
## show it from the frame the hold becomes possible — not from the frame they
## start pressing.** A required hold is the only input in the game that can be
## performed *correctly for most of its duration* and still do nothing, and a
## player who lets go at 80% learns nothing from the silence: they conclude the
## button is broken. The gate shipped as "A TO DESCEND", a player tapped it, and
## the bug report was "A to descend doesn't work" (see `Prompt._say_prompt`).
## Saying HOLD fixed the instruction. This fixes the feedback.
##
## Two shapes because there are two places a hold happens and they have different
## room:
##
##   * `bar()` — a track with a fill, for anything that already has a rectangle
##     to sit on: the interact prompt's box, a shop row. It costs no new screen
##     real estate and it cannot be confused with a health bar because it lives
##     inside the thing it is about.
##   * `ring()` — an arc, for a hold that has no box: the extraction hold draws
##     one around the bag number, because the thing being spent is what the ring
##     is drawn around.
##
## **The empty track is not decoration.** `bar()` draws the track whenever a hold
## is possible, at t01 = 0, before the player has touched anything. That empty
## track is the only pre-press tell that this prompt is a hold at all -- the word
## HOLD in the line says it in language, and this says it in shape, and one of
## the two will be the one that lands.
##
## Static, and drawing into whatever CanvasItem it is handed, because the
## callers are unrelated nodes (the HUD autoload, the trade screen, and whatever
## grows a hold next) and none of them should own the look.
##
## Screens built out of Control nodes rather than out of `_draw` call `bar()`
## through `HoldBar` (scripts/ui/hold_bar.gd) instead of directly: a Control
## draws its own commands BENEATH its children, so a menu that drew this over one
## of its own rows would render it behind that row's StyleBox. Same widget, same
## rule, one node of indirection.

## How thick the fill track is, in reference px (see `Pal.px`).
const BAR_H := 3.0


## A left-to-right fill inside `rect`. `t01` 0 draws the empty track alone.
##
## The track is the fill colour at low alpha rather than a separate palette
## entry: at 3 px a hue change reads as a different WIDGET, and this is one
## widget in two states.
##
## 0.38 and not the 0.22 this shipped with for an hour: the prompt plate is
## already `Color(VOID, 0.72)`, and a track at 0.22 over that was invisible in
## the capture -- which would have left the empty track claiming to be a tell
## while telling the player nothing. Measured off the frame, not off the number.
static func bar(canvas: CanvasItem, rect: Rect2, t01: float,
		col: Color = Pal.BONE) -> void:
	canvas.draw_rect(rect, Color(col, 0.38))
	var f := clampf(t01, 0.0, 1.0)
	if f <= 0.0:
		return
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x * f, rect.size.y)), col)


## A clockwise arc from 12 o'clock. Nothing is drawn at t01 = 0 -- a ring has no
## quiet empty state the way a bar does; an unfilled circle sitting over the HUD
## reads as a target reticle.
##
## Point count scales with the arc so a sliver is not a 48-segment polyline.
static func ring(canvas: CanvasItem, centre: Vector2, radius: float, t01: float,
		width: float, col: Color = Pal.BONE) -> void:
	var f := clampf(t01, 0.0, 1.0)
	if f <= 0.0:
		return
	canvas.draw_arc(centre, radius, -PI * 0.5, -PI * 0.5 + TAU * f,
		maxi(8, int(48 * f)), col, width)

## A rectangle's own frame redrawn as it fills, clockwise from the top-left
## corner. HUD_PLAN decision 15.
##
## The third construction, and it exists because the extraction hold had become a
## 54 px arc floating over the bag, centred on the anchor of a gold total that was
## deleted in 2026-08-09 — a ring around nothing, positioned by a ghost. The
## styleguide's argument for the ring was right ("you are literally drawing a ring
## around your money") and the BAG RIM already is that ring: it frames the bag, it
## is already 2 px, and its colour is already the thing that says what is at
## stake. So this deletes a widget and an anchor rather than moving them.
##
## Like `ring` and unlike `bar`, nothing is drawn at t01 = 0: the rim is already
## on screen in its own colour, and a second frame at zero would be a doubled
## border rather than an empty track.
##
## Drawn as four segments in corner order and not as a stroked rect, because a
## partial rect has no stroke — the whole point is that you can see how far round
## it has got.
static func frame(canvas: CanvasItem, rect: Rect2, t01: float,
		width: float, col: Color = Pal.BONE) -> void:
	var f := clampf(t01, 0.0, 1.0)
	if f <= 0.0:
		return
	# Perimeter walked clockwise from the top-left, so the four runs are the four
	# edges in the order a clock hand would meet them if the rect were a dial.
	var w := rect.size.x
	var h := rect.size.y
	var total := (w + h) * 2.0
	if total <= 0.0:
		return
	var want := total * f
	var tl := rect.position
	var legs := [
		[tl, Vector2(tl.x + w, tl.y), w],                              # top
		[Vector2(tl.x + w, tl.y), Vector2(tl.x + w, tl.y + h), h],     # right
		[Vector2(tl.x + w, tl.y + h), Vector2(tl.x, tl.y + h), w],     # bottom
		[Vector2(tl.x, tl.y + h), tl, h],                              # left
	]
	for leg: Array in legs:
		if want <= 0.0:
			return
		var a: Vector2 = leg[0]
		var b: Vector2 = leg[1]
		var len: float = leg[2]
		var take: float = minf(want, len)
		canvas.draw_line(a, a + (b - a).normalized() * take, col, width)
		want -= take
