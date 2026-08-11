extends RefCounted
## **The half of the Burst that could never happen.** `docs/ITEMS.md` §8, D4.
##
## `burst_cast.gd` proves the working casts. It also grants itself three charges
## on line 139, and until this card it was the ONLY caller of
## `Game.add_charges()` in the repository -- so the thing it proved was a verb
## with no way to load it. Kill the Slag Ogre, take the Burst, reach it on the
## ring, and there was nothing in the shipped game that would sell you a charge.
##
## Point it at GARRISON. It descends on its own, because the claim is not "a
## counter took some gold" -- it is that a charge bought upstairs is in the pouch
## when you get down there and comes out of it when you pull the trigger.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/charge_buy.gd \
##     --out=/tmp/charge/x.png --warmup=60
##
## What it claims, in the order it proves them:
##
##   A  Before the Slag Ogre, she does not sell them. The line is ABSENT, not
##      greyed -- ammunition for a verb you have never seen is a spoiler and a
##      slot that lies (`SupplyDb.GATED_BY` makes the same argument for arrows).
##   B  Owning the working, her board grows a CHARGES row of its own.
##   C  It is bought the way a player buys it: walk up, Trade, cursor onto the
##      row, HOLD. The gold goes down and the pouch goes UP, and the frames
##      either side of the press are the same row with a different number in it.
##   D  It reaches the HUD -- the working's hand cell is a counter and the
##      numeral in it is the one the counter just sold.
##   E  It survives the shaft. He goes down with three and the trigger spends
##      exactly one, on a mote that flies and goes off.
##
## C and E are the two the card asked for and they are the two with frames. The
## rest is the plumbing that makes them reachable.

## The bundle's price is `AlchemyDb.CHARGE_GOLD`; this is enough to buy one and
## not so much that "the gold went down" is invisible against it.
const PURSE := 600

var out := ""
var _fails := 0


