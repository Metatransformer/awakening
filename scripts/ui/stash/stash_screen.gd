class_name StashScreen
extends Control
## The footlocker's screen. One grid of the things you own, each cell saying how
## many are on the shelf and how many are on you. Left puts it away, right takes
## it back.
##
## ## Why this is not `TradeScreen` with a third mode
##
## It nearly is, and the resemblance is deliberate down to the panel rect — a
## player should recognise this as the same furniture the vendor is made of. But
## `TradeScreen` answers *one* question per cell ("do I want this at that price")
## with one commit on one button, and every part of it is shaped by that: the
## price is the only GOLD thing on the screen, the hold gauge marks the commits
## that eat components, the footer asks the catalogue why it said no.
## A locker asks a different question — *which side of the room does this live
## on* — and it answers with a direction rather than a confirmation. Threading a
## two-way transfer through `_commit`, `_verb` and `_hold_time` would have made
## all three of them ask "which mode is this" before doing anything, which is the
## drift the single trade screen exists to prevent (see its class doc).
##
## What IS shared is shared, and that includes the picture: the cells are
## `ItemGrid`, the chrome is `UITheme` and `UiKit` — the same `PlateHeader`,
## `StatBand` and `FooterToast` the counters wear — and the polled input, the
## panel geometry and the footer's `Glyph` caps are what they always were.
## Nothing here re-invents a widget. This screen was the last place in the game
## where a stack of amber was a line of text rather than an amber-tinted cell,
## which meant the bag looked like one game and the shelf you were moving it onto
## looked like another.
##
## ## Nothing in this file writes the bag or the shelf
##
## Deposit is `Run.consume` + `Game.stash_add`; withdrawal is `Run.collect` +
## `Game.stash_take`. Both directions are two calls in that order, and the order
## is the whole safety argument: each of those functions returns HOW MANY it
## actually moved, so the second call is always given the first one's answer
## rather than what was asked for. A full locker and a full bag are then the same
## kind of event — a smaller number came back — and neither can duplicate a
## stack or drop one on the floor between two dictionaries.

## Cells across, and the shop's number for the shop's reason: four was measured
## against this same frame width.
const COLS := 4
const DETAIL_W := 340

## Between the two counts on a cell. The stored figure is on the LEFT of the
## arrow and the carried figure on the right, which is the same spatial mapping
## the buttons use — see `_tick_input`.
const SWAP := " ⇄ "

## The prop that opened this. Held only so the locker can be told to shut its
## lid; see `Footlocker.activate`.
var host: Node = null

var _rows: Array[Dictionary] = []
var _cursor: int = 0
var _refuse: float = -1.0
var _refuse_why: String = ""
var _closing: bool = false

var _grid: ItemGrid
## The `StatBand` and the slot it is rebuilt into. Two of its cells move on every
## transfer and one follows the cursor, so those are written through
## `UiKit.band_value` rather than by rebuilding under the focused cell.
var _band: Control
var _band_slot: VBoxContainer
var _empty: Label
var _d_kind: Label
var _d_name: Label
var _d_split: Label
var _d_blurb: Label
var _hint: Label
var _hold_bar: HoldBar
## The refusal, as a `FooterToast`. `_refuse` and `_refuse_why` survive alongside
## it because `tools/directors/house_rest.gd` reads both to prove the screen said
## WHY it would not take a stack.
var _toast: Control
var _toast_slot: VBoxContainer


## Same construction as `TradeScreen.open`, and for the same reason its note
## gives: a Control parented to a Node3D never draws, and the caller is a chest
## standing in a 3D garrison.
static func open(from: Node) -> StashScreen:
	var layer := CanvasLayer.new()
	layer.name = "StashLayer"
	# 60. Above the HUD, below the pause menu, exactly where the trade screen
	# sits — and for the reason its note now gives: Escape and Start CLOSE this
	# screen and no longer also raise the menu behind it.
	layer.layer = 60
	var s := StashScreen.new()
	s.host = from
	layer.add_child(s)
	from.get_tree().current_scene.add_child(layer)
	return s


