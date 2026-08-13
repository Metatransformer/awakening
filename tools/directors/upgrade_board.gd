extends RefCounted
## Cards #118 and #175's acceptance test, as a measurement instead of an opinion.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/upgrade_board.gd \
##     --out=/tmp/board/x.png --size=1280x720 --warmup=60
##
## The board is a Moonlighter-like progression map: service tabs, one textured
## stone row per track, authored names on every full-size rung, arrows between
## rungs, and visible locks on the future. A persistent inspector beside it owns
## the selected upgrade's stat result and icon/required/owned recipe rows.
##
## Four beats:
##
##   A  a fresh smith            — tabs, named nodes, locks, stone and recipe
##   B  the same smith, climbed  — the active tab has no locks left
##   C  A vs B, as a pixel count over the board's own rect
##   D  every other counter that draws a board, so a `groups()` row with no
##      `icon` token or a bad one is found here and not by a player
##   E  the TRADE window, where the same asset family lands on `ItemCell` -- the
##      bag is the other half of the card's "bring in icons for the items we
##      have", and it draws through a different resolver than the board does
##
## **Both directions of calibration, per CLAUDE.md §2.** The instrument this
## needs is a pixel diff, and a pixel diff's two failure modes are opposite: it
## can be blind (Z0 — two boards it should be able to tell apart read as
## identical) and it can be hallucinating (Z1 — the NULL case, one board against
## itself, which must be exactly zero). Z1 is the one that matters most here and
## is the reason the board is stilled before every capture: this project has a
## fog that never converges and a quantiser that turns a 1/255 wobble into ink
## (CLAUDE.md §3), and a shop screen sits over a live room.

const MIN_DIFF := 0.06

var _rig
var _out := ""
var _fresh: Image = null


func run(rig) -> void:
	_rig = rig
	_out = rig.arg("out", "/tmp/board/x.png").get_base_dir()
	await rig.wait_frames(20)

	await _calibrate()
	await _fresh_smith()
	await _climbed_smith()
	await _other_counters()
	await _item_glyphs()
	print("BOARD done")


func _ck(ok: bool, what: String) -> bool:
	if ok:
		print("  ok   %s" % what)
	else:
		_rig.fail(what)
	return ok


# --- the instrument ----------------------------------------------------------

## Fraction of pixels that differ between two same-size images, over the 0.02 the
## directors here call ink (5 of 255, summed across the three channels).
##
## Through `get_data()` and not `get_pixel()`, for the reason `frame_repro.gd`
## already wrote down: this is a quarter of a million pixels a call and GDScript
## charges per call, not per byte.
func _ink(a: Image, b: Image) -> float:
	if a == null or b == null:
		return -1.0
	# Footer copy and a material recipe can change the board well by a few pixels.
	# Compare the common top-left board rect; both inputs are already crops of the
	# same named BoardScroll.
	if a.get_size() != b.get_size():
		var common := Vector2i(mini(a.get_width(), b.get_width()),
			mini(a.get_height(), b.get_height()))
		if common.x <= 0 or common.y <= 0:
			return -1.0
		a = a.get_region(Rect2i(Vector2i.ZERO, common))
		b = b.get_region(Rect2i(Vector2i.ZERO, common))
	var ra := _rgb(a)
	var rb := _rgb(b)
	var total := a.get_width() * a.get_height()
	var n := 0
	var i := 0
	while i < total:
		var j := i * 3
		var d := absi(ra[j] - rb[j]) + absi(ra[j + 1] - rb[j + 1]) \
			+ absi(ra[j + 2] - rb[j + 2])
		if d > 5:
			n += 1
		i += 1
	return float(n) / float(maxi(total, 1))


## An image's bytes as flat RGB, on a copy. `convert` is destructive and the
## fresh board is held across two beats -- converting the caller's image in place
## would mean the second comparison ran against something the first had edited.
func _rgb(img: Image) -> PackedByteArray:
	if img.get_format() == Image.FORMAT_RGB8:
		return img.get_data()
	var c := img.duplicate() as Image
	c.convert(Image.FORMAT_RGB8)
	return c.get_data()


