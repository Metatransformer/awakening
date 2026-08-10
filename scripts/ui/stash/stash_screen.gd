class_name StashScreen
extends Control
## The footlocker's screen. One list, two columns: what is on you, what is on the
## shelf. Left puts it away, right takes it back.
##
## ## Why this is not `TradeScreen` with a third mode
##
## It nearly is, and the resemblance is deliberate down to the panel rect — a
## player should recognise this as the same furniture the vendor is made of. But
## `TradeScreen` answers *one* question per row ("do I want this at that price")
## with one commit on one button, and every part of it is shaped by that: the
## price column is the only GOLD thing on the screen, the hold gauge marks the
## commits that eat components, the footer asks the catalogue why it said no.
## A locker asks a different question — *which side of the room does this live
## on* — and it answers with a direction rather than a confirmation. Threading a
## two-way transfer through `_commit`, `_verb` and `_hold_time` would have made
## all three of them ask "which mode is this" before doing anything, which is the
## drift the single trade screen exists to prevent (see its class doc).
##
## What IS shared is shared: `PixelFont`, `Pal`, the polled input, the panel
## geometry and the footer's `Glyph` caps. Nothing here re-invents a widget.
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

const ROW_H := 26.0        ## reference px, TradeScreen's
const PAD := 22.0

## The prop that opened this. Held only so the locker can be told to shut its
## lid; see `Footlocker.activate`.
var host: Node = null

var _rows: Array[Dictionary] = []
var _cursor: int = 0
var _flash: float = -1.0
var _flash_row: int = -1
var _refuse: float = -1.0
var _refuse_why: String = ""
var _closing: bool = false


## Same construction as `TradeScreen.open`, and for the same reason its note
## gives: a Control parented to a Node3D never draws, and the caller is a chest
## standing in a 3D town.
static func open(from: Node) -> StashScreen:
	var layer := CanvasLayer.new()
	layer.name = "StashLayer"
	# 60. Above the HUD, below the pause menu, exactly where the trade screen
	# sits — pausing out of the locker should put the menu on top of it.
	layer.layer = 60
	var s := StashScreen.new()
	s.host = from
	layer.add_child(s)
	from.get_tree().current_scene.add_child(layer)
	return s


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fit()
	get_viewport().size_changed.connect(_fit)
	_build_rows()
	Prompt.block(self)
	Bus.screen_opened.emit(&"stash")


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	queue_redraw()


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


# --- Rows -------------------------------------------------------------------

## One row per ITEM KIND, not per location — the whole point of the screen is to
## compare the two piles of the same thing, and a stack that was split across
## both would otherwise be two rows the player has to add up themselves.
##
## Relics are refused, and refused HERE only for the drawing: `Run.consume` would
## happily take one out of the bag, and `RelicDb` would then have a unique that
## exists in a dictionary nobody unpacks. A relic is not merchandise and it is not
## material — it goes to the Society and nowhere else (`docs/GDD.md` §6.3), and
## `Run.extract` already moved it out of the bag before the player reached this
## room. The guard is belt and braces for the day something else puts one back.
##
## **Built ONCE, on open.** Carried-first is the right order to arrive at and the
## wrong order to maintain, because a transfer moves a row across the sort key it
## was just sorted by: stow the top stack and it drops to the bottom, the row
## under the cursor changes identity between two frames of one held button, and
## the rest of the hold empties something the player never chose. The director
## caught exactly that (`tools/directors/house_rest.gd`, "retrieving put all 4
## back in the bag") — the hold retrieved one amber, the list re-sorted, and the
## remaining 0.4 s went into whatever landed under the cursor.
##
## Nothing is lost by freezing it: the per-id TOTAL cannot change while this
## screen is up. Every door in and out of both piles is on this screen, and all
## either of them does is move a count from one column to the other. So the set
## of rows is fixed for the life of the screen by construction, not by hope.
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
			"color": Pal.rarity_color(int(def.rarity)),
			"blurb": def.blurb,
		})

	# Carried first, then by value: the rows you came in to deal with are the
	# ones in your hands, and under them the shelf reads as a shelf.
	_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ac := Run.bag.has(a["id"])
		var bc := Run.bag.has(b["id"])
		if ac != bc:
			return ac
		return int(a["value"]) > int(b["value"]))

	_refresh()


