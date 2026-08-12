extends RefCounted
## Every blurb a counter can print, printed — and measured for clipping.
##
## **Card #31 said the relic lore was cut off mid-word because `wrap()` defaults
## to two lines.** That mechanism no longer exists: `CanvasText.wrap` was deleted
## when the trade screen was rebuilt out of `Control` nodes, and the blurb is now
## a `Label` with `AUTOWRAP_WORD_SMART` and `SIZE_EXPAND_FILL`. So the card cannot
## be implemented as written, and the only honest way to answer it is to draw all
## twelve lore lines and look at them. This is the instrument that does that.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/lore_panes.gd \
##     --out=/tmp/lore/x.png --size=1280x720 --warmup=60
##
## Three counters, because the detail pane is ONE widget shared by all of them and
## the relics are only the longest tenant: the Lanternkeeper's twelve, the smith's
## board, and the alchemist's. The relic pane is walked TWICE — once with nothing
## recovered, which is the state a new player reads it in and which prints
## `_unwritten` rather than lore, and once with all twelve in hand, which is the
## only state the lore is reachable at all.
##
## **The measurement is the Label's own two counters**, not a pixel diff:
## `get_line_count()` is how many lines the wrap produced and
## `get_visible_line_count()` is how many of them fit in the rect it was given.
## Clipping is exactly `visible < total`, and a `Label` that overflows drops whole
## lines off the bottom silently — no ellipsis, no warning. That is the failure
## the card describes, phrased in the units the widget actually has.
##
## Its own director rather than a beat inside `relic_donate.gd`, which owns the
## Lanternkeeper otherwise: that one walks to her, donates, and checks the ledger,
## and forty cursor moves with a capture on each would be most of its runtime
## spent on a question that is not about donating. This is about ONE `Label` in a
## screen four counters share, so it opens the counters directly and does nothing
## else.
##
## CLAUDE.md §2 wants an instrument pointed at a known answer in BOTH directions,
## and a clipping check is the kind that rots into a no-op the day the property is
## renamed. So `_calibrate` forces a paragraph far too long for the pane and
## demands the check REPORT clipping; the twelve real lines then have to report
## none. A run where both halves agree is worth reading. A run where only the
## second half passes proves nothing.


var _fails := 0
## The most lines any real blurb needed, and the fewest the pane ever had room
## for. Reported together at the end, because "it fits" is only interesting next
## to how close it came.
var _worst_lines := 0
var _worst_who := ""
var _least_room := 9999


func _keeper_ids() -> Array:
	var out: Array = []
	for row in RelicDb.RELICS:
		out.append(row["id"])
	return out


## Does the blurb the pane is currently showing fit in the pane?
##
## Read AFTER a capture, for the same reason `hud_pole.gd` reads `layout_rects()`
## after one: the frame the checker judges has to be the frame that was
## photographed, or the two halves of the proof are about different states.
## **Two ways to lose a line, and the check has to see both.** The first pass at
## this asked only `visible < total` and was proved a no-op by its own calibration
## beat: an eighteen-line paragraph reported eighteen of eighteen drawn. That was
## not the property being wrong — the pane really does hold eighteen lines at 720p
## — but it showed what the other half of the answer had to be, because a `Label`
## with `SIZE_EXPAND_FILL` and autowrap does not *only* clip. Its minimum size
## grows with the wrap, so a paragraph past the pane's capacity pushes the card
## taller instead, and the overflow leaves by the bottom of the SCREEN with every
## line still counted as drawn. Legible means all the lines exist AND the rect
## they are in is on screen.
func _fits(screen, who: String, expect_clip: bool = false) -> bool:
	var lb: Label = screen._tip.blurb
	var total: int = lb.get_line_count()
	var shown: int = lb.get_visible_line_count()
	var rect := lb.get_global_rect()
	var view := Rect2(Vector2.ZERO, Vector2(lb.get_viewport_rect().size))
	var spills: float = rect.end.y - view.end.y
	# The pane's own capacity, in lines, so "it fits" is reported next to how much
	# room was left rather than on its own.
	var line_h: float = maxf(float(lb.get_line_height()), 1.0)
	var room := int(floor(rect.size.y / line_h))
	var bad := shown < total or spills > 0.5
	if not expect_clip:
		if total > _worst_lines:
			_worst_lines = total
			_worst_who = who
		_least_room = mini(_least_room, room - total)
	if bad == expect_clip:
		if expect_clip:
			print(("  ok   LORE calibration: an over-long blurb reported %d of %d "
				+ "lines drawn and %.0f px past the bottom of the screen — the "
				+ "check can see a blurb it cannot hold")
				% [shown, total, maxf(spills, 0.0)])
		return true
	if expect_clip:
		print(("LORE FAIL calibration: the over-long blurb reported %d of %d lines "
			+ "inside the frame and the check saw nothing wrong. It is a no-op; "
			+ "every pass below is worthless.") % [shown, total])
	else:
		print(("LORE FAIL %s: %d of %d lines drawn, %.0f px past the bottom of the "
			+ "screen") % [who, shown, total, spills])
		print("         text: %s" % lb.text)
	_fails += 1
	return false