## The board's own rect, cropped out of a full frame. The diff is about the BOARD
## and not about the room behind the window: a shop screen leaves most of the
## viewport showing the garrison, and a diff over the whole frame would be
## measuring a torch.
## The rig has no "give me the frame" call -- `capture` writes a PNG -- so the
## frame comes back off disk. That is not a detour: the PNG is the thing the card
## asks to be able to tell apart, so diffing the saved files measures exactly
## what a human opening them would see, quantiser and all.
func _board_shot(screen: TradeScreen, path: String) -> Image:
	_rig.still_the_frame()
	await _rig.wait_frames(3)
	await _rig.capture(path)
	var full := Image.load_from_file(path)
	if full == null:
		_ck(false, "the capture at %s could not be read back" % path)
		return null
	var well := screen.find_child("BoardScroll", true, false) as Control
	if well == null:
		return full
	# `capture` resizes to --size, and the Control rects are in viewport units,
	# so the crop is only right after a scale. On a 1:1 run this is 1.0 and the
	# line costs nothing; on a hiDPI backbuffer it is the difference between the
	# board and a strip of the wall beside it.
	var vp := screen.get_viewport().get_visible_rect().size
	var k := Vector2(full.get_width() / maxf(vp.x, 1.0), full.get_height() / maxf(vp.y, 1.0))
	var r := well.get_global_rect()
	var clipped := Rect2i(Vector2i((r.position * k).floor()), Vector2i((r.size * k).ceil())) \
		.intersection(Rect2i(Vector2i.ZERO, full.get_size()))
	if clipped.size.x <= 0 or clipped.size.y <= 0:
		return full
	return full.get_region(clipped)


## Point the diff at two answers it already knows, in both directions.
##
## Z0 — it can SEE a difference. A copy with one row of pixels rewritten must
##      read as changed; an `_ink` that always answered 0 would pass every check
##      in this file and prove nothing.
## Z1 — the NULL case, and the half a stall-style calibration cannot catch. One
##      image against ITSELF is exactly 0. If that is ever non-zero the diff is
##      inventing ink, and C's verdict below is a coin toss (CLAUDE.md §2 — six
##      of this project's instrument failures were false positives, not blind
##      ones).
func _calibrate() -> void:
	var a := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	a.fill(Color(0.1, 0.1, 0.12))
	var b := a.duplicate() as Image
	_ck(_ink(a, b) == 0.0, "Z1 the null case is exactly zero (identical images)")
	for x in 64:
		b.set_pixel(x, 32, Color(0.9, 0.9, 0.9))
	_ck(absf(_ink(a, b) - (1.0 / 64.0)) < 0.001,
		"Z0 the diff sees one changed row of 64 (%.4f)" % _ink(a, b))


# --- the beats ---------------------------------------------------------------

## Rung 0 on everything, which is what a save that has never been to the smith
## looks like. Reset explicitly rather than trusting the boot state: the other
## directors in this tree share a `Game` and the fresh half of the comparison is
## the half that a leftover purchase would silently ruin.
func _fresh_smith() -> void:
	Game.upgrades.clear()
	var screen := _open("THE FORGE", ShopDb)
	await _rig.wait_frames(16)

	var ladder := screen.find_child("Board", true, false) as UpgradeLadder
	_ck(ladder != null, "A0 the smith draws an UpgradeLadder")
	var rows := _rows(ladder)
	var named := _named_rungs(ladder)
	_ck(_tabs(ladder) >= 2, "A1 the smith exposes service tabs (%d drawn)" % _tabs(ladder))
	_ck(_faces(ladder) == rows,
		"A2 every visible track has a face (%d of %d)" % [_faces(ladder), rows])
	_ck(_stone_tracks(ladder) == rows,
		"A3 every visible track has textured stone (%d of %d)" % [_stone_tracks(ladder), rows])
	_ck(named.x == named.y and named.y > 0,
		"A4 every rung has an authored name (%d of %d)" % [named.x, named.y])
	_ck(_locks(ladder) > 0,
		"A5 future rungs are full locked nodes (%d locks)" % _locks(ladder))
	var detail := screen.find_child("UpgradeDetail", true, false) as Control
	_ck(detail != null, "A6 progression keeps a persistent detail inspector")
	_ck(_recipe_icons(detail) > 0,
		"A7 the selected recipe shows material icons (%d drawn)" % _recipe_icons(detail))

	_fresh = await _board_shot(screen, _out.path_join("a_fresh.png"))
	screen.close()
	await _rig.wait_frames(8)


