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
## Until 2026-08-09 this was canvas-drawn rows: `DEEP AMBER X2` and a number, in a
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
## to the five slots they had the sense to pack. An extraction still shows one
## column, because the whole bag came back and a split there would be the screen
## inventing a distinction the ending did not make.
##
## Flow opens it and Flow closes it -- the button calls `Flow.to_garrison()`,
## and `Flow` is still the only thing in the project that changes scenes.

## Cells across, the pouch's number for the pouch's reason.
const COLS := ItemGrid.COLS
## Cells across on a death, where the haul is drawn as TWO columns: what the
## floor kept, and what the document case brought home (docs/GDD.md §3.1). The
## frame is 878 px of usable width; at the old 140 px card that bought 3 + 2.
## The compact 60 px square easily preserves 4 + 3 with room for the two ending
## captions, so the columns stay semantically stable rather than expanding just
## because the tile shrank.
const LOST_COLS := 4
const KEPT_COLS := 3
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
## Only the newly completed, known observations named on this receipt. This is
## deliberately not derived from the database or the full completed set: either
## would make an old entry look newly learned on every return.
var _field_notes: Array[StringName] = []
var _age: float = 0.0
var _armed: bool = false
var _leaving: bool = false

## The hover card, the same one the bag, the locker, the counters and the EQUIP
## page use. The receipt is the one screen where the player cannot ACT on a
## stack -- which is exactly why it is worth being able to read one: this is
## where they find out what a thing they have never seen before was worth.
var _tip: ItemTip
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
	UITheme.prewarm()
	theme = UITheme.theme()

	# The pointer is captured for camera look while you play; hand it back or the
	# one button on this screen cannot be clicked. FREED HERE, PUT BACK NOWHERE:
	# `GameCamera._settle_pointer` derives the way back from what is still up,
	# because a screen that remembers what it found and restores it is the bug
	# that has killed mouse look three times in this project.
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
	_field_notes = _valid_field_notes()


func _valid_field_notes() -> Array[StringName]:
	var out: Array[StringName] = []
	var raw: Variant = result.get("field_notes", [])
	if not raw is Array:
		return out
	for value: Variant in raw:
		if not value is StringName and not value is String:
			continue
		var id: StringName = StringName(value)
		if Game.has_completed_field_observation(id) and not out.has(id) \
				and not FieldNotesDb.display_text(id).is_empty():
			out.append(id)
	return out


