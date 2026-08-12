extends RefCounted
## The counter's description card, walked with the pad and with the mouse.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/shop_tip.gd \
##     --out=/tmp/tip/x.png --size=1280x720 --warmup=60
##
## Card #119 replaced the shop's right-hand detail column with a tooltip anchored
## to the cell under the cursor. That change has exactly three ways to go wrong and
## none of them is visible in one screenshot of one row:
##
##   A  The card covers the cell it is describing -- which is the one thing a
##      description must never do, and which only happens at SOME cells.
##   B  The card runs off the screen at the edges of the board. The smith's
##      bottom row and the Lanternkeeper's twelfth relic are the corners.
##   C  The card stops following. It is fed by `TradeScreen._point_at` and by
##      nothing else on purpose (the board POLLS the arrows and ALSO lets cells
##      take focus -- CLAUDE.md §3, cards #74/#76), and a mouse that moves the
##      cursor through `cell_focused` is the path most likely to come apart.
##
## So the card is checked at EVERY cell of three boards, on both input paths, and
## the geometry is asserted as numbers rather than eyeballed: the tip rect against
## the anchor cell's rect, and the tip rect against the viewport.
##
## **Both directions of calibration, per CLAUDE.md §2**, and it is the Z beats
## rather than a note: an instrument that cannot see the failure it is looking for
## passes everything, and every check below is worth exactly what Z0..Z3 are
## worth. See `_calibrate` for what each of the four settles and why the obvious
## version of it -- shove the real card and watch the check fire -- does not work
## on a widget that corrects itself every frame.
##
## The pad is driven with real `InputEventKey`s and never with `Input.action_press`
## (which dispatches no event at all -- CLAUDE.md §3) and never by assigning
## `screen._cursor` (which holds for one frame -- #40, #77). The mouse is driven
## with a real `InputEventMouseMotion` at a cell's centre, which is what makes
## `ItemGrid`/`UpgradeLadder`'s `mouse_entered` fire the way a hand does.

var _rig
var _out := ""
## Every cell the pad walk stopped on, so "it visited all of them" is a number and
## not a hope. `relic_donate`'s G8 is the same claim about the same board.
var _seen := {}


func run(rig) -> void:
	_rig = rig
	_out = rig.arg("out", "/tmp/tip/x.png").get_base_dir()
	await rig.wait_frames(20)

	await _calibrate()
	await _smith()
	await _keeper()
	await _quartermaster()
	print("TIP done")


# --- the instrument ----------------------------------------------------------

## Report a check either way. `rig.fail` is the protocol (card #72) and is what
## makes the run's exit status mean something; the `ok` line is printed here
## because a director whose whole output is silence on success gives a reader no
## way to tell "forty checks passed" from "the beat never ran".
func _ck(ok: bool, what: String) -> bool:
	if ok:
		print("  ok   %s" % what)
	else:
		_rig.fail(what)
	return ok


## The two predicates, over bare geometry. Split out from the screen readers
## below so `_calibrate` can hand them rectangles whose answer is known -- see
## its docstring.
func _hits(tip: Rect2, cell: Rect2) -> bool:
	return tip.intersects(cell)


func _fits(tip: Rect2, view: Vector2) -> bool:
	return Rect2(Vector2.ZERO, view).encloses(tip)


# Annotated and never inferred. `screen` is untyped -- like `rig`, and for
# `forge_loop`'s reason -- so everything read off it is a `Variant`, and
# `var x := screen.foo()` is a parse error (CLAUDE.md §3).
func _tip_rect(screen) -> Rect2:
	var r: Rect2 = screen._tip.get_global_rect()
	return r


func _cell_rect(screen) -> Rect2:
	var r: Rect2 = screen._tip.anchor.get_global_rect()
	return r


func _view(screen) -> Vector2:
	var v: Vector2 = screen.get_viewport_rect().size
	return v


## Does the card sit on the cell it is describing?
func _overlaps(screen) -> bool:
	if screen._tip.anchor == null:
		return false
	return _hits(_tip_rect(screen), _cell_rect(screen))


## Is the whole card on the screen?
func _inside(screen) -> bool:
	return _fits(_tip_rect(screen), _view(screen))


