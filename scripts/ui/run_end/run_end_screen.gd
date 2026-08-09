class_name RunEndScreen
extends Control
## The end of a run, both ways it can end. One screen, because there is one
## question: what did that cost, and what did I come back with.
##
## The two endings are the same receipt with a different verdict on it. EXTRACTED
## prices the haul and shows the toll you paid; YOU DIED shows the identical list
## with a cross struck through it, which is the whole point -- the loss has to be
## legible as the specific things you decided to keep carrying, not as a number
## going to zero. A separate death screen would have been a second place for the
## loot list, the value arithmetic and the layout to drift apart, and it would have
## made the two endings feel like different games instead of two outcomes of one
## decision (docs/METAGAME.md §3).
##
## **What it replaced.** A `Label3D` in the town scene that said "YOU DIED / LOST
## N ITEMS" over the yard. It was authored at (0, 2.6, +6.6) and the arrival camera
## sits at (0, 1.7, +8) pitched down about thirty degrees, so the label was roughly
## sixty degrees above the middle of the only frame a returning player ever sees:
## the game had a death notice that nobody had ever read. It also arrived AFTER the
## fade, in town, which is the wrong room -- a run ends underground and the screen
## that says so belongs over the floor it ended on.
##
## Drawn with PixelFont and Pal, not Control children and a Theme, for the reason
## the HUD and the shop are: docs/STYLEGUIDE.md bans the engine's fallback font,
## and a summary screen in Open Sans next to a HUD made of whole pixels is the
## loudest "unfinished" signal the game could send.
##
## Flow opens it and Flow closes it -- BACK TO TOWN calls `Flow.to_town()`, and
## `Flow` is still the only thing in the project that changes scenes.

## Rows of loot, before the list starts scrolling into the footer. Twelve bag
## slots is the ceiling the forge sells up to, so this is "all of it" today and a
## clamp rather than a scroller on purpose: a run summary you have to page through
## is a summary that failed.
const MAX_ROWS := 12
const PAD := 22.0
const ROW_H := 22.0
## Seconds before the button will answer. Long enough that the press that killed
## you -- or the rope you were still holding -- cannot also dismiss the screen you
## have not read yet. The edges below are release-armed as well; this is the
## belt for the case where the player is simply leaning on the button.
const SETTLE := 0.45

## What `Run.summary` said when this opened. Copied rather than read live: the
## button starts a scene change, and `Run.enter()` on the far side of it will
## clear the thing this screen is still drawing during the fade.
var result: Dictionary = {}

var _rows: Array[Dictionary] = []
var _age: float = 0.0
var _armed: bool = false
var _hover: bool = false
var _leaving: bool = false
var _button: Rect2 = Rect2()


## Put one over the current scene. `host` only has to be in the tree.
##
## Its own CanvasLayer at 150: above the HUD (50), Feel's vignette (60) and the
## pause menu (100), below Flow's fade (200) so the ride home draws over this and
## not under it.
static func open(host: Node, summary: Dictionary) -> RunEndScreen:
	var layer := CanvasLayer.new()
	layer.name = "RunEndLayer"
	layer.layer = 150
	var s := RunEndScreen.new()
	s.result = summary.duplicate(true)
	layer.add_child(s)
	var parent: Node = host.get_tree().current_scene
	if parent == null:
		parent = host.get_tree().root
	parent.add_child(layer)
	return s


func _ready() -> void:
	# A Control parented straight to a CanvasLayer is outside the viewport's
	# Control tree, so anchors never resolve and it sits at size (0,0). Size it
	# from the viewport and keep it there. (Same note as TradeScreen.)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fit()
	get_viewport().size_changed.connect(_fit)

	# The pointer is captured for camera look while you play; hand it back or the
	# one button on this screen cannot be clicked.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_rows()
	Prompt.block(self)
	Bus.screen_opened.emit(&"run_end")


func _exit_tree() -> void:
	Prompt.unblock(self)
	Bus.screen_closed.emit(&"run_end")


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	queue_redraw()


func died() -> bool:
	return not bool(result.get("extracted", false))


# --- Rows -------------------------------------------------------------------

## One row per stack, richest first.
##
## Sorted by what the line is WORTH and not by name or by pickup order, because
## on the death screen this list is an argument: the thing at the top is what you
## should have gone home with, and burying it under eleven bone shards makes the
## screen a receipt instead of a lesson.
func _build_rows() -> void:
	_rows.clear()
	var contents: Dictionary = result.get("contents", {})
	var banked: Dictionary = result.get("banked", {})
	for key in contents:
		var id := StringName(key)
		var def := ItemDb.get_def(id)
		if def == null:
			continue
		var n := int(contents[key])
		_rows.append({
			"label": def.display_name,
			"count": n,
			"value": def.value * n,
			"color": Pal.rarity_color(int(def.rarity)),
			# Components banked to the workbench are not money and must not be
			# priced like money -- the forge never pays gold for one. They get the
			# cyan "TO THE BENCH" instead, which is also the only way the screen
			# can explain why they are missing from the vendor total.
			"banked": banked.has(key) or banked.has(id),
		})
	_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["value"]) > int(b["value"]))