func _stacks_of(contents: Dictionary, banked: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key in contents:
		var id := StringName(key)
		var def := ItemDb.get_def(id)
		if def == null:
			continue
		var n := int(contents[key])
		out.append({
			# The id, for the hover card: everything else in here is already
			# painted on the tile, and the card wants the def's own sentences.
			"id": id,
			"label": def.display_name,
			"count": n,
			"value": def.value * n,
			"color": def.tint,
			"icon": UiKit.item_icon(id),
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
	# `edge_to_edge`: the plate header, the band and the footer reach the frame's
	# edge and the body owns its inset, like every other window in the menu.
	UITheme.style_panel(frame, UITheme.FRAME_FACE_SOLID, true)
	frame.custom_minimum_size = Vector2(MenuUtil.FRAME_SIZE.x * 0.72, 0)
	centre.add_child(frame)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	frame.add_child(stack)

	_build_verdict(stack, dead, accent)
	_build_body(stack, dead, accent)
	_build_footer(stack)

	# Last, so it draws over the frame and over the cross.
	_tip = ItemTip.make(self)


## What one stack of the haul was, on the card beside it.
##
## `index` is into `rows` — the array the column was built from — because the
## grid packs its cells in order and the receipt has no holes. A padding cell
## reports -1 and the card goes away rather than keeping the last stack's
## sentences beside an empty square.
func _describe(rows: Array[Dictionary], grid: ItemGrid, index: int) -> void:
	if _tip == null:
		return
	if index < 0 or index >= rows.size():
		_tip.hide_tip()
		return
	var row := rows[index]
	var def := ItemDb.get_def(StringName(row.get("id", &"")))
	if def == null:
		_tip.hide_tip()
		return
	_tip.clear()
	_tip.point_at(grid.cell_for(index))
	_tip.kicker.text = "%s  ·  %s" % [def.rarity_name().to_upper(),
		def.bench_name() if def.is_component() else "INGREDIENT"]
	_tip.title.text = def.display_name
	_tip.price.text = "%d ◇  ·  %d in the pile" % [int(row["value"]), int(row["count"])]
	_tip.blurb.text = def.blurb
	# The one thing the receipt is FOR, said per stack: where this went. The tile
	# says BENCH or a number; the card says what that means.
	if bool(row["banked"]):
		_tip.say_note("To the workbench. The forge never pays gold for one.",
			UITheme.TEXT_DIM)
	elif died():
		_tip.say_note("The floor kept it." if grid.name == "Haul"
			else "It came home in the case.", UITheme.TEXT_DIM)
	else:
		_tip.say_note("The vendor buys this.", UITheme.TEXT_DIM)


## The headline, what killed you, and the run's four numbers.
##
## The ending's colour is the plate's LEFT EDGE, which is what `PlateHeader`'s
## `edge` is for: a semantic stripe down the identity band. It used to be the
## whole frame's border, tinted by duplicating the theme's StyleBoxFlat -- a
## trick the kit's frame cannot do (it is a StyleBoxTexture) and would not want
## to, since a coloured border on a window is the first step back into the
## asset-pack look § the palette note warns about. The claim it was making --
## "you can tell which ending this is from across the room, before a word of it
## is read" -- is unchanged; it is made by a stripe and a headline instead.
func _build_verdict(parent: Node, dead: bool, accent: Color) -> void:
	# `Prog.label`, the short form and not the name -- the receipt is already
	# unambiguously about the run you just made, so printing the dungeon's name
	# here would be the screen telling you something you have been looking at for
	# ten minutes.
	UiKit.plate_header(parent, {
		"kicker": Prog.label(int(result.get("level", 1))),
		"title": "You Died" if dead else "Recovered",
		"title_color": accent,
		"edge": accent,
		"emblem": "" if dead else UiKit.action_icon("leave"),
	})

	if dead:
		# Named, because "you died" is not information and "killed by an elite
		# wraith" is. An unclaimed kill says THE DARK rather than inventing an
		# attacker -- falling, a trap, or a hit whose owner never stamped itself.
		var killer := String(result.get("killer", &""))
		if killer.is_empty():
			killer = "THE DARK"
		var by := Label.new()
		UITheme.apply_text_style(by, UITheme.TYPE_PARAGRAPH_2, UITheme.DANGER)
		by.text = "Killed by %s" % killer.to_lower()
		by.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_bottom", 8)
		pad.add_child(by)
		parent.add_child(pad)

	UiKit.stat_band(parent, _band_cells(dead))


## What the run DID, as opposed to what it earned -- the earnings are the two
## big figures at the bottom, which are the screen's argument and do not belong
## in a row of small captions.
##
## The fee cell reads "—" on a death rather than "0": a `FEE PAID 0` line on a
## death screen reads as a refund, and the old tally hid the row entirely, which
## made the band four cells on one ending and three on the other.
func _band_cells(dead: bool) -> Array:
	var fee := int(result.get("fee", 0))
	return [
		{"label": "Rooms", "value": "%d" % int(result.get("depth", 0))},
		{"label": "Slain", "value": "%d" % int(result.get("kills", 0)),
			"icon": UiKit.action_icon("sword")},
		{"label": "Fee", "value": "—" if fee <= 0 else "%d ◇" % fee,
			"tone": null if fee <= 0 else UITheme.WARNING},
		{"label": "Stacks", "value": "%d" % (_rows.size() + _kept.size()),
			"icon": UiKit.action_icon("bag")},
	]


func _build_body(parent: Node, dead: bool, accent: Color) -> void:
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 20)
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	pad.add_child(col)

	_build_loot(col, dead, accent)
	_build_field_notes(col)
	_build_total(col, dead)


## The observations completed by this debrief, and no others. Two compact columns
## keep the worst case (all five observations) to three short rows at 720p.
func _build_field_notes(parent: Node) -> void:
	if _field_notes.is_empty():
		return

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel",
		UITheme.hud_box(UITheme.GRAY_1, 12, 6, 12, 6))
	parent.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	col.add_child(header)

	var title_label := Label.new()
	title_label.text = "FIELD NOTES READY"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_text_style(title_label, UITheme.TYPE_H3)
	header.add_child(title_label)

	var filing_hint := Label.new()
	filing_hint.text = "FILE THEM IN THE BOOK BY THE BED"
	UITheme.apply_text_style(filing_hint, UITheme.TYPE_PARAGRAPH_2, UITheme.SUCCESS)
	header.add_child(filing_hint)

	var awards := GridContainer.new()
	awards.columns = 2
	awards.add_theme_constant_override("h_separation", 18)
	awards.add_theme_constant_override("v_separation", 2)
	col.add_child(awards)
	for id: StringName in _field_notes:
		var line := HBoxContainer.new()
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_theme_constant_override("separation", 8)
		awards.add_child(line)

		var observed := Label.new()
		observed.text = FieldNotesDb.display_text(id)
		observed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.apply_text_style(observed, UITheme.TYPE_CAPTION, UITheme.TEXT)
		line.add_child(observed)

		var status := Label.new()
		status.text = "READY TO FILE"
		UITheme.apply_text_style(status, UITheme.TYPE_CAPTION, UITheme.SUCCESS)
		line.add_child(status)


## The bag, and the cross through it.
##
## **On a death this is two columns, side by side** (docs/GDD.md §3.1): the seven
## slots the floor kept, crossed out, and next to them the five the document
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
	card.add_theme_stylebox_override("panel", UITheme.well())
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

	# A Label and not a `section_rule`: a rule's text is gold, and both of these
	# captions are carrying a LOAD-BEARING colour -- the ending's accent on one,
	# CYAN on the case (docs/STYLEGUIDE.md §1). Same exception, same reason, as
	# the pouch's case caption.
	var caption := Label.new()
	UITheme.apply_text_style(caption, UITheme.TYPE_H3,
		UITheme.TEXT_DIM if struck else accent)
	caption.text = caption_text
	col.add_child(caption)

	if rows.is_empty():
		var none := Label.new()
		UITheme.apply_text_style(none, UITheme.TYPE_PARAGRAPH_2, UITheme.TEXT_DIM)
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
			"label": String(r["label"]),
			# Two numbers about one tile, which is the receipt and nothing else:
			# how many came back (top-left) and what the pile was worth (top
			# right). They used to be the name plus one line -- "Grave Wax ×2"
			# over "40 ◇" -- and on a square tile the ×2 is the first thing an
			# ellipsis eats.
			"tag": "×%d" % int(r["count"]),
			"sub": "BENCH" if bool(r["banked"]) else "%d ◇" % int(r["value"]),
			"tint": r["color"],
			"icon": r.get("icon", ""),
			"mark": bool(r["mark"]),
		})
	grid.set_cells(cells)

	# Nothing on this screen is choosable -- there is one button and it is in the
	# footer. Cells that could take FOCUS would put a highlight on a stack the
	# player cannot do anything with, and on the death screen that highlight would
	# sit on top of the cross.
	#
	# The POINTER is a different question and the answer changed with the card:
	# the cells stay unfocusable and stay unpressable, and they pass
	# `mouse_entered` so hovering one says what it was. A dismiss is read in
	# `_input`, which runs before the GUI phase, so a click on a cell still
	# closes the screen.
	for i in grid.count():
		var cell := grid.cell_at(i)
		cell.focus_mode = Control.FOCUS_NONE
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
	grid.cell_focused.connect(func(index: int) -> void: _describe(rows, grid, index))

	if struck:
		_strike = Strike.new()
		_strike.col = accent
		over.add_child(_strike)
		_strike.watch(grid)

	if rows.size() > shown:
		var more := Label.new()
		UITheme.apply_text_style(more, UITheme.TYPE_CAPTION, UITheme.TEXT_DIM)
		more.text = "+%d more" % (rows.size() - shown)
		col.add_child(more)


