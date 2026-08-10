class_name RunEndScreen
extends Control
## The end of a run, both ways it can end. One screen, because there is one
## question: what did that cost, and what did I come back with.
##
## The two endings are the same receipt with a different verdict on it. EXTRACTED
## prices the haul and shows the toll you paid; YOU DIED shows the identical grid
## with a cross struck through it, which is the whole point -- the loss has to be
## legible as the specific things you decided to keep carrying, not as a number
## going to zero. A separate death screen would have been a second place for the
## loot list, the value arithmetic and the layout to drift apart, and it would have
## made the two endings feel like different games instead of two outcomes of one
## decision (docs/METAGAME.md §3).
##
## **What it replaced.** A `Label3D` in the garrison scene that said "YOU DIED /
## LOST N ITEMS" over the yard. It was authored at (0, 2.6, +6.6) and the arrival
## camera sits at (0, 1.7, +8) pitched down about thirty degrees, so the label was
## roughly sixty degrees above the middle of the only frame a returning player ever
## sees: the game had a death notice that nobody had ever read. It also arrived AFTER
## the fade, in the garrison, which is the wrong room -- a run ends underground
## and the screen that says so belongs over the floor it ended on.
##
## ## The haul is a GRID, and it is the bag's grid
##
## Until 2026-08-09 this was PixelFont rows: `DEEP AMBER X2` and a number, in a
## column. That was the same deep amber the player had been looking at as a
## tinted cell for the whole run -- in the pouch, at the vendor, on the locker's
## shelf -- and at the one moment that matters most, the moment it is taken away
## from them, it arrived as a line of text. `ItemGrid` fixes that: the cells here
## are the pouch's cells, so the cross is drawn over the actual picture of the bag
## rather than over a description of it.
##
## The frame, the header and the footer are the pause menu's theme for the same
## reason. The only thing that departs from it is the BORDER, which goes red on a
## death and cyan on an extraction -- one authored colour, carrying the outcome
## before a word of the panel is read.
##
## ## A death has two columns
##
## Since the document case (docs/GDD.md §3.1) there is a second grid beside the
## crossed one: what the case brought home. It is a column and not a footnote
## because the case is only forgiveness if the player can see it *against* what
## it did not save — the amber they went one room too far for, crossed out, next
## to the three slots they had the sense to pack. An extraction still shows one
## column, because the whole bag came back and a split there would be the screen
## inventing a distinction the ending did not make.
##
## Flow opens it and Flow closes it -- the button calls `Flow.to_garrison()`,
## and `Flow` is still the only thing in the project that changes scenes.

const THEME_PATH := "res://scenes/ui/menu/menu_theme.tres"
## Cells across, the pouch's number for the pouch's reason.
const COLS := 4
## Cells across on a death, where the haul is drawn as TWO columns: what the
## floor kept, and what the document case brought home (docs/GDD.md §3.1). The
## frame is 878 px of usable width, so 3 + 2 cells at 140 plus separations comes
## to 736 and fits with room to spare — 4 + 3 does not.
const LOST_COLS := 3
const KEPT_COLS := 2
## Cells of loot, before the haul starts running off the panel. Twelve bag slots
## is the ceiling the forge sells up to, so this is "all of it" today and a clamp
## rather than a scroller on purpose: a run summary you have to page through is a
## summary that failed.
const MAX_ROWS := 12
## Seconds before the button will answer. Long enough that the press that killed
## you -- or the rope you were still holding -- cannot also dismiss the screen you
## have not read yet. The accept below is release-armed as well; this is the
## belt for the case where the player is simply leaning on the button.
const SETTLE := 0.45

## What `Run.summary` said when this opened. Copied rather than read live: the
## button starts a scene change, and `Run.enter()` on the far side of it will
## clear the thing this screen is still drawing during the fade.
var result: Dictionary = {}

var _rows: Array[Dictionary] = []
## The case's stacks, built the same way. Only ever non-empty on a death, because
## an extraction brings the whole bag home and splitting it in two would be the
## screen inventing a distinction the ending did not make.
var _kept: Array[Dictionary] = []
var _age: float = 0.0
var _armed: bool = false
var _leaving: bool = false

var _button: Button
var _strike: Strike


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
	theme = load(THEME_PATH) as Theme

	# The pointer is captured for camera look while you play; hand it back or the
	# one button on this screen cannot be clicked.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_rows()
	_build()
	_fit()
	get_viewport().size_changed.connect(_fit)
	Prompt.block(self)
	Bus.screen_opened.emit(&"run_end")


func _exit_tree() -> void:
	Prompt.unblock(self)
	Bus.screen_closed.emit(&"run_end")


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func died() -> bool:
	return not bool(result.get("extracted", false))


