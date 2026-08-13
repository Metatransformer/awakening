extends RefCounted
## A bulk sale is ONE sale, and the keeper says so once. Card #125.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/vendor_voice.gd \
##     --out=/tmp/vendor/x.png --warmup=60 --sound
##
## `--sound` is not required -- every assertion here is a count, and `AudioServer`
## behaves under the Dummy driver -- but this is the one director meant to be
## LISTENED to, which is what the card asks for. Without it the run is silent and
## still correct.
##
## ## What is measured, and why it is a count and not a frame
##
## From the owner's playtest: *"when you sell multiple things it should not spam
## the voice."* Selling eight stacks is eight taps, eight landed commits and eight
## `Voice.say(speaker, &"deal")` calls -- and `Voice`'s one-mouth rule says
## starting a line STOPS whatever was mid-sentence, so the quartermaster said
## "good pri-good pri-good pri-good price", one syllable per press.
##
## **No screenshot can see that, and neither can `Voice.speaking()`** -- it is
## true throughout either version -- and neither can `Voice.line()`, which names
## the same file both times. What differs is how many takes STARTED. That is why
## `Voice.takes_started` exists and it is what every check below reads.
##
## ## Calibration, both directions (CLAUDE.md §2)
##
## A counter stuck at its initial value would pass "the keeper spoke once" for
## entirely the wrong reason, and so would a build with the voice switched off.
## So the first beat pins the instrument to a known answer at both ends:
##
##   N0  one sale raises the counter by exactly 1, and `Voice.line()` is the
##       quartermaster's own take -- the instrument can SEE a line.
##   N1  a second sale, AFTER the first line has finished, raises it again. This
##       is the half that cannot be faked by a mute build: it is what proves the
##       burst in B would have counted 6 if 6 had been said. The fix is "do not
##       interrupt yourself", not "stop talking".
##
## The `pickup` beat at the end is the same shape on the SFX side and carries the
## same pair: five motes on one frame must start ONE pickup, and five hits on one
## frame must start MORE than one, because that sound is deliberately not in
## `Sfx.MIN_GAP`.

var _rig
var _out := ""
## `Bus.items_sold` emissions, which is the number of transactions that actually
## landed. Without it, "the keeper spoke once" is also what a screen that sold
## NOTHING would report -- and that is the failure mode a self-satisfied fix for
## this card has.
var _sales := 0


func run(rig) -> void:
	_rig = rig
	_out = rig.arg("out", "/tmp/vendor/x.png").get_base_dir()
	# This director measures transaction voice cadence, not wishlist policy. Own a
	# deterministic bag whose individual rows remain immediate sales.
	Game.restore_wishlist_lines([])
	Settings.set_auto_wishlist(false)
	Bus.items_sold.connect(func(_sold: Dictionary, _paid: int) -> void:
		_sales += 1)
	await rig.wait_frames(20)

	await _one_at_a_time()
	await _the_burst()
	await _the_bulk_row()
	await _the_chimes()
	print("VENDOR done")


func _ck(ok: bool, what: String) -> bool:
	if ok:
		print("  ok   %s" % what)
	else:
		_rig.fail(what)
	return ok


# --- calibration -------------------------------------------------------------

## N0 and N1. See the header: these are what the burst beat's number MEANS.
func _one_at_a_time() -> void:
	var screen = await _counter()
	if screen == null:
		return

	var before: int = Voice.takes_started
	if not await _sell_one(screen):
		_rig.fail("N0 could not sell a stack at all")
		screen.close()
		return
	_ck(Voice.takes_started == before + 1,
		"N0 one sale starts exactly one take (%d -> %d), and it is '%s'"
			% [before, Voice.takes_started, Voice.line()])

	# Let him finish, then sell again. A rule that said "one line per screen"
	# would pass every check in `_the_burst` and be a different bug.
	var ended: bool = await _rig.until(func() -> bool: return not Voice.speaking(), 8.0)
	before = Voice.takes_started
	var sold: bool = await _sell_one(screen)
	_ck(ended and sold and Voice.takes_started == before + 1,
		"N1 a sale AFTER the line ends starts another (%d -> %d) -- the counter can go up twice"
			% [before, Voice.takes_started])
	await _rig.capture(_out.path_join("a_counter.png"))
	screen.close()
	await _rig.wait_frames(8)


