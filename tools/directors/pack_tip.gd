extends RefCounted
## The BAG's description card, walked with the pad and with the mouse.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/ui/menu/_menu_test.tscn \
##     --director=res://tools/directors/pack_tip.gd \
##     --out=/tmp/pack/x.png --size=1280x720 --warmup=60
##
## Card #156 took the counter's hover card (`ItemTip`, card #119) and gave it to
## every other screen that draws items — the bag, the locker, the EQUIP page and
## the receipt — deleting three more right-hand detail columns. `shop_tip.gd`
## owns the counters; this owns the rest, and each of the three has a shape the
## widget has never been on:
##
##   the BAG      two grids (the case and the bag), a button in neither of them
##                (the escape rope), and a left-hand column that puts the cells
##                further left than any counter's board does
##   EQUIP        slots in the MIDDLE of the frame, where the card cannot go
##                right and has to fall through to the second candidate
##   the RECEIPT  cells that cannot take focus at all, so the hover route is the
##                only route in
##
## `tools/directors/shop_tip.gd` is the same proof for the counter and this is
## deliberately its twin — the three ways the card goes wrong do not change with
## the screen:
##
##   A  It covers the cell it is describing. The one thing a description of a
##      thing must never do, and it only happens at SOME cells.
##   B  It runs off the screen. The bag's last row and the rope, which is the
##      lowest thing on the page, are this screen's corners.
##   C  It stops following. The pouch feeds it from `_describe`, which is reached
##      from FOUR places — the bag grid's `cell_focused`, the case grid's, the
##      rope's `focus_entered`, and `_describe_focus` on a refresh — and a card
##      that latched one of them would pass every "is it on screen" check while
##      describing the wrong item.
##
## So the card is checked at EVERY cell of both grids, on both input paths, and
## the geometry is numbers rather than an eyeball: the tip rect against the
## anchor cell's rect, and the tip rect against the viewport.
##
## **Both directions of calibration (CLAUDE.md §2)** and it is Z0..Z3 rather than
## a note. An instrument that has only ever been shown a passing value has never
## been tested: Z0/Z1 hand the two predicates rectangles whose answer is known,
## Z2 shoves the live card onto its own cell and requires it back (the placement
## runs every frame and corrects itself — which is exactly why shoving the real
## card is the only way to prove the placement is live rather than a one-shot),
## and Z3 requires the numbers to be about the CURRENT cell.
##
## Real `InputEventKey` and a real `InputEventMouseMotion` throughout. Never
## `Input.action_press`, which dispatches no event at all, and never an
## assignment to a panel's cursor field, which holds for one frame (CLAUDE.md
## §3, cards #40 and #77).
##
## What this director does NOT claim: that the bag is five per row and fits the
## frame. `menu_pages.gd` beats 1 and 2 own that, counted off the drawn cells'
## x positions, and a second copy of that measurement here would be a second
## place it can disagree.

var _rig
var _out := ""
var _pass := 0
var _fail := 0


func run(rig) -> void:
	_rig = rig
	_out = rig.arg("out", "/tmp/pack/x.png").get_base_dir()
	await rig.wait_frames(20)

	var menu: PauseMenu = Menu
	var pouch: MenuPouchPanel = menu.get_node("Root/Screens/PouchScreen")

	_fill_the_bag()
	await rig.wait_frames(6)
	await _open_pouch(menu)
	if not pouch.visible:
		_rig.fail("the INVENTORY screen never came up")
		return

	await _calibrate(pouch)
	await _shape(pouch)
	await _walk(pouch, "b_bag")
	await _mouse_path(pouch, "c_mouse")
	await _rope(pouch)
	await _equip(menu)
	await _receipt()
	print("PACK done (%d passed, %d failed)" % [_pass, _fail])


# --- the instrument ----------------------------------------------------------

func _ck(ok: bool, what: String) -> bool:
	if ok:
		_pass += 1
		print("  ok   %s" % what)
	else:
		_fail += 1
		_rig.fail(what)
	return ok


## The two predicates, over bare geometry, so `_calibrate` can hand them
## rectangles whose answer it already knows.
func _hits(tip: Rect2, cell: Rect2) -> bool:
	return tip.intersects(cell)


func _fits(tip: Rect2, view: Vector2) -> bool:
	return Rect2(Vector2.ZERO, view).encloses(tip)