## The same counter with every ladder climbed. `Game.upgrades` is the store the
## board reads through `ShopDb.groups`, so writing it is writing the save.
func _climbed_smith() -> void:
	for id: StringName in [&"edge", &"guard", &"string", &"chain"]:
		Game.upgrades[id] = K.FORGE_MAX
	for piece: StringName in Game.PLATE_PIECES:
		Game.upgrades[Game.plate_track(piece, Game.PLATE_HEAVY)] = K.FORGE_MAX
	var screen := _open("THE FORGE", ShopDb)
	await _rig.wait_frames(16)

	var ladder := screen.find_child("Board", true, false) as UpgradeLadder
	_ck(_locks(ladder) == 0,
		"B0 a climbed active tab has no locks left (%d)" % _locks(ladder))

	var climbed := await _board_shot(screen, _out.path_join("b_climbed.png"))

	# C. The card's own sentence, as a number.
	var ink := _ink(_fresh, climbed)
	if ink < 0.0:
		_ck(false, "C the two board crops have no common pixels to compare")
	else:
		_ck(ink >= MIN_DIFF,
			"C two saves are told apart without reading a word (%.1f%% of the board differs, want >= %.0f%%)"
				% [ink * 100.0, MIN_DIFF * 100.0])
	screen.close()
	await _rig.wait_frames(8)


## Every other counter that draws a board. Besides catching missing track art,
## this proves the shared tab/name/stone contract against each catalogue shape.
func _other_counters() -> void:
	for row in RelicDb.RELICS:
		Game.set_flag(RelicDb.flag_held(row["id"]))
	var counters := [
		["THE FAR LANTERN", RelicDb, "d_keeper"],
		["THE QUARTERMASTER", SupplyDb, "d_supply"],
		["THE STILLROOM", AlchemyDb, "d_alchemy"],
		["THE JEWELLER", JewelDb, "d_jewel"],
	]
	for c in counters:
		var screen := _open(String(c[0]), c[1] as GDScript)
		await _rig.wait_frames(14)
		var ladder := screen.find_child("Board", true, false) as UpgradeLadder
		var rows := _rows(ladder)
		var faces := _faces(ladder)
		if rows > 0:
			_ck(faces == rows, "%s every row has a face (%d of %d)"
				% [String(c[2]), faces, rows])
			_ck(_tabs(ladder) > 0, "%s has at least one upgrade tab" % String(c[2]))
			_ck(_stone_tracks(ladder) == rows,
				"%s every row has textured stone (%d of %d)"
					% [String(c[2]), _stone_tracks(ladder), rows])
			var named := _named_rungs(ladder)
			_ck(named.x == named.y and named.y > 0,
				"%s every rung is named (%d of %d)"
					% [String(c[2]), named.x, named.y])
		_rig.still_the_frame()
		await _rig.wait_frames(3)
		await _rig.capture(_out.path_join(String(c[2]) + ".png"))
		screen.close()
		await _rig.wait_frames(8)


# --- reading the board -------------------------------------------------------

## Rows are the named track panels under the active tab's Tracks container.
func _rows(ladder: UpgradeLadder) -> int:
	if ladder == null:
		return 0
	return ladder.find_children("Track_*", "PanelContainer", true, false).size()