## Re-read the two counts into the rows that already exist. Order untouched —
## see `_build_rows`.
func _refresh() -> void:
	for row in _rows:
		var id: StringName = row["id"]
		row["carried"] = int(Run.bag.get(id, 0))
		row["stored"] = Game.stash_count(id)
	_cursor = clampi(_cursor, 0, maxi(_rows.size() - 1, 0))
	queue_redraw()


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
## nothing here is irreversible: the worst a mis-held row does is put the wrong
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
		_cursor = (_cursor + dir + _rows.size()) % _rows.size()
		_hold = 0.0
		_hold_dir = 0
		queue_redraw()

	# LEFT stows, RIGHT retrieves, and the mapping is spatial rather than
	# mnemonic: the STORED column is drawn on the left of the row and the CARRIED
	# column on the right, so the stack moves the way the thumb pushed it. A
	# transfer screen whose directions have to be remembered is a transfer screen
	# read wrong once per session forever.
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
	queue_redraw()


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
	_flash = 0.0
	_flash_row = _cursor
	_refresh()


func _refused(why: String) -> void:
	_refuse = 0.0
	_refuse_why = why


func _process(delta: float) -> void:
	_tick_input(delta)
	if _closing:
		return
	for t in [&"_flash", &"_refuse"]:
		var v: float = get(t)
		if v >= 0.0:
			set(t, v + delta)
	if _flash > 0.35:
		_flash = -1.0
		_flash_row = -1
	if _refuse > 0.6:
		_refuse = -1.0
	queue_redraw()


# --- Draw -------------------------------------------------------------------