func _tip_rect(pouch) -> Rect2:
	var r: Rect2 = pouch._tip.get_global_rect()
	return r


func _anchor_rect(pouch) -> Rect2:
	var r: Rect2 = pouch._tip.anchor.get_global_rect()
	return r


func _view(pouch) -> Vector2:
	var v: Vector2 = pouch.get_viewport_rect().size
	return v


func _overlaps(pouch) -> bool:
	if pouch._tip.anchor == null:
		return false
	return _hits(_tip_rect(pouch), _anchor_rect(pouch))


func _inside(pouch) -> bool:
	return _fits(_tip_rect(pouch), _view(pouch))


func _calibrate(pouch) -> void:
	var cell := Rect2(100.0, 100.0, 84.0, 84.0)
	_ck(_hits(Rect2(120.0, 110.0, 340.0, 90.0), cell)
			and not _hits(Rect2(200.0, 100.0, 340.0, 90.0), cell),
		"Z0 calibration: the overlap check sees a card ON a cell and not one beside it")
	_ck(not _fits(Rect2(1100.0, 600.0, 340.0, 200.0), Vector2(1280.0, 720.0))
			and _fits(Rect2(100.0, 100.0, 340.0, 200.0), Vector2(1280.0, 720.0)),
		"Z1 calibration: the on-screen check sees a card off the bottom-right")

	if pouch._tip.anchor == null:
		_ck(false, "Z2 the card is describing something to shove")
		return
	var was := _tip_rect(pouch)
	pouch._tip.position = _anchor_rect(pouch).position
	await _rig.wait_frames(2)
	_ck(_tip_rect(pouch).is_equal_approx(was) and not _overlaps(pouch),
		"Z2 the card put itself back after being shoved onto its own cell")

	await _key(KEY_RIGHT)
	_ck(not _tip_rect(pouch).is_equal_approx(was),
		"Z3 the card moved when the cursor did (%s -> %s)"
			% [was.position, _tip_rect(pouch).position])
	await _rig.capture(_out.path_join("a_calibration.png"))


# --- the screen --------------------------------------------------------------

## The removal itself, and the two ways a floating card is drawn wrong.
func _shape(pouch) -> void:
	_ck(pouch._tip != null and pouch._tip.visible,
		"A0 the bag has a description card, and it is up")
	_ck(pouch.find_child("Detail", true, false) == null,
		"A1 the right-hand detail column is gone")
	# Last child, so it draws over the frame and the paper doll rather than under
	# them. Card #48 shipped a screen UNDER the world's legend; a card that
	# floats is one more thing to get in the wrong order.
	_ck(pouch._tip.get_index() == pouch.get_child_count() - 1,
		"A2 the card is the last thing the pouch draws")
	# And it must not take the pointer: the card floats over the cells, so a card
	# with a live mouse filter would eat `mouse_entered` from whatever it landed
	# on and the mouse path in `_mouse_path` would die the moment it covered a row.
	var greedy: Array[String] = []
	for n: Node in _all(pouch._tip):
		var c := n as Control
		if c != null and c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			greedy.append(String(c.name))
	_ck(greedy.is_empty(),
		"A3 nothing on the card takes the pointer (%s)" % [greedy])


# --- walking -----------------------------------------------------------------