## What the pointer was doing before this screen took the viewport.
##
## FREED HERE, PUT BACK NOWHERE. `GameCamera._settle_pointer` owns the way back
## and derives it from what is still up; a screen that remembers what it found
## and restores it is the bug documented in that note, which has now cost this
## project mouse look three separate times.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	UITheme.prewarm()
	theme = UITheme.theme()
	_build()
	_fit()
	get_viewport().size_changed.connect(_fit)
	_build_rows()
	# The camera captures the pointer for look. Hand it back or not one cell on
	# this screen can be clicked.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Prompt.block(self)
	Bus.screen_opened.emit(&"stash")


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _exit_tree() -> void:
	Prompt.unblock(self)
	Bus.screen_closed.emit(&"stash")


func close() -> void:
	if _closing:
		return
	_closing = true
	var layer := get_parent()
	if layer is CanvasLayer:
		layer.queue_free()
	else:
		queue_free()


# --- Building ----------------------------------------------------------------

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(Pal.VOID, 0.86)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var centre := CenterContainer.new()
	add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var frame := PanelContainer.new()
	frame.name = "Frame"
	# `edge_to_edge`: the header plate, the band and the footer reach the frame
	# edge and the body between them owns its own inset. Same as the counters.
	UITheme.style_panel(frame, UITheme.FRAME_FACE_SOLID, true)
	frame.custom_minimum_size = MenuUtil.FRAME_SIZE
	centre.add_child(frame)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	frame.add_child(stack)

	_build_header(stack)
	_build_body(stack)
	_build_footer(stack)


func _build_header(parent: Node) -> void:
	UiKit.plate_header(parent, {
		"kicker": "Stow · Retrieve",
		"title": "Footlocker",
		"emblem": UiKit.action_icon("locker"),
	})

	# Where the purse sits on the trade screen, because the band answers the same
	# glance — "how much of this have I got left". SLOTS, not coin: the locker
	# never sees gold, and drawing a gold figure on a screen with no price on it
	# is the lie `docs/GDD.md` §6.3 forbids of the relic receipt.
	_band_slot = VBoxContainer.new()
	_band_slot.add_theme_constant_override("separation", 0)
	parent.add_child(_band_slot)
	_rebuild_band()


## Both capacities, then the shape of the job. SHELF and BAG are the two things
## a transfer can run out of, so they lead and they go WARNING at the brim —
## the refusal toast then confirms what the band already warned about, instead of
## being the first the player hears of it.
func _band_cells() -> Array:
	var shelf := Game.stash_slots_used()
	var bag := Run.slots_used()
	return [
		{"key": &"shelf", "label": "Shelf",
			"value": "%d/%d" % [shelf, K.STASH_SLOTS],
			"icon": UiKit.action_icon("locker"),
			"tone": UITheme.WARNING if shelf >= K.STASH_SLOTS else null},
		{"key": &"bag", "label": "Bag",
			"value": "%d/%d" % [bag, Game.bag_slots],
			"icon": UiKit.action_icon("bag"),
			"tone": UITheme.WARNING if bag >= Game.bag_slots else null},
		{"label": "Kinds", "value": str(_rows.size())},
		# Written by `_describe`, because it follows the cursor rather than the
		# transfer — the one cell a rebuild would get wrong.
		{"key": &"split", "label": "This kind", "value": "—"},
	]


func _rebuild_band() -> void:
	if _band_slot == null:
		return
	for child in _band_slot.get_children():
		child.queue_free()
		_band_slot.remove_child(child)
	_band = UiKit.stat_band(_band_slot, _band_cells())
	# The `split` cell is left at its "—" placeholder. It is the cursor's cell, and
	# `_refresh` calls `_point_at` -> `_describe` immediately after this — which is
	# also the only order that works, because the first band is built from
	# `_build_header`, before the detail pane the describer writes exists.


