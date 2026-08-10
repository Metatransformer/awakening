extends RefCounted
## The relic, end to end: off the floor, through the rope, over the counter, and
## into a lamp you can see from where you are standing.
##
## Point it at GARRISON. It never changes scene on purpose -- `Run.enter()`
## opens a run from wherever you are and the two things this card is about (the
## bag's refusal, and the courtyard) both need the garrison's twelve props alive
## in the same instance the camera is looking at. The gate's own hold is proven
## by `run_end.gd` and does not need proving twice.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/relic_donate.gd \
##     --out=/tmp/relic/x.png --warmup=60
##
## What it claims, in the order it proves them:
##
##   A  The table is twelve rows, twelve props, and a `Catalogue` whose verb is
##      RECORD and whose every line is a hold.
##   B  A relic leaves the floor into the BAG, and the extraction fee goes UP
##      because it is in there. The vendor will not touch it.
##   C  A full bag REFUSES it visibly -- the thing is still on the flagstones,
##      pulsing, and not in a toast.
##   D  Dying does not destroy it. The room can place it again.
##   E  Extraction is where it stops being losable.
##   F  The Lanternkeeper's counter offers it, on the SAME `TradeScreen`, and
##      says where the eleven you have not found are.
##   G  A donation is a HOLD. A tap records nothing.
##   H  The unlock BITES: the smith's ceiling moves a rung, and the fee moves
##      25% -> 20%.
##   I  The same corner of the yard, the same camera, dark and then lit.
##
## I is the one that matters, and it is the only claim here that a check cannot
## make for you. `docs/SCOPE.md` §4.1 asks "did the garrison changing register,
## or did you have to be told?" -- so the two frames are the answer, and if you
## have to flick between them to spot the difference the mechanic has failed
## whatever the count of green lines below says.

var out := ""
var _fails := 0
## The fixed eye for the before/after pair. Made once and re-used, because two
## frames from two cameras prove nothing at all.
var _cam: Camera3D = null
var _game_cam: Camera3D = null
## The two poses the before/after pairs are taken from. Stored rather than
## recomputed: the garrison is rebuilt twice on the way here and two frames from
## two slightly different eyes prove nothing.
var _hall := Transform3D.IDENTITY
var _mid := Transform3D.IDENTITY

## The corner the two frames are about: the Tally-Ledger's lamp, which is the
## prop nearest the gate and therefore the first one the player can possibly
## light (floor 1's deep chest, GDD §6.2 row 1).
const WATCH := &"lamp_weighhouse"
## The relic that lights it, and the second one, whose bite is the fee.
const FIRST := &"tally_ledger"
const SECOND := &"rope_drum"


