class_name MenuPaperDoll
extends Control
## The hero, drawn as a figure, with what he is holding hung off it.
##
## It lives on the POUCH because the pouch is the screen that answers "what have
## I got on me", and the two hands are on you in exactly the way the bag is.
## The bag is the part you can spend; this is the part you cannot.
##
## **It is read-only, deliberately.** Changing a hand is the ITEMS screen's job
## and the D-pad's, and there is exactly one of each in this game -- a second
## place to equip would be a second `cycle_armament` caller to keep honest, which
## is the drift `ArmamentDb`'s header is about. Nothing here takes focus, so the
## pouch's existing focus loop (cells → bench → rope → Back) is untouched by the
## column appearing beside it.
##
## **Why a drawn figure and not the hero's own model.** A SubViewport with the
## rig in it would cost a second camera, a second light, and an animation state
## to freeze, all for a 140 px card that has to read at a glance -- and it would
## show a character who owns no armour wearing exactly what he wore last screen.
## A silhouette says "you" in one shape, and the SLOTS are the information.
##
## Left hand on the left, right hand on the right -- viewer's order, not the
## hero's. It is the order `MenuEquipPanel.HANDS` puts them in and the order the
## HUD's two cells sit in, and three screens agreeing beats one of them being
## anatomically correct about a figure with its back to nothing.

## **Two sizes of the same figure, and only one figure.** `full` off is the
## pouch's card: the body, the two hands, the bound bottle. `full` on is the
## equipment screen's: the same body with the eight worn slots hung off it in two
## columns, armour down the left and the jewelcrafter's work down the right.
##
## One control and one `_draw`, not two scripts. A second paper doll is exactly
## the shape of the duplication CLAUDE.md §0 is about -- the two would agree on
## the day they were written and disagree by the second time a slot was added.
var full: bool = false

## Reference size. The card gives it whatever width it has; the height is a
## minimum so the figure does not squash on a short frame.
##
## 156 and not the 246 this was first drawn at. A `custom_minimum_size` inside a
## VBox inside a PanelContainer is a floor the parent frame does NOT get to
## refuse: at 246 the pouch's frame grew to ~697 px inside a 720 px viewport and
## the header sat on the top edge of the screen. Same trap the equip screen's
## SLOT_MIN comment warns about, arrived at from the other direction.
const MIN_SIZE := Vector2(140, 156)
## The full doll's floor. Two plate columns plus a body between them; below this
## the plates start eating the figure. Still comfortably inside 720p once the
## equip screen's header and footer are taken off.
const FULL_MIN_SIZE := Vector2(252, 336)
## Hand icons, in px. The equip screen's slots draw at 48 and have a 228 px card
## to do it in; here two of them plus a body have to share ~140.
const ICON_PX := 34

## One worn slot's plate: the name, what it committed to, and its rungs.
##
## 64 and not the 84 this was drawn at first. The column is ~250 px inside the
## equip screen's card, and at 84 the two stacks left the figure a 56 px lane --
## which capped the body at 145 px in a card 390 tall, so the doll came out as a
## thumbnail floating in white space with its plates touching each other. The
## widest thing any plate has to hold is "BRACELET", which is eight glyphs of
## PixelFont: 48 px, plus the padding either side.
const PLATE_W := 64.0
const PLATE_H := 44.0
## Between a plate's inner edge and the figure's lane.
const PLATE_GAP := 10.0
## How much of the body's height its arm span is: `half * 3` where `half` is
## `body_h * 0.115` (see `_draw_figure`). The full doll sizes the figure so that
## span fits the lane between the columns, rather than sizing the lane.
const SPAN_OF_H := 0.35
## Rung pips. Small, because four of them plus their gaps have to sit inside
## `PLATE_W` with the plate's own padding either side.
const PIP := 7.0
const PIP_GAP := 3.0

## The left column, top to bottom: the armour, in the order it is worn down the
## body. `ShopDb.groups()` puts the smith's board in this same order, so a player
## going from the counter to this screen finds the rows where they left them.
const ARMOUR: Array[StringName] = [&"chest", &"arms", &"legs", &"boots"]
## The right column: her four, in `Game.JEWEL_SLOTS` order.
const JEWELS: Array[StringName] = [&"amulet", &"ring1", &"ring2", &"bracelet"]
## Short enough for a 84 px plate. "SECOND RING" is not, and `JewelDb.BLANKS`
## has it at that length because a shop row has a whole line to spend.
const SLOT_NAMES := {
	&"chest": "CHEST", &"arms": "ARMS", &"legs": "LEGS", &"boots": "BOOTS",
	&"amulet": "AMULET", &"ring1": "RING I", &"ring2": "RING II",
	&"bracelet": "BRACELET",
}
## What an uncommitted slot says. Not blank: a plate with nothing in it reads as
## a slot that failed to draw, and this screen's whole job is telling you which
## of the eight you have not started.
const UNSET := "-"