## Faces are TextureRects with a texture on them. Counted rather than assumed,
## because `UiKit.track_icon` answers "" for a token with no file and the row
## then draws no face at all — which is exactly the failure this counts.
func _faces(ladder: UpgradeLadder) -> int:
	if ladder == null:
		return 0
	var n := 0
	for node in ladder.find_children("*", "TextureRect", true, false):
		var t := node as TextureRect
		if t.texture != null and is_equal_approx(t.custom_minimum_size.x,
				UpgradeLadder.ROW_ICON_PX):
			n += 1
	return n


func _tabs(ladder: UpgradeLadder) -> int:
	if ladder == null:
		return 0
	return ladder.find_children("Tab_*", "Button", true, false).size()


func _stone_tracks(ladder: UpgradeLadder) -> int:
	if ladder == null:
		return 0
	var n := 0
	for node in ladder.find_children("Track_*", "PanelContainer", true, false):
		if (node as PanelContainer).get_theme_stylebox("panel") is StyleBoxTexture:
			n += 1
	return n


## A future rung remains a full Button and carries the generated lock glyph.
func _locks(ladder: UpgradeLadder) -> int:
	if ladder == null:
		return 0
	var n := 0
	for node in ladder.find_children("Rung_*", "Button", true, false):
		var button := node as Button
		if button.focus_mode != Control.FOCUS_NONE:
			continue
		for child in button.find_children("*", "TextureRect", true, false):
			if is_equal_approx((child as TextureRect).custom_minimum_size.x, 17.0):
				n += 1
				break
	return n


## x = authored/readable names, y = total rungs. The rejected set is the old
## Roman-numeral-only board, plus the empty label failure.
func _named_rungs(ladder: UpgradeLadder) -> Vector2i:
	if ladder == null:
		return Vector2i.ZERO
	var good := 0
	var total := 0
	var roman := ["I", "II", "III", "IV", "V", "VI"]
	for node in ladder.find_children("Rung_*", "Button", true, false):
		total += 1
		var labels := node.find_children("*", "Label", true, false)
		var text := String((labels[0] as Label).text).strip_edges() if not labels.is_empty() else ""
		if not text.is_empty() and not roman.has(text):
			good += 1
	return Vector2i(good, total)


func _recipe_icons(detail: Control) -> int:
	if detail == null:
		return 0
	var n := 0
	for node in detail.find_children("*", "TextureRect", true, false):
		if (node as TextureRect).texture != null:
			n += 1
	return n


## The bag and the counter, in TRADE mode. `UpgradeLadder` reads
## `UiKit.track_icon`; `ItemCell` reads `UiKit.item_icon`, which is a different
## family in a different folder with a HUD-first fallback in front of it. Two
## resolvers means two ways to draw nothing, so both are counted.
##
## `>= 4` rather than "every cell": a stall the quartermaster has not stocked is
## empty, and an item with no bake yet draws the old chip-and-name cell on
## purpose (see `build_item_icons.py --check`, which calls that UNBAKED and not a
## failure). What must never happen is a counter of full cells with NO art at
## all, which is what a broken resolver looks like.
func _item_glyphs() -> void:
	Run.collect(&"iron_scrap", 4)
	Run.collect(&"bone_shard", 3)
	Game.add_gold(400)
	var screen := TradeScreen.open(_rig.scene(), TradeScreen.Mode.TRADE,
		"THE QUARTERMASTER", SupplyDb, &"quartermaster", "Trade")
	await _rig.wait_frames(16)

	var art := 0
	for node in screen.find_children("Art", "TextureRect", true, false):
		if (node as TextureRect).texture != null:
			art += 1
	_ck(art >= 4, "E0 the bag draws item glyphs (%d cells carry art)" % art)

	_rig.still_the_frame()
	await _rig.wait_frames(3)
	await _rig.capture(_out.path_join("e_items.png"))
	screen.close()
	await _rig.wait_frames(8)


func _open(title: String, db: GDScript) -> TradeScreen:
	return TradeScreen.open(_rig.scene(), TradeScreen.Mode.PROGRESSION, title, db,
		&"smith", "Upgrades")
