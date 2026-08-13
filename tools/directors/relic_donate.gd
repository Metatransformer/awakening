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
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
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
##      **Every one of the twelve is reachable with the D-pad** -- one press of
##      RIGHT is one line. G8 counts them, and it is the check that found the
##      board stepping two at a time (see `TradeScreen._input`).
##   G  A donation is a HOLD, driven by a thumb: the cursor is WALKED onto the
##      row and the button held until the ledger says so. A tap records nothing,
##      and holding a relic she already has is refused on the footer where the
##      player can read it.
##   H  The unlock BITES: the smith's ceiling moves a rung, and the fee moves
##      25% -> 20%.
##   I  The same corner of the yard, the same camera, dark and then lit.
##   K  **The two Verses pay out something playable** (`docs/ITEMS.md` §8, D5).
##      Before the donation the ring will not step onto either one; after it,
##      both are stops the D-pad reaches, and each does what GDD §6.2 says --
##      Sustain holds the chain through a break, Ballast burns the cheapest
##      stack for a soak window. Both halves are photographed, because a ring
##      that showed everything always would pass a positive-only check.
##
## I is the one that matters, and it is the only claim here that a check cannot
## make for you. `docs/SCOPE.md` §4.1 asks "did the garrison changing register,
## or did you have to be told?" -- so the two frames are the answer, and if you
## have to flick between them to spot the difference the mechanic has failed
## whatever the count of green lines below says.
##
## The pair for ONE donation is `r_18_watch_dark.png` -> `r_23_flare.png`, and
## the pose they share is the only one here aimed at the lamp under test. `_hall`
## and `_mid` are the yard-scale pair and neither contains it; H9 was shot from
## `_hall` and was therefore a photograph of two OTHER props, both dark, under a
## green line. `F4` and `H9a` now assert the lamp is inside the frustum, so the
## frame cannot drift off its subject again. See `_watch_pose`.
##
## `--wrong-row` is the null case. It skips the walk in G and reproduces card
## #74 exactly -- eleven red checks, headed by `H0a ... (THE RIVEN CHORD)` --
## which is what makes the green run above mean anything.

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
## And the pose that is actually ON `WATCH`.
##
## `_hall` and `_mid` are the two the yard-scale claim (I) is made from -- "would
## you see it from her counter", "would you see it walking anywhere" -- and
## neither of them contains the Tally-Ledger's lamp. That is fine for I and it
## was quietly fatal for H9: the flare frame was shot from `_hall`, which holds
## the two lamps at the FAR side of the ring, so `r_23_flare.png` was a picture
## of two props that had not lit and could not, laid under a green line saying a
## third one had. Measured -- the lit lamp sits at (1.44, 0, -8.92) and
## `is_position_in_frustum` says false for `_hall` and true for the two in shot.
## Card #52 is the same shape: a beat failing on an arrow counter in a frame that
## turned out to be of a shield.
var _watch_pose := Transform3D.IDENTITY

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
	await _verse_dark(rig)
	await _pickup(rig)
	await _full_bag(rig)
	await _death(rig)
	await _extract(rig)
	await _dark(rig)
	await _counter(rig)
	await _record(rig)
	await _bite(rig)
	await _verse_lit(rig)
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

	# The unique ids, the unique props, the bag's def for each one AND -- the part
	# no director had -- the two tables that PLACE these rows. `RelicDb.validate()`
	# owns all of it now; this beat used to hand-roll the first three and had
	# nothing at all to say about `FloorDb` or `BossDb`, which is how boss 4 spent
	# three milestones dropping a relic that had been deleted from the manifest
	# (`docs/ITEMS.md` §8, D1 and D2). Printed line by line rather than as a count,
	# because "3 problems" sends the reader to the wrong file.
	var problems := RelicDb.validate()
	for p in problems:
		print("RELIC FAIL A2 %s" % p)
	_fails += problems.size()
	_ck("A2 the manifest and the tables that place it agree (%d problems)"
		% problems.size(), problems.is_empty())
	# The two Verses exist and are two of the twelve (GDD §6.2 rows 6 and 7).
	# Named outright rather than left to the count above: the count was twelve on
	# the day the jig and the gear were still in it.
	for id: StringName in [&"sustain_verse", &"ballast_verse"]:
		_ck("A3 %s is one of the twelve" % id, RelicDb.is_relic(id))
	_ck("A4 and the two rows they were paid for are gone",
		not RelicDb.is_relic(&"fletchers_jig")
			and not RelicDb.is_relic(&"waterwheel_gear"))

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
	# GDD §6.4: a relic arrives broken and gold is what fixes it. Eleven priced
	# and the first one free -- a tutorial you cannot afford is not a tutorial.
	# This beat used to assert `priced == 0` and it was right to, until §6.4 was
	# built; it is written the other way round now so the next person to zero the
	# column has to argue with the doc rather than with a passing run.
	_ck("A8 eleven lines carry a repair price (%d priced)" % priced, priced == 11)
	_ck("A9 and the first repair is free",
		RelicDb.repair_cost(FIRST) == 0 and RelicDb.repair_cost(&"riven_chord") > 0)
	# The price BITES: a relic in your hand you cannot pay for is refused, and the
	# footer says so in the counter's words rather than the bank's.
	var purse := Game.gold
	var plate: Dictionary = {}
	for line in lines:
		if line["id"] == &"anvil_plate":
			plate = line
	Game.gold = 0
	Game.set_flag(RelicDb.flag_held(&"anvil_plate"))
	_ck("A10 a repair you cannot afford is refused (%s)" % RelicDb.refusal(plate),
		not RelicDb.can_buy(plate) and RelicDb.refusal(plate).contains("REPAIR"))
	Game.gold = RelicDb.repair_cost(&"anvil_plate")
	_ck("A11 and allowed the moment the purse covers it", RelicDb.can_buy(plate))
	# Put the world back: the beats below are about the Tally-Ledger and a stray
	# held flag would have the board writing up a relic nobody carried in.
	Game.flags.erase(RelicDb.flag_held(&"anvil_plate"))
	Game.gold = purse
	# A Verse is READ, not repaired, and the bag says so before either happens.
	_ck("A12 a Verse is unread, not broken (%s / %s)"
		% [RelicDb.arrival_name(&"sustain_verse"), RelicDb.arrival_name(FIRST)],
		RelicDb.arrival_name(&"sustain_verse") == "The Unread Sustain-Verse"
			and RelicDb.arrival_name(FIRST) == "Broken Tally-Ledger of Fair Weights")
	_ck("A13 and the bag points at the home counter (%s)"
		% ItemDb.get_def(FIRST).blurb,
		ItemDb.get_def(FIRST).blurb.begins_with("Take it to the smith."))
	# The first cut priced a row at "1 of yourself" and the screen drew a RUST
	# "1 WEIGHTS" over a relic the player was holding. See `RelicDb.lines`.
	_ck("A14 no line prices a component", with_parts == 0)