func run(rig) -> void:
	out = rig.arg("out", "/tmp/relic/x.png").get_base_dir()
	Bus.screen_closed.connect(func(what: StringName) -> void:
		print("RELIC note: %s closed" % what))
	await rig.wait_frames(24)

	_table()
	await _pickup(rig)
	await _full_bag(rig)
	await _death(rig)
	await _extract(rig)
	await _dark(rig)
	await _counter(rig)
	await _record(rig)
	await _bite(rig)
	await _lit(rig)

	if _fails == 0:
		print("RELIC ok")
	else:
		print("RELIC FAIL -- %d check(s) failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_fails += 1
		print("RELIC FAIL %s" % label)


# --- A. The table -----------------------------------------------------------

func _table() -> void:
	_ck("A0 twelve relics, no thirteenth", RelicDb.RELICS.size() == 12)
	_ck("A1 twelve props to light", RelicDb.props().size() == 12)

	var seen_id := {}
	var seen_prop := {}
	for row in RelicDb.RELICS:
		_ck("A2 %s is a unique id" % row["id"], not seen_id.has(row["id"]))
		seen_id[row["id"]] = true
		# Two relics sharing a prop would mean eleven lamps for twelve donations,
		# and the twelfth would change nothing anybody could see.
		_ck("A3 %s lights its own prop (%s)" % [row["id"], row["prop"]],
			not seen_prop.has(row["prop"]))
		seen_prop[row["prop"]] = true
		# The bag has to be able to HOLD one, or the whole card is unreachable.
		_ck("A4 %s is a thing ItemDb knows" % row["id"],
			ItemDb.get_def(row["id"]) != null)

	_ck("A5 she RECORDS, in her own word (%s)" % RelicDb.craft_verb(),
		RelicDb.craft_verb() == "RECORD")
	var lines := RelicDb.lines()
	_ck("A6 the board is all twelve, found or not", lines.size() == 12)
	var priced := 0
	var with_parts := 0
	var tapped := 0
	for line in lines:
		if int(line["cost"]) != 0:
			priced += 1
		if not (line.get("parts", {}) as Dictionary).is_empty():
			with_parts += 1
		# Every row, not just the affordable ones: a tap-to-donate row would be
		# the one press in the game that cannot be given back.
		if not RelicDb.crafts(line):
			tapped += 1
	_ck("A7 every line is a hold (%d taps)" % tapped, tapped == 0)
	_ck("A8 no line costs gold", priced == 0)
	# The first cut priced a row at "1 of yourself" and the screen drew a RUST
	# "1 WEIGHTS" over a relic the player was holding. See `RelicDb.lines`.
	_ck("A9 no line prices a component", with_parts == 0)


# --- B. Off the floor and into the bag ---------------------------------------

func _pickup(rig) -> void:
	Game.gold = 60000
	Run.enter(31337)
	# Something worth carrying, so the fee is a real number rather than
	# `Run.EXTRACT_MIN`'s floor -- a fee that is already clamped cannot be seen
	# to rise.
	Run.collect(&"deep_amber", 6)
	await rig.wait_frames(6)
	var fee_before := Run.extract_cost()
	_ck("B0 the bag is worth enough to have a real fee (%d gold, fee %d)"
		% [Run.bag_value(), fee_before], Run.bag_value() > 200)
	_ck("B1 the Tally-Ledger is still down there", RelicDb.outstanding(FIRST))

	var mote := _place(rig, FIRST, 2.8)
	_ck("B2 the room placed it", mote != null)
	if mote == null:
		return
	# Read NOW, not after the capture: the mote frees itself the instant it is
	# taken, and every later line that wants "where it was" wants a Vector3 and
	# not a node that may have popped.
	var spot := mote.global_position
	_ck("B3 it is cold -- there is no such thing as a hot relic",
		is_equal_approx(mote.heat_mult, 1.0))
	await rig.wait_frames(14)
	await rig.capture(out.path_join("r_00_onfloor.png"))
	_ck("B3a it is still lying there, out of reach", is_instance_valid(mote))

	# Walked over, nothing pressed. Same contract as an ingredient, which is the
	# whole point of reusing LootMote.
	_stand_at(rig, spot)
	var got := await _wait_until(rig, func() -> bool: return Run.bag.has(FIRST), 90)
	_ck("B4 walking over it picked it up, nothing pressed", got)
	var fee_after := Run.extract_cost()
	print("RELIC bag=%s value=%d fee %d -> %d" % [
		Run.bag, Run.bag_value(), fee_before, fee_after])
	_ck("B5 it costs a slot", Run.bag.get(FIRST, 0) == 1)
	_ck("B6 the fee went UP because it is in the bag (%d -> %d)"
		% [fee_before, fee_after], fee_after > fee_before)

	# --- The vendor will not touch it ----------------------------------------
	_ck("B7 the vendor prices it at nothing", Run.line_value(FIRST) == 0)
	_ck("B8 he refuses to buy it", Run.sell(FIRST) == 0)
	var before_all: int = Run.bag.get(FIRST, 0)
	Run.sell_all()
	_ck("B9 SELL EVERYTHING leaves it in the bag",
		Run.bag.get(FIRST, 0) == before_all and before_all == 1)
	await rig.wait_frames(8)
	await rig.capture(out.path_join("r_01_inbag.png"))


# --- C. A full bag says no, out loud -----------------------------------------

func _full_bag(rig) -> void:
	# Stuffed with the commonest thing there is until `collect` stops taking it.
	# `Run.collect` fills slot by slot and breaks when there is no slot left, so
	# this is the bag being genuinely full and not a number being written.
	Run.collect(&"bone_shard", 9999)
	await rig.wait_frames(4)
	print("RELIC full slots=%d/%d" % [Run.slots_used(), Game.bag_slots])
	_ck("C0 the bag is full", Run.slots_used() >= Game.bag_slots)

	var mote := _place(rig, SECOND, 2.8)
	_ck("C1 the Rope-Drum is on the floor", mote != null)
	if mote == null:
		return
	# BESIDE it, not on top of it. Standing on the mote is enough to trigger the
	# refusal and is also enough to bury it under the hero -- and the refusal is a
	# thing you have to SEE on the floor, so the beat's own frame cannot be the one
	# frame where the floor is hidden. 0.65 m is inside LootMote's 0.75 m trigger,
	# so it still refuses; it is just refusing next to him instead of under him.
	_stand_at(rig, mote.global_position + Vector3(0.65, 0.0, 0.0))
	await rig.wait_frames(2)
	# Polled on the mote's OWN refusal timer rather than a frame count: `_refused`
	# decays, and a fixed wait photographs either a pulse or nothing depending on
	# how fast the machine is.
	var refused := await _wait_until(rig,
		func() -> bool: return is_instance_valid(mote) and mote._refused > 0.0, 120)
	_ck("C2 it refused", refused)
	_ck("C3 the relic did NOT vanish into a full bag", not Run.bag.has(SECOND))
	_ck("C4 it is still lying there", is_instance_valid(mote))
	# The frame is the claim. A check can see `_refused > 0`; only the eye can
	# see whether the thing on the flagstones reads as "still here, still yours".
	await rig.capture(out.path_join("r_02_refused.png"))


# --- D. Dying is a walk, not a loss ------------------------------------------

func _death(rig) -> void:
	_ck("D0 the relic is in the bag when he dies", Run.bag.has(FIRST))
	Run.die()
	await _dismiss_receipt(rig, "death")

	print("RELIC after death held=%s donated=%s outstanding=%s bag=%d" % [
		RelicDb.held(FIRST), RelicDb.donated(FIRST),
		RelicDb.outstanding(FIRST), Run.bag_count()])
	_ck("D1 death took the bag", Run.bag.is_empty())
	_ck("D2 the relic is NOT in hand", not RelicDb.held(FIRST))
	_ck("D3 and it was NOT recorded either", not RelicDb.donated(FIRST))
	# The whole rule, as one answer: nothing was written, so the floor puts it
	# back with no code (docs/GDD.md §3).
	_ck("D4 it is outstanding again -- still down there", RelicDb.outstanding(FIRST))
	var again := RelicPickup.place(rig.scene(), FIRST, Vector3(0.0, 0.0, 0.0))
	_ck("D5 the room can place it again -- recoverable, not gone", again != null)
	if again != null:
		again.queue_free()
	await rig.wait_frames(6)


# --- E. Extraction is where it stops being losable ---------------------------

func _extract(rig) -> void:
	Game.gold = 60000
	Run.enter(31338)
	await rig.wait_frames(6)
	for id in [FIRST, SECOND]:
		var mote := _place(rig, id, 2.8)
		if mote == null:
			_ck("E0 %s could be placed" % id, false)
			continue
		_stand_at(rig, mote.global_position)
		await rig.wait_frames(2)
		var got := await _wait_until(rig,
			func() -> bool: return Run.bag.has(id), 90)
		_ck("E0 %s is in the bag" % id, got)

	var toll := Run.relic_toll()
	_ck("E1 the rope weighs them (%d gold of toll)" % toll, toll > 0)
	_ck("E2 extraction succeeded", Run.extract())
	await _dismiss_receipt(rig, "extraction")

	print("RELIC banked held=%s/%s bag=%s" % [
		RelicDb.held(FIRST), RelicDb.held(SECOND), Run.bag])
	_ck("E3 the Tally-Ledger reached the garrison", RelicDb.held(FIRST))
	_ck("E4 so did the Rope-Drum", RelicDb.held(SECOND))
	_ck("E5 neither is still in the bag",
		not Run.bag.has(FIRST) and not Run.bag.has(SECOND))
	_ck("E6 holding is not recording", not RelicDb.donated(FIRST))


# --- I, first half. The dark yard --------------------------------------------

## The BEFORE frame, and the camera both frames are taken from.
##
## Placed on the customer's side of the Lanternkeeper's counter, looking the way
## she is looking -- which is to say, the exact view the player gets when they
## close her screen and turn round. Not aimed AT the lamp: "would you notice"
## is the question, and a camera pointed at the answer cannot ask it.
func _dark(rig) -> void:
	var garrison := rig.scene() as Garrison
	_ck("F0 the Lanternkeeper is in the garrison", garrison != null and garrison.keeper != null)
	_ck("F1 the courtyard has twelve dark props",
		garrison != null and garrison.lights.size() == 12)
	if garrison == null or garrison.keeper == null:
		return
	var watched := garrison.light_of(WATCH)
	_ck("F2 the Tally-Ledger's prop exists", watched != null)
	var dark := 0
	for l in garrison.lights:
		if not l.lit():
			dark += 1
	_ck("F3 all twelve start dark (%d)" % dark, dark == 12)

	_game_cam = rig.scene().get_node_or_null(^"GameCamera") as Camera3D
	_cam = Camera3D.new()
	_cam.fov = 55.0
	garrison.add_child(_cam)
	var front: Vector3 = garrison.keeper.global_transform.basis * Vector3(0.0, 0.0, 1.0)
	_cam.global_position = garrison.keeper.global_position + front * 2.2 \
		+ Vector3(0.0, 1.68, 0.0)
	_cam.look_at(_cam.global_position + front * 6.0 - Vector3(0.0, 0.4, 0.0), Vector3.UP)
	_hall = _cam.global_transform
	# And one from the middle of the yard, looking back down the ring. Two poses
	# because the first one answers "would you see it from her counter" and this
	# one answers "would you see it walking anywhere", and a mechanic that only
	# passes from one spot has not passed.
	_cam.global_position = Vector3(0.0, 1.75, 2.0)
	_cam.look_at(Vector3(-3.0, 1.2, -9.0), Vector3.UP)
	_mid = _cam.global_transform

	_cam.global_transform = _hall
	_cam.make_current()
	await rig.wait_frames(6)
	await rig.capture(out.path_join("r_10_hall_dark.png"))
	_cam.global_transform = _mid
	await rig.wait_frames(4)
	await rig.capture(out.path_join("r_15_mid_dark.png"))
	if _game_cam != null:
		_game_cam.make_current()
	await rig.wait_frames(4)


# --- F. The counter -----------------------------------------------------------

func _counter(rig) -> void:
	var garrison := rig.scene() as Garrison
	if garrison == null or garrison.keeper == null:
		return
	# Addressed the way a player addresses her. Calling `activate()` would prove
	# the screen opens and nothing about whether she can be reached.
	var front: Vector3 = garrison.keeper.global_transform.basis * Vector3(0.0, 0.0, 1.0)
	# 2.0 out, which is the far side of her counter (`ShopBooth.KEEPER_BACK` is
	# 0.95) and still inside the 2.3 m trigger. Standing at 1.7 puts the hero
	# inside the counter's own collider.
	_stand_at(rig, garrison.keeper.global_position + front * 2.0,
		garrison.keeper.global_position)
	var focused := await _wait_until(rig,
		func() -> bool: return Prompt.focus == garrison.keeper, 120)
	_ck("G0 she owns the interact button", focused)
	await rig.tap(["interact"])
	await rig.wait_frames(16)

	var screen := _screen(rig)
	if screen == null:
		_ck("G1 her counter opened", false)
		return
	_ck("G1 her counter opened", true)
	_ck("G2 it is the SAME TradeScreen the smith uses", screen is TradeScreen)
	_ck("G3 pointed at her catalogue", screen.catalogue == RelicDb)
	_ck("G4 the board is the whole list -- it IS the quest log (%d)"
		% screen._rows.size(), screen._rows.size() == 12)

	var have := _row(screen, FIRST)
	var havent := _row(screen, &"riven_chord")
	_ck("G5 the one in hand can be recorded",
		not have.is_empty() and RelicDb.can_buy(have["line"]))
	_ck("G6 one you have never seen cannot",
		not havent.is_empty() and not RelicDb.can_buy(havent["line"]))
	var why := RelicDb.refusal(havent["line"]) if not havent.is_empty() else ""
	_ck("G7 and the refusal says WHERE, not NOT ENOUGH GOLD (%s)" % why,
		why.begins_with("NOT RECOVERED") and why.contains("LONG DESCENT"))
	# Pressed, so the footer is in the frame. `_refuse` is set by the press.
	screen._cursor = screen._rows.find(havent)
	screen._commit()
	await rig.wait_frames(8)
	await rig.capture(out.path_join("r_20_counter.png"))


# --- G. A donation is a hold --------------------------------------------------

func _record(rig) -> void:
	var screen := _screen(rig)
	if screen == null:
		_ck("H0 her screen was still open", false)
		return
	screen._refresh()
	var line := _row(screen, FIRST)
	if line.is_empty():
		_ck("H0 the Tally-Ledger is on the board", false)
		return
	screen._cursor = screen._rows.find(line)
	_ck("H0 the footer says her word (%s)" % screen._verb(),
		str(screen._verb()) == "RECORD")

	await rig.tap(["ui_accept"])
	await rig.wait_frames(8)
	_ck("H1 a TAP records nothing", not RelicDb.donated(FIRST))

	# Sampled every frame and released on the first non-zero reading. Ten frames
	# is ten frames of unknown duration in this harness, and a fixed wait here
	# read 0.00 in alchemy_loop on a slow run because the whole hold had already
	# elapsed and the bar it was looking at had reset.
	Input.action_press(&"ui_accept")
	var peak := 0.0
	for _i in 30:
		await rig.wait_frames(1)
		peak = maxf(peak, screen._hold)
		if peak > 0.0:
			break
	Input.action_release(&"ui_accept")
	await rig.wait_frames(6)
	_ck("H2 the gauge fills while she writes (%.2f)" % peak, peak > 0.0)
	_ck("H3 letting go there recorded nothing", not RelicDb.donated(FIRST))

	# The shutter waits for the GAUGE, not for a frame count. One `wait_frames(1)`
	# here fired at `_hold` ~= 0.02 and produced a frame of an empty bar, i.e. a
	# picture that proves the opposite of the beat it belongs to. A quarter of the
	# hold is enough arc to read as a bar filling and still leaves most of the
	# hold un-elapsed, so the frame says "mid-press" rather than "nearly done".
	Input.action_press(&"ui_accept")
	var shot := await _wait_until(rig,
		func() -> bool: return screen._hold >= TradeScreen.CRAFT_HOLD * 0.25, 60)
	_ck("H3a the gauge is visibly part-filled for the frame (%.2f of %.2f)"
		% [screen._hold, TradeScreen.CRAFT_HOLD], shot)
	await rig.capture(out.path_join("r_21_hold.png"))
	await rig.hold_seconds(["ui_accept"], 0.9)
	await rig.wait_frames(10)
	print("RELIC recorded donated=%s count=%d" % [
		RelicDb.donated(FIRST), RelicDb.donated_count()])
	_ck("H4 held through, it is in the ledger", RelicDb.donated(FIRST))
	_ck("H5 it left her hand", not RelicDb.held(FIRST))
	screen._refresh()
	var again := _row(screen, FIRST)
	_ck("H6 the row now refuses -- there is one of these (%s)"
		% RelicDb.refusal(again["line"]),
		not again.is_empty() and RelicDb.refusal(again["line"]) == "ALREADY RECORDED")
	_ck("H7 nought left of it", RelicDb.remaining(FIRST) == 0)
	await rig.wait_frames(6)
	await rig.capture(out.path_join("r_22_recorded.png"))

	# Close it, and watch the lamp come on. The flare is deliberately deferred
	# to this moment -- see `GarrisonLight` -- because the counter draws a
	# curtain over the world and a lamp that lit underneath it would be a
	# garrison that was quietly already different.
	await rig.tap(["ui_cancel"])
	var gone := await _wait_until(rig, func() -> bool: return _screen(rig) == null, 90)
	_ck("H8 her screen closed", gone)
	# `_hall` explicitly, not "wherever the camera was left". The fixed camera is a
	# shared prop and the dark pair moved it to `_mid` on its way out, so this
	# capture had been quietly shooting the wrong pose -- a flare frame that cannot
	# be laid against `r_10_hall_dark.png` is not evidence of anything.
	if _cam != null:
		_cam.make_current()
		_cam.global_transform = _hall

	# Timed off the lamp's OWN clock, not off frames. The overshoot peaks halfway
	# through `FLARE_TIME` and four frames of a ~22 fps harness lands wherever it
	# lands -- which is the trap the brief names outright ("MEASURE state, do not
	# trust shutter timing"). Catching the peak is the point: the frame has to show
	# the lamp brighter than it will settle, because that overshoot IS the event.
	var lamp: GarrisonLight = (rig.scene() as Garrison).light_of(WATCH)
	# Two separate claims, because only one of them is about the game. That the
	# lamp is LIT and lit AFTER the curtain lifted is the mechanic; catching the
	# overshoot in the shutter is a photograph, and a slow machine missing the peak
	# must not be reported as the feature being broken.
	_ck("H9 the lamp came on when the counter closed, not behind it",
		await _wait_until(rig, func() -> bool: return lamp != null and lamp.lit(), 30))
	var peaked := await _wait_until(rig,
		func() -> bool: return lamp != null and lamp._flare >= GarrisonLight.FLARE_TIME * 0.5,
		45)
	if not peaked:
		print("RELIC note: shutter missed the flare's peak; r_23 is a settled lamp")
	await rig.capture(out.path_join("r_23_flare.png"))


# --- H. The bite ---------------------------------------------------------------

## The half of this card that a lamp cannot prove: the donation changed a NUMBER
## somewhere else in the game, through the accessor, with no `if` at the call
## site. One ladder and one fee, which are the two shapes every other relic is a
## copy of.
func _bite(rig) -> void:
	if _game_cam != null:
		_game_cam.make_current()
	# --- A ladder learned a rung ---------------------------------------------
	# Read off the SMITH, not off `RelicDb`: the claim is that his counter moved,
	# and `forge_rungs_known()` agreeing with itself would prove nothing.
	var cap := ShopDb.cap_of(&"edge")
	print("RELIC forge edge ceiling=%d rungs_known=%d" % [
		cap, RelicDb.forge_rungs_known()])
	_ck("I0 the smith's edge ladder reaches rung 2 now (%d)" % cap, cap == 2)
	_ck("I1 and not rung 3 -- that is the Anvil-Plate's line", cap < K.FORGE_MAX)

	# --- The rope got cheaper -------------------------------------------------
	Run.enter(31339)
	Run.collect(&"deep_amber", 6)
	await rig.wait_frames(4)
	var fee_before := Run.extract_cost()
	var rate_before := RelicDb.extract_rate(Run.EXTRACT_RATE)

	var line := {}
	for l in RelicDb.lines():
		if l["id"] == SECOND:
			line = l
	if line.is_empty():
		_ck("I2 the Rope-Drum is on her board", false)
		return
	_ck("I2 the Rope-Drum can be recorded", RelicDb.can_buy(line))
	# Straight through the catalogue this time, with no screen up: the hold is
	# proven above, and this is also the OTHER half of `GarrisonLight`'s wiring
	# -- a donation with nothing blocking input lights the lamp on the spot.
	print("RELIC recording the drum, blocked=%s" % Prompt.blocked)
	_ck("I3 recording it took", RelicDb.buy(line))
	var fee_after := Run.extract_cost()
	var rate_after := RelicDb.extract_rate(Run.EXTRACT_RATE)
	print("RELIC fee %d -> %d  rate %.2f -> %.2f (bag %d)" % [
		fee_before, fee_after, rate_before, rate_after, Run.bag_value()])
	_ck("I4 the rope charged the base rate before (%.2f)" % rate_before,
		is_equal_approx(rate_before, Run.EXTRACT_RATE))
	_ck("I5 it charges the drum's rate now (%.2f)" % rate_after,
		is_equal_approx(rate_after, RelicDb.RATE_WITH_DRUM))
	# The number the player actually pays, not just the constant behind it.
	_ck("I6 and leaving actually costs less (%d -> %d)" % [fee_before, fee_after],
		fee_after < fee_before)

	Run.bag.clear()
	Run.in_dungeon = false
	Bus.bag_changed.emit(Run.bag, 0)
	await rig.wait_frames(6)


# --- I, second half. The lit yard ---------------------------------------------

func _lit(rig) -> void:
	var garrison := rig.scene() as Garrison
	if garrison == null:
		return
	_ck("J0 two are recorded", RelicDb.donated_count() == 2)
	var watched := garrison.light_of(WATCH)
	_ck("J1 the Tally-Ledger's lamp is lit", watched != null and watched.lit())
	var winch := garrison.light_of(&"winch_lamp")
	_ck("J2 the Rope-Drum's lamp is lit", winch != null and winch.lit())
	var lit_count := 0
	for l in garrison.lights:
		if l.lit():
			lit_count += 1
	_ck("J3 two of twelve, and only two (%d)" % lit_count, lit_count == 2)

	# Wait the flare out, so the AFTER frame is the resting brightness rather
	# than the peak. If the difference only reads during the overshoot, the
	# garrison is not actually different -- it merely blinked at you once.
	await rig.wait_seconds(GarrisonLight.FLARE_TIME + 0.4)
	if _cam != null:
		_cam.make_current()
		_cam.global_transform = _hall
	await rig.wait_frames(6)
	await rig.capture(out.path_join("r_11_hall_lit.png"))
	if _cam != null:
		_cam.global_transform = _mid
	await rig.wait_frames(4)
	await rig.capture(out.path_join("r_16_mid_lit.png"))

	# And the wide, for a human comparing the whole courtyard.
	var wide := Camera3D.new()
	wide.fov = 62.0
	garrison.add_child(wide)
	wide.global_position = Vector3(0.0, 9.5, 15.0)
	wide.look_at(Vector3(0.0, 1.0, -3.0), Vector3.UP)
	wide.make_current()
	await rig.wait_frames(4)
	await rig.capture(out.path_join("r_12_wide_lit.png"))

	# All twelve, so somebody can see what the last frame of the game looks like
	# next to the first one. Forced with `sync()` rather than through the counter:
	# the counter is proven above, and this frame is about the CONTRAST.
	for row in RelicDb.RELICS:
		Game.set_flag(RelicDb.flag_donated(row["id"]))
	for l in garrison.lights:
		l.sync()
	await rig.wait_frames(6)
	await rig.capture(out.path_join("r_13_wide_all.png"))
	if _cam != null:
		_cam.make_current()
		_cam.global_transform = _hall
	await rig.wait_frames(4)
	await rig.capture(out.path_join("r_14_hall_all.png"))
	if _cam != null:
		_cam.global_transform = _mid
	await rig.wait_frames(4)
	await rig.capture(out.path_join("r_17_mid_all.png"))
	wide.queue_free()


# --- Helpers ------------------------------------------------------------------

## Drop the relic `ahead` metres NORTH of the hero and hand back the mote.
##
## North, because the chase camera sits south of him: a mote dropped on the
## camera's side of the hero is a mote in the player's lap, and the frame this
## beat exists to take is "there is a thing on the floor over there".
##
## `ahead` has to clear the mote's own 0.75 m trigger plus the hero's body or the
## pickup fires before the shutter does -- which is exactly what happened, and
## the failure was a freed instance in the NEXT line rather than a missing frame.
##
## And it goes off to one side as well, because straight-ahead-of-the-hero is
## straight BEHIND the hero from a camera that sits directly behind him: the
## first cut of `r_00_onfloor.png` was a frame of the hero's back with the thing
## it was taken to photograph hidden inside his silhouette. The check passed and
## the picture proved nothing, which is CLAUDE.md §2's whole warning.
const ASIDE := 1.6


func _place(rig, id: StringName, ahead: float) -> LootMote:
	var players: Array = rig.get_nodes_in_group(&"player")
	if players.is_empty():
		return null
	var hero: Node3D = players[0]
	return RelicPickup.place(rig.scene(), id,
		hero.global_position + Vector3(ASIDE, 0.0, -ahead))


## Poll a condition rather than waiting a fixed number of frames. The harness
## runs at whatever speed the machine allows (~22 fps), so every fixed wait in a
## director is a wait of unknown duration -- and the failures that produces read
## as game bugs.
func _wait_until(rig, cond: Callable, frames: int) -> bool:
	for _i in frames:
		if cond.call():
			return true
		await rig.wait_frames(1)
	return cond.call()


## Both ends of a run raise `RunEndScreen` and pause the tree. Press its one
## button, then wait out the whole ride home -- `game_flow._go` autosaves at the
## very END of a transition, and returning early lets that write land inside a
## later beat.
func _dismiss_receipt(rig, tag: String) -> void:
	var raised := await _wait_until(rig,
		func() -> bool: return _end_screen(rig) != null, 240)
	_ck("%s raised the receipt" % tag, raised)
	await rig.wait_seconds(RunEndScreen.SETTLE + 0.2)
	await rig.hold_seconds([&"ui_accept"], 0.2)
	for _i in 300:
		await rig.wait_seconds(0.05)
		if not Flow.busy and not Flow.ending and _end_screen(rig) == null:
			break
	await rig.wait_seconds(0.3)
	print("RELIC %s -> scene=%s paused=%s busy=%s" % [
		tag, rig.scene().name, rig.paused, Flow.busy])


func _end_screen(rig) -> RunEndScreen:
	for n in _all(rig.scene()):
		if n is RunEndScreen:
			return n
	return null


func _screen(rig) -> TradeScreen:
	var found: Array[TradeScreen] = []
	for n in _all(rig.scene()):
		if n is TradeScreen:
			found.append(n)
	if found.size() > 1:
		_fails += 1
		print("RELIC FAIL %d trade screens are open at once" % found.size())
	return found[0] if not found.is_empty() else null


func _row(screen, id: StringName) -> Dictionary:
	for r in screen._rows:
		if r.get("kind") == &"buy" and r["line"]["id"] == id:
			return r
	return {}


func _all(root: Node) -> Array:
	var found := [root]
	for c in root.get_children():
		found.append_array(_all(c))
	return found


## Teleport. Pathing a hero across garrison with synthetic input is its own
## project and the thing under test is the counter and the bag.
func _stand_at(rig, where: Vector3, look_at: Variant = null) -> void:
	var players: Array = rig.get_nodes_in_group(&"player")
	if players.is_empty():
		return
	var hero: Node3D = players[0]
	hero.global_position = where
	if look_at != null:
		var to: Vector3 = K.flat((look_at as Vector3) - where)
		if to != Vector3.ZERO:
			hero.facing_yaw = atan2(to.x, to.z)
			hero.rotation.y = hero.facing_yaw + PI
