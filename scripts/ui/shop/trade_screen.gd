class_name TradeScreen
extends Control
## The vendor and the smith, which are the same screen pointed in two directions.
##
## Drawn with PixelFont and Pal rather than built out of Control nodes and a
## Theme, for the same reason the HUD is: docs/STYLEGUIDE.md bans the engine's
## fallback font, and a shop that looks like an editor panel next to a HUD made
## of whole pixels is the single loudest "unfinished" signal the game could send.
##
## One list, one cursor, one number that moves. The player is answering "what is
## this worth" over and over, so the price column is the only thing that is ever
## GOLD, and the running total is the only thing that animates.

enum Mode { SELL, BUY }

const ROW_H := 26.0        ## reference px
const PAD := 22.0
const ROLL_TIME := 0.25

var mode: Mode = Mode.SELL
var title: String = "VENDOR"

var _rows: Array[Dictionary] = []
var _cursor: int = 0
var _shown_gold: float = 0.0
var _flash: float = -1.0
var _flash_row: int = -1
var _refuse: float = -1.0
var _closing: bool = false


## The screen makes its own CanvasLayer. A Control parented to a Node3D never
## draws, and every caller here is a prop standing in a 3D town.
static func open(host: Node, screen_mode: Mode, screen_title: String) -> TradeScreen:
	var layer := CanvasLayer.new()
	layer.name = "TradeLayer"
	# Above the HUD (50), below the pause menu (100): pausing out of the shop
	# should still put the pause menu on top of it.
	layer.layer = 60
	var s := TradeScreen.new()
	s.mode = screen_mode
	s.title = screen_title
	layer.add_child(s)
	host.get_tree().current_scene.add_child(layer)
	return s


func _ready() -> void:
	# A Control parented straight to a CanvasLayer is outside the viewport's
	# Control tree, so anchors alone never resolve and it sits at size (0,0) --
	# which _draw reads as "no viewport yet" and skips. Size it from the viewport
	# and keep it there.
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fit()
	get_viewport().size_changed.connect(_fit)

	_shown_gold = float(Game.gold)
	_refresh()
	Prompt.block(self)
	Bus.screen_opened.emit(&"trade")


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	queue_redraw()


func _exit_tree() -> void:
	Prompt.unblock(self)
	Bus.screen_closed.emit(&"trade")


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

## Rebuilt after every transaction rather than mutated: a sold-out stack has to
## leave the list, and a cursor pointing at a row that no longer exists is the
## classic shop-screen crash.
func _refresh() -> void:
	_rows.clear()
	if mode == Mode.SELL:
		for id: StringName in Run.bag:
			var def := ItemDb.get_def(id)
			if def == null:
				continue
			var n: int = Run.bag[id]
			_rows.append({
				"kind": &"item",
				"id": id,
				"label": def.display_name,
				"count": n,
				# Not def.value * n: a stack carries its share of the run's heat
				# premium, and the row has to name the gold that will actually
				# land or the screen is lying about its own prices.
				"price": Run.line_value(id),
				"color": Pal.rarity_color(int(def.rarity)),
				"blurb": def.blurb,
				"ok": true,
			})
		_rows.sort_custom(func(a, b) -> bool: return a["price"] > b["price"])
		if not _rows.is_empty():
			_rows.append({
				"kind": &"all",
				"label": "SELL EVERYTHING",
				"count": 0,
				"price": Run.bag_value(),
				"color": Pal.BONE,
				"blurb": "Empty the bag. The smith is two doors down.",
				"ok": true,
			})
	else:
		for line in ShopDb.lines():
			var left := ShopDb.remaining(line["id"])
			var parts: Dictionary = line.get("parts", {})
			_rows.append({
				"kind": &"buy",
				"line": line,
				"label": line["label"],
				"count": left,
				"price": int(line["cost"]),
				"color": Pal.BONE,
				# The blurb says what the thing IS; the detail says what the
				# number DOES, in the unit the player feels. A forge line without
				# the second sentence is asking them to buy on faith.
				"blurb": "%s   %s" % [line["blurb"], line.get("detail", "")],
				"parts": parts,
				"ok": ShopDb.can_buy(line),
			})

	_cursor = clampi(_cursor, 0, maxi(_rows.size() - 1, 0))
	queue_redraw()


# --- Input ------------------------------------------------------------------
## Polled, not event-driven. Two reasons, and the second is the real one:
##
##  1. Held-direction repeat is a timer, and a timer next to `_unhandled_input`
##     is two clocks for one behaviour.
##  2. `Input.action_press()` -- what the capture harness drives the game with --
##     sets action STATE and never synthesises an InputEvent, so anything that
##     only listens to `_unhandled_input` cannot be exercised by a tool. A screen
##     that can only be tested by a human is a screen that does not get tested.
##
## Both edges start DISARMED, which is what stops the interact press that opened
## this screen -- still held -- from buying the top line on arrival.