func _ready() -> void:
	custom_minimum_size = FULL_MIN_SIZE if full else MIN_SIZE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The three things that can change what is drawn here, and the only three.
	# The world is paused behind this screen, so there is nothing to poll for --
	# but the ITEMS tab is one shoulder press away and a hand changed there has to
	# be on the figure when the player pages back.
	Bus.loadout_changed.connect(
		func(_s: int, _r: StringName, _l: StringName) -> void: queue_redraw())
	Bus.bottles_changed.connect(func(_c: Array) -> void: queue_redraw())
	Bus.item_selected_changed.connect(func(_i: int) -> void: queue_redraw())
	# The eight worn slots only ever change at a counter, and a counter is a
	# different screen -- but the menu is not torn down between the two, so the
	# doll has to hear about it rather than redraw on open.
	if full:
		Bus.item_acquired.connect(func(_id: StringName) -> void: queue_redraw())


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 40.0 or h < 80.0:
		return
	if full:
		_draw_full(w, h)
		return
	var cx := w * 0.5
	# The figure IS the control now. The three lines naming the slots are the
	# pouch's Labels below this, not something drawn in here.
	#
	# Capped against the WIDTH and centred in whatever height the card has. The
	# control is EXPAND_FILL, so on a tall frame it is handed 400+ px, and a body
	# drawn to fill that out of a 116 px column comes out as a stick insect. 1.55
	# is roughly a standing figure's own aspect.
	var body_h: float = minf(h * 0.94, w * 1.55)
	var top := (h - body_h) * 0.5
	_draw_figure(cx, top, body_h)
	# Belt over the torso, hands over the belt: the boxes are the information and
	# the body is the thing they hang off, so nothing on the figure occludes one.
	_draw_belt(cx, top + body_h * 0.60, body_h * 0.20)
	_draw_hands(cx, top, body_h)


# --- The full doll -------------------------------------------------------------

## The figure between two columns of plates, each plate wired to the part of the
## body it is worn on.
##
## **The leader lines are the reason this is a drawn control and not eight more
## Buttons in a VBox.** A list of "CHEST - HEAVY II" rows is the same eight facts
## and none of the reading: what a doll gives you is that the empty plate is
## attached to a leg, so "what have I not started" is answered by looking rather
## than by reading four labels and remembering which four you read.
func _draw_full(w: float, h: float) -> void:
	var cx := w * 0.5
	# The body gets the gap between the columns, and is sized to FIT it -- height
	# first, then cut back if the arms would reach into a plate. The other way
	# round (lane sets the height) is what produced the thumbnail; see PLATE_W.
	var lane: float = maxf(w - (PLATE_W + PLATE_GAP) * 2.0, 60.0)
	var body_h: float = minf(h * 0.94, lane / SPAN_OF_H)
	var top := (h - body_h) * 0.5

	# No hand boxes and no belt on this one. They are not missing -- they are two
	# columns to the right, as four cards big enough to read the weapon's name off,
	# which is more than a 34 px box on a hip ever said. Drawn here as well they
	# were a third copy of a fact this screen already makes twice, and the two
	# icons sat exactly where the ARMS and RING leaders come in.
	_draw_figure(cx, top, body_h)

	var half := body_h * 0.115
	var shoulder := top + body_h * 0.115 * 2.4
	var hip := top + body_h * 0.60
	# Where each plate's leader lands. Measured off the same skeleton
	# `_draw_figure` builds, so a change to the figure moves the wires with it.
	var anchors := {
		&"chest": Vector2(cx - half * 0.9, shoulder + body_h * 0.07),
		&"arms": Vector2(cx - half * 1.42, hip + body_h * 0.02),
		&"legs": Vector2(cx - half * 0.45, hip + body_h * 0.12),
		&"boots": Vector2(cx - half * 0.72, top + body_h * 0.98),
		&"amulet": Vector2(cx + half * 0.25, shoulder + body_h * 0.01),
		&"ring1": Vector2(cx + half * 1.46, hip + body_h * 0.05),
		&"ring2": Vector2(cx + half * 1.5, hip + body_h * 0.09),
		&"bracelet": Vector2(cx + half * 1.34, hip - body_h * 0.02),
	}

	var span := body_h - PLATE_H
	for i in ARMOUR.size():
		var y := top + span * (float(i) / float(ARMOUR.size() - 1))
		_draw_plate(Vector2(0.0, y), ARMOUR[i], anchors[ARMOUR[i]], false)
	for i in JEWELS.size():
		var y := top + span * (float(i) / float(JEWELS.size() - 1))
		_draw_plate(Vector2(w - PLATE_W, y), JEWELS[i], anchors[JEWELS[i]], true)


