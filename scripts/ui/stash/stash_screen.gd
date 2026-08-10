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
## What IS shared is shared, and since 2026-08-09 that includes the picture: the
## cells are `ItemGrid`, the frame and the footer are the pause menu's theme, and
## the polled input, the panel geometry and the footer's `Glyph` caps are what
## they always were. Nothing here re-invents a widget. This screen was the last
## place in the game where a stack of amber was a line of text rather than an
## amber-tinted cell, which meant the bag looked like one game and the shelf you
## were moving it onto looked like another.
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

const THEME_PATH := "res://scenes/ui/menu/menu_theme.tres"
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
var _cap_label: Label
var _empty: Label
var _d_kind: Label
var _d_name: Label
var _d_split: Label
var _d_blurb: Label
var _hint: Label
var _hold_bar: HoldBar


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
## Saved and put back rather than forced to VISIBLE on the way out: this screen
## can be up in the garrison (pointer captured for camera look) or over a menu
## that already freed it, and a screen that unconditionally captures on close
## grabs the cursor in cases where nobody had it. Same contract as `PauseMenu`.
var _prev_mouse: int = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = load(THEME_PATH) as Theme
	_build()
	_fit()
	get_viewport().size_changed.connect(_fit)
	_build_rows()
	# The camera captures the pointer for look. Hand it back or not one cell on
	# this screen can be clicked.
	_prev_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Prompt.block(self)
	Bus.screen_opened.emit(&"stash")


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _exit_tree() -> void:
	Prompt.unblock(self)
	Bus.screen_closed.emit(&"stash")
	Input.mouse_mode = _prev_mouse as Input.MouseMode


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
	frame.theme_type_variation = &"MenuFrame"
	frame.custom_minimum_size = MenuUtil.FRAME_SIZE
	centre.add_child(frame)

	var stack := VBoxContainer.new()
	stack.theme_type_variation = &"MenuStack"
	frame.add_child(stack)

	_build_header(stack)
	_build_body(stack)
	_build_footer(stack)


func _build_header(parent: Node) -> void:
	var header := PanelContainer.new()
	header.theme_type_variation = &"MenuHeader"
	parent.add_child(header)

	var row := HBoxContainer.new()
	header.add_child(row)

	var name_label := Label.new()
	name_label.theme_type_variation = &"MenuTitle"
	name_label.text = "FOOTLOCKER"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	# Where the purse sits on the trade screen, because it answers the same
	# glance — "how much of this have I got left". SLOTS, not coin: the locker
	# never sees gold, and drawing a gold figure on a screen with no price on it
	# is the lie `docs/GDD.md` §6.3 forbids of the relic receipt.
	_cap_label = Label.new()
	_cap_label.theme_type_variation = &"MenuValue"
	_cap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_cap_label)


func _build_body(parent: Node) -> void:
	var pad := MarginContainer.new()
	pad.theme_type_variation = &"MenuBodyPad"
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(pad)

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 24)
	pad.add_child(split)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	split.add_child(left)

	var card := PanelContainer.new()
	card.theme_type_variation = &"MenuSection"
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(card)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	card.add_child(inner)

	# The caption is the legend for every cell's second line. The two counts on a
	# cell are a bare pair of numbers, and a bare pair of numbers reads either way
	# round — this is the one place that says which is which, so it is worded in
	# the same order and with the same arrow the cells use.
	var caption := Label.new()
	caption.theme_type_variation = &"MenuHeading"
	caption.text = "ON THE SHELF%sIN THE BAG" % SWAP
	inner.add_child(caption)

	_grid = ItemGrid.new()
	_grid.name = "Kinds"
	_grid.columns = COLS
	_grid.cell_focused.connect(_on_cell_looked)
	inner.add_child(_grid)

	_empty = Label.new()
	_empty.theme_type_variation = &"MenuMuted"
	_empty.text = "Nothing to put away."
	inner.add_child(_empty)

	_build_detail(split)


func _build_detail(parent: Node) -> void:
	var card := PanelContainer.new()
	card.name = "Detail"
	card.theme_type_variation = &"MenuSection"
	card.custom_minimum_size = Vector2(DETAIL_W, 0)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)

	_d_kind = Label.new()
	_d_kind.theme_type_variation = &"MenuMuted"
	col.add_child(_d_kind)

	_d_name = Label.new()
	_d_name.theme_type_variation = &"MenuHeading"
	_d_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_d_name)

	# The cell's second line, spelled out in words. The cell has room for "2 ⇄ 3"
	# and the arrow is learnable, but there is no reason to make the player learn
	# it when the pane beside the cursor can just say it.
	_d_split = Label.new()
	_d_split.theme_type_variation = &"MenuValue"
	_d_split.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_d_split)

	_d_blurb = Label.new()
	_d_blurb.theme_type_variation = &"MenuSlotStat"
	_d_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_blurb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_d_blurb)


func _build_footer(parent: Node) -> void:
	var footer := PanelContainer.new()
	footer.theme_type_variation = &"MenuFooter"
	parent.add_child(footer)

	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	footer.add_child(row)

	_hint = Label.new()
	_hint.theme_type_variation = &"MenuHint"
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

	var used := Game.stash_slots_used()
	_cap_label.text = "%d/%d" % [used, K.STASH_SLOTS]
	_cap_label.modulate = Pal.RUST if used >= K.STASH_SLOTS else Color.WHITE

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
		return
	var row := _rows[_cursor]
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
	_refresh()


func _refused(why: String) -> void:
	_refuse = 0.0
	_refuse_why = why


func _process(delta: float) -> void:
	_tick_input(delta)
	if _closing:
		return
	if _refuse >= 0.0:
		_refuse += delta
		if _refuse > 0.6:
			_refuse = -1.0
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
	if _refuse >= 0.0:
		_hint.text = _refuse_why
		_hint.modulate = Pal.RUST
	else:
		_hint.text = "← STOW    RETRIEVE →    HOLD FOR ALL    %s LEAVE" % leave_cap
		_hint.modulate = Color.WHITE