const REPEAT_DELAY := 0.38
const REPEAT_RATE := 0.09

## Same release-edge trick as Prompt: a confirm that depends on catching a
## one-frame `just_pressed` is a confirm that occasionally does nothing.
var _armed_accept: bool = false
var _armed_cancel: bool = false
var _repeat: float = 0.0


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

	var accept := Input.is_action_pressed(&"ui_accept") or Input.is_action_pressed(&"interact")
	if not accept:
		_armed_accept = true
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
		queue_redraw()

	if accept and _armed_accept:
		_armed_accept = false
		_commit()


func _commit() -> void:
	if _cursor < 0 or _cursor >= _rows.size():
		return
	var row := _rows[_cursor]
	var done := false
	match row["kind"]:
		&"item":
			done = Run.sell(row["id"]) > 0
		&"all":
			done = Run.sell_all() > 0
		&"buy":
			done = ShopDb.buy(row["line"])

	if done:
		_flash = 0.0
		_flash_row = _cursor
	else:
		_refuse = 0.0
	_refresh()


func _process(delta: float) -> void:
	_tick_input(delta)
	if _closing:
		return
	if not is_equal_approx(_shown_gold, float(Game.gold)):
		var step: float = maxf(1.0, absf(Game.gold - _shown_gold)) * (delta / ROLL_TIME)
		_shown_gold = move_toward(_shown_gold, float(Game.gold), step)
	for t in [&"_flash", &"_refuse"]:
		var v: float = get(t)
		if v >= 0.0:
			set(t, v + delta)
	if _flash > 0.35:
		_flash = -1.0
		_flash_row = -1
	if _refuse > 0.45:
		_refuse = -1.0
	queue_redraw()


# --- Draw -------------------------------------------------------------------