## Walk the cursor over EVERY row of a board, photograph each, and measure each.
##
## Not one representative screenshot: the pane is re-filled per row and the
## longest string is the only one that can overflow, so a board checked at row 0
## is a board that has not been checked.
func _walk(rig, screen, out: String, prefix: String) -> void:
	var n: int = screen._rows.size()
	if n == 0:
		print("LORE FAIL %s: the board has no rows to read" % prefix)
		_fails += 1
		return
	for i in n:
		screen._point_at(i)
		# Two frames: `_point_at` defers the scroll and the containers have not
		# re-laid-out on the frame the text was set, so `get_visible_line_count()`
		# on frame 0 answers for the PREVIOUS row's rect.
		await rig.wait_frames(3)
		await rig.capture(out.path_join("%s_%02d.png" % [prefix, i]))
		_fits(screen, "%s row %d (%s)" % [prefix, i, screen._rows[i]["label"]])


## The other direction. Force a paragraph no pane of this size could hold and
## require the check to say so — see the header.
func _calibrate(rig, screen, out: String) -> void:
	var keep: String = screen._tip.blurb.text
	# Forty repeats, not eight. Eight was the first attempt and it FIT — the pane
	# swallowed all eighteen lines of it — which is a fact worth keeping in the
	# file: the card this director answers claims a two-line cap, and the widget
	# holds eighteen lines of nonsense without complaint. The known-bad case has to
	# be far past that to be known-bad at all.
	screen._tip.blurb.text = ("The Society does not write up an object it has not "
		+ "seen, and this sentence exists only to be too long for the card it is "
		+ "in. ").repeat(40)
	await rig.wait_frames(3)
	await rig.capture(out.path_join("z_00_calibration.png"))
	_fits(screen, "calibration", true)
	screen._tip.blurb.text = keep
	await rig.wait_frames(2)


## Opened directly rather than walked to. `relic_donate.gd` and `forge_loop.gd`
## own whether these counters can be REACHED; this is a question about one Label,
## and each is given its own `voice` so the refusal footer is the one that counter
## would really print rather than the Lanternkeeper's borrowed for all three.
func _counter(rig, mode: int, title: String, db: GDScript,
		voice: StringName, service: String) -> TradeScreen:
	var screen := TradeScreen.open(rig.scene(), mode, title, db, voice, service)
	await rig.wait_frames(12)
	return screen


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/lore/x.png").get_base_dir()
	await rig.wait_frames(30)

	# 1. Her board cold: nothing recovered, so every row prints `_unwritten`
	#    rather than lore. It is the state the counter spends most of a first run
	#    in and it goes through the same Label, so it is checked the same way.
	var keeper: TradeScreen = await _counter(rig, TradeScreen.Mode.PROGRESSION,
		"THE FAR LANTERN", RelicDb, &"keeper", "Artifacts")
	await _walk(rig, keeper, out, "a_cold")
	await _calibrate(rig, keeper, out)
	keeper.close()
	await rig.wait_frames(6)

	# 2. Her board with all twelve in hand — HELD and not donated, which is the
	#    one state where the lore is written AND the repair price is still on the
	#    row, so the pane is as full as it ever gets: kicker, name, price, and the
	#    longest paragraph in the game underneath them.
	for id in _keeper_ids():
		Game.set_flag(RelicDb.flag_held(id))
	keeper = await _counter(rig, TradeScreen.Mode.PROGRESSION, "THE FAR LANTERN",
		RelicDb, &"keeper", "Artifacts")
	await _walk(rig, keeper, out, "b_lore")
	keeper.close()
	await rig.wait_frames(6)

	# 3. The smith. His blurbs are `blurb + "   " + detail` (`_build_buy_rows`),
	#    so they are the same shape as hers and the pane cannot tell them apart.
	var smith: TradeScreen = await _counter(rig, TradeScreen.Mode.PROGRESSION,
		"THE FORGE", ShopDb, &"smith", "Smithing")
	await _walk(rig, smith, out, "c_forge")
	smith.close()
	await rig.wait_frames(6)

	# 4. The alchemist. Her board is GATED on donated relics (`knows_draught`), so
	#    a cold run shows two rows and says nothing about the other six. Donate all
	#    twelve first and the board opens to its full width — which is also the
	#    only way to photograph the recipes, and a recipe pushes the blurb DOWN the
	#    card, taking room off exactly the widget this card is about.
	for id in _keeper_ids():
		Game.set_flag(RelicDb.flag_donated(id))
	var alch: TradeScreen = await _counter(rig, TradeScreen.Mode.PROGRESSION,
		"THE ALCHEMIST", AlchemyDb, &"alchemist", "Alchemy")
	await _walk(rig, alch, out, "d_alchemist")
	alch.close()
	await rig.wait_frames(4)

	print("LORECHECK worst=%d lines (%s) tightest_margin=%d spare lines fails=%d" % [
		_worst_lines, _worst_who, _least_room, _fails])
	if _fails > 0:
		print("LORE FAIL %d pane(s) clipped — see the LORE lines above" % _fails)