func run(rig) -> void:
	out = rig.arg("out", "/tmp/charge/x.png").get_base_dir()
	Bus.screen_closed.connect(func(what: StringName) -> void:
		print("CHARGE note: %s closed" % what))
	await rig.wait_frames(20)

	await _cold(rig)
	await _owned(rig)
	await _buy(rig)
	await _hud(rig)
	await _underground(rig)

	if _fails == 0:
		print("CHARGE OK the alchemist sells them, the pouch carries them, the trigger spends one")
	else:
		print("CHARGE FAIL -- %d check(s) failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_fails += 1
		print("CHARGE FAIL %s" % label)


# --- A. Before the Slag Ogre --------------------------------------------------

func _cold(rig) -> void:
	Game.gold = PURSE
	_ck("A0 the working is not owned yet", not Game.has(&"burst"))
	_ck("A1 the pouch is empty (%d)" % Game.charges, Game.charges == 0)
	var ids := _ids()
	print("CHARGE cold board=%s" % [ids])
	# ABSENT, not refused. A greyed row still tells you charges exist and still
	# has to be scrolled past, which is the argument `shop_db.gd:44-52` makes
	# about the bow's ladder in more words than this needs.
	_ck("A2 she does not sell charges to someone with no working",
		not ids.has(AlchemyDb.CHARGE_ID))
	await rig.wait_frames(4)


# --- B. The Slag Ogre's drop --------------------------------------------------

## Granted, and said out loud. What this director is about starts one room after
## the boss dies; that the Ogre hands over `&"burst"` is `boss_db.gd`'s row and
## `mvp_loop`'s claim, and proving it twice here would be the second copy of a
## thing that already passes.
func _owned(rig) -> void:
	Game.grant(&"burst")
	print("CHARGE precondition: granted the Burst -- the Slag Ogre's drop (GDD §5.2)")
	_ck("B0 the working is owned", Game.has(&"burst"))
	var ids := _ids()
	print("CHARGE warm board=%s" % [ids])
	_ck("B1 her board grew the charge line", ids.has(AlchemyDb.CHARGE_ID))
	# The row, not just the line. A line with no group is a line the board never
	# draws, which is exactly how the Lanternkeeper's counter shipped blank once
	# (`RelicDb.groups`'s note).
	var titles: Array = []
	for g in AlchemyDb.groups():
		titles.append(String(g["title"]))
	_ck("B2 and a row of its own to draw it in (%s)" % [titles],
		titles.has("CHARGES"))
	await rig.wait_frames(4)


# --- C. Bought over the counter -----------------------------------------------

func _buy(rig) -> void:
	var garrison := rig.scene() as Garrison
	if garrison == null or garrison.alchemist == null:
		_ck("C0 the alchemist is in the garrison", false)
		return
	_ck("C0 the alchemist is in the garrison", true)
	# Addressed the way a player addresses him: stand where the prompt reaches,
	# press what it names. Calling `activate()` would prove the screen opens and
	# nothing about whether he can be reached.
	_stand_at(rig, garrison.alchemist.global_position + Vector3(0.0, 0.0, 1.6),
		garrison.alchemist.global_position)
	var focused := await _wait_until(rig,
		func() -> bool: return Prompt.focus == garrison.alchemist, 120)
	_ck("C1 he owns the interact button", focused)
	await rig.tap(["interact"])
	_ck("C1b he offers to trade", await rig.talk("Trade"))
	await rig.wait_frames(16)

	var screen := _screen(rig)
	if screen == null:
		_ck("C2 his counter opened", false)
		return
	_ck("C2 his counter opened", true)
	var row := _row(screen, AlchemyDb.CHARGE_ID)
	if row.is_empty():
		_ck("C3 CHARGES is on the board", false)
		return
	_ck("C3 CHARGES is on the board", true)
	_ck("C4 it costs gold and NOT materials -- a charge is stock, not a brew",
		int(row["line"]["cost"]) > 0
			and (row["line"].get("parts", {}) as Dictionary).is_empty())
	_ck("C5 he will sell it (%s)" % AlchemyDb.refusal(row["line"]),
		AlchemyDb.can_buy(row["line"]))

	# `_point_at`, and not `screen._cursor = i` (CLAUDE.md §3, card #77). The
	# assignment is half a move: `_point_at` is the half that calls `grab_focus`,
	# which is DEFERRED, so the `focus_entered` it queues lands a frame later, runs
	# back through `_on_cell_looked`, and puts `_cursor` on whatever row the last
	# `_refresh` left the focus on. Card #74 was nine red checks of exactly that.
	#
	# Going through `_point_at` makes the round trip IDEMPOTENT -- it re-points at
	# the row that was asked for -- so a beat that waits a frame before acting is
	# safe rather than racing. That is why no wait is added here: the fix is the
	# call, not a sleep.
	screen._point_at(screen._rows.find(row))
	screen._refresh()
	# The cursor has to be back on the row after a refresh, or the "before" frame
	# is a photograph of the bottle line.
	screen._point_at(screen._rows.find(_row(screen, AlchemyDb.CHARGE_ID)))
	await rig.wait_frames(8)
	var gold_before := Game.gold
	var charges_before := Game.charges
	# **The frame the card asked for, first half.** The row, the price, and the
	# count it is about, before a coin moves.
	await rig.capture(out.path_join("c_00_before.png"))

	# **A TAP, and that is the right answer.** `Catalogue.crafts()` makes a line a
	# hold when it eats `parts`, and the charge line has none -- so it presses
	# exactly like the smith's ARROWS X10 and unlike every brew on this same
	# board. The hold is not ceremony: it protects a press that spends materials
	# the floor gave you and cannot give back. Gold you can earn again.
	#
	# Asserted rather than assumed, because "which press is this" is the kind of
	# thing that drifts silently: the first cut of this director expected a hold
	# here and reported three failures for a counter that was behaving correctly.
	var brew := _row(screen, &"heart_draught")
	_ck("C6 it is a tap, like the smith's arrows, and not a hold like a brew",
		not AlchemyDb.crafts(row["line"])
			and not brew.is_empty() and AlchemyDb.crafts(brew["line"]))
	await rig.tap(["ui_accept"])
	await rig.wait_frames(12)
	print("CHARGE bought gold %d -> %d  charges %d -> %d" % [
		gold_before, Game.gold, charges_before, Game.charges])
	_ck("C7 the pouch went up by a bundle (%d -> %d)"
		% [charges_before, Game.charges],
		Game.charges == charges_before + AlchemyDb.CHARGE_BATCH)
	_ck("C8 and it cost the counter's price (%d -> %d)" % [gold_before, Game.gold],
		Game.gold == gold_before - AlchemyDb.CHARGE_GOLD)

	screen._refresh()
	screen._point_at(screen._rows.find(_row(screen, AlchemyDb.CHARGE_ID)))
	# **Wait for the PURSE to stop rolling.** `TradeScreen` lerps `_shown_gold`
	# towards `Game.gold` (`:1048`) -- the purse is the one thing on that header
	# that animates -- so a frame taken ten frames after the press photographs a
	# number in flight. The first cut of this beat produced an "after" frame
	# reading 516 for a purse of 510, which is not a bug and is exactly the kind
	# of picture that gets read as one. Polled on the value rather than waited
	# out, because how long the roll takes depends on the harness's frame rate.
	await _wait_until(rig,
		func() -> bool: return absf(screen._shown_gold - float(Game.gold)) < 0.5, 180)
	await rig.wait_frames(4)
	# **The frame the card asked for, second half.** The same row and the same
	# camera, with the count moved and the purse settled on what it paid. Two
	# frames from two screens prove nothing.
	await rig.capture(out.path_join("c_01_after.png"))

	# And the ceiling, which is the other thing the row has to be able to say.
	Game.add_charges(Game.max_charges)
	screen._refresh()
	var full := _row(screen, AlchemyDb.CHARGE_ID)
	_ck("C9 a full pouch refuses (%d/%d)" % [Game.charges, Game.max_charges],
		not full.is_empty() and not AlchemyDb.can_buy(full["line"]))
	_ck("C10 and the refusal says the pouch, not the money (%s)"
		% AlchemyDb.refusal(full["line"]),
		AlchemyDb.refusal(full["line"]).contains("POUCH"))
	screen._point_at(screen._rows.find(full))
	screen._commit()
	await rig.wait_frames(8)
	await rig.capture(out.path_join("c_02_full.png"))

	# Back to three, so what goes down the shaft is what the counter sold and not
	# what this beat topped it up with.
	Game.charges = AlchemyDb.CHARGE_BATCH
	Bus.ammo_changed.emit(AlchemyDb.CHARGE_ID, Game.charges)

	await rig.tap(["ui_cancel"])
	var gone := await _wait_until(rig, func() -> bool: return _screen(rig) == null, 90)
	_ck("C11 his screen closed", gone)
	await rig.wait_frames(10)


# --- D. It reaches the HUD ----------------------------------------------------

func _hud(rig) -> void:
	# PRESSED, not assigned -- the ring is how a player reaches it and this is
	# the only version of the check that would notice `RIGHT_POOL` losing the row.
	var reached: bool = await rig.draw_weapon(&"burst")
	_ck("D0 D-pad steps the right hand onto the working", reached)
	_ck("D1 the working's hand cell is a charge counter (%s)"
		% ArmamentDb.hand_count(&"burst"),
		ArmamentDb.hand_count(&"burst") == AlchemyDb.CHARGE_ID)
	_ck("D2 and it counts what the counter sold (%d)"
		% Game.ammo_count(AlchemyDb.CHARGE_ID),
		Game.ammo_count(AlchemyDb.CHARGE_ID) == AlchemyDb.CHARGE_BATCH)
	await rig.wait_frames(20)
	await rig.capture(out.path_join("c_03_hud.png"))


# --- E. Down the shaft, and spent ---------------------------------------------

func _underground(rig) -> void:
	var garrison := rig.scene() as Garrison
	if garrison == null:
		return
	_stand_at(rig, garrison.gate.global_position + Vector3(0.0, 0.0, 1.8))
	await _wait_until(rig, func() -> bool: return Prompt.focus == garrison.gate, 90)
	# `hold_seconds`, not a frame count. alchemy_loop.gd's H beat carries the long
	# note about why: the descent is ~0.9 s of hold plus a scene change, and a
	# frame budget that lands short releases the button mid-transition.
	await rig.hold_seconds(["interact"], 1.6)
	await rig.wait_frames(140)
	_ck("E0 he went down", Run.in_dungeon)
	if not Run.in_dungeon:
		return
	print("CHARGE underground charges=%d scene=%s" % [Game.charges, rig.scene().name])
	# **They do not refill underground and they do not evaporate either**
	# (GDD §6.5). What you paid for upstairs is what you have down here.
	_ck("E1 the charges came down with him (%d)" % Game.charges,
		Game.charges == AlchemyDb.CHARGE_BATCH)

	var players: Array = rig.get_nodes_in_group(&"player")
	if players.is_empty():
		_ck("E2 there is a hero to cast it", false)
		return
	var hero: Node3D = players[0]
	var reached: bool = await rig.draw_weapon(&"burst")
	_ck("E2 the working is in his right hand down here", reached)
	await rig.wait_frames(10)
	await rig.capture(out.path_join("c_04_underground.png"))

	var before := Game.charges
	Input.action_press(&"heavy")
	await rig.wait_frames(30)
	_ck("E3 the trigger raised the working (stance=%s)" % hero.call(&"aim_item"),
		StringName(hero.call(&"aim_item")) == &"burst")
	# The frame with the stance up and the numeral still reading three: this is
	# the last one before the thing that was bought is gone.
	await rig.capture(out.path_join("c_05_aimed.png"))
	Input.action_release(&"heavy")

	# Watched frame by frame. The mote leaves at the end of the cast clip, so a
	# fixed wait finds either nothing yet or something already landed
	# (burst_cast.gd's note).
	var mote: Node3D = null
	for _i in 60:
		await rig.wait_frames(1)
		mote = _mote(rig)
		if mote != null:
			break
	_ck("E4 the release put a mote in the air", mote != null)
	_ck("E5 and it spent exactly one charge (%d -> %d)" % [before, Game.charges],
		Game.charges == before - 1)

	# Step off the line before the shutter. The camera rides down the aim, so for
	# the first couple of metres the mote is behind his own head from every
	# camera the player has -- burst_cast.gd found that by looking at two PNGs
	# with no mote in them while every assertion passed.
	await rig.hold_seconds(["move_left"], 0.6)
	for _i in 120:
		if mote == null or not is_instance_valid(mote):
			break
		if bool(mote.get(&"_settled")):
			break
		await rig.wait_frames(1)
	await rig.capture(out.path_join("c_06_mote.png"))

	# And it goes off, which is the difference between a charge spent and a
	# charge lost. The fuse runs from the CAST (`K.BOMB_FUSE`), sampled every
	# frame so the blast frame is the blast frame.
	var spent := false
	for _i in 300:
		await rig.wait_frames(1)
		if mote == null or not is_instance_valid(mote):
			spent = true
			break
		if bool(mote.get(&"_spent")):
			spent = true
			break
	# The flash OPENS over `BurstCast.FLASH_OPEN`; the frame `_spent` flips on is
	# the frame the flash is still scaled to zero.
	for _i in 20:
		await rig.wait_frames(1)
		if mote == null or not is_instance_valid(mote):
			break
		if float(mote.get(&"_flash_t")) >= BurstCast.FLASH_OPEN:
			break
	_ck("E6 the charge went off", spent)
	await rig.capture(out.path_join("c_07_blast.png"))
	print("CHARGE spent charges=%d" % Game.charges)


# --- Helpers ------------------------------------------------------------------

func _ids() -> Array:
	var ids: Array = []
	for l in AlchemyDb.lines():
		ids.append(l["id"])
	return ids


func _mote(rig) -> Node3D:
	for n in _all(rig.scene()):
		if n is BurstCast:
			return n as Node3D
	return null


func _row(screen, id: StringName) -> Dictionary:
	for r in screen._rows:
		if r.get("kind") == &"buy" and r["line"]["id"] == id:
			return r
	return {}


func _screen(rig) -> TradeScreen:
	var found: Array[TradeScreen] = []
	for n in _all(rig.scene()):
		if n is TradeScreen:
			found.append(n)
	if found.size() > 1:
		_fails += 1
		print("CHARGE FAIL %d trade screens are open at once" % found.size())
	return found[0] if not found.is_empty() else null


func _all(root: Node) -> Array:
	var found := [root]
	for c in root.get_children():
		found.append_array(_all(c))
	return found


## Poll a condition rather than waiting a fixed number of frames. The harness
## runs at whatever speed the machine allows, so every fixed wait is a wait of
## unknown duration and the failures that produces read as game bugs.
func _wait_until(rig, cond: Callable, frames: int) -> bool:
	for _i in frames:
		if cond.call():
			return true
		await rig.wait_frames(1)
	return cond.call()


## Teleport. Pathing a hero across the garrison with synthetic input is its own
## project and the thing under test is the counter and the pouch.
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