# --- the card ----------------------------------------------------------------

## Stack after stack, as fast as a hand can tap, inside one line's length.
func _the_burst() -> void:
	var screen = await _counter()
	if screen == null:
		return
	var take := _take_length()
	var before: int = Voice.takes_started
	var sold_before := _sales
	var t0 := Time.get_ticks_msec()
	for _n in 6:
		if not await _sell_one(screen):
			break
	var elapsed := float(Time.get_ticks_msec() - t0) / 1000.0
	var sold := _sales - sold_before

	if not _ck(sold >= 4, "B0 the burst really sold %d stacks" % sold):
		screen.close()
		return
	# The claim below only means anything if the whole burst fitted inside one
	# take -- two lines a full take apart is a conversation, not spam. Checked
	# rather than assumed, because it is the premise of the check under it.
	if not _ck(elapsed < take,
			"B1 the burst fitted inside one take (%.2f s of %.2f s)" % [elapsed, take]):
		screen.close()
		return
	_ck(Voice.takes_started == before + 1,
		"B2 %d sales in %.2f s, and the keeper started %d line(s)"
			% [sold, elapsed, Voice.takes_started - before])
	await _rig.capture(_out.path_join("b_burst.png"))
	screen.close()
	await _rig.wait_frames(8)


## The other way to empty a bag: SELL UNMARKED, one held press, many stacks.
##
## This half already behaved -- `Run.sell_ids` is atomic and emits `items_sold`
## once for the lot -- and it is checked anyway, because the card describes the
## signal as firing per ITEM, and a claim about the code that is not true today is
## exactly the kind that quietly becomes true again.
func _the_bulk_row() -> void:
	var screen = await _counter()
	if screen == null:
		return
	if not await _aim_at(screen, &"all"):
		_rig.fail("C0 there is no SELL UNMARKED row on a full bag")
		screen.close()
		return
	var before: int = Voice.takes_started
	var sold_before := _sales
	var stacks: int = Run.bag.size()
	await _rig.hold_seconds(["ui_accept"], TradeScreen.CRAFT_HOLD + 0.35)
	await _rig.wait_frames(8)
	_ck(_sales - sold_before == 1,
		"C1 a bag of %d stacks left as ONE transaction (%d emission(s))"
			% [stacks, _sales - sold_before])
	_ck(Voice.takes_started == before + 1,
		"C2 and the keeper said one line (%d -> %d)" % [before, Voice.takes_started])
	await _rig.capture(_out.path_join("c_bulk.png"))
	screen.close()
	await _rig.wait_frames(8)


## The same shape on the SFX side, with its control.
##
## A chime is not a person: `Sfx.MIN_GAP` collapses a same-frame burst of ONE
## file and caps nothing else. So five motes swept up in a stride -- five real
## `Run.collect` calls, five `loot_gained`s on one frame -- must come out as one
## `pickup`; and five hits, whose sound is deliberately not in the table, must
## come out as more than one. **The second half is the control**: without it this
## beat passes on a build where nothing plays at all.
func _the_chimes() -> void:
	_ck(not Sfx.MIN_GAP.has(&"coin_trade"),
		"D0 the coins are still allowed to stack -- the chime is texture, not a sentence")

	_hush()
	Run.bag.clear()
	await _rig.wait_frames(2)
	if not _ck(_playing(&"pickup") == 0, "D1 the pool starts quiet"):
		return
	for _n in 5:
		Run.collect(&"iron_scrap", 1)
	await _rig.wait_frames(2)
	var pickups := _playing(&"pickup")
	_ck(pickups == 1, "D2 five motes on one frame started %d pickup(s)" % pickups)

	_hush()
	await _rig.wait_frames(2)
	for _n in 5:
		Bus.hit_landed.emit(null, 1, Vector3.ZERO)
	await _rig.wait_frames(2)
	var hits := _playing(&"hit_flesh")
	_ck(hits > 1,
		"D3 control: five hits on one frame started %d hit_flesh -- the count CAN see a burst"
			% hits)