func _build_body(parent: Node) -> void:
	var pad := MarginContainer.new()
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 20)
	parent.add_child(pad)

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 24)
	pad.add_child(split)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	split.add_child(left)

	var card := PanelContainer.new()
	# A sunken recess, not a raised card: the grid is a thing you reach INTO.
	card.add_theme_stylebox_override("panel", UITheme.well())
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(card)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	card.add_child(inner)

	# The caption is the legend for every cell's second line. The two counts on a
	# cell are a bare pair of numbers, and a bare pair of numbers reads either way
	# round — this is the one place that says which is which, so it is worded in
	# the same order and with the same arrow the cells use.
	UITheme.section_rule(inner, "ON THE SHELF%sIN THE BAG" % SWAP)

	_grid = ItemGrid.new()
	_grid.name = "Kinds"
	_grid.columns = COLS
	_grid.cell_focused.connect(_on_cell_looked)
	inner.add_child(_grid)

	_empty = Label.new()
	_empty.text = "Nothing to put away."
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_text_style(_empty, UITheme.TYPE_PARAGRAPH_2, UITheme.TEXT_DIM)
	inner.add_child(_empty)

	_build_detail(split)


func _build_detail(parent: Node) -> void:
	var card := PanelContainer.new()
	card.name = "Detail"
	UITheme.style_panel(card, UITheme.BG_INSET)
	card.custom_minimum_size = Vector2(DETAIL_W, 0)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)

	# The kicker/title/number stack of a `PlateHeader`, written by hand because
	# this one is REWRITTEN on every cursor move — see the same note on
	# `TradeScreen._build_detail`.
	_d_kind = Label.new()
	UITheme.apply_text_style(_d_kind, UITheme.TYPE_CAPTION, UITheme.ACCENT)
	col.add_child(_d_kind)

	_d_name = Label.new()
	_d_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_text_style(_d_name, UITheme.TYPE_H1, UITheme.TEXT)
	col.add_child(_d_name)

	# The cell's second line, spelled out in words. The cell has room for "2 ⇄ 3"
	# and the arrow is learnable, but there is no reason to make the player learn
	# it when the pane beside the cursor can just say it.
	_d_split = Label.new()
	_d_split.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_text_style(_d_split, UITheme.TYPE_PARAGRAPH_1, UITheme.ACCENT)
	col.add_child(_d_split)

	_d_blurb = Label.new()
	_d_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_blurb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UITheme.apply_text_style(_d_blurb, UITheme.TYPE_PARAGRAPH_2, UITheme.TEXT_DIM)
	col.add_child(_d_blurb)


## The refusal is a `FooterToast` and NOT the hint line recoloured, which is what
## it used to be. "← STOW  RETRIEVE →  HOLD FOR ALL" is the one line telling a
## player which way the thumb goes, and it vanished at exactly the moment a
## refused transfer had them looking for it.
func _build_footer(parent: Node) -> void:
	var footer := PanelContainer.new()
	footer.add_theme_stylebox_override("panel",
		UITheme.hud_box(UITheme.GRAY_1, 20, 10, 20, 10))
	parent.add_child(footer)

	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	footer.add_child(row)

	_toast_slot = VBoxContainer.new()
	_toast_slot.add_theme_constant_override("separation", 0)
	_toast_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_toast_slot)

	_hint = Label.new()
	UITheme.apply_text_style(_hint, UITheme.TYPE_CAPTION, UITheme.TEXT_DIM)
	row.add_child(_hint)

	_hold_bar = HoldBar.new()
	_hold_bar.col = Pal.BONE
	row.add_child(_hold_bar)


# --- Rows -------------------------------------------------------------------