## Both grids, cell by cell, with the card checked at every stop.
##
## RIGHT **wraps inside a row** (`ItemGrid._wire_focus`, and it is deliberate —
## a stick that dead-ends every fifth cell is the failure that wiring exists to
## prevent), so a walk that only pressed RIGHT would circle the case's three
## cells forever and report every check green off three of the twelve. So: RIGHT
## while the row still has an unvisited cell in it, DOWN the moment it comes back
## round to one already seen.
##
## The walk is driven by keys and read off the FOCUS OWNER, never off an index
## the director chose: what is under test is that the four routes into
## `_describe` agree with each other, and a director that asked the panel which
## cell it was on would be asking one of the four.
func _walk(pouch, tag: String) -> void:
	var n: int = pouch._grid.count() + pouch._case_grid.count()
	if n <= 0:
		_rig.fail("%s: the bag drew no cells to walk" % tag)
		return
	var seen := {}
	var bad_cover := 0
	var bad_edge := 0
	var bad_text := 0
	var bad_anchor := 0
	var shots := 0
	var off := 0
	for _step in n * 4:
		if seen.size() >= n:
			break
		var cell := _focused() as Button
		var want := _expect(pouch, cell)
		if want == "":
			# Off the grids — the spill under the bottom row. Two in a row and
			# the walk has left the collection for good rather than clipped a
			# padding cell, so stop instead of wandering the page.
			off += 1
			if off >= 2:
				break
			await _key(KEY_UP)
			continue
		off = 0
		if seen.has(cell.get_path()):
			await _key(KEY_DOWN)
			continue
		seen[cell.get_path()] = true
		if shots < 2 and (seen.size() == 1 or seen.size() == n - 1):
			shots += 1
			await _rig.capture(_out.path_join("%s_%02d.png" % [tag, seen.size()]))
		if pouch._tip.anchor != cell:
			bad_anchor += 1
			print("  PACK anchor: %s card is hung off %s, focus is on %s" % [tag,
				pouch._tip.anchor, cell.name])
		elif _overlaps(pouch):
			bad_cover += 1
			print("  PACK cover: %s tip %s over cell %s" % [tag,
				_tip_rect(pouch), _anchor_rect(pouch)])
		if not _inside(pouch):
			bad_edge += 1
			print("  PACK edge: %s tip %s in %s" % [tag, _tip_rect(pouch),
				_view(pouch)])
		if pouch._tip.title.text != want:
			bad_text += 1
			print("  PACK text: %s card says '%s', the cell is '%s'"
				% [tag, pouch._tip.title.text, want])
		await _key(KEY_RIGHT)

	_ck(bad_anchor == 0,
		"%s the card hung off the cell that had focus (%d of %d wrong)"
			% [tag, bad_anchor, n])
	_ck(bad_cover == 0,
		"%s the card never covered the cell it describes (%d of %d)"
			% [tag, bad_cover, n])
	_ck(bad_edge == 0,
		"%s the card never left the screen (%d of %d)" % [tag, bad_edge, n])
	_ck(bad_text == 0,
		"%s the card named the cell's own item at every stop (%d wrong)"
			% [tag, bad_text])
	# The claim `relic_donate` G8 and `shop_tip` both make, for the same reason:
	# a grid stepping two at a time reaches half its cells and passes every check
	# above off the half it reached. Every cell of both grids, or this beat's
	# numerators are about a board the director only saw part of.
	_ck(seen.size() == n,
		"%s every cell of the case and the bag was reached (%d of %d)"
			% [tag, seen.size(), n])


## The mouse. Land the pointer on a cell the focus is NOT on and require the card
## to have gone there — this is the route through `mouse_entered` rather than
## `focus_entered`, and it is the one most likely to come apart.
func _mouse_path(pouch, tag: String) -> void:
	var here := _focused()
	var target: Button = null
	for i in pouch._grid.count():
		var c: Button = pouch._grid.cell_at(i)
		if c != null and c != here and _expect(pouch, c) != "":
			target = c
			break
	if target == null:
		_rig.fail("%s: no second cell to hover" % tag)
		return

	var want := _expect(pouch, target)
	await _hover(target.get_global_rect().get_center())
	_ck(pouch._tip.anchor == target,
		"%s the mouse moved the card onto the hovered cell" % tag)
	_ck(pouch._tip.title.text == want,
		"%s the card reads the hovered cell ('%s')" % [tag, pouch._tip.title.text])
	_ck(not _overlaps(pouch), "%s the hovered card is not on its own cell" % tag)
	_ck(_inside(pouch), "%s the hovered card is on screen" % tag)
	await _rig.capture(_out.path_join("%s.png" % tag))

	# And back to the pad on the same screen: the two routes share one card and
	# the failure worth catching is one of them poisoning the other.
	target.grab_focus()
	await _rig.wait_frames(4)
	await _key(KEY_RIGHT)
	var now := _focused() as Button
	_ck(pouch._tip.anchor == now,
		"%s the pad still moves the card after the mouse has" % tag)


## The rope is not in either grid and it is the lowest thing on the page, so it
## is this screen's bottom edge — the case `ItemTip`'s "under it" and "over it"
## fallbacks exist for.
func _rope(pouch) -> void:
	pouch._rope.grab_focus()
	await _rig.wait_frames(8)
	_ck(pouch._tip.anchor == pouch._rope,
		"D0 the card follows focus off the grids onto the escape rope")
	_ck(pouch._tip.title.text == "Escape Rope",
		"D1 ...and says what it is ('%s')" % pouch._tip.title.text)
	_ck(not _overlaps(pouch), "D2 the card is not on the rope button")
	_ck(_inside(pouch), "D3 the card is on screen at the bottom of the page (%s in %s)"
		% [_tip_rect(pouch), _view(pouch)])
	await _rig.capture(_out.path_join("d_rope.png"))