## The total, which on an extraction is what the vendor will pay and on a death is
## what the floor kept. Heat's premium is folded into `value` exactly as it is in
## `Run.bag_value()`, and called out separately when there is any, because a
## player who chained six kills earned that part deliberately.
func _build_total(parent: Node, dead: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var what := Label.new()
	UITheme.apply_text_style(what, UITheme.TYPE_H2,
		UITheme.DANGER if dead else UITheme.ACCENT)
	what.text = "LOST" if dead else "HAUL"
	what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	what.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(what)

	var premium := int(result.get("premium", 0))
	if premium > 0:
		var hot := Label.new()
		UITheme.apply_text_style(hot, UITheme.TYPE_CAPTION, UITheme.TEXT_DIM)
		hot.text = "including %d hot" % premium
		hot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(hot)

	var value := Label.new()
	UITheme.apply_text_style(value, UITheme.TYPE_TITLE,
		UITheme.DANGER if dead else UITheme.ACCENT)
	value.text = "%d ◇" % int(result.get("value", 0))
	row.add_child(value)

	# The second figure, and it goes under the first rather than beside it: LOST
	# and CAME HOME are not two halves of one sum, they are the two answers, and
	# putting them on one line would invite the player to subtract.
	if not dead:
		return
	var kept_row := HBoxContainer.new()
	kept_row.add_theme_constant_override("separation", 12)
	parent.add_child(kept_row)

	# CYAN, the way out, and the case is the way out that worked. Kept as `Pal`'s
	# game-semantic colour rather than a kit token, same as the column caption.
	var kept_what := Label.new()
	UITheme.apply_text_style(kept_what, UITheme.TYPE_H2, Pal.CYAN)
	kept_what.text = "CAME HOME"
	kept_what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kept_what.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	kept_row.add_child(kept_what)

	var kept_value := Label.new()
	UITheme.apply_text_style(kept_value, UITheme.TYPE_TITLE, Pal.CYAN)
	kept_value.text = "%d ◇" % int(result.get("kept_value", 0))
	kept_row.add_child(kept_value)


## The way home, and the one thing on this screen you can press.
##
## A single button rather than a "press any key" line: the run is over and going
## home is not a dismissal, it is the next move in the loop. The button that works
## is read off the live InputMap through `Glyph`, like every other prompt in the
## game, so a pad player is told A and a keyboard player is told ENTER.
func _build_footer(parent: Node) -> void:
	var footer := PanelContainer.new()
	footer.add_theme_stylebox_override("panel",
		UITheme.hud_box(UITheme.GRAY_1, 20, 12, 20, 12))
	parent.add_child(footer)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	footer.add_child(col)

	# The hub is the Highbridge garrison, not a town (docs/GDD.md §6).
	_button = Button.new()
	UITheme.style_pill_button(_button)
	_button.text = "BACK TO THE GARRISON"
	_button.focus_mode = Control.FOCUS_ALL
	_button.pressed.connect(_on_button)
	col.add_child(_button)

	var hint_text := _accept_hint()
	if hint_text.is_empty():
		return
	var hint := Label.new()
	UITheme.apply_text_style(hint, UITheme.TYPE_CAPTION, UITheme.TEXT_DIM)
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
## The cross, struck through each STACK the floor kept -- not through the column.
##
## One cross over the whole grid crossed out the empty space as well, which reads
## as "the column is void" rather than "these three stacks are gone", and on a
## death with one stack lost it drew a metre-wide X over a single cell's worth of
## loot. The loss is per item, so the mark is per item.
##
## The rects come from the grid's own cells rather than from arithmetic on
## columns and separations: the MarginContainer fits this overlay and the grid to
## the same rect, so a cell's position inside the grid is its position inside
## here, and a layout change cannot put the two out of step. It does mean the
## marks are only correct AFTER the grid has sorted, hence `sort_children`.
class Strike extends Control:
	var col: Color = Pal.VITAL

	var _grid: ItemGrid

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE

	func watch(grid: ItemGrid) -> void:
		_grid = grid
		if grid != null and not grid.sort_children.is_connected(queue_redraw):
			grid.sort_children.connect(queue_redraw)
		queue_redraw()

	func _draw() -> void:
		if _grid == null:
			return
		var line := Color(col, 0.85)
		for i in _grid.count():
			var cell := _grid.cell_at(i)
			if cell == null:
				continue
			# Inset so the arms end ON the cell rather than butting into the gap
			# between two cells, where two neighbouring crosses would touch and
			# read as one long zigzag.
			var r := Rect2(cell.position, cell.size).grow(-4.0)
			draw_line(r.position, r.end, line, 3.0)
			draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y),
				line, 3.0)
			draw_rect(r, Color(col, 0.5), false, 2.0)