# --- Input ------------------------------------------------------------------

## Polled, and release-armed, for the reasons trade_screen.gd sets out at length:
## `Input.action_press()` from the capture harness never synthesises an InputEvent,
## so a screen that only listens to `_unhandled_input` cannot be exercised by a
## tool; and a confirm that depends on catching a one-frame `just_pressed` is a
## confirm that occasionally does nothing.
func _process(delta: float) -> void:
	_age += delta
	if _leaving:
		return

	var down := Input.is_action_pressed(&"ui_accept") \
		or Input.is_action_pressed(&"interact") \
		or Input.is_action_pressed(&"context")
	if not down:
		_armed = true
	elif _armed and _age >= SETTLE:
		_armed = false
		_leave()
	queue_redraw()


## Swallow the buttons that would open something UNDER this screen.
##
## `_input` runs before every `_unhandled_input` in the tree, which is where the
## pause menu and the pouch listen. Without this, Escape during the ending screen
## opens a pause menu at layer 100 -- invisible behind this one at 150, holding
## the focus, and clearing `get_tree().paused` on the way out from under a screen
## that is relying on it.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel") \
			or event.is_action_pressed(&"inventory"):
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var was := _hover
		_hover = _button.has_point((event as InputEventMouseMotion).position)
		if was != _hover:
			queue_redraw()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT \
				and _button.has_point(mb.position) and _age >= SETTLE:
			_leave()


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	# Flow owns the transition and the fade. It also un-pauses the tree -- this
	# screen does not, because the fade should run over a world that is still
	# stopped rather than let the monsters get one more swing in behind it.
	Flow.to_town()


# --- Draw -------------------------------------------------------------------

func _draw() -> void:
	var s := size
	if s.x < 1.0 or s.y < 1.0:
		return

	var dead := died()
	# Heavier than the shop's 0.86. The shop is a conversation you are having in
	# a town you are safe in; this is the room going quiet.
	draw_rect(Rect2(Vector2.ZERO, s), Color(Pal.VOID, 0.93))

	var pad := Pal.px(PAD, s.y)
	# The panel is MEASURED, not chosen.
	#
	# It was a flat 80% of the screen height, and on a four-line haul -- which is
	# most runs -- that left half a screen of empty midnight between the total and
	# the button. A box with a third of it blank does not read as a receipt; it
	# reads as a form with fields the game failed to fill in.
	#
	# `_body` therefore runs twice: once with the ink off to find out how tall the
	# content is, then for real inside a border cut to fit. Two passes over one
	# layout rather than a second set of height expressions to keep in step -- a
	# measurement that can drift from the thing it measures is how you get a
	# clipped last row nobody notices until a run with twelve stacks in the bag.
	var pw := s.x * 0.60
	var need := _body(s, Rect2(s.x * 0.20, 0.0, pw, s.y), pad, pad, dead, true) + pad
	var ph := minf(need, s.y * 0.94)
	var panel := Rect2(s.x * 0.20, (s.y - ph) * 0.5, pw, ph)
	draw_rect(panel, Color(Pal.MIDNIGHT, 0.96))
	draw_rect(panel, Pal.RUST if dead else Pal.CYAN, false, Pal.px(2.0, s.y))
	_body(s, panel, pad, panel.position.y + pad, dead, false)


## Everything inside the border, top to bottom, returning the y it ended at.
##
## `dry` draws nothing and only walks the layout. It is the whole reason the panel
## can be the size of its contents.
func _body(s: Vector2, panel: Rect2, pad: float, y: float, dead: bool,
		dry: bool) -> float:
	y = _draw_verdict(s, panel, pad, y, dead, dry)
	y = _draw_tally(s, panel, pad, y, dry)
	y = _draw_loot(s, panel, pad, y, dead, dry)
	return _draw_button(s, panel, pad, y, dry)