## EQUIP. The same card, on the screen whose "items" are the two hands, the
## alternate set and the eight directions of the kit wheel.
##
## Its detail column went the same way the bag's did, and it is the screen where
## the placement is hardest: the hand slots are 228 px wide and sit in the MIDDLE
## of the frame, so the card cannot go right (the stat column is there) and has
## to fall through to the second candidate. That fallback is exactly what
## `ItemTip.spot_for` is four candidates long for, and nothing else in the game
## exercises it from the middle.
func _equip(menu: PauseMenu) -> void:
	var equip = menu.get_node("Root/Screens/EquipScreen")
	if menu.is_open:
		menu.close()
		await _rig.wait_frames(6)
	menu.open()
	await _rig.wait_frames(8)
	# `_open_onto` is how the menu's own buttons land on a page — the same call
	# `open_pouch` makes. Setting `visible` by hand would skip the focus the page
	# grabs on arriving, and focus is what this beat reads.
	menu._open_onto(PauseMenu.Screen.EQUIP)
	await _rig.wait_frames(14)
	if not equip.visible:
		_rig.fail("E: the EQUIP page never came up")
		return

	_ck(equip.find_child("Detail", true, false) == null,
		"E0 the EQUIP page has no detail column either")
	_ck(equip._tip != null and equip._tip.get_index() == equip.get_child_count() - 1,
		"E1 its card is the last thing it draws")

	# Every hand slot and every wheel cell, driven by the real focus rather than
	# by `_describe` — a director that called the writer would prove the writer
	# and not the four routes into it.
	var bad_cover := 0
	var bad_edge := 0
	var bad_anchor := 0
	var seen := 0
	var cells: Array = []
	for b: Button in equip._slots:
		cells.append(b)
	for b: Button in equip._wheel_cells:
		cells.append(b)
	for b: Button in cells:
		b.grab_focus()
		await _rig.wait_frames(5)
		seen += 1
		if equip._tip.anchor != b:
			bad_anchor += 1
			print("  PACK anchor: EQUIP card is on %s, focus is %s"
				% [equip._tip.anchor, b.name])
		elif _hits(equip._tip.get_global_rect(), b.get_global_rect()):
			bad_cover += 1
			print("  PACK cover: EQUIP tip %s over slot %s"
				% [equip._tip.get_global_rect(), b.get_global_rect()])
		if not _fits(equip._tip.get_global_rect(), _view(equip)):
			bad_edge += 1
			print("  PACK edge: EQUIP tip %s in %s"
				% [equip._tip.get_global_rect(), _view(equip)])
	_ck(seen > 0, "E2 the EQUIP page has slots to describe (%d)" % seen)
	_ck(bad_anchor == 0,
		"E3 the card hung off the focused slot at all %d of them (%d wrong)"
			% [seen, bad_anchor])
	_ck(bad_cover == 0, "E4 it never covered the slot it describes (%d)" % bad_cover)
	_ck(bad_edge == 0, "E5 it never left the screen (%d)" % bad_edge)
	_ck(String(equip._tip.kicker.text).contains("KIT WHEEL"),
		"E6 the last cell walked was a wheel direction ('%s')" % equip._tip.kicker.text)
	await _rig.capture(_out.path_join("e_equip.png"))
	menu.close()
	await _rig.wait_frames(8)