## One cell per ITEM KIND, not per location — the whole point of the screen is to
## compare the two piles of the same thing, and a stack that was split across
## both would otherwise be two cells the player has to add up themselves.
##
## Relics are refused, and refused HERE only for the drawing: `Run.consume` would
## happily take one out of the bag, and `RelicDb` would then have a unique that
## exists in a dictionary nobody unpacks. A relic is not merchandise and it is not
## material — it goes to the Society and nowhere else (`docs/GDD.md` §6.3), and
## `Run.extract` already moved it out of the bag before the player reached this
## room. The guard is belt and braces for the day something else puts one back.
##
## **Built ONCE, on open.** Carried-first is the right order to arrive at and the
## wrong order to maintain, because a transfer moves a cell across the sort key it
## was just sorted by: stow the top stack and it drops to the end, the cell under
## the cursor changes identity between two frames of one held button, and the
## rest of the hold empties something the player never chose. The director
## caught exactly that (`tools/directors/house_rest.gd`, "retrieving put all 4
## back in the bag") — the hold retrieved one amber, the list re-sorted, and the
## remaining 0.4 s went into whatever landed under the cursor.
##
## Nothing is lost by freezing it: the per-id TOTAL cannot change while this
## screen is up. Every door in and out of both piles is on this screen, and all
## either of them does is move a count from one column to the other. So the set
## of cells is fixed for the life of the screen by construction, not by hope.
func _build_rows() -> void:
	_rows.clear()
	var ids: Array[StringName] = []
	for id: StringName in Run.bag:
		if not RelicDb.is_relic(id) and not ids.has(id):
			ids.append(id)
	for id: StringName in Game.stash:
		if not RelicDb.is_relic(id) and not ids.has(id):
			ids.append(id)

	for id in ids:
		var def := ItemDb.get_def(id)
		if def == null:
			continue
		_rows.append({
			"id": id,
			"label": def.display_name,
			"value": def.value,
			"carried": 0,
			"stored": 0,
			"color": def.tint,
			"mark": def.is_component(),
			"blurb": def.blurb,
		})

	# Carried first, then by value: the cells you came in to deal with are the
	# ones in your hands, and under them the shelf reads as a shelf.
	_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ac := Run.bag.has(a["id"])
		var bc := Run.bag.has(b["id"])
		if ac != bc:
			return ac
		return int(a["value"]) > int(b["value"]))

	_refresh()


## Re-read the two counts into the cells that already exist. Order untouched —
## see `_build_rows`.
func _refresh() -> void:
	for row in _rows:
		var id: StringName = row["id"]
		row["carried"] = int(Run.bag.get(id, 0))
		row["stored"] = Game.stash_count(id)
	_cursor = clampi(_cursor, 0, maxi(_rows.size() - 1, 0))

	var cells: Array = []
	for i in _rows.size():
		var row := _rows[i]
		cells.append({
			"index": i,
			"label": String(row["label"]),
			"sub": "%s%s%s" % [_fig(int(row["stored"])), SWAP,
				_fig(int(row["carried"]))],
			"tint": row["color"],
			"mark": bool(row["mark"]),
		})
	_grid.set_cells(cells)
	_empty.visible = _rows.is_empty()
	# Rebuilt rather than written cell by cell: nothing here is mid-animation, and
	# a rebuild cannot go stale. The `split` cell is the exception and is written
	# by `_describe`, because it follows the cursor rather than the transfer.
	_rebuild_band()

	_point_at(_cursor)


## A zero is drawn as a dash. "0" in a pair of counts is a number the eye stops
## on; a dash is the absence it actually means, and the two figures are being
## compared at a glance.
func _fig(n: int) -> String:
	return str(n) if n > 0 else "—"


func _point_at(i: int) -> void:
	_cursor = clampi(i, 0, maxi(_rows.size() - 1, 0))
	var cell := _grid.cell_at(_cursor)
	if cell != null and cell.get_viewport() != null:
		cell.grab_focus()
	_describe()