## The headline, the floor it happened on, and -- if it was a death -- what did it.
func _draw_verdict(s: Vector2, panel: Rect2, pad: float, y: float,
		dead: bool, dry: bool) -> float:
	var floor_no := int(result.get("level", 1))
	var ft := Pal.px(12.0 / PixelFont.H, s.y)
	if not dry:
		# `Prog.label`, the short form and not the name -- the receipt is already
		# unambiguously about the run you just made, so printing the dungeon's
		# name here would be the screen telling you something you have been
		# looking at for ten minutes.
		PixelFont.draw_text(self, Prog.label(floor_no),
			Vector2(panel.position.x + pad, y), ft, Pal.MOTH)
		PixelFont.draw_right(self, "%d ROOMS" % int(result.get("depth", 0)),
			Vector2(panel.end.x - pad, y), ft, Pal.MOTH)
	y += PixelFont.height(ft) + Pal.px(14.0, s.y)

	var ht := Pal.px(30.0 / PixelFont.H, s.y)
	if not dry:
		PixelFont.draw_centred(self, "YOU DIED" if dead else "EXTRACTED",
			Vector2(panel.get_center().x, y), ht, Pal.VITAL if dead else Pal.CYAN)
	y += PixelFont.height(ht) + Pal.px(10.0, s.y)

	if dead:
		# Named, because "you died" is not information and "killed by an elite
		# wraith" is. An unclaimed kill says THE DARK rather than inventing an
		# attacker -- falling, a trap, or a hit whose owner never stamped itself.
		var killer := String(result.get("killer", &""))
		if killer.is_empty():
			killer = "THE DARK"
		var kt := Pal.px(14.0 / PixelFont.H, s.y)
		if not dry:
			PixelFont.draw_centred(self, "KILLED BY %s" % killer,
				Vector2(panel.get_center().x, y), kt, Pal.RUST)
		y += PixelFont.height(kt)

	return y + Pal.px(16.0, s.y)


## What the run did, as opposed to what it earned.
func _draw_tally(s: Vector2, panel: Rect2, pad: float, y: float,
		dry: bool) -> float:
	var t := Pal.px(14.0 / PixelFont.H, s.y)
	if not dry:
		PixelFont.draw_text(self, "ENEMIES SLAIN",
			Vector2(panel.position.x + pad, y), t, Pal.BONE)
		PixelFont.draw_right(self, "%d" % int(result.get("kills", 0)),
			Vector2(panel.end.x - pad, y), t, Pal.BONE)
	y += PixelFont.height(t) + Pal.px(6.0, s.y)

	# The toll, and only on the ending that charged one. A "FEE PAID 0" line on a
	# death screen reads as a refund.
	var fee := int(result.get("fee", 0))
	if fee > 0:
		if not dry:
			PixelFont.draw_text(self, "TELEPORT FEE",
				Vector2(panel.position.x + pad, y), t, Pal.BONE)
			PixelFont.draw_right(self, "-%d" % fee,
				Vector2(panel.end.x - pad, y), t, Pal.GOLD)
		y += PixelFont.height(t) + Pal.px(6.0, s.y)

	var rule_y := y + Pal.px(8.0, s.y)
	if not dry:
		draw_rect(Rect2(panel.position.x + pad, rule_y,
			panel.size.x - pad * 2.0, Pal.px(1.0, s.y)), Pal.ASH)
	# 20 and not 14: the death screen's cross is boxed, and its top edge starts
	# slightly ABOVE the first row. At 14 that edge landed a couple of pixels under
	# this rule and the two read as one doubled line.
	return rule_y + Pal.px(20.0, s.y)


## The bag, and the cross through it.
func _draw_loot(s: Vector2, panel: Rect2, pad: float, y: float,
		dead: bool, dry: bool) -> float:
	var t := Pal.px(13.0 / PixelFont.H, s.y)
	var row_h := Pal.px(ROW_H, s.y)
	var top := y

	if _rows.is_empty():
		if not dry:
			PixelFont.draw_centred(self, "EMPTY HANDED",
				Vector2(panel.get_center().x, y), t, Pal.MOTH)
		return y + PixelFont.height(t) + Pal.px(10.0, s.y)

	var shown: int = mini(_rows.size(), MAX_ROWS)
	if not dry:
		for i in shown:
			var row := _rows[i]
			var line_y := y + row_h * i
			PixelFont.draw_text(self, "%s X%d" % [row["label"], int(row["count"])],
				Vector2(panel.position.x + pad, line_y), t, row["color"])
			if bool(row["banked"]):
				PixelFont.draw_right(self, "TO THE BENCH",
					Vector2(panel.end.x - pad, line_y), t, Pal.CYAN)
			else:
				PixelFont.draw_right(self, "%d" % int(row["value"]),
					Vector2(panel.end.x - pad, line_y), t, Pal.GOLD)
	y += row_h * shown
	if _rows.size() > shown:
		if not dry:
			PixelFont.draw_text(self, "+%d MORE" % (_rows.size() - shown),
				Vector2(panel.position.x + pad, y), t, Pal.MOTH)
		y += row_h

	# The total, which on an extraction is what the vendor will pay and on a death
	# is what the floor kept. Heat's premium is folded into `value` exactly as it
	# is in Run.bag_value(), and called out separately when there is any, because
	# a player who chained six kills earned that part deliberately.
	y += Pal.px(6.0, s.y)
	var vt := Pal.px(18.0 / PixelFont.H, s.y)
	var value := int(result.get("value", 0))
	if not dry:
		PixelFont.draw_text(self, "LOST" if dead else "HAUL",
			Vector2(panel.position.x + pad, y), vt, Pal.BONE)
		PixelFont.draw_right(self, "%d" % value,
			Vector2(panel.end.x - pad, y), vt, Pal.RUST if dead else Pal.GOLD)
	y += PixelFont.height(vt)

	var premium := int(result.get("premium", 0))
	if premium > 0:
		var pt := Pal.px(11.0 / PixelFont.H, s.y)
		y += Pal.px(4.0, s.y)
		if not dry:
			PixelFont.draw_right(self, "INCLUDING %d HOT" % premium,
				Vector2(panel.end.x - pad, y), pt, Pal.MOTH)
		y += PixelFont.height(pt)

	if dead and not dry:
		_strike(Rect2(panel.position.x + pad * 0.6, top - Pal.px(4.0, s.y),
			panel.size.x - pad * 1.2, y - top + Pal.px(8.0, s.y)), s)
	return y + Pal.px(12.0, s.y)