## One worn slot. The plate, its leader, and the three facts on it: which slot,
## which path it committed to, and how far up that path it is.
func _draw_plate(at: Vector2, slot: StringName, anchor: Vector2,
		jewel: bool) -> void:
	var paths: Array = JewelDb.PATHS[slot] if jewel \
		else [Game.PLATE_HEAVY, Game.PLATE_LIGHT]
	var rungs: int = K.JEWEL_MAX if jewel else K.FORGE_MAX
	# "Which path did this commit to" is not stored anywhere -- it is answered by
	# asking which of the two siblings has a rung in it (game_state.gd's note over
	# PLATE_PIECES). One reader of that rule per screen; this is this screen's.
	var path: StringName = &""
	var level := 0
	for p: StringName in paths:
		var track: StringName = Game.jewel_track(slot, p) if jewel \
			else Game.plate_track(slot, p)
		var n: int = Game.jewel_level(track) if jewel else Game.forge_level(track)
		if n > 0:
			path = p
			level = n
			break

	var r := Rect2(at, Vector2(PLATE_W, PLATE_H))
	var live := level > 0
	draw_rect(r, Color(Pal.MIDNIGHT, 0.92))
	draw_rect(r, Color(Pal.MOTH, 0.85) if live else Color(Pal.ASH, 0.7), false, 1.0)

	# The wire, from the plate's inner edge to the body. Drawn AFTER the plate's
	# fill so it does not show through it, and dimmer than either -- it is
	# saying "this plate is about that part of you", which is a thing you should
	# be able to stop seeing once you have seen it.
	var from := Vector2(r.end.x if at.x < anchor.x else r.position.x,
		r.position.y + PLATE_H * 0.5)
	var col := Color(Pal.MOTH, 0.45) if live else Color(Pal.ASH, 0.4)
	# A dog-leg, not a diagonal: the elbow is at the plate's own height, so eight
	# of these crossing the same figure stay tellable apart.
	var knee := Vector2(lerpf(from.x, anchor.x, 0.55), from.y)
	draw_line(from, knee, col, 1.0)
	draw_line(knee, anchor, col, 1.0)
	draw_circle(anchor, 2.0, col)

	var pad := 5.0
	PixelFont.draw_text(self, String(SLOT_NAMES.get(slot, slot)),
		r.position + Vector2(pad, pad), 1.0, Color(Pal.MOTH, 0.95))
	var tag := String(JewelDb.PATH_INFO[path]["label"]) if jewel and live \
		else (String(path).to_upper() if live else UNSET)
	PixelFont.draw_text(self, tag, r.position + Vector2(pad, pad + 11.0), 1.0,
		Pal.BONE if live else Color(Pal.ASH, 0.9))
	_draw_pips(Vector2(r.position.x + pad, r.end.y - pad - PIP), rungs, level)


## The ladder, as filled and hollow pips. This is the number the player came to
## the screen for -- "how much of this piece have I bought" -- and it is a shape
## rather than a numeral so that eight of them read as one picture.
func _draw_pips(at: Vector2, count: int, filled: int) -> void:
	for i in count:
		var p := Rect2(at + Vector2(float(i) * (PIP + PIP_GAP), 0.0),
			Vector2(PIP, PIP))
		if i < filled:
			draw_rect(p, Pal.GOLD)
		else:
			draw_rect(p, Color(Pal.ASH, 0.85), false, 1.0)


# --- The figure ---------------------------------------------------------------