## The mouse landed on a cell. Follow it — a click is also a look.
func _on_cell_looked(index: int) -> void:
	if index >= 0 and index != _cursor:
		_point_at(index)


func _describe() -> void:
	if _rows.is_empty():
		_d_kind.text = ""
		_d_name.text = ""
		_d_split.text = ""
		_d_blurb.text = ""
		UiKit.band_value(_band, &"split", "—")
		return
	var row := _rows[_cursor]
	UiKit.band_value(_band, &"split", "%s%s%s" % [
		_fig(int(row["stored"])), SWAP, _fig(int(row["carried"]))])
	var def := ItemDb.get_def(row["id"])
	_d_kind.text = "%s  ·  %s" % [def.rarity_name().to_upper(),
		def.bench_name() if def.is_component() else "INGREDIENT"]
	_d_name.text = String(row["label"])
	_d_split.text = "%d on the shelf  ·  %d in the bag" % [
		int(row["stored"]), int(row["carried"])]
	_d_blurb.text = String(row["blurb"])


# --- Input ------------------------------------------------------------------
## Polled, for both of `TradeScreen`'s reasons — and the second is still the real
## one: `Input.action_press()` is what the capture harness drives the game with
## and it synthesises no InputEvent, so a screen that only listened to
## `_unhandled_input` could not be exercised by a director. See
## `tools/directors/house_rest.gd`, which is the only thing that will ever prove
## this file works.

const REPEAT_DELAY := 0.38
const REPEAT_RATE := 0.09
## Hold-to-move-the-whole-stack. Shorter than `TradeScreen.CRAFT_HOLD`, because
## nothing here is irreversible: the worst a mis-held cell does is put the wrong
## pile on the wrong side of a room you are standing in.
const ALL_HOLD := 0.4
## How long a refusal stays on the footer. The old 0.6 s was tuned for a one-line
## recolour; "THE LOCKER IS FULL" now arrives as its own toast, and a message
## that leaves before it is read is the same as no message.
const REFUSE_TIME := 1.8

var _armed_cancel: bool = false
var _armed_move: bool = false
var _repeat: float = 0.0
var _hold: float = 0.0
var _hold_dir: int = 0


func _tick_input(delta: float) -> void:
	if _closing:
		return

	var cancel := Input.is_action_pressed(&"ui_cancel") or Input.is_action_pressed(&"pause")
	if not cancel:
		_armed_cancel = true
	elif _armed_cancel:
		_armed_cancel = false
		close()
		return

	if _rows.is_empty():
		return

	# UP and DOWN only. Left and right are the transfer, and they were the
	# transfer when this was a list — a grid does not get to take them back, so
	# the cursor walks the cells in reading order with the vertical axis and the
	# horizontal one keeps its verb. Wrapping means one direction still visits
	# every cell, which is the guarantee the grid makes everywhere else.
	var dir := 0
	if Input.is_action_just_pressed(&"ui_down"):
		dir = 1
	elif Input.is_action_just_pressed(&"ui_up"):
		dir = -1
	if dir != 0:
		_repeat = REPEAT_DELAY
	elif Input.is_action_pressed(&"ui_down") or Input.is_action_pressed(&"ui_up"):
		_repeat -= delta
		if _repeat <= 0.0:
			_repeat = REPEAT_RATE
			dir = 1 if Input.is_action_pressed(&"ui_down") else -1
	if dir != 0:
		_hold = 0.0
		_hold_dir = 0
		_point_at((_cursor + dir + _rows.size()) % _rows.size())

	# LEFT stows, RIGHT retrieves, and the mapping is spatial rather than
	# mnemonic: the STORED figure is drawn on the left of the cell's arrow and
	# the CARRIED figure on the right, so the stack moves the way the thumb
	# pushed it. A transfer screen whose directions have to be remembered is a
	# transfer screen read wrong once per session forever.
	var want := 0
	if Input.is_action_pressed(&"ui_left"):
		want = -1
	elif Input.is_action_pressed(&"ui_right"):
		want = 1

	if want == 0:
		_armed_move = true
		_hold = 0.0
		_hold_dir = 0
		return

	if _armed_move:
		_armed_move = false
		_hold_dir = want
		_move(want, 1)
		return

	# Still down from the tap that moved one. Past the hold, the rest follows.
	# `_hold_dir` of 0 means this direction has already had its whole-stack move
	# and is waiting for the button to come up — without that, a held key fires
	# again the moment `_hold` refills, finds an empty column and puts "NOTHING
	# STORED" under a transfer that worked perfectly.
	if _hold_dir == 0 or want != _hold_dir:
		return
	_hold += delta
	if _hold >= ALL_HOLD:
		_hold = 0.0
		_hold_dir = 0
		_move(want, -1)