## The X over the haul. Two bars corner to corner across the whole block, plus a
## box around it, so it reads as one thing crossed out rather than as decoration
## between the rows.
##
## Drawn LAST over the list, not instead of it. The list has to stay readable
## through the cross -- being told you lost 340 gold means nothing next to seeing
## the deep amber you went one room too far for with a line through it.
func _strike(r: Rect2, s: Vector2) -> void:
	var w := Pal.px(3.0, s.y)
	var col := Color(Pal.VITAL, 0.75)
	draw_line(r.position, r.end, col, w)
	draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y),
		col, w)
	draw_rect(r, Color(Pal.VITAL, 0.45), false, Pal.px(2.0, s.y))


## BACK TO TOWN, and the one thing on this screen you can press.
##
## A single button rather than a "press any key" line: the run is over and going
## home is not a dismissal, it is the next move in the loop. It carries the button
## that works read off the live InputMap through `Glyph`, like every other prompt
## in the game, so a pad player is told A and a keyboard player is told ENTER.
##
## It sits in the content flow under the haul rather than pinned to the panel's
## floor. Pinned, it was as far from the total as the panel was tall -- and the
## panel was a fixed 80% of the screen, so on a short run the only control on the
## screen was half a screen away from the only thing on it worth reading.
func _draw_button(s: Vector2, panel: Rect2, pad: float, y: float,
		dry: bool) -> float:
	var t := Pal.px(16.0 / PixelFont.H, s.y)
	var label := "BACK TO TOWN"
	var bw := PixelFont.width(label, t) + pad * 2.0
	var bh := PixelFont.height(t) + pad
	y += Pal.px(12.0, s.y)
	var r := Rect2(panel.get_center().x - bw * 0.5, y, bw, bh)

	if not dry:
		# Only the real pass owns the hit rect. The measuring pass runs against a
		# panel parked at y = 0, and a click tested against that rect would answer
		# a press made a screen's height above the button.
		_button = r
		var ready := _age >= SETTLE
		# Breathes while it waits, so a screen with one control on it does not read
		# as a still image the player is meant to admire.
		var pulse := 0.5 + 0.5 * sin(_age * 3.4)
		var edge := Pal.BONE if (_hover or _leaving) else Color(Pal.BONE,
			0.45 + 0.4 * pulse)
		if not ready:
			edge = Color(Pal.ASH, 0.6)
		draw_rect(r, Color(Pal.ASH, 0.35 if _hover else 0.18))
		draw_rect(r, edge, false, Pal.px(2.0, s.y))
		PixelFont.draw_centred(self, label,
			Vector2(r.get_center().x, r.position.y + (bh - PixelFont.height(t)) * 0.5),
			t, Pal.BONE if ready else Pal.MOTH)
	y = r.end.y

	var hint := _accept_hint()
	if not hint.is_empty():
		var ct := Pal.px(11.0 / PixelFont.H, s.y)
		y += Pal.px(7.0, s.y)
		if not dry:
			PixelFont.draw_centred(self, hint,
				Vector2(panel.get_center().x, y), ct, Pal.MOTH)
		y += PixelFont.height(ct)
	return y


## "ENTER", or "A" on a pad.
##
## `Glyph.long` and not `Glyph.cap`, which is the one place in the project that
## wants the long form: `cap` is the four-character squeeze for the HUD's 40 px
## key cells, and this line has a whole panel to sit in. Under a button the
## abbreviation is a worse answer than the word -- which is how "ENTE" got here in
## the first place (see Glyph.cap_for).
func _accept_hint() -> String:
	var e := Glyph.event_for(&"ui_accept", Settings != null and Settings.using_pad)
	return "" if e == null else Glyph.long(e)