## Head, torso, arms, legs, and a pip at each joint. The pips are what make it
## read as a jointed body rather than as a keyhole made of rectangles -- the same
## trick the map's chest glyph uses, where the band is doing all the work.
func _draw_figure(cx: float, top: float, h: float) -> void:
	var head_r := h * 0.115
	var shoulder := top + head_r * 2.4
	var hip := top + h * 0.60
	var foot := top + h
	var half := h * 0.115          # half the torso's width

	var skin := Color(Pal.ASH, 0.95)
	var edge := Color(Pal.MOTH, 0.55)
	var limb: float = maxf(h * 0.055, 3.0)

	# Legs first, so the torso's hem sits over them.
	for s: float in [-1.0, 1.0]:
		_limb(Vector2(cx + s * half * 0.45, hip),
			Vector2(cx + s * half * 0.75, foot), limb, skin)
	# Arms, hanging. Not raised: a figure with its arms out is a figure doing
	# something, and this one is standing still holding what it holds.
	for s: float in [-1.0, 1.0]:
		_limb(Vector2(cx + s * half, shoulder + h * 0.03),
			Vector2(cx + s * half * 1.5, hip + h * 0.06), limb, skin)

	# Torso: shoulders wider than the waist, which is the whole silhouette.
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - half * 1.15, shoulder),
		Vector2(cx + half * 1.15, shoulder),
		Vector2(cx + half * 0.85, hip),
		Vector2(cx - half * 0.85, hip),
	]), skin)
	# Solid, with a neck under it. It was a thick `draw_arc` over a smaller filled
	# circle for one render and came out a doughnut -- the ring and the fill were
	# two greys a shade apart and the hole read as a hole.
	_limb(Vector2(cx, top + head_r * 1.6), Vector2(cx, shoulder), limb, skin)
	draw_circle(Vector2(cx, top + head_r), head_r, skin)

	# The joints. Three pips a side, and the whole reason the shape reads as a
	# body you could pose.
	for p: Vector2 in [
		Vector2(cx - half, shoulder + h * 0.03),
		Vector2(cx + half, shoulder + h * 0.03),
		Vector2(cx - half * 0.45, hip), Vector2(cx + half * 0.45, hip),
	]:
		draw_circle(p, limb * 0.55, edge)


## One bone, as a thick line with rounded ends. `draw_line` is fine here and not
## in `MapDraw`: these are diagonal and 4 px thick, where the soft edge is the
## point rather than the bug.
func _limb(a: Vector2, z: Vector2, w: float, col: Color) -> void:
	draw_line(a, z, col, w, true)


# --- The slots ----------------------------------------------------------------

## An icon box either side of the torso, at the height a hand would be.
func _draw_hands(cx: float, top: float, h: float) -> void:
	var y := top + h * 0.42
	var reach: float = minf(size.x * 0.5 - ICON_PX * 0.5 - 4.0, h * 0.30)
	for i in 2:
		var hand: StringName = Game.HAND_LEFT if i == 0 else Game.HAND_RIGHT
		var side: float = -1.0 if i == 0 else 1.0
		_slot(Vector2(cx + side * reach, y), ICON_PX, Game.armament(hand))


## The bound item cell, at the belt. It is the third thing the HUD's cluster
## draws and the third thing you are carrying without it costing a bag slot, so
## it belongs on the figure rather than in the grid.
func _draw_belt(cx: float, y: float, box: float) -> void:
	var potion := Game.selected_potion()
	# Narrower than the hand boxes and than the waist it sits on. At the torso's
	# full width it stopped reading as a box hung on a belt and started reading
	# as a pair of shorts.
	var g: float = minf(box, ICON_PX) * 0.78
	var r := Rect2(Vector2(cx, y) - Vector2(g, g) * 0.5, Vector2(g, g))
	draw_rect(r, Color(Pal.MIDNIGHT, 0.9))
	# The same border the hands get, so the three slots read as one set rather
	# than as two slots and a patch of clothing.
	draw_rect(r, Color(Pal.MOTH, 0.7) if potion != &"" else Color(Pal.ASH, 0.75),
		false, 1.0)
	if potion == &"":
		return
	draw_rect(r.grow(-g * 0.26), PotionDb.tint_of(potion))


## One equipment box: the armament's baked icon, or its two letters when it has
## none. Never an empty box with nothing in it -- an empty cell reads as "you
## have no sword", which is the lie `ArmamentDb.LETTERS` exists to prevent.
func _slot(c: Vector2, g: float, id: StringName) -> void:
	var r := Rect2(c - Vector2(g, g) * 0.5, Vector2(g, g))
	draw_rect(r, Color(Pal.MIDNIGHT, 0.85))
	draw_rect(r, Color(Pal.MOTH, 0.7) if id != &"" else Color(Pal.ASH, 0.6),
		false, 1.0)
	var tex := ArmamentDb.icon(id)
	if tex != null:
		# NEAREST, like every other place these bakes are drawn: they are 5-bit
		# posterised and a bilinear stretch turns the palette into a gradient.
		draw_texture_rect(tex, r.grow(-2.0), false, Color.WHITE)
		return
	# No icon: the letters, centred, in the HUD's own font so the fallback looks
	# like the rest of the game rather than like a missing asset.
	var text := ArmamentDb.letter(id)
	var scale: float = maxf(floorf(g / 16.0), 1.0)
	# `draw_centred` centres horizontally and takes the TOP of the line, so the
	# vertical half is on this side.
	PixelFont.draw_centred(self, text,
		Vector2(c.x, c.y - PixelFont.height(scale) * 0.5), scale,
		Pal.MOTH if id != &"" else Color(Pal.ASH, 0.8))