## The RECEIPT, which is the one screen where a stack cannot be acted on — and
## the one where the player is most likely to be looking at something they have
## never seen before, because it is what the floor just took off them.
##
## Its cells are deliberately unfocusable (a highlight on a stack you cannot
## touch, over the cross), so this beat is MOUSE ONLY. That is the whole risk
## worth checking: the hover route is the only route in, and it goes through a
## `mouse_filter` that was `IGNORE` until the card existed.
func _receipt() -> void:
	Run.enter(9101)
	Run.collect(&"deep_amber", 2)
	Run.collect(&"bone_shard", 6)
	Run.extract()
	# Copied BEFORE the ride home is stood down, and the ride home stood down
	# before a receipt of our own is opened. `Run.extract()` starts the real
	# ending, and the real ending opens its OWN `RunEndScreen` a second or so
	# later -- on the same layer, later in the scene, so it draws OVER this
	# beat's screen. The first version of this beat did not wait, and every check
	# below passed off a widget that was underneath another receipt: the card was
	# visible, anchored, correctly placed, and photographed as a blank strip of
	# somebody else's screen. `forgive_loop._settle`, whole, and for the reason
	# its own comment gives.
	var summary: Dictionary = Run.summary.duplicate(true)
	await _rig.wait_seconds(1.2)
	Flow.ending = false
	for n in _all(_rig.scene()):
		if n is RunEndScreen:
			n.get_parent().queue_free()
	_rig.paused = false
	await _rig.wait_frames(10)

	var screen := RunEndScreen.open(_rig.scene(), summary)
	await _rig.wait_frames(16)
	_ck(_receipts() == 1,
		"F0 exactly one receipt is up (%d)" % _receipts())

	var grid: ItemGrid = null
	for n in _all(screen):
		if n is ItemGrid:
			grid = n
			break
	if grid == null or grid.count() == 0:
		_ck(false, "F1 the receipt drew a grid of stacks")
		screen.get_parent().queue_free()
		return
	var cell: Button = grid.cell_at(0)
	_ck(cell.focus_mode == Control.FOCUS_NONE,
		"F1 the receipt's stacks still cannot take focus")
	await _hover(cell.get_global_rect().get_center())
	_ck(screen._tip.visible and screen._tip.anchor == cell,
		"F2 hovering a stack put the card on it")
	_ck(screen._tip.title.text != "",
		"F3 ...and the card names it ('%s')" % screen._tip.title.text)
	_ck(not _hits(screen._tip.get_global_rect(), cell.get_global_rect()),
		"F4 the card is not on the stack it describes")
	_ck(_fits(screen._tip.get_global_rect(), _view(screen)),
		"F5 the card is on screen (%s in %s)"
			% [screen._tip.get_global_rect(), _view(screen)])
	await _rig.capture(_out.path_join("f_receipt.png"))
	screen.get_parent().queue_free()
	await _rig.wait_frames(6)


# --- plumbing ----------------------------------------------------------------

## What the card SHOULD say about `cell`, or "" if that is not a cell of either
## grid (a padding cell, the tab strip, the Back button).
##
## Derived from the panel's own id arrays rather than from the card, which is the
## thing under test. An empty slot is a real answer here and not a skip: the bag
## draws its capacity, so most of a fresh bag is empty cells and a card that went
## blank over them would be the screen saying nothing where it says "Empty".
func _expect(pouch, cell: Button) -> String:
	if cell == null:
		return ""
	for pair: Array in [[pouch._case_grid, pouch._case_ids],
			[pouch._grid, pouch._cell_ids]]:
		var grid: ItemGrid = pair[0]
		var ids: Array = pair[1]
		for i in grid.count():
			if grid.cell_at(i) != cell:
				continue
			if i >= ids.size():
				return ""
			var id: StringName = ids[i]
			return "Empty" if id == &"" else ItemDb.get_def(id).display_name
	return ""


## How many receipts are in the scene. One, or this beat is reading a widget
## that is underneath another one.
func _receipts() -> int:
	var n := 0
	for x in _all(_rig.scene()):
		if x is RunEndScreen:
			n += 1
	return n


func _focused() -> Control:
	return _rig.root.gui_get_focus_owner()


func _all(n: Node) -> Array[Node]:
	var out: Array[Node] = [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out


func _open_pouch(menu: PauseMenu) -> void:
	if menu.is_open:
		menu.close()
		await _rig.wait_frames(6)
	menu.open_pouch()
	await _rig.wait_frames(14)


## Enough distinct stacks that the grid is a full picture and not three cells and
## a lot of dashes. `menu_pages._fill_the_bag`, whole.
func _fill_the_bag() -> void:
	Run.enter(1)
	for id: StringName in ItemDb.all().keys():
		if Run.slots_used() >= Game.bag_slots:
			break
		Run.collect(id, 1)


func _key(code: int) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await _rig.wait_frames(2)
	await _rig.wait_frames(5)


func _hover(at: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = at
	mm.global_position = at
	mm.relative = Vector2.ONE
	Input.parse_input_event(mm)
	await _rig.wait_frames(6)