# --- K, first half. The ring without the Verses -------------------------------

## The NEGATIVE case, and it is the half of this card that is easy to skip.
##
## `docs/ITEMS.md` §8 D5 was two rows and two ring stops that did not exist, and
## the obvious way to close it is to add them and photograph them working. That
## proves nothing on its own: a ring that carried every stop unconditionally
## would take exactly the same picture. So this runs FIRST, before anything has
## been recorded, and presses the D-pad the way a player does — `rig.draw_weapon`
## walks the ring and comes back false when the ring never lands on the id.
##
## The other four stops are granted here because the ring has to have somewhere
## to go. With only the sword owned the walk is one entry long and
## `cycle_armament` early-returns, so a refusal would prove the early return
## rather than the ownership gate -- and the six-stop walk after the donation
## would be a four-stop walk for a reason that has nothing to do with the Verses.
func _verse_dark(rig) -> void:
	for id: StringName in [&"bow", &"hookshot", &"burst"]:
		Game.grant(id)
	Game.add_arrows(12)
	Game.add_charges(6)
	await rig.wait_frames(4)

	_ck("K0 neither Verse has been read", not RelicDb.donated(&"sustain_verse")
		and not RelicDb.donated(&"ballast_verse"))
	_ck("K1 so the game says you do not own the workings",
		not Game.armament_owned(&"sustain") and not Game.armament_owned(&"ballast"))
	# Both stops are IN the pool -- they are two of the manifest's six
	# (`docs/SCOPE.md` §1) -- and the pool is not what decides. This beat is here
	# because "it is not on the ring" and "it is not in RIGHT_POOL" are two
	# different claims and only the first one is the player's.
	_ck("K2 both are among the ring's six stops (%d)" % Game.RIGHT_POOL.size(),
		Game.RIGHT_POOL.size() == 6 and Game.RIGHT_POOL.has(&"sustain")
			and Game.RIGHT_POOL.has(&"ballast"))

	var stops := await _walk_ring(rig, "K3 before", out.path_join("r_30_ring_before"))
	_ck("K3 the ring is sword/bow/hookshot/burst and stops there (%s)" % [stops],
		not stops.has(&"sustain") and not stops.has(&"ballast"))
	# Assigned before asserting, never `not await f()` inside the argument list:
	# an `await` buried in a call's arguments is the kind of expression that
	# parses today and resumes somewhere surprising the day the callee changes.
	var reached_sustain: bool = await rig.draw_weapon(&"sustain", 10)
	_ck("K4 D-pad → never lands on Sustain, however long you press it",
		not reached_sustain)
	var reached_ballast: bool = await rig.draw_weapon(&"ballast", 10)
	_ck("K5 nor on Ballast", not reached_ballast)
	# The frame the two checks above are about: the hand after ten presses of →,
	# which is a hand holding something that is not a Verse.
	await rig.wait_frames(6)
	await rig.capture(out.path_join("r_31_ring_refused.png"))
	await rig.draw_weapon(&"sword", 10)


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
	_ck("B9 SELL UNMARKED leaves it in the bag",
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
	# Was "death took the bag", and that stopped being the rule when the document
	# case landed (GDD §3.1): death takes the HOLD and the case comes home, so an
	# empty bag is now the wrong claim and this beat failed on the merge. What is
	# still true -- and is the entire reason `case_fits` refuses a relic a case
	# slot -- is that no relic is ever in the part that survives. A relic you were
	# carrying is always still down there.
	_ck("D1 death did not bring the relic home", not Run.bag.has(FIRST))
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
	# And one standing in front of the watched prop, looking at it from the yard
	# side. Derived from the lamp rather than written down, so a prop that moves
	# takes its camera with it instead of leaving the shutter pointed at a wall.
	if watched != null:
		var inward: Vector3 = -watched.global_position
		inward.y = 0.0
		inward = inward.normalized()
		_cam.global_position = watched.global_position + inward * 4.5 \
			+ Vector3(0.0, 2.0, 0.0)
		_cam.look_at(watched.global_position + Vector3(0.0, 1.8, 0.0), Vector3.UP)
		_watch_pose = _cam.global_transform

	_cam.global_transform = _hall
	_cam.make_current()
	await rig.wait_frames(6)
	await rig.capture(out.path_join("r_10_hall_dark.png"))
	_cam.global_transform = _mid
	await rig.wait_frames(4)
	await rig.capture(out.path_join("r_15_mid_dark.png"))
	# The dark half of H9's pair, from the pose H9 will be judged in.
	_cam.global_transform = _watch_pose
	await rig.wait_frames(4)
	_ck("F4 the watched lamp is IN the frame its flare will be judged in",
		watched != null and _cam.is_position_in_frustum(
			watched.global_position + Vector3(0.0, 1.8, 0.0)))
	await rig.capture(out.path_join("r_18_watch_dark.png"))
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
	# The Far Lantern is behind the Artifacts option now (`Npc.activate`, 2026-08-10).
	_ck("G0b the Lanternkeeper offers Artifacts", await rig.talk("Artifacts"))
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
	# One press of RIGHT is ONE line, and twelve of them visit twelve.
	#
	# G4 above says this board IS the quest log. A quest log whose rows cannot be
	# reached is not one, and that is what this counted: RIGHT stepped **two**
	# cells, so over an even board the cursor ran 0,2,4,6,8,10,0,… and the six
	# odd-numbered relics could not be selected at all -- and a relic that cannot
	# be selected cannot be donated. `TradeScreen._input` is the fix and carries
	# the measurement; this is the check that would notice it coming back.
	var seen := {}
	for _i in screen.line_count():
		seen[screen._cursor] = true
		await rig.tap(["ui_right"])
		await rig.wait_frames(2)
	# What this MEASURES is twelve presses visiting twelve distinct lines, which
	# is the claim that matters -- every relic is selectable, so every relic is
	# donatable. It does not, strictly, pin the step to one: a step of 5, 7 or 11
	# is also coprime with twelve and would also visit all of them. Nothing here
	# can produce those, and saying "RIGHT steps one line" would be the same
	# over-claim this whole card was about.
	_ck("G8 twelve presses of RIGHT visit twelve distinct lines (%d of %d)"
		% [seen.size(), screen.line_count()], seen.size() == screen.line_count())

	# Pressed, so the footer is in the frame. `_refuse` is set by the press.
	# Walked to rather than assigned -- see `_walk_to`. A cursor the board's own
	# focus does not agree with draws the highlight on one row and refuses a
	# different one, and a capture of that is a photograph of nothing.
	_ck("G9 the D-pad reaches the one she has not found",
		await _walk_to(rig, screen, &"riven_chord"))
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
	# `--wrong-row` is this beat's null case, and the reason it exists is that
	# every check below was green-by-construction the moment `_walk_to` landed:
	# a fixture fix that cannot be made to fail again is a fixture nobody can
	# trust the next time. The flag skips the walk and leaves the cursor exactly
	# where `_refresh`'s deferred focus grab put it -- which is card #74's
	# reading, reproduced on demand, from H4 down.
	if rig.arg("wrong-row", "") != "":
		print("RELIC note: --wrong-row, the cursor is NOT being moved to the ledger")
	else:
		await _walk_to(rig, screen, FIRST)
	# Asked of where the cursor IS, and never of what `_walk_to` returned. The
	# whole of card #74 was a beat that believed its own bookkeeping about the
	# cursor instead of reading it, so a check here that trusts a return value
	# would be the same mistake wearing the fix's clothes -- and under
	# `--wrong-row` it would go green over a cursor sitting on the wrong relic.
	var on: StringName = &""
	if screen._cursor >= 0 and screen._cursor < screen._rows.size():
		var here: Dictionary = screen._rows[screen._cursor]
		on = here["line"]["id"] if here.has("line") else &""
	_ck("H0a the cursor is ON the Tally-Ledger's row (%s)" % screen.cursor_label(),
		on == FIRST)
	_ck("H0 the footer says her word (%s)" % screen._verb(),
		str(screen._verb()) == "RECORD")

	await rig.tap(["ui_accept"])
	await rig.wait_frames(8)
	_ck("H1 a TAP records nothing", not RelicDb.donated(FIRST))

	# Sampled every frame and released on the first non-zero reading. Ten frames
	# is ten frames of unknown duration in this harness, and a fixed wait here
	# read 0.00 in alchemy_loop on a slow run because the whole hold had already
	# elapsed and the bar it was looking at had reset.
	#
	# `rig.press`, not `Input.action_press`. The bare call is CLAUDE.md §3's
	# trap and it was sitting on both of this beat's holds; `TradeScreen` polls,
	# so it is NOT what broke this card -- but a screen that grows one
	# `_unhandled_input` reader would take these two beats silently dark with it.
	await rig.press(&"ui_accept")
	var peak := 0.0
	for _i in 30:
		await rig.wait_frames(1)
		peak = maxf(peak, screen._hold)
		if peak > 0.0:
			break
	rig.release(&"ui_accept")
	await rig.wait_frames(6)
	_ck("H2 the gauge fills while she writes (%.2f)" % peak, peak > 0.0)
	_ck("H3 letting go there recorded nothing", not RelicDb.donated(FIRST))

	# The shutter waits for the GAUGE, not for a frame count. One `wait_frames(1)`
	# here fired at `_hold` ~= 0.02 and produced a frame of an empty bar, i.e. a
	# picture that proves the opposite of the beat it belongs to. A quarter of the
	# hold is enough arc to read as a bar filling and still leaves most of the
	# hold un-elapsed, so the frame says "mid-press" rather than "nearly done".
	await rig.press(&"ui_accept")
	var shot := await _wait_until(rig,
		func() -> bool: return screen._hold >= TradeScreen.CRAFT_HOLD * 0.25, 60)
	_ck("H3a the gauge is visibly part-filled for the frame (%.2f of %.2f)"
		% [screen._hold, TradeScreen.CRAFT_HOLD], shot)
	await rig.capture(out.path_join("r_21_hold.png"))
	# ONE unbroken press, from the shutter above through the commit. It used to
	# be `hold_seconds` here on top of a press that was never released, which is
	# a second press of an already-held button -- harmless as it turned out, and
	# still nothing a player's thumb can do. The wait is generous because a
	# refused commit has to reach its own end rather than the harness's.
	var took := await _wait_until(rig,
		func() -> bool: return RelicDb.donated(FIRST), 120)
	rig.release(&"ui_accept")
	await rig.wait_frames(10)
	print("RELIC recorded donated=%s count=%d held_for=%s" % [
		RelicDb.donated(FIRST), RelicDb.donated_count(), took])
	_ck("H4 held through, it is in the ledger", RelicDb.donated(FIRST))
	_ck("H5 it left her hand", not RelicDb.held(FIRST))
	screen._refresh()
	var again := _row(screen, FIRST)
	_ck("H6 the row now refuses -- there is one of these (%s)"
		% RelicDb.refusal(again["line"]),
		not again.is_empty() and RelicDb.refusal(again["line"]) == "ALREADY RECORDED")
	_ck("H7 nought left of it", RelicDb.remaining(FIRST) == 0)

	# Hold it AGAIN, so the refusal is on the footer for the shutter. H6 above
	# reads `ALREADY RECORDED` off the catalogue, which is a string in a
	# function; this is the player holding the button on a relic she has already
	# given away and being told so, and it is the version of that claim a frame
	# can carry. The second hold cannot re-record it -- `can_buy` is false now,
	# so `_commit` falls to `_show_refusal` -- and H4 above is what proves the
	# first one landed.
	await rig.hold_seconds(["ui_accept"], 0.7)
	await rig.wait_frames(4)
	# Through the meta the kit puts there for exactly this, never `get_child(0)`
	# -- `FooterToast.build` says so in its own comment.
	var said := ""
	if screen._toast != null and screen._toast.has_meta(&"toast_label"):
		said = String((screen._toast.get_meta(&"toast_label") as Label).text)
	_ck("H7a holding it again is refused ON SCREEN, not in silence (%s)" % said,
		screen._refuse >= 0.0 and said.to_upper().contains("ALREADY RECORDED"))
	await rig.capture(out.path_join("r_22_recorded.png"))

	# Close it, and watch the lamp come on. The flare is deliberately deferred
	# to this moment -- see `GarrisonLight` -- because the counter draws a
	# curtain over the world and a lamp that lit underneath it would be a
	# garrison that was quietly already different.
	await rig.tap(["ui_cancel"])
	var gone := await _wait_until(rig, func() -> bool: return _screen(rig) == null, 90)
	_ck("H8 her screen closed", gone)
	# `_watch_pose` explicitly, not "wherever the camera was left" and not `_hall`.
	# The fixed camera is a shared prop and the dark pair moved it on its way out,
	# so this capture had been quietly shooting the wrong pose -- and `_hall`,
	# which it was corrected to, does not contain the lamp either. See
	# `_watch_pose`. `r_18_watch_dark.png` is this frame's before.
	if _cam != null:
		_cam.make_current()
		_cam.global_transform = _watch_pose

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
	# The photograph's own claim, separate from the mechanic's. A frame that does
	# not contain the thing it is evidence of is not evidence, and nothing else
	# in this run would have noticed.
	_ck("H9a and r_23 is a frame OF that lamp",
		lamp != null and _cam != null
			and _cam.is_position_in_frustum(lamp.global_position + Vector3(0.0, 1.8, 0.0)))
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
	# Straight through the catalogue this time, with no screen up. This proves
	# the OTHER half of `GarrisonLight`'s wiring -- that a donation with nothing
	# blocking input lights the lamp on the spot -- and **it proves nothing
	# whatever about the hold**, because it never touches a button.
	#
	# This comment used to say "the hold is proven above". It was false for as
	# long as card #74 was open: the hold above was RED, and four lines of
	# confident prose next to a green line is how nine failing checks read as a
	# working system. H4 is the only check in this file that a player's thumb
	# reaches. If it is red, nothing here covers for it.
	print("RELIC recording the drum, blocked=%s" % Prompt.blocked)
	_ck("I3 the catalogue records it with no screen up (the API, NOT the hold)",
		RelicDb.buy(line))
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


# --- K, second half. The two Verses pay out ------------------------------------

## Read both Verses over the counter, then use what they bought.
##
## `docs/ITEMS.md` §8 D5 in one beat: the ring gains two stops it did not have,
## and each of them does the thing GDD §6.2 names. Every claim below is read off
## the same accessors the game reads -- `Game.armament_owned`, `Heat.tier`,
## `Game.armour_soak()`, `Run.bag` -- and the presses go through the D-pad and
## the shoulder button rather than through the functions underneath them, because
## the defect being closed was precisely that the functions existed and no button
## reached them.
func _verse_lit(rig) -> void:
	Game.gold = 60000
	# A stock of charges, because these two spend the same pool Burst does and
	# the run between here and `_verse_dark` may have taken them.
	Game.add_charges(6)
	for id: StringName in [&"sustain_verse", &"ballast_verse"]:
		Game.set_flag(RelicDb.flag_held(id))
	var read := 0
	for line in RelicDb.lines():
		if line["id"] == &"sustain_verse" or line["id"] == &"ballast_verse":
			if RelicDb.buy(line):
				read += 1
	_ck("K6 both Verses were read at the counter (%d)" % read, read == 2)
	_ck("K7 the alchemist taught the workings",
		RelicDb.knows_working(&"sustain") and RelicDb.knows_working(&"ballast"))
	_ck("K8 so the game now says you own them",
		Game.armament_owned(&"sustain") and Game.armament_owned(&"ballast"))

	var stops := await _walk_ring(rig, "K9 after", out.path_join("r_35_ring_after"))
	_ck("K9 the ring is six stops now, with both Verses on it (%s)" % [stops],
		stops.size() == 6 and stops.has(&"sustain") and stops.has(&"ballast"))

	await _sustain(rig)
	await _ballast(rig)


## GDD §6.2 row 6: *the Heat chain holds through one break.*
##
## Photographed at a real tier, with the control shot beside it -- the second
## break, with the ward already spent, has to actually cost the chain or the
## first frame is a picture of a bar that never drops.
func _sustain(rig) -> void:
	Run.enter(31340)
	Game.heal(99)
	# Through the Bus, not through `Heat._advance`: the door a kill comes in by is
	# part of what is being proved, and `Heat` refuses to advance outside a run.
	for _i in 5:
		Bus.enemy_died.emit(null, Vector3.ZERO)
	await rig.wait_frames(4)
	print("RELIC heat kills=%d tier=%d window=%.2f" % [
		Heat.kills, Heat.tier, Heat.window])
	_ck("K10 the chain is lit (%d kills, tier %d)" % [Heat.kills, Heat.tier],
		Heat.tier >= 2 and Heat.kills >= 5)
	await rig.capture(out.path_join("r_40_heat_lit.png"))

	var drawn: bool = await rig.draw_weapon(&"sustain", 10)
	_ck("K11 D-pad → now reaches the Sustain-Verse", drawn)
	await rig.wait_frames(6)
	# The HUD cell, which is the whole of "it is on the ring and selectable":
	# `ArmamentDb.letter()` draws SU and `hand_count()` puts the charge tally
	# under it, exactly as it does for Burst.
	await rig.capture(out.path_join("r_41_sustain_hand.png"))

	var charges_before := Game.charges
	var tier_before := Heat.tier
	# Pressed. The shoulder button, on the hero, with nothing else driving it.
	await rig.tap(["attack"])
	await rig.wait_frames(8)
	print("RELIC sustain charges %d -> %d armed=%s" % [
		charges_before, Game.charges, Heat.sustained])
	_ck("K12 casting it spent a charge (%d -> %d)" % [charges_before, Game.charges],
		Game.charges == charges_before - 1)
	_ck("K13 and the chain is warded", Heat.sustained)
	await rig.capture(out.path_join("r_42_sustain_armed.png"))

	# Topped up first, so the window is not about to run out under the blow and
	# make this beat a race between two doors into the same break.
	Bus.enemy_died.emit(null, Vector3.ZERO)
	await rig.wait_frames(2)
	var kills_before := Heat.kills
	Game.damage(K.HEALTH_POINT)
	await rig.wait_frames(6)
	print("RELIC struck: tier %d -> %d, kills %d -> %d, armed=%s" % [
		tier_before, Heat.tier, kills_before, Heat.kills, Heat.sustained])
	_ck("K14 the blow landed and the chain HELD (tier %d, %d kills)"
		% [Heat.tier, Heat.kills],
		Heat.tier == tier_before and Heat.kills == kills_before)
	_ck("K15 and the ward is spent -- one break, not a stance", not Heat.sustained)
	await rig.capture(out.path_join("r_43_sustain_held.png"))

	# The control. Same blow, no ward: if this one does not cost the chain, the
	# frame above is a picture of a bar that never drops.
	Game.damage(K.HEALTH_POINT)
	await rig.wait_frames(6)
	print("RELIC struck again: tier %d kills %d" % [Heat.tier, Heat.kills])
	_ck("K16 the NEXT break costs the chain (tier %d, %d kills)"
		% [Heat.tier, Heat.kills], Heat.tier < tier_before)
	await rig.capture(out.path_join("r_44_chain_broken.png"))


## GDD §6.2 row 7: *burn the cheapest stack in the bag for a soak window.*
##
## Two things have to be true and only one of them is the buff. The bag has to
## lose the CHEAP line and keep the dear one -- a working that ate the Deep Amber
## is a button nobody presses twice -- and a blow has to visibly cost less while
## the window is up and full price once it is not.
func _ballast(rig) -> void:
	Game.heal(99)
	Run.collect(&"bone_shard", 4)
	Run.collect(&"deep_amber", 3)
	await rig.wait_frames(6)

	var drawn: bool = await rig.draw_weapon(&"ballast", 10)
	_ck("K17 D-pad → reaches the Ballast-Verse", drawn)
	await rig.wait_frames(6)
	await rig.capture(out.path_join("r_51_ballast_hand.png"))

	# --- The case is not reachable, and this beat was not planned -------------
	# `Run.collect` FILLS THE CASE FIRST (its own note: the forgiving default),
	# so a fresh bag of two lines is two lines that are entirely in the document
	# case -- and the first run of this director cast Ballast into that and got
	# nothing at all. That is the working being right: the case is the game's one
	# promise (GDD §3.1) and `Run._take_slot` walks the HOLD, exactly as the
	# thief does. It is asserted here rather than quietly worked around, because
	# a director that only ever tests the reachable case would not notice the day
	# somebody widened the scan.
	var cased_charges := Game.charges
	_ck("K18 everything is in the case, so there is nothing to burn (%s)"
		% [Run.cased], not Run.burnable())
	await rig.tap(["attack"])
	await rig.wait_frames(8)
	_ck("K19 casting into a case-only bag costs no charge (%d)" % Game.charges,
		Game.charges == cased_charges
			and Game.draught_left(Game.BALLAST_ID) <= 0.0)

	# Out of the case and into the hold, which is where a player's overflow lives
	# by the time they are deep enough to want this.
	Run.unstow(&"bone_shard")
	Run.unstow(&"deep_amber")
	await rig.wait_frames(6)
	var amber_before: int = Run.in_hold(&"deep_amber")
	var soak_before := Game.armour_soak()
	print("RELIC ballast hold bone=%d amber=%d case=%s soak=%d" % [
		Run.in_hold(&"bone_shard"), amber_before, Run.cased, soak_before])
	_ck("K20 there is something cheap and something dear in the HOLD",
		Run.in_hold(&"bone_shard") > 0 and amber_before > 0)
	await rig.capture(out.path_join("r_50_bag_before.png"))

	var charges_before := Game.charges
	await rig.tap(["attack"])
	await rig.wait_frames(8)
	print("RELIC ballast bag=%s charges %d -> %d soak %d -> %d window=%.2f" % [
		Run.bag, charges_before, Game.charges, soak_before, Game.armour_soak(),
		Game.draught_left(Game.BALLAST_ID)])
	_ck("K21 the cheapest stack burned", Run.in_hold(&"bone_shard") == 0)
	_ck("K22 the dear one is untouched -- it burns what you can spare (%d)"
		% Run.in_hold(&"deep_amber"), Run.in_hold(&"deep_amber") == amber_before)
	_ck("K23 a charge went with it (%d -> %d)" % [charges_before, Game.charges],
		Game.charges == charges_before - 1)
	_ck("K24 the window is up (%.1f s)" % Game.draught_left(Game.BALLAST_ID),
		Game.draught_left(Game.BALLAST_ID) > 0.0)
	_ck("K25 and it is worn: soak %d -> %d" % [soak_before, Game.armour_soak()],
		Game.armour_soak() == soak_before + K.BALLAST_SOAK)
	await rig.capture(out.path_join("r_52_bag_burned.png"))

	# --- The blow, twice -----------------------------------------------------
	# `take_hit`, not `Game.damage`: the soak lives on the damage path and calling
	# past it would be the director proving its own arithmetic.
	var hero := _hero(rig)
	if hero == null:
		_ck("K26 there is a hero to hit", false)
		return
	Game.heal(99)
	await rig.wait_frames(4)
	var before := Game.health_points
	var landed: bool = hero.take_hit(Hit.make(4,
		hero.global_position + Vector3(0.0, 0.0, 2.0), &"contact"))
	await rig.wait_frames(6)
	var soaked := before - Game.health_points
	print("RELIC soaked blow: %d HP (landed=%s)" % [soaked, landed])
	_ck("K26 a 4 HP blow cost %d while the window was up" % soaked,
		landed and soaked < 4)
	await rig.capture(out.path_join("r_53_hit_soaked.png"))

	# The control, and it doubles as proof the window ENDS. Waited out on the
	# game's clock rather than erased, because a window nobody can outlast is a
	# permanent soak with a countdown drawn on it.
	await rig.wait_seconds(K.BALLAST_TIME + 0.6)
	_ck("K27 the window ran out on its own",
		Game.draught_left(Game.BALLAST_ID) <= 0.0)
	Game.heal(99)
	await rig.wait_seconds(K.IFRAME_TIME + 0.2)
	var bare_before := Game.health_points
	var bare_landed: bool = hero.take_hit(Hit.make(4,
		hero.global_position + Vector3(0.0, 0.0, 2.0), &"contact"))
	await rig.wait_frames(6)
	var bare := bare_before - Game.health_points
	print("RELIC bare blow: %d HP (landed=%s)" % [bare, bare_landed])
	_ck("K28 the same blow costs %d with the window gone -- %d more"
		% [bare, bare - soaked], bare_landed and bare > soaked)
	await rig.capture(out.path_join("r_54_hit_bare.png"))

	Run.bag.clear()
	Run.in_dungeon = false
	Bus.bag_changed.emit(Run.bag, 0)
	await rig.draw_weapon(&"sword", 10)
	await rig.wait_frames(6)


# --- I, second half. The lit yard ---------------------------------------------

func _lit(rig) -> void:
	var garrison := rig.scene() as Garrison
	if garrison == null:
		return
	# FOUR, not two: the Tally-Ledger and the Rope-Drum from `_record`/`_bite`,
	# plus the two Verses `_verse_lit` reads over the same counter. This beat
	# asserted two until the K beats landed, and the count is the point of it --
	# what it is checking is that a donation lights ONE prop and not the yard, so
	# it has to move with the donations rather than be relaxed into a `>=`.
	const DONATED_BY_NOW := 4
	_ck("J0 four are recorded (%d)" % RelicDb.donated_count(),
		RelicDb.donated_count() == DONATED_BY_NOW)
	var watched := garrison.light_of(WATCH)
	_ck("J1 the Tally-Ledger's lamp is lit", watched != null and watched.lit())
	var winch := garrison.light_of(&"winch_lamp")
	_ck("J2 the Rope-Drum's lamp is lit", winch != null and winch.lit())
	var lit_count := 0
	for l in garrison.lights:
		if l.lit():
			lit_count += 1
	_ck("J3 four of twelve, and only four (%d)" % lit_count,
		lit_count == DONATED_BY_NOW)

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
	var hero := _hero(rig)
	if hero == null:
		return null
	return RelicPickup.place(rig.scene(), id,
		hero.global_position + Vector3(ASIDE, 0.0, -ahead))


func _hero(rig) -> Hero:
	var players: Array = rig.get_nodes_in_group(&"player")
	return players[0] as Hero if not players.is_empty() else null


## Step the right hand all the way round the ring with D-pad →, one frame per
## stop, and hand back the ids it actually landed on.
##
## The FRAMES are the point and the returned array is the caption. A ring is a
## thing you press your way round, so "Sustain is on it" is a sequence of HUD
## cells and not a single capture -- one photograph of a cell reading SU would be
## a photograph of a hand, which is what `Game.loadout` could have been made to
## say without a ring stop existing at all.
##
## Stops when it comes back to something it has already seen, so the walk's
## LENGTH is the ring's length rather than a number this function chose.
func _walk_ring(rig, tag: String, prefix: String) -> Array:
	var seen: Array = []
	for _i in Game.RIGHT_POOL.size() + 2:
		var id: StringName = Game.armament(Game.HAND_RIGHT)
		if seen.has(id):
			break
		seen.append(id)
		await rig.wait_frames(4)
		await rig.capture("%s_%d_%s.png" % [prefix, seen.size() - 1, id])
		await rig.tap(["weapon_next"])
		await rig.wait_frames(2)
	print("RELIC %s ring = %s" % [tag, seen])
	return seen


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


## Put the counter's cursor on `id` by PRESSING THE D-PAD, and never by
## assigning `_cursor`.
##
## **The assignment is what card #74 turned out to be.** `screen._cursor = i` is
## half a move: `TradeScreen._point_at` is the other half, and it is the half
## that calls `grab_focus` on the row's `Button`. Godot's focus grab is
## DEFERRED -- the `focus_entered` it queues lands a frame or more later, runs
## `UpgradeLadder._look` -> `cell_focused` -> `TradeScreen._on_cell_looked` ->
## `_point_at`, and puts `_cursor` **back on whatever row the last `_refresh`
## left the focus on**. So the assignment held for one frame, the half-second
## hold below completed on THE RIVEN CHORD -- a relic nobody has recovered, which
## `can_buy` refuses -- and the donation that the run was built to prove never
## happened. Nine checks went red and read as "the hold never commits".
##
## Measured, not reasoned: with the assignment in place the board printed
## `ledger_idx=0` and `cur=11` in the same frame, the gauge ran 0.16 -> 0.48 ->
## 0 with `armed` dropping to false (that IS the commit firing) and the footer's
## refusal timer restarting from 0.02. The screen did everything right.
##
## `mvp_loop.gd` met the same edge from the other side in #40 and reached for
## `screen._point_at`. Pressing the button is better: `_point_at` is still the
## harness reaching into the screen, and a walk over the board is also a test of
## the left/right wrap the board promises. `cursor_label`/`line_count` exist for
## exactly this and say so in their docstrings.
func _walk_to(rig, screen, id: StringName) -> bool:
	# One press per row plus one, so a board that will not move terminates here
	# rather than in the harness's wall clock.
	for _i in screen.line_count() + 1:
		var at: int = screen._cursor
		if at >= 0 and at < screen._rows.size():
			var r: Dictionary = screen._rows[at]
			if r.get("kind") == &"buy" and r["line"]["id"] == id:
				return true
		await rig.tap(["ui_right"])
		# The focus round trip above is why: the cursor this asks about next
		# frame is not settled in the frame the press landed in.
		await rig.wait_frames(2)
	return false


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