func _draw() -> void:
	var s := size
	if s.x < 1.0 or s.y < 1.0:
		return

	draw_rect(Rect2(Vector2.ZERO, s), Color(Pal.VOID, 0.86))

	var pad := Pal.px(PAD, s.y)
	var panel := Rect2(s.x * 0.16, s.y * 0.13, s.x * 0.68, s.y * 0.74)
	draw_rect(panel, Color(Pal.MIDNIGHT, 0.94))
	draw_rect(panel, Pal.ASH, false, Pal.px(2.0, s.y))

	var t2 := Pal.px(20.0 / PixelFont.H, s.y)
	PixelFont.draw_text(self, "FOOTLOCKER",
		panel.position + Vector2(pad, pad), t2, Pal.BONE)

	# Where the purse sits on the trade screen, because it answers the same
	# glance — "how much of this have I got left" — and moving it would make the
	# two screens read as two programs. Slots, not coin: the locker never sees
	# gold, and drawing a gold figure on a screen with no price on it is the
	# lie `docs/GDD.md` §6.3 forbids of the relic receipt.
	var used := Game.stash_slots_used()
	var cap := "%d/%d" % [used, K.STASH_SLOTS]
	var gt := Pal.px(24.0 / PixelFont.H, s.y)
	PixelFont.draw_right(self, cap, Vector2(panel.end.x - pad, panel.position.y + pad),
		gt, Pal.RUST if used >= K.STASH_SLOTS else Pal.BONE)

	var rule_y := panel.position.y + pad + PixelFont.height(gt) + Pal.px(10.0, s.y)
	draw_rect(Rect2(panel.position.x + pad, rule_y,
		panel.size.x - pad * 2.0, Pal.px(1.0, s.y)), Pal.ASH)

	# The two column heads, over the two number columns, so the row below is
	# readable without the footer. Drawn even on an empty locker — the empty
	# state has to say what the screen WOULD be for.
	var ht := Pal.px(11.0 / PixelFont.H, s.y)
	var head_y := rule_y + Pal.px(6.0, s.y)
	PixelFont.draw_right(self, "STORED",
		Vector2(_col_stored(panel), head_y), ht, Pal.MOTH)
	PixelFont.draw_right(self, "CARRIED",
		Vector2(_col_carried(panel), head_y), ht, Pal.MOTH)

	if _rows.is_empty():
		PixelFont.draw_centred(self, "NOTHING TO PUT AWAY",
			panel.get_center(), Pal.px(16.0 / PixelFont.H, s.y), Pal.MOTH)
		_footer(s, panel, pad)
		return

	var row_h := Pal.px(ROW_H, s.y)
	var rt := Pal.px(14.0 / PixelFont.H, s.y)
	var y := head_y + PixelFont.height(ht) + Pal.px(8.0, s.y)

	for i in _rows.size():
		var row := _rows[i]
		var r := Rect2(panel.position.x + pad * 0.5, y, panel.size.x - pad, row_h)

		if i == _cursor:
			draw_rect(r, Color(Pal.ASH, 0.45))
			draw_rect(Rect2(r.position.x, r.position.y,
				Pal.px(3.0, s.y), r.size.y), Pal.BONE)
			if _hold_dir != 0:
				var bar_h := Pal.px(HoldGauge.BAR_H, s.y)
				HoldGauge.bar(self, Rect2(r.position.x, r.end.y - bar_h,
					r.size.x, bar_h), _hold / ALL_HOLD, Pal.BONE)
		if i == _flash_row and _flash >= 0.0:
			draw_rect(r, Color(Pal.BONE, 0.35 * (1.0 - _flash / 0.35)))

		var text_y := y + (row_h - PixelFont.height(rt)) * 0.5
		PixelFont.draw_text(self, str(row["label"]),
			Vector2(r.position.x + pad, text_y), rt, row["color"])

		# A zero is drawn as a dash. "0" in a column of counts is a number the
		# eye stops on; a dash is the absence it actually means, and the two
		# columns are being compared at a glance.
		var stored := int(row["stored"])
		var carried := int(row["carried"])
		PixelFont.draw_right(self, "%d" % stored if stored > 0 else "-",
			Vector2(_col_stored(panel), text_y), rt,
			Pal.BONE if stored > 0 else Pal.ASH)
		PixelFont.draw_right(self, "%d" % carried if carried > 0 else "-",
			Vector2(_col_carried(panel), text_y), rt,
			Pal.BONE if carried > 0 else Pal.ASH)

		y += row_h

	var bt := Pal.px(12.0 / PixelFont.H, s.y)
	var bh := PixelFont.height(bt) * 1.5
	var blurb := PixelFont.wrap(str(_rows[_cursor]["blurb"]), bt,
		panel.size.x - pad * 2.0, 4)
	var by := panel.end.y - pad * 2.4 - bh * (blurb.size() - 1)
	for i in blurb.size():
		PixelFont.draw_text(self, blurb[i],
			Vector2(panel.position.x + pad, by + bh * i), bt, Pal.MOTH)

	_footer(s, panel, pad)


## The two count columns, right-aligned at fixed fractions so the heads, the
## numbers and the arrows in the footer all line up on one pair of edges.
func _col_stored(panel: Rect2) -> float:
	return panel.position.x + panel.size.x * 0.70


func _col_carried(panel: Rect2) -> float:
	return panel.position.x + panel.size.x * 0.92


## Buttons off the live InputMap through `Glyph`, never written in — the trade
## screen's footer shipped as "ENTER / ESC" under a game being played on a pad,
## and this is the same line.
func _footer(s: Vector2, panel: Rect2, pad: float) -> void:
	var ft := Pal.px(12.0 / PixelFont.H, s.y)
	var leave_cap := Glyph.cap(&"ui_cancel")
	if leave_cap.is_empty():
		leave_cap = "ESC"
	var hint := "< STOW    RETRIEVE >    HOLD FOR ALL    %s LEAVE" % leave_cap
	var col: Color = Pal.ASH
	if _refuse >= 0.0:
		hint = _refuse_why
		col = Pal.RUST
	PixelFont.draw_text(self, hint,
		Vector2(panel.position.x + pad, panel.end.y - pad), ft, col)