## `count` of -1 means the whole stack. Negative rather than a second function
## because both paths are the same two calls and the only difference is the
## number handed to the first of them.
func _move(direction: int, count: int) -> void:
	if _cursor < 0 or _cursor >= _rows.size():
		return
	var row := _rows[_cursor]
	var id: StringName = row["id"]
	var moved := 0
	if direction < 0:
		var carried: int = row["carried"]
		var want: int = carried if count < 0 else mini(count, carried)
		if want <= 0:
			_refused("NOT CARRYING ANY")
			return
		# Ask the locker for room BEFORE taking anything out of the bag. The
		# other order loses the difference: `consume` does not put back what
		# `stash_add` could not take.
		var room := Game.stash_room_for(id)
		if room <= 0:
			_refused("THE LOCKER IS FULL")
			return
		moved = Game.stash_add(id, Run.consume(id, mini(want, room)))
	else:
		var stored: int = row["stored"]
		var want2: int = stored if count < 0 else mini(count, stored)
		if want2 <= 0:
			_refused("NOTHING STORED")
			return
		# The other order, for the same reason from the other side: `collect`
		# already refuses what will not fit and reports how much did, so the
		# shelf is debited by the answer rather than by the question.
		moved = Run.collect(id, want2, 1.0)
		if moved <= 0:
			_refused("THE BAG IS FULL")
			return
		Game.stash_take(id, moved)
	if moved <= 0:
		_refused("THE LOCKER IS FULL")
		return
	# The transfer that just landed answers whatever the last refusal said.
	_end_refusal()
	_refresh()


## `_refuse` and `_refuse_why` are kept alongside the toast because
## `tools/directors/house_rest.gd` reads them to prove the screen said WHY. They
## are the record; the toast is the picture of it.
func _refused(why: String) -> void:
	_end_refusal()
	_refuse = 0.0
	_refuse_why = why
	_toast = UiKit.footer_toast(_toast_slot, why, UITheme.DANGER)


func _end_refusal() -> void:
	_refuse = -1.0
	_refuse_why = ""
	if _toast != null and is_instance_valid(_toast):
		_toast.queue_free()
	_toast = null


func _process(delta: float) -> void:
	_tick_input(delta)
	if _closing:
		return
	if _refuse >= 0.0:
		_refuse += delta
		if _refuse > REFUSE_TIME:
			_end_refusal()
	_paint_chrome()


## Buttons off the live InputMap through `Glyph`, never written in — the trade
## screen's footer shipped as "ENTER / ESC" under a game being played on a pad,
## and this is the same line.
func _paint_chrome() -> void:
	_hold_bar.visible = _hold_dir != 0
	_hold_bar.progress = _hold / ALL_HOLD

	var leave_cap := Glyph.cap(&"ui_cancel")
	if leave_cap.is_empty():
		leave_cap = "ESC"
	# The hint says which way the thumb goes and nothing else. Why a transfer was
	# refused is the toast's line — see `_build_footer`.
	_hint.text = "← STOW    RETRIEVE →    HOLD FOR ALL    %s LEAVE" % leave_cap