## Point everything at an answer that is known, in both directions, before any of
## it is trusted below.
##
## THREE things have to be true for the forty checks in `_walk` to mean anything,
## and they fail in three different ways:
##
##   Z0/Z1  The predicates can see a bad geometry. Handed rectangles rather than
##          the live widget, because the live widget is CORRECT -- an instrument
##          that has only ever been shown passing values has never been tested,
##          and the first draft of this beat shoved the real card and could not
##          make either check fire (`_place_tip` runs in `_process` and had put
##          it back before the next frame was read, which is the answer to Z2).
##   Z2     The placement is live. Shove the card onto its own cell by hand and
##          it is back one frame later.
##   Z3     The numbers are about the CURRENT cell. A reader that had latched
##          one rect would pass every check in `_walk` while describing nothing.
func _calibrate() -> void:
	var screen := _open(TradeScreen.Mode.PROGRESSION, "THE FORGE", ShopDb,
		&"smith", "Smithing")
	await _rig.wait_frames(12)

	var cell := Rect2(100.0, 100.0, 80.0, 60.0)
	_ck(_hits(Rect2(120.0, 110.0, 200.0, 90.0), cell)
			and not _hits(Rect2(200.0, 100.0, 200.0, 90.0), cell),
		"Z0 calibration: the overlap check sees a card ON a cell and not one beside it")
	_ck(not _fits(Rect2(1100.0, 600.0, 340.0, 200.0), Vector2(1280.0, 720.0))
			and _fits(Rect2(100.0, 100.0, 340.0, 200.0), Vector2(1280.0, 720.0)),
		"Z1 calibration: the on-screen check sees a card off the bottom-right")

	var was := _tip_rect(screen)
	screen._tip.position = _cell_rect(screen).position
	await _rig.wait_frames(2)
	_ck(_tip_rect(screen).is_equal_approx(was)
			and not _overlaps(screen),
		"Z2 the card put itself back after being shoved onto its own cell")

	# Z3. Two different cells, two different rects — read off the live widget.
	await _key(KEY_RIGHT)
	_ck(not _tip_rect(screen).is_equal_approx(was),
		"Z3 the card moved when the cursor did (%s -> %s)"
			% [was.position, _tip_rect(screen).position])
	await _rig.capture(_out.path_join("z_calibration.png"))
	screen.close()
	await _rig.wait_frames(8)


# --- the boards --------------------------------------------------------------

## The smith: five rows of ladders, and the board card #119 is written about.
func _smith() -> void:
	var screen := _open(TradeScreen.Mode.PROGRESSION, "THE FORGE", ShopDb,
		&"smith", "Smithing")
	await _rig.wait_frames(14)

	# A. The column is gone and the board has the width it was using.
	_ck(screen._tip != null and screen._tip.visible,
		"A0 the counter has a description card")
	_ck(screen.find_child("Detail", true, false) == null,
		"A1 the right-hand detail column is gone")
	# Last child of the screen, so it draws over the frame -- and the screen's own
	# CanvasLayer is 60, over the HUD's 50. Card #48 shipped the shop UNDER the
	# world's control legend; a floating card is one more layer to get wrong.
	_ck(screen._tip.get_index() == screen.get_child_count() - 1,
		"A2 the card is the last thing the screen draws")
	var well := screen.find_child("BoardScroll", true, false) as Control
	var frame := screen.find_child("Frame", true, false) as Control
	if well != null and frame != null:
		var slack: float = frame.get_global_rect().end.x - well.get_global_rect().end.x
		_ck(slack < 60.0,
			"A3 the board reaches the frame's right edge (%.0f px short)" % slack)

	await _walk(screen, "b_forge")
	await _mouse_path(screen, "c_forge_mouse")
	screen.close()
	await _rig.wait_frames(8)


## The Lanternkeeper: twelve relics, four rows, and the bottom-left corner that
## card #119 asks to be tested at. Her board is also the one that scrolls.
func _keeper() -> void:
	for row in RelicDb.RELICS:
		Game.set_flag(RelicDb.flag_held(row["id"]))
	var screen := _open(TradeScreen.Mode.PROGRESSION, "THE FAR LANTERN", RelicDb,
		&"keeper", "Artifacts")
	await _rig.wait_frames(14)
	await _walk(screen, "d_keeper")
	screen.close()
	await _rig.wait_frames(8)


## The other layout: two `ItemGrid`s, stock and bag, with the cursor crossing
## from one to the other. The card has to follow it across the gap.
func _quartermaster() -> void:
	Run.collect(&"iron_scrap", 4)
	Run.collect(&"bone_shard", 3)
	Game.add_gold(400)
	var screen := _open(TradeScreen.Mode.TRADE, "THE QUARTERMASTER", SupplyDb,
		&"quartermaster", "Trade")
	await _rig.wait_frames(14)
	_ck(screen.find_child("Detail", true, false) == null,
		"E0 the trade window has no detail column either")
	await _walk(screen, "e_trade")
	await _mouse_path(screen, "f_trade_mouse")
	screen.close()
	await _rig.wait_frames(8)


# --- walking -----------------------------------------------------------------