func _draw() -> void:
	var s := size
	if s.x < 1.0 or s.y < 1.0:
		return

	# Darken the world rather than hide it. You are standing in the town while
	# you do this, and the shop is a conversation, not a menu screen.
	draw_rect(Rect2(Vector2.ZERO, s), Color(Pal.VOID, 0.86))

	var pad := Pal.px(PAD, s.y)
	var panel := Rect2(s.x * 0.16, s.y * 0.13, s.x * 0.68, s.y * 0.74)
	draw_rect(panel, Color(Pal.MIDNIGHT, 0.94))
	draw_rect(panel, Pal.ASH, false, Pal.px(2.0, s.y))

	var t2 := Pal.px(20.0 / PixelFont.H, s.y)
	PixelFont.draw_text(self, title,
		panel.position + Vector2(pad, pad), t2, Pal.BONE)

	# The purse. Right-aligned and monospaced so it does not reflow as it rolls.
	var gold_s := "%d" % int(round(_shown_gold))
	var gt := Pal.px(24.0 / PixelFont.H, s.y)
	PixelFont.draw_right(self, gold_s,
		Vector2(panel.end.x - pad - Pal.px(20.0, s.y), panel.position.y + pad),
		gt, Pal.GOLD)
	_diamond(Vector2(panel.end.x - pad - Pal.px(8.0, s.y),
		panel.position.y + pad + PixelFont.height(gt) * 0.5),
		Pal.px(8.0, s.y), Pal.GOLD)

	var rule_y := panel.position.y + pad + PixelFont.height(gt) + Pal.px(10.0, s.y)
	draw_rect(Rect2(panel.position.x + pad, rule_y,
		panel.size.x - pad * 2.0, Pal.px(1.0, s.y)), Pal.ASH)

	if _rows.is_empty():
		PixelFont.draw_centred(self,
			"NOTHING TO SELL" if mode == Mode.SELL else "SOLD OUT",
			Vector2(panel.get_center().x, panel.get_center().y),
			Pal.px(16.0 / PixelFont.H, s.y), Pal.MOTH)
		_footer(s, panel, pad)
		return

	var row_h := Pal.px(ROW_H, s.y)
	var rt := Pal.px(14.0 / PixelFont.H, s.y)
	var y := rule_y + Pal.px(12.0, s.y)

	for i in _rows.size():
		var row := _rows[i]
		var selected := i == _cursor
		var r := Rect2(panel.position.x + pad * 0.5, y,
			panel.size.x - pad, row_h)

		if selected:
			draw_rect(r, Color(Pal.ASH, 0.45))
			draw_rect(Rect2(r.position.x, r.position.y,
				Pal.px(3.0, s.y), r.size.y), Pal.BONE)
		if i == _flash_row and _flash >= 0.0:
			draw_rect(r, Color(Pal.GOLD, 0.5 * (1.0 - _flash / 0.35)))

		var affordable: bool = row["ok"]
		var name_col: Color = row["color"] if affordable else Color(Pal.MOTH, 0.45)
		var text_y := y + (row_h - PixelFont.height(rt)) * 0.5

		PixelFont.draw_text(self, str(row["label"]),
			Vector2(r.position.x + pad, text_y), rt, name_col)

		# Quantity column, fixed at a third across, so the eye can run down it.
		var qx := panel.position.x + panel.size.x * 0.52
		if row["kind"] == &"item":
			PixelFont.draw_text(self, "X%d" % int(row["count"]),
				Vector2(qx, text_y), rt, Pal.MOTH)
		elif row["kind"] == &"buy":
			var parts: Dictionary = row.get("parts", {})
			if not parts.is_empty():
				_recipe(parts, Vector2(qx, text_y), rt)
			elif int(row["count"]) >= 0:
				PixelFont.draw_text(self, "%d LEFT" % int(row["count"]),
					Vector2(qx, text_y), rt,
					Pal.MOTH if int(row["count"]) > 0 else Pal.RUST)

		var price_col: Color = Pal.GOLD if affordable else Pal.RUST
		if mode == Mode.SELL:
			price_col = Pal.GOLD
		PixelFont.draw_right(self, "%d" % int(row["price"]),
			Vector2(r.end.x - pad, text_y), rt, price_col)

		y += row_h

	# The blurb for the highlighted line, in the one place blurbs ever appear.
	# Wrapped, not clipped: a forge line carries its before/after numbers here
	# ("8.7 M REACH -> 11.9 M REACH") and unwrapped that ran straight out through
	# the right edge of the panel and on across the dungeon behind it.
	var row2 := _rows[_cursor]
	var bt := Pal.px(12.0 / PixelFont.H, s.y)
	var bh := PixelFont.height(bt) * 1.5
	var blurb := PixelFont.wrap(str(row2["blurb"]), bt, panel.size.x - pad * 2.0)
	var by := panel.end.y - pad * 2.4 - bh * (blurb.size() - 1)
	for i in blurb.size():
		PixelFont.draw_text(self, blurb[i],
			Vector2(panel.position.x + pad, by + bh * i), bt, Pal.MOTH)

	_footer(s, panel, pad)


## The component half of a bill: `3 GRIT  1 CORE`, each token GOLD when the
## workbench can cover it and RUST when it cannot.
##
## Per-token colour, not per-row: a recipe you are one core short of and a recipe
## you have none of look identical if the whole line just greys out, and the
## difference between them is a whole run's worth of where to go looking.
func _recipe(parts: Dictionary, at: Vector2, scale: float) -> void:
	var x := at.x
	for id: StringName in parts:
		var need := int(parts[id])
		var def := ItemDb.get_def(id)
		if def == null:
			continue
		var have := Game.component_count(id)
		var token := "%d %s" % [need, def.code()]
		PixelFont.draw_text(self, token, Vector2(x, at.y), scale,
			Pal.GOLD if have >= need else Pal.RUST)
		x += PixelFont.width(token, scale) + PixelFont.width("  ", scale)


func _footer(s: Vector2, panel: Rect2, pad: float) -> void:
	var ft := Pal.px(12.0 / PixelFont.H, s.y)
	var hint := "ENTER SELL    ESC LEAVE" if mode == Mode.SELL \
		else "ENTER BUY    ESC LEAVE"
	var col: Color = Pal.RUST if _refuse >= 0.0 else Pal.ASH
	if _refuse >= 0.0:
		# Ask the catalogue WHY rather than assuming money. Once a line can be
		# refused for four different reasons, a hardcoded "NOT ENOUGH GOLD"
		# sends the player back down for the wrong thing.
		hint = "NOTHING THERE"
		if mode == Mode.BUY and _cursor >= 0 and _cursor < _rows.size():
			var why := ShopDb.refusal(_rows[_cursor]["line"])
			hint = why if why != "" else "NOT ENOUGH GOLD"
	PixelFont.draw_text(self, hint,
		Vector2(panel.position.x + pad, panel.end.y - pad), ft, col)


func _diamond(centre: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(0.0, -r), centre + Vector2(r, 0.0),
		centre + Vector2(0.0, r), centre + Vector2(-r, 0.0),
	]), col)