## Stop every pooled voice and forget when each sound last played.
##
## The second half matters: `MIN_GAP` is measured against a WALL clock, so a
## `pickup` rung by the beats above would still be inside its gap here and the
## burst would be collapsed for the wrong reason. Clearing the ledger does not
## disable the rule -- it only says "nothing has played recently", which is the
## precondition the beat is entitled to.
func _hush() -> void:
	for v: AudioStreamPlayer3D in Sfx._pool:
		v.stop()
	Sfx._last_played.clear()


## How many of `Sfx`'s pooled voices are playing `id` this instant.
##
## Compared against the CACHED stream rather than a path: `Sfx._load` hands the
## same resource to every voice, so identity is what makes "a voice started" into
## "the RIGHT sound started". The pool is twelve and round-robin, so five
## simultaneous shots never steal each other.
func _playing(id: StringName) -> int:
	var want: AudioStream = Sfx._load(id)
	if want == null:
		return 0
	var n := 0
	for v: AudioStreamPlayer3D in Sfx._pool:
		if v.playing and v.stream == want:
			n += 1
	return n


# --- plumbing ----------------------------------------------------------------

## The quartermaster's counter, opened directly and stocked. `mvp_loop` owns
## whether she can be WALKED to; this is a question about one line of audio.
func _counter():
	Run.bag.clear()
	for id: StringName in [&"iron_scrap", &"bone_shard", &"deep_amber",
			&"cracked_flint", &"ash_resin", &"fired_cullet", &"cut_gemstone"]:
		Run.collect(id, 2)
	Game.add_gold(200)
	var screen := TradeScreen.open(_rig.scene(), TradeScreen.Mode.TRADE,
		"THE QUARTERMASTER", SupplyDb, &"quartermaster", "Trade")
	await _rig.wait_frames(16)
	if screen.line_count() <= 0:
		_rig.fail("the counter opened with an empty board")
		return null
	return screen


## How long the keeper's `deal` take runs, so `B1` can state its own premise.
##
## Read off the file rather than by saying it: a measurement that made a sound
## would put a take on the counter that the player never heard, and every delta
## below would be one too many.
func _take_length() -> float:
	var s: AudioStream = Voice._load(&"quartermaster", "good_price")
	return s.get_length() if s != null else 0.0


## Put the cursor on the first row of `kind`, by pressing RIGHT like a player.
##
## Never `screen._cursor = i` (CLAUDE.md §3): the assignment is half a move, and
## `_point_at` -- the half that calls the DEFERRED `grab_focus` -- puts it back on
## whatever row the last `_refresh` left the focus on, a frame later.
func _aim_at(screen, kind: StringName) -> bool:
	for _i in screen.line_count() + 1:
		var at: int = screen._cursor
		if at >= 0 and at < screen._rows.size():
			var row: Dictionary = screen._rows[at]
			if row.get("kind") == kind:
				return true
		await _key(KEY_RIGHT)
	return false


## Aim at a sellable stack and tap. True when a sale actually landed.
func _sell_one(screen) -> bool:
	if not await _aim_at(screen, &"item"):
		return false
	var before := _sales
	await _rig.tap(["ui_accept"])
	await _rig.wait_frames(3)
	return _sales > before


## A real key, both keycodes set so the keycode-bound `ui_*` actions and the
## physical-bound game actions each see it. `Input.action_press` dispatches no
## `InputEvent` at all (CLAUDE.md §3), and `TradeScreen._input` takes the four
## arrows off the EVENT to stop the board stepping twice (#74).
func _key(code: int) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await _rig.wait_frames(2)
