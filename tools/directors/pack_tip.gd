extends RefCounted
## The BAG's description card, walked with the pad and with the mouse.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/ui/menu/_menu_test.tscn \
##     --director=res://tools/directors/pack_tip.gd \
##     --out=/tmp/pack/x.png --size=1280x720 --warmup=60
##
## Card #156 took the counter's hover card (`ItemTip`, card #119) and gave it to
## the pouch and the locker, deleting their right-hand detail columns. That is
## the same widget on a screen with a shape it has never been on: **two grids**
## (the case and the bag), a button that is not in either of them (the escape
## rope), and a left-hand column that puts the cells further left than any
## counter's board does.
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