# --- Rows -------------------------------------------------------------------

## One cell per stack, richest first.
##
## Sorted by what the stack is WORTH and not by name or by pickup order, because
## on the death screen this grid is an argument: the thing in the top-left is what
## you should have gone home with, and burying it under eleven bone shards makes
## the screen a receipt instead of a lesson.
func _build_rows() -> void:
	var banked: Dictionary = result.get("banked", {})
	_rows = _stacks_of(result.get("contents", {}), banked)
	# Only on a death. `died()` is not consulted here on purpose -- `kept` is
	# simply absent from an extraction's summary, so an empty second column and a
	# missing one are the same thing and neither needs a branch.
	_kept = _stacks_of(result.get("kept", {}), banked)


func _stacks_of(contents: Dictionary, banked: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key in contents:
		var id := StringName(key)
		var def := ItemDb.get_def(id)
		if def == null:
			continue
		var n := int(contents[key])
		out.append({
			"label": def.display_name,
			"count": n,
			"value": def.value * n,
			"color": def.tint,
			"mark": def.is_component(),
			# Components banked to the workbench are not money and must not be
			# priced like money -- the forge never pays gold for one. They get the
			# cyan "TO THE BENCH" instead, which is also the only way the screen
			# can explain why they are missing from the vendor total.
			"banked": banked.has(key) or banked.has(id),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["value"]) > int(b["value"]))
	return out


# --- Building ----------------------------------------------------------------

func _build() -> void:
	var dead := died()
	var accent: Color = Pal.VITAL if dead else Pal.CYAN

	# Heavier than the shop's 0.86. The shop is a conversation you are having in
	# a garrison you are safe in; this is the room going quiet.
	var dim := ColorRect.new()
	dim.color = Color(Pal.VOID, 0.93)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var centre := CenterContainer.new()
	add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var frame := PanelContainer.new()
	frame.name = "Frame"
	frame.theme_type_variation = &"MenuFrame"
	frame.custom_minimum_size = Vector2(MenuUtil.FRAME_SIZE.x * 0.72, 0)
	centre.add_child(frame)

	# The one deliberate departure from the menu theme. The border says which
	# ending this is from across the room, before a word of it is read, which is
	# what the old hand-drawn panel's coloured edge did and the only part of it
	# worth keeping. A duplicate of the theme's box rather than a second authored
	# StyleBox, so the corner radius and the fill stay the menu's.
	var box := frame.get_theme_stylebox(&"panel", &"MenuFrame")
	if box is StyleBoxFlat:
		var edged := (box as StyleBoxFlat).duplicate() as StyleBoxFlat
		edged.border_color = accent
		frame.add_theme_stylebox_override(&"panel", edged)

	var stack := VBoxContainer.new()
	stack.theme_type_variation = &"MenuStack"
	frame.add_child(stack)

	_build_verdict(stack, dead, accent)
	_build_body(stack, dead, accent)
	_build_footer(stack)


## The headline, the floor it happened on, and -- if it was a death -- what did it.
func _build_verdict(parent: Node, dead: bool, accent: Color) -> void:
	var header := PanelContainer.new()
	header.theme_type_variation = &"MenuHeader"
	parent.add_child(header)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	header.add_child(col)

	var top := HBoxContainer.new()
	col.add_child(top)

	# `Prog.label`, the short form and not the name -- the receipt is already
	# unambiguously about the run you just made, so printing the dungeon's name
	# here would be the screen telling you something you have been looking at for
	# ten minutes.
	var where := Label.new()
	where.theme_type_variation = &"MenuMuted"
	where.text = Prog.label(int(result.get("level", 1)))
	where.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(where)

	var rooms := Label.new()
	rooms.theme_type_variation = &"MenuMuted"
	rooms.text = "%d ROOMS" % int(result.get("depth", 0))
	rooms.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(rooms)

	var verdict := Label.new()
	verdict.theme_type_variation = &"MenuTitle"
	verdict.text = "YOU DIED" if dead else "EXTRACTED"
	verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	verdict.modulate = accent
	col.add_child(verdict)

	if not dead:
		return
	# Named, because "you died" is not information and "killed by an elite
	# wraith" is. An unclaimed kill says THE DARK rather than inventing an
	# attacker -- falling, a trap, or a hit whose owner never stamped itself.
	var killer := String(result.get("killer", &""))
	if killer.is_empty():
		killer = "THE DARK"
	var by := Label.new()
	by.theme_type_variation = &"MenuHint"
	by.text = "KILLED BY %s" % killer
	by.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	by.modulate = Pal.RUST
	col.add_child(by)


func _build_body(parent: Node, dead: bool, accent: Color) -> void:
	var pad := MarginContainer.new()
	pad.theme_type_variation = &"MenuBodyPad"
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	pad.add_child(col)

	_build_tally(col)
	_build_loot(col, dead, accent)
	_build_total(col, dead)


## What the run did, as opposed to what it earned.
func _build_tally(parent: Node) -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = &"MenuSection"
	parent.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	card.add_child(col)

	_stat_row(col, "ENEMIES SLAIN", "%d" % int(result.get("kills", 0)), Pal.BONE)

	# The toll, and only on the ending that charged one. A "FEE PAID 0" line on a
	# death screen reads as a refund.
	var fee := int(result.get("fee", 0))
	if fee > 0:
		_stat_row(col, "TELEPORT FEE", "-%d" % fee, Pal.GOLD)


func _stat_row(parent: Node, what: String, value: String, tint: Color) -> void:
	var row := HBoxContainer.new()
	row.theme_type_variation = &"MenuStatRow"
	parent.add_child(row)

	var a := Label.new()
	a.theme_type_variation = &"MenuSlotStat"
	a.text = what
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(a)

	var b := Label.new()
	b.theme_type_variation = &"MenuValue"
	b.text = value
	b.modulate = tint
	row.add_child(b)


## The bag, and the cross through it.
##
## **On a death this is two columns, side by side** (docs/GDD.md §3.1): the nine
## slots the floor kept, crossed out, and next to them the three the document
## case brought home, not crossed. They are drawn at the same moment, in the same
## card, at the same cell size, because the case is only forgiveness if you can
## SEE it against what it did not save — a second screen, or a line of text
## underneath, would turn the one comparison this pass exists to make into two
## separate facts.
##
## An extraction stays one column. Everything came back, so a split would be the
## receipt inventing a distinction the ending did not make.
func _build_loot(parent: Node, dead: bool, accent: Color) -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = &"MenuSection"
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(card)

	if not dead:
		_build_column(card, "WHAT CAME BACK", _rows, COLS, false, accent)
		return

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	_build_column(row, "WHAT THE FLOOR KEPT", _rows, LOST_COLS, true, accent)
	# CYAN, the way out (docs/STYLEGUIDE.md §1). The case is the other way out --
	# the one that worked when the rope did not.
	#
	# "Nothing was packed" and not "Empty handed": an empty case is not bad luck,
	# it is a decision the player made by never opening the pouch, and that
	# sentence is the only thing on the screen that can say so.
	_build_column(row, "THE CASE BROUGHT HOME", _kept, KEPT_COLS, false, Pal.CYAN,
		"Nothing was packed.")


## One captioned grid, struck through or not.
func _build_column(parent: Node, caption_text: String, rows: Array[Dictionary],
		cols: int, struck: bool, accent: Color,
		empty_text: String = "Empty handed.") -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(col)

	var caption := Label.new()
	caption.theme_type_variation = &"MenuHeading"
	caption.text = caption_text
	if not struck:
		caption.modulate = accent
	col.add_child(caption)

	if rows.is_empty():
		var none := Label.new()
		none.theme_type_variation = &"MenuMuted"
		none.text = empty_text
		col.add_child(none)
		return

	# The grid and the cross share one rect, which is the whole reason there is a
	# MarginContainer here rather than the grid straight in the column: a
	# MarginContainer fits EVERY child to its rect, so the overlay lines up with
	# the cells by construction instead of by two sets of coordinates that have to
	# be kept in step.
	var over := MarginContainer.new()
	col.add_child(over)

	var grid := ItemGrid.new()
	grid.name = "Kept" if not struck and cols == KEPT_COLS else "Haul"
	grid.columns = cols
	over.add_child(grid)

	var shown: int = mini(rows.size(), MAX_ROWS)
	var cells: Array = []
	for i in shown:
		var r := rows[i]
		cells.append({
			"index": i,
			"label": "%s ×%d" % [String(r["label"]), int(r["count"])],
			"sub": "BENCH" if bool(r["banked"]) else "%d ◇" % int(r["value"]),
			"tint": r["color"],
			"mark": bool(r["mark"]),
		})
	grid.set_cells(cells)

	# Nothing on this screen is choosable -- there is one button and it is in the
	# footer. Cells that could take focus would put a highlight on a stack the
	# player cannot do anything with, and on the death screen that highlight would
	# sit on top of the cross.
	for i in grid.count():
		var cell := grid.cell_at(i)
		cell.focus_mode = Control.FOCUS_NONE
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if struck:
		_strike = Strike.new()
		_strike.col = accent
		over.add_child(_strike)

	if rows.size() > shown:
		var more := Label.new()
		more.theme_type_variation = &"MenuMuted"
		more.text = "+%d more" % (rows.size() - shown)
		col.add_child(more)


## The total, which on an extraction is what the vendor will pay and on a death is
## what the floor kept. Heat's premium is folded into `value` exactly as it is in
## `Run.bag_value()`, and called out separately when there is any, because a
## player who chained six kills earned that part deliberately.
func _build_total(parent: Node, dead: bool) -> void:
	var row := HBoxContainer.new()
	row.theme_type_variation = &"MenuStatRow"
	parent.add_child(row)

	var what := Label.new()
	what.theme_type_variation = &"MenuHeading"
	what.text = "LOST" if dead else "HAUL"
	what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(what)

	var premium := int(result.get("premium", 0))
	if premium > 0:
		var hot := Label.new()
		hot.theme_type_variation = &"MenuMuted"
		hot.text = "including %d hot" % premium
		row.add_child(hot)

	var value := Label.new()
	value.theme_type_variation = &"MenuTitle"
	value.text = "%d ◇" % int(result.get("value", 0))
	value.modulate = Pal.RUST if dead else Pal.GOLD
	row.add_child(value)

	# The second figure, and it goes under the first rather than beside it: LOST
	# and CAME HOME are not two halves of one sum, they are the two answers, and
	# putting them on one line would invite the player to subtract.
	if not dead:
		return
	var kept_row := HBoxContainer.new()
	kept_row.theme_type_variation = &"MenuStatRow"
	parent.add_child(kept_row)

	var kept_what := Label.new()
	kept_what.theme_type_variation = &"MenuHeading"
	kept_what.text = "CAME HOME"
	kept_what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kept_what.modulate = Pal.CYAN
	kept_row.add_child(kept_what)

	var kept_value := Label.new()
	kept_value.theme_type_variation = &"MenuTitle"
	kept_value.text = "%d ◇" % int(result.get("kept_value", 0))
	kept_value.modulate = Pal.CYAN
	kept_row.add_child(kept_value)


## The way home, and the one thing on this screen you can press.
##
## A single button rather than a "press any key" line: the run is over and going
## home is not a dismissal, it is the next move in the loop. The button that works
## is read off the live InputMap through `Glyph`, like every other prompt in the
## game, so a pad player is told A and a keyboard player is told ENTER.
func _build_footer(parent: Node) -> void:
	var footer := PanelContainer.new()
	footer.theme_type_variation = &"MenuFooter"
	parent.add_child(footer)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	footer.add_child(col)

	# The hub is the Highbridge garrison, not a town (docs/GDD.md §6).
	_button = Button.new()
	_button.theme_type_variation = &"MenuCommand"
	_button.text = "BACK TO THE GARRISON"
	_button.focus_mode = Control.FOCUS_ALL
	_button.pressed.connect(_on_button)
	col.add_child(_button)

	var hint_text := _accept_hint()
	if hint_text.is_empty():
		return
	var hint := Label.new()
	hint.theme_type_variation = &"MenuHint"
	hint.text = hint_text
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)


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

	# Breathes while it waits, so a screen with one control on it does not read as
	# a still image the player is meant to admire. Disabled until SETTLE, because
	# a button that looks live before it answers is a button the player files as
	# broken.
	var ready := _age >= SETTLE
	_button.disabled = not ready
	_button.modulate = Color.WHITE if ready else Color(1, 1, 1,
		0.45 + 0.25 * (0.5 + 0.5 * sin(_age * 3.4)))

	var down := Input.is_action_pressed(&"ui_accept") \
		or Input.is_action_pressed(&"interact") \
		or Input.is_action_pressed(&"context")
	if not down:
		_armed = true
	elif _armed and ready:
		_armed = false
		_leave()


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


func _on_button() -> void:
	if _age >= SETTLE:
		_leave()


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	# Flow owns the transition and the fade. It also un-pauses the tree -- this
	# screen does not, because the fade should run over a world that is still
	# stopped rather than let the monsters get one more swing in behind it.
	Flow.to_garrison()


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


## The X over the haul. Two bars corner to corner across the whole grid, plus a
## box around it, so it reads as one thing crossed out rather than as decoration
## between the cells.
##
## Drawn OVER the cells, not instead of them. The grid has to stay readable
## through the cross -- being told you lost 340 gold means nothing next to seeing
## the deep amber you went one room too far for with a line through it. It is a
## leaf Control and a sibling of the grid for `HoldBar`'s reason: a Control draws
## its own commands BENEATH its children, so a cross drawn by the card over its
## own cells would render behind every one of their StyleBoxes.
class Strike extends Control:
	var col: Color = Pal.VITAL

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var line := Color(col, 0.75)
		draw_line(r.position, r.end, line, 3.0)
		draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y),
			line, 3.0)
		draw_rect(r, Color(col, 0.45), false, 2.0)