## Press RIGHT across the whole board and check the card at every stop.
##
## One press per cell plus one, so the walk wraps and the last cell is checked
## from both sides. A capture at the first and last stop only: forty PNGs of a
## board is a contact sheet nobody reads, and the numbers below are the proof.
func _walk(screen, tag: String) -> void:
	_seen.clear()
	var n: int = screen.line_count()
	if n <= 0:
		_rig.fail("%s: the board has no lines to walk" % tag)
		return
	var bad_cover := 0
	var bad_edge := 0
	var bad_text := 0
	for i in n + 1:
		_seen[screen._cursor] = true
		if i == 0 or i == n - 1:
			await _rig.capture(_out.path_join("%s_%02d.png" % [tag, i]))
		if _overlaps(screen):
			bad_cover += 1
			print("  TIP cover: %s at %s (tip %s over cell %s)" % [tag,
				screen.cursor_label(), screen._tip.get_global_rect(),
				screen._tip.anchor.get_global_rect()])
		if not _inside(screen):
			bad_edge += 1
			print("  TIP edge: %s at %s (tip %s in %s)" % [tag,
				screen.cursor_label(), screen._tip.get_global_rect(),
				screen.get_viewport_rect().size])
		if screen._tip.title.text != screen.cursor_label():
			bad_text += 1
			print("  TIP text: %s card says '%s', cursor is on '%s'" % [tag,
				screen._tip.title.text, screen.cursor_label()])
		await _key(KEY_RIGHT)
	_ck(bad_cover == 0,
		"%s the card never covered the cell it describes (%d of %d)"
			% [tag, bad_cover, n])
	_ck(bad_edge == 0,
		"%s the card never left the screen (%d of %d)" % [tag, bad_edge, n])
	_ck(bad_text == 0,
		"%s the card read the cursor's line at every cell (%d wrong)"
			% [tag, bad_text])
	# The same claim `relic_donate` G8 makes, and for the same reason: a board
	# stepping two at a time reaches half its cells and passes everything above.
	_ck(_seen.size() == n,
		"%s one press is one cell -- %d of %d reached" % [tag, _seen.size(), n])


## The mouse path. Land the pointer on a cell the cursor is NOT on and check that
## the card went there.
##
## A real `InputEventMouseMotion` at the cell's centre, which is what `ItemGrid`
## and `UpgradeLadder` hang `mouse_entered` off. Nothing here touches the cursor
## directly; if the mouse route into `_on_cell_looked` ever comes apart this is
## the beat that notices.
func _mouse_path(screen, tag: String) -> void:
	var target := -1
	for line: int in screen._order:
		if line != screen._cursor:
			target = line
			break
	if target < 0:
		_rig.fail("%s: the board has only one cell, nothing to hover" % tag)
		return
	var cell := _cell_for(screen, target)
	if cell == null:
		_rig.fail("%s: no cell for line %d" % [tag, target])
		return

	var was: int = screen._cursor
	await _hover(cell.get_global_rect().get_center())
	_ck(screen._cursor == target,
		"%s the mouse moved the cursor (%d -> %d)" % [tag, was, screen._cursor])
	_ck(screen._tip.title.text == screen.cursor_label(),
		"%s the card followed the mouse ('%s')" % [tag, screen._tip.title.text])
	_ck(not _overlaps(screen),
		"%s the hovered card is not on its own cell" % tag)
	_ck(_inside(screen), "%s the hovered card is on screen" % tag)
	await _rig.capture(_out.path_join("%s.png" % tag))

	# And back to the pad on the same screen, because the two paths share one
	# cursor and the failure worth catching is one of them poisoning the other.
	await _key(KEY_RIGHT)
	_ck(screen._tip.title.text == screen.cursor_label(),
		"%s the pad still moves it after the mouse has ('%s')"
			% [tag, screen._tip.title.text])


# --- plumbing ----------------------------------------------------------------

func _cell_for(screen, line: int) -> Button:
	if screen.mode == TradeScreen.Mode.TRADE:
		var at: int = screen._stock_rows.find(line)
		if at >= 0:
			return screen._stock_grid.cell_at(at)
		at = screen._bag_rows.find(line)
		return screen._bag_grid.cell_at(at) if at >= 0 else null
	return screen._ladder.cell_at(screen._ladder.slot_of_line(line))


## A real key, down the InputMap, both keycodes set so the keycode-bound `ui_*`
## actions and the physical-bound game actions both see it. Lifted from
## `mouse_cursor.gd`, which lifted it from `_menu_director.gd`.
func _key(code: int) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await _rig.wait_frames(2)
	await _rig.wait_frames(4)


## Put the pointer at a screen position, for real.
func _hover(at: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = at
	mm.global_position = at
	mm.relative = Vector2.ONE
	Input.parse_input_event(mm)
	await _rig.wait_frames(6)


## Opened directly rather than walked to. `forge_loop` and `relic_donate` own
## whether these counters can be REACHED; this is a question about one widget on
## a screen four counters share.
func _open(mode: int, title: String, db: GDScript, voice: StringName,
		service: String) -> TradeScreen:
	return TradeScreen.open(_rig.scene(), mode, title, db, voice, service)
