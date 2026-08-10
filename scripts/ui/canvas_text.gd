class_name CanvasText
extends RefCounted
## Canvas-drawn UI text, set in the game's DISPLAY face — `UITheme.display_font()`,
## which is Cinzel SemiBold.
##
## This is the hard-edged voice of the HUD, the loading card, the world-facing
## prompts and the run-end tally: everything that is painted with `draw_*` onto a
## CanvasItem rather than typeset into a Control. Screens built from Controls go
## through `UITheme.apply_text_style` instead; this is the same two-face system
## seen from the canvas side, so a header reads as the same header either way.
##
## ## It used to be a 5x7 bitmap
##
## Until 2026-08-10 this class was `PixelFont`: a table of 5x7 glyph rows drawn
## as one `draw_rect` per lit pixel, with no font file behind it. It was replaced
## because the game had shipped two real OFL faces (see `UITheme.BODY_TTF`) and
## the HUD was still the only surface in the build that ignored them — a pixel
## grid under Cinzel menus reads as an unfinished screen, not as a treatment.
##
## Three things went with it, and each is worth knowing before you write a string:
##
##  * **The glyph table.** There is no MISSING block any more, so a character the
##    face lacks falls through to the system fallback (`allow_system_fallback` is
##    on) rather than drawing as a solid cell. The arrows ↑ ↓ ← → come from there.
##  * **Monospace.** Widths are MEASURED now, so a counter rolling 90 -> 100 can
##    reflow while it counts. Every number in the HUD is drawn with `draw_right`,
##    which pins the end that matters; keep it that way.
##  * **Integer scaling.** A curved face does not want to land on the pixel grid,
##    so `scale_for` deliberately does NOT round the way `Pal.px` does.
##
## ## The scale contract, unchanged
##
## `scale` is screen pixels per "font pixel" and a line of capitals is `H` font
## pixels tall — so `height(scale)` is the cap height, and `draw_text` puts the
## TOP of the capitals at `at.y`. Every layout in `hud.gd` is written in those
## units and none of them had to move.

## Cap height of one line, in font pixels. Kept from the 5x7 grid so the call
## sites' `N / CanvasText.H` sizing still means "N screen px tall".
const H := 7

## Cinzel's capitals stand at 0.70 em. The em size we ask TextServer for is
## therefore TALLER than the cap height we advertise — that is the whole reason
## this constant exists rather than passing `H * scale` straight to draw_string,
## which would render every label a third smaller than the layout expects.
const CAP_RATIO := 0.70

## Below this the flared serifs close up and the line turns to mush (the same
## floor `UITheme.display_font()` documents). Small HUD readouts at 720p land
## near it, so it is a clamp and not an assert.
const MIN_SIZE := 9


static func font() -> Font:
	return UITheme.display_font()


## Screen px per font px for a measurement authored at `ref_px` tall against
## `Pal.REF_H`. Use this instead of `Pal.px(ref_px / CanvasText.H, screen_h)`:
## `Pal.px` rounds to a whole pixel, which was correct for a bitmap and costs a
## 10px label 30% of its height at 720p now that it is a vector face.
static func scale_for(ref_px: float, screen_h: float) -> float:
	return maxf(MIN_SIZE * CAP_RATIO / H, ref_px * screen_h / Pal.REF_H / H)


## The em size TextServer is asked for, given our cap-height scale.
static func size_of(scale: float) -> int:
	return maxi(MIN_SIZE, int(round(H * scale / CAP_RATIO)))


## Width of `text` in screen pixels at `scale`. Uppercased first, because
## `draw_text` uppercases and a measurement of the other string is a wrong one.
static func width(text: String, scale: float) -> float:
	if text.is_empty():
		return 0.0
	return font().get_string_size(text.to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, size_of(scale)).x


static func height(scale: float) -> float:
	return H * scale


## Break `text` on spaces so no line exceeds `max_width` screen pixels, capped at
## `max_lines` (the overflow is dropped, not squeezed).
##
## This measures now rather than counting characters — the old version could do
## the latter only because every glyph was the same width. It exists because the
## shop drew its blurb as one unwrapped line and the longer forge blurbs ran out
## through the right edge of the panel and kept going.
static func wrap(text: String, scale: float, max_width: float,
		max_lines: int = 2) -> PackedStringArray:
	var lines := PackedStringArray()
	var line := ""
	for word in text.split(" ", false):
		var candidate: String = word if line.is_empty() else line + " " + word
		if width(candidate, scale) <= max_width:
			line = candidate
			continue
		if not line.is_empty():
			lines.append(line)
			if lines.size() >= max_lines:
				return lines
		# A single word wider than the line gets cut rather than overhanging.
		line = word
		while line.length() > 1 and width(line, scale) > max_width:
			line = line.substr(0, line.length() - 1)
	if not line.is_empty() and lines.size() < max_lines:
		lines.append(line)
	return lines


## Draw `text` with the TOP of its capitals at `at`. Returns the advance width.
##
## Uppercased: Cinzel's lowercase is a small-cap, so the face is at its most
## itself in capitals, and every string in this game was written for a table that
## had no lowercase at all. Do not "fix" a caller by giving it sentence case
## without looking at the frame.
##
## The baseline sits at `at.y + height(scale)` — cap top at `at.y`, exactly where
## the bitmap's first lit row used to be, which is why no layout moved.
static func draw_text(ci: CanvasItem, text: String, at: Vector2,
		scale: float, color: Color) -> float:
	var up := text.to_upper()
	var size := size_of(scale)
	ci.draw_string(font(), Vector2(at.x, at.y + height(scale)), up,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	return font().get_string_size(up, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Same, but the text ENDS at `right`. Every number in this HUD is right-aligned
## so the digits stay put as the value grows — which matters more now than it did
## under a monospaced table, because the glyphs no longer share a width.
static func draw_right(ci: CanvasItem, text: String, right: Vector2,
		scale: float, color: Color) -> void:
	draw_text(ci, text, Vector2(right.x - width(text, scale), right.y), scale, color)


static func draw_centred(ci: CanvasItem, text: String, centre: Vector2,
		scale: float, color: Color) -> void:
	draw_text(ci, text, Vector2(
		centre.x - width(text, scale) * 0.5, centre.y), scale, color)
