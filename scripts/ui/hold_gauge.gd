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
## Static, and drawing into whatever CanvasItem it is handed, because the three
## callers are three unrelated nodes (the HUD autoload, the trade screen, and
## whatever grows a hold next) and none of them should own the look.

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
