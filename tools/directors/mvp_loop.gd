extends RefCounted
## Drives the whole Moonlighter loop end to end and photographs every beat.
##
## Sell -> buy -> descend -> fight -> loot -> extract -> sell again. This is the
## only proof that matters for the MVP: each system has been rendered on its own,
## and the interesting failures are all at the seams (a scene change that eats
## the HUD, a prompt that survives the screen that blocked it, a bag that empties
## into nothing).
##
## The hero is TELEPORTED between beats rather than walked. Pathing a character
## across a procedural dungeon with synthetic input is its own project, and the
## thing under test here is the loop, not the navmesh.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/mvp_loop.gd --out=/tmp/mvp/x.png

var out := ""

## `Game.deaths` as it stood when this director started.
##
## **The one fact that tells a beat "the run you are testing is over".** `Run.die()`
## is the only thing that increments it and the only thing that empties the bag
## mid-floor, so it is the sentinel every beat below the gate checks — and it is a
## COUNTER rather than `Run.in_dungeon`, because the garrison beats run with
## `in_dungeon = false` on purpose (`_sell`) and a check on that flag reads every
## garrison prompt failure as a death. That is not a hypothetical: it is the line
## `_approach` used to print, and issue #14 spent two runs of somebody's time on it.
var _deaths := 0


func run(rig) -> void:
	out = rig.arg("out", "/tmp/mvp/x.png").get_base_dir()
	_deaths = Game.deaths

	# `--run-seed=N` pins the FLOOR, which `--seed` does not: `--seed` seeds the
	# global RNG, and the dungeon is built from `Run.rng`, which `Run.enter()`
	# seeds off the wall clock. So every run of this director drew a different
	# floor and a floor-shaped bug (#36) could only be met by re-running until it
	# turned up. `Run.seed_next` is consumed by the `enter()` the gate triggers.
	var run_seed := int(rig.arg("run-seed", "0"))
	if run_seed != 0:
		Run.seed_next = run_seed

	await rig.wait_frames(30)

	await _garrison_arrival(rig)

	# THE GARRISON BEATS ARE A CHAIN AND THEY STOP THE RUN WHEN THEY BREAK.
	#
	# Every beat after this one assumes the one before it happened: the gate beat
	# needs the shop screens closed, the dungeon beats need a dungeon, the receipt
	# needs a run to end. When the sell beat silently did not happen, this director
	# printed FOUR more failures -- no focus at the gate, no descent, no dungeon,
	# no enemies -- none of which were about the systems they named, and a reader
	# had no way to tell that from a real regression in four systems at once.
	# One cause, one message, and nothing downstream pretending to have been tested.
	if not await _sell(rig):
		rig.fail("MVP ABORT the sell beat did not happen -- stopping rather than"
			+ " reporting four failures it would have caused")
		return
	if not await _buy(rig):
		rig.fail("MVP ABORT the buy beat did not happen -- stopping rather than"
			+ " reporting four failures it would have caused")
		return
	if not await _descend(rig):
		rig.fail("MVP ABORT never got underground -- stopping rather than reporting"
			+ " the dungeon, the fight and the rope as broken from up here")
		return

	# Same chain rule as the three above, and it is the other half of #14. The
	# fight beat can end with the run itself over -- the hero killed by the floor
	# while this director stood on a drop -- and every beat after it then reports
	# a chest that is not there and a rope that "refused to start" for a hero who
	# is standing in the garrison. One cause, one message.
	if not await _fight(rig):
		rig.fail("MVP ABORT the fight beat ended the run -- stopping rather than"
			+ " reporting the chest and the rope as broken from the garrison")
		return
	await _extract(rig)
	await _return(rig)


## Has the run ended under us, and if so say which way.
##
## Called at the seams of `_fight`, because that is where it happens: the tour
## teleports the hero next to whatever is nearest with no regard for the twenty-odd
## monsters converging on him, and `Run.die()` empties the bag, sets `in_dungeon`
## false and sends `Flow` home. Every later beat then reports a failure it did not
## cause -- which is exactly what issue #14 read like from the outside, complete
## with `MVP after_pickup bag=0 value=0` under a log line saying `hero 12/12`.
##
## **The healths in this director's log are not evidence and this is why.**
## `Game.heal(Game.max_quarters)` runs twice inside `_fight`, deliberately (see
## the note there), so a hero who died a frame earlier is reported at full health
## a frame later. The death has to be read off the counter, never off the bar.
func _ended(rig, where: String) -> bool:
	if Game.deaths > _deaths:
		rig.fail(("MVP FAIL the hero died %s -- deaths %d -> %d, the floor killed him"
			+ " while this beat was waiting. Nothing after this line was tested,"
			+ " and the health in the lines above it is the heal, not the truth.")
			% [where, _deaths, Game.deaths])
		return true
	if not Run.in_dungeon:
		rig.fail(("MVP FAIL the run ended %s without a death (in_dungeon=false,"
			+ " deaths=%d) -- something took the hero out of the dungeon that was"
			+ " not the rope and was not dying") % [where, Game.deaths])
		return true
	return false


# --- Garrison ---------------------------------------------------------------

func _garrison_arrival(rig) -> void:
	print("MVP garrison gold=%d hearts=%d/%d" % [
		Game.gold, Game.quarters, Game.max_quarters])
	await rig.capture(out.path_join("m_00_garrison.png"))


func _sell(rig) -> bool:
	# Arrive as though a run had just paid out, so the vendor has something to
	# buy and the bag corner has something to show.
	Run.in_dungeon = false
	Run.collect(&"iron_scrap", 5)
	Run.collect(&"ghost_silk", 3)
	Run.collect(&"deep_amber", 2)
	Run.collect(&"bone_shard", 11)
	await rig.wait_frames(10)

	var garrison := rig.scene() as Garrison
	if not await _approach(rig, garrison.vendor,
			garrison.vendor.global_position + Vector3(0.0, 0.0, 1.6)):
		return false
	print("MVP focus=%s bag=%d" % [
		Prompt.focus.prompt if Prompt.focus != null else "<none>", Run.bag_value()])
	await rig.capture(out.path_join("m_01_vendor_prompt.png"))

	await rig.tap(["interact"])
	# The press opens a CONVERSATION now, and the shop is the Trade option at the
	# end of it (`Npc.activate`, 2026-08-10). `rig.talk` is the whole of that beat
	# and it presses real buttons to do it.
	if not await rig.talk("Trade"):
		rig.fail("MVP FAIL the vendor would not offer to trade")
		return false
	# The screen is a state, not a frame count: `TradeScreen` is built inside
	# `Npc._choose_trade` and is up on the next frame, but a beat that assumed so
	# would be making the same mistake one layer along.
	var opened: bool = await rig.until(func() -> bool: return _screen(rig) != null)
	if not opened:
		rig.fail("MVP FAIL the vendor took the press and no shop screen came up")
		return false
	var screen := _screen(rig)
	if screen.mode != TradeScreen.Mode.TRADE or screen.catalogue != SupplyDb:
		rig.fail("MVP FAIL Trade opened the wrong layout or catalogue")
		return false
	if screen._stock_grid == null or screen._bag_grid == null:
		rig.fail("MVP FAIL Trade did not build both inventory grids")
		return false
	var stock_ids: Array[StringName] = []
	for i: int in screen._stock_rows:
		if i < 0 or i >= screen._rows.size() \
				or screen._rows[i].get("kind") != &"buy":
			rig.fail("MVP FAIL Trade's stock index does not point at a buy row")
			return false
		var id: StringName = screen._rows[i]["line"]["id"]
		stock_ids.append(id)
		if not SupplyDb.STOCK_IDS.has(id):
			rig.fail("MVP FAIL Trade exposed non-stock id %s" % id)
			return false
	if screen.visible_catalogue_ids != SupplyDb.STOCK_IDS:
		rig.fail("MVP FAIL Trade was not filtered to STOCK_IDS (%s)"
			% [screen.visible_catalogue_ids])
		return false
	if not screen._stock_rows.has(screen._cursor) \
			or screen._tip.title.text != screen.cursor_label():
		rig.fail("MVP FAIL Trade did not start on stock detail (cursor=%d stock=%s detail=%s)"
			% [screen._cursor, stock_ids, screen._tip.title.text])
		return false
	await rig.wait_frames(14)
	await rig.capture(out.path_join("m_02_sell_screen.png"))

	# Sell the first BAG stack, not the first row: Trade starts on quartermaster
	# stock and the live bag occupies the second inventory grid.
	if screen._bag_rows.is_empty():
		rig.fail("MVP FAIL Trade has no bag rows to sell")
		return false
	screen._point_at(screen._bag_rows[0])
	await rig.wait_frames(2)
	await rig.tap(["ui_accept"])
	await rig.wait_frames(20)
	await rig.capture(out.path_join("m_03_sold_one.png"))

	# `_point_at`, not `_cursor = `. **Assigning the field moved the cursor and
	# left the FOCUS behind**, and that only went unnoticed while the harness was
	# unable to press a button: `ItemGrid`'s cells are real `Button`s, `_point_at`
	# is what calls `grab_focus` on them, and a `ui_accept` that reaches the
	# focused one emits `cell_focused` -> `_on_cell_looked` -> `_point_at(0)`.
	# `rig.tap` dispatches a real event now (#40), so the next press snapped the
	# cursor back to the top row and sold Iron Scrap instead of holding SELL
	# UNMARKED -- reported as "holding SELL UNMARKED did not sell the bulk slice".
	# The screen was right and the shortcut was wrong.
	var sell_all := -1
	for i: int in screen._bag_rows:
		if screen._rows[i].get("kind") == &"all":
			sell_all = i
			break
	if sell_all < 0:
		rig.fail("MVP FAIL Trade has no SELL UNMARKED bag row")
		return false
	var bulk_ids: Array[StringName] = screen._rows[sell_all]["ids"].duplicate()
	screen._point_at(sell_all)
	screen.queue_redraw()

	# SELL UNMARKED is a HOLD (`TradeScreen._hold_time`): one press should not
	# be able to sell the slice, and the row draws a gauge saying so. A tap first,
	# because a beat that only holds would pass with the hold deleted.
	await rig.tap(["ui_accept"])
	await rig.wait_frames(12)
	if bulk_ids.any(func(id: StringName) -> bool: return not Run.bag.has(id)):
		rig.fail("MVP FAIL a tap sold the bulk slice -- SELL UNMARKED is meant to be held")
	# Held in game seconds. A frame count is a duration of unknown length and the
	# gauge advances by `delta` (see `rig.hold_seconds`).
	await rig.hold_seconds(["ui_accept"], 0.9)
	await rig.wait_frames(24)
	var sold_bulk := bulk_ids.all(func(id: StringName) -> bool: return not Run.bag.has(id))
	if not sold_bulk:
		rig.fail("MVP FAIL holding SELL UNMARKED left bulk ids behind (%s)" % [bulk_ids])
	print("MVP after_sell gold=%d bag=%d" % [Game.gold, Run.bag_value()])
	await rig.capture(out.path_join("m_04_sold_all.png"))

	await rig.tap(["ui_cancel"])
	# The close is a state too, and it is the one that bit the gate beat: a hold
	# that lands while the screen is still shutting goes into the screen.
	await rig.until(func() -> bool: return _screen(rig) == null)
	return sold_bulk


## **The bag slot is bought at the QUARTERMASTER, not at the smith.**
##
## It was the forge's until card #91, which put Brannoc behind the floor 1
## miniboss -- and a new save that cannot reach the smith for its whole first hour
## cannot buy a bag slot, a heart or an arrow either. So the repeatable stock and
## permanent upgrades moved to Kessa's two services (`SupplyDb`, `Npc.COUNTERS`),
## and the MVP loop
## follows them: the loop this director exists to prove is *sell the bag, spend
## the gold, go back down*, and every step of it is now reachable on the first
## descent, which it was not while this beat walked to a man who is not there.
##
## She is where `_sell` left the hero standing, so the approach is usually a
## no-op. It is still made, because `_sell` can leave him a pace off.
func _buy(rig) -> bool:
	var garrison := rig.scene() as Garrison
	if not await _approach(rig, garrison.vendor,
			garrison.vendor.global_position + Vector3(0.0, 0.0, 1.6)):
		return false
	await rig.tap(["interact"])
	# Her SECOND option: Trade is the two-sided stock/bag service, while Upgrades
	# is the permanent bag and heart progression board.
	if not await rig.talk("Upgrades"):
		rig.fail("MVP FAIL the quartermaster would not open Upgrades")
		return false
	var opened: bool = await rig.until(func() -> bool: return _screen(rig) != null)
	if not opened:
		rig.fail("MVP FAIL Upgrades took the press and no shop screen came up")
		return false
	var screen := _screen(rig)
	if screen.mode != TradeScreen.Mode.PROGRESSION or screen.catalogue != SupplyDb:
		rig.fail("MVP FAIL Upgrades opened the wrong layout or catalogue")
		return false
	var buy_ids: Array[StringName] = []
	for row: Dictionary in screen._rows:
		if row.get("kind") == &"buy":
			buy_ids.append(row["line"]["id"])
	var available_upgrade_ids: Array[StringName] = []
	for line: Dictionary in SupplyDb.lines():
		var id: StringName = line["id"]
		if SupplyDb.UPGRADE_IDS.has(id):
			available_upgrade_ids.append(id)
	if screen.visible_catalogue_ids != SupplyDb.UPGRADE_IDS \
			or buy_ids != available_upgrade_ids:
		rig.fail("MVP FAIL Upgrades ids are %s, expected available %s"
			% [buy_ids, available_upgrade_ids])
		return false
	await rig.wait_frames(14)
	await rig.capture(out.path_join("m_05_shop.png"))

	# Walk to the BAG SLOT line -- cheap enough that one run pays for it.
	#
	# By NAME, not by counting presses. Availability and future ladder additions
	# can change a progression board's order, so no fixed count is safe.
	var walked := 0
	while screen.cursor_label() != "BAG SLOT" and walked < screen.line_count():
		# RIGHT is one cell. Down is a whole ROW now that the counter is a grid.
		await rig.tap(["ui_right"])
		await rig.wait_frames(4)
		walked += 1
	if screen.cursor_label() != "BAG SLOT":
		rig.fail("MVP FAIL Upgrades has no BAG SLOT line to buy")
		return false
	var was_gold := Game.gold
	var was_slots := Game.bag_slots
	await rig.tap(["ui_accept"])
	await rig.wait_frames(24)
	print("MVP after_buy gold=%d slots=%d sword=+%d armour=+%d" % [
		Game.gold, Game.bag_slots, Game.sword_bonus(), Game.armour_soak()])
	# This beat used to only PRINT. When the counter became a grid the cursor
	# landed somewhere else, the press bought nothing, and the run went green --
	# the regression was sitting in plain sight in the log for two runs. A beat
	# that names the thing it bought is the difference between a director and a
	# transcript.
	if Game.bag_slots != was_slots + 1 or Game.gold >= was_gold:
		rig.fail("MVP FAIL BAG SLOT did not buy (gold %d -> %d, slots %d -> %d)"
			% [was_gold, Game.gold, was_slots, Game.bag_slots])
		return false
	await rig.capture(out.path_join("m_06_bought.png"))

	await rig.tap(["ui_cancel"])
	await rig.until(func() -> bool: return _screen(rig) == null)
	return true


func _descend(rig) -> bool:
	var garrison := rig.scene() as Garrison

	# Wait for the GATE to actually own the interact button before holding it.
	#
	# This beat was flaky about one run in five, and the failure was expensive
	# out of all proportion: the hold went into the smith's screen while it was
	# still closing, the descent silently did not happen, and every beat after it
	# — the dungeon, the fight, the chest, the rope — then reported a failure it
	# did not cause. Two sessions have now gone hunting the economy for what was
	# a screen that had not finished shutting. A fixed frame count after
	# `ui_cancel` is the wrong instrument; wait for the state you need instead.
	#
	# That lesson is `_approach` now, and the sell and buy beats above -- which
	# had the same bug against the shop triggers rather than against a closing
	# screen -- go through it too.
	if not await _approach(rig, garrison.gate,
			garrison.gate.global_position + Vector3(0.0, 0.0, 1.8)):
		return false
	print("MVP gate focus=%s" % [
		Prompt.focus.prompt if Prompt.focus != null else "<none>"])
	await rig.capture(out.path_join("m_07_gate.png"))

	# The compound gate now opens onto the authored outskirts rather than
	# teleporting through the surface journey.
	await rig.hold_seconds(["interact"], 1.3)
	var reached_outskirts: bool = await rig.until(func() -> bool:
		return rig.scene() is GarrisonOutskirts, 10.0)
	if not reached_outskirts:
		rig.fail("MVP FAIL holding DEPART did not open the outskirts")
		return false
	var outskirts: GarrisonOutskirts = rig.scene() as GarrisonOutskirts
	await rig.wait_frames(30)
	await rig.capture(out.path_join("m_08_outskirts.png"))
	if not await _approach(rig, outskirts.sunken_cut,
			outskirts.sunken_cut.global_position + Vector3(0.0, 0.0, 1.8)):
		return false
	print("MVP cut focus=%s" % [
		Prompt.focus.prompt if Prompt.focus != null else "<none>"])
	await rig.hold_seconds(["interact"], 1.3)
	var arrived: bool = await rig.until(
		func() -> bool: return Run.in_dungeon and _dungeon(rig) != null, 10.0)
	await rig.wait_frames(60)
	print("MVP descended in_dungeon=%s scene=%s" % [
		Run.in_dungeon, rig.scene().name])
	await rig.capture(out.path_join("m_08_arrived.png"))
	if not arrived:
		rig.fail("MVP FAIL holding DESCEND at the Sunken Cut did not open the dungeon")
	return arrived


# --- Dungeon ----------------------------------------------------------------

func _fight(rig) -> bool:
	var dun := _dungeon(rig)
	if dun == null:
		rig.fail("MVP FAIL no dungeon in %s" % rig.scene().name)
		return false
	print("MVP layout rooms=%d deepest=%s seed=%d" % [
		dun.rooms.size(), dun.deepest, Run.seed_used])

	# **Split, because the bare total opened a card that then had to be closed --
	# and then PICKED FROM, because the split was being printed and ignored.**
	# `enemies=24` reads as a crowd and is not one: on floor 1 between ten and
	# fifteen of those bodies are the vault's guards, the boss and the miniboss,
	# each behind a door that cannot be opened on the way past, and the rest are
	# 2-4 per room across six rooms (`Prog.pack(1)`). Issue #42 was opened on the
	# undivided number and closed by measuring the divided one --
	# `tools/directors/floor_crowd.gd` is what measures it, and
	# `docs/BESTIARY.md` §7 is what the split means.
	var split := _split_foes(rig, dun)
	var open: Array = split["walked"]
	var sealed: Array = split["sealed"]
	var foes: Array = split["all"]
	print("MVP enemies=%d (%d in rooms, %d behind a door)" % [
		foes.size(), open.size(), sealed.size()])
	if foes.is_empty():
		rig.fail("MVP FAIL no enemies spawned")
		return false
	# **THE PICK IS FROM THE ROOMS, AND `foes[0]` WAS NOT (#60).**
	#
	# What was measured, because #60 was opened on a guess and the guess was
	# wrong in the reassuring direction. `get_nodes_in_group` answers in TREE
	# ORDER, and the tree order is:
	#
	#   * `Vault` and `MinibossArena` hang off the `Dungeon` itself, not off a
	#     room root, and are built after every room -- so their 12-15 bodies come
	#     LAST in the group, never first;
	#   * the boss's `Arena` IS a child of its room root, and `_build_anchors`
	#     runs before `_populate`, so the boss precedes that room's own pack --
	#     but the arena's room is the DEEPEST one, which lands 3rd to 5th in the
	#     rooms dict, while the first populated room is the 1st or 2nd.
	#
	# So `foes[0]` was a room body on 40 of 40 seeds probed, and this beat has
	# NOT been measuring a vault fight. The card's premise -- "the sealed bodies
	# iterate first on every seed" -- came from `floor_crowd._census`, which
	# PRINTS its sealed tally before its per-room lines; that is a report layout,
	# not an iteration order, and nobody had checked which.
	#
	# The pick is still wrong, and stays fixed, because nothing above is a
	# property anyone maintains: it holds only while the deepest room is never
	# the first populated one and the vault is never parented into a room. Either
	# of those is one anchor-ordering commit away, and the failure it would cause
	# is silent -- the hero teleported inside a sealed vault, with the fight, the
	# drop, the chest and the extraction beats all reporting on a run no player
	# could have had. The diagnosis is printed EVERY run below, so the day the
	# order does change, the log says so instead of going quiet.
	if open.is_empty():
		rig.fail(("MVP FAIL every one of this floor's %d bodies is behind a door"
			+ " (vault / arena / miniboss) -- there is no fight a player could"
			+ " reach here, and fighting a sealed one would measure a run that"
			+ " cannot happen. Refusing to pick.") % foes.size())
		return false
	# CharacterBody3D, not a concrete enemy class. The dungeon spawns only `Enemy`
	# now, but this stays loose on purpose: it used to be typed to the box-built
	# `Crawler`, and the moment the nearest foe was a goblin the assignment threw
	# at runtime and aborted this whole beat SILENTLY -- straight past the fight,
	# the drops and the chest, while the log still ended with a tidy "MVP home".
	# Anything that reaches for a specific enemy class here will break again the
	# next time the roster grows.
	var foe: CharacterBody3D = open[0]
	var owner_of: Dictionary = split["owner_of"]
	print("MVP foe kind=%s in room %s (group head was %s, %s)" % [
		str(foe.get("kind")), owner_of[foe.get_parent()],
		str(foes[0].get("kind")),
		"the same body" if foes[0] == foe else "sealed under %s -- SKIPPED"
			% (foes[0] as Node).get_parent().name])

	# Stand just outside its reach, facing it, so the telegraph is on camera.
	var toward := K.flat(foe.global_position - Vector3.ZERO)
	_stand_at(rig, foe.global_position - toward * 2.2, foe.global_position)
	await rig.wait_frames(30)
	await rig.capture(out.path_join("m_09_enemy.png"))

	var hero: Hero = rig.scene().get_tree().get_first_node_in_group(&"player")
	var before: int = foe.health.quarters
	# Close, then swing until it dies or we run out of patience.
	#
	# **EVERY WAIT IN THIS LOOP IS A GAME-CLOCK WAIT, AND THAT IS ISSUE #14.** It
	# used to press `attack` and then `wait_frames(34)`, a count of RENDERED
	# frames standing in for the length of a sword swing -- and `swing_time` is
	# 0.60 game seconds, 0.99 on the third step of the chain
	# (`HeroCombat.chain_time_scale`). 34 frames is 0.28 s on the 120 Hz Mac this
	# was written on and several seconds on a machine with four other directors
	# rendering: so on a fast tree the next press landed in the FRONT half of the
	# swing that was still running, where `HeroCombat._press` drops it on purpose
	# (a press on the first frame is the player mashing), and eleven of twelve
	# swings went nowhere. That is the log everybody read as "damage is broken":
	# `foe hp 5 -> 1`, one blow's worth of damage out of a dozen presses.
	#
	# So the loop waits for the swing it just asked for: into ATTACK, out of
	# ATTACK, then a beat. `Hero.state` is the public one and `rig.until` now
	# spends its budget in game seconds.
	var taken := 0
	var refused := 0
	for swing in 12:
		# `health.dead` rather than a state enum. The health component is what
		# every hurtable thing in the game shares (docs/CONTRACT.md §8); a state
		# enum is per-class and this beat should not care which class it drew.
		if not is_instance_valid(foe) or foe.health.dead:
			break
		var toe := K.flat(foe.global_position - Vector3.ZERO)
		_stand_at(rig, foe.global_position - toe * 1.1, foe.global_position)
		await rig.wait_physics_frames(2)
		await rig.tap(["attack"])
		# Did the button come out as a swing at all? A refusal is silent by design
		# (`HeroCombat._can_swing` -- an empty stamina bar makes no noise), so a
		# beat that does not ask cannot tell "the sword missed" from "the sword
		# never moved", and those are different bugs in different files.
		if await rig.until(func() -> bool:
				return hero.state == Hero.MoveState.ATTACK, 0.5):
			taken += 1
			await rig.until(func() -> bool:
				return hero.state != Hero.MoveState.ATTACK, 2.5)
			await rig.wait_seconds(0.12)
		else:
			refused += 1
			await rig.wait_seconds(0.35)
	print("MVP swings=%d taken=%d refused=%d stamina=%.0f" % [
		taken + refused, taken, refused, Game.stamina])
	print("MVP foe hp %d -> %s (hero %d/%d)" % [before,
		foe.health.quarters if is_instance_valid(foe) else "dead",
		Game.quarters, Game.max_quarters])
	await rig.capture(out.path_join("m_10_swung.png"))
	# Said in the beat's own words, which is what #14's "done looks like" asked
	# for. Three different things end this loop and they used to look identical.
	if _ended(rig, "during the fight"):
		return false
	if refused > 0:
		rig.fail("MVP FAIL the attack button was refused %d times of %d -- the hero"
			% [refused, taken + refused] + " never entered ATTACK for those presses"
			+ " (stamina=%.0f)" % Game.stamina)
	if is_instance_valid(foe) and not foe.health.dead:
		rig.fail("MVP FAIL %d swings did not kill a %d-quarter %s: it is on %d"
			% [taken, before, str(foe.get("kind")), foe.health.quarters])

	# Patched up HERE, the frame the fight ends, rather than four beats later
	# where it used to be. The reason is unchanged -- see the note below -- but
	# the timing was tuned against monsters that stood where they spawned. Now
	# that they close in, the hero came out of the swing loop on two quarters
	# and died during the WALK to the drop, which emptied the bag, sent Flow to
	# the garrison, and reported "no chest" and "the rope refused to start" for
	# a run that had no chest and no dungeon left. The line above is where the
	# balance signal lives; this is where the cascade gets cut.
	#
	# Not cheating the test -- the opposite. The tour teleports between beats
	# with no regard for what is standing nearby, so the hero routinely arrives
	# at the chest on his last heart and dies. That is `Run.die()` working
	# correctly, but every remaining beat then reports a failure it did not
	# cause. Death has its own proof; this one is about the seams between the
	# screens.
	Game.heal(Game.max_quarters)

	await rig.wait_frames(40)
	var motes := _motes(rig)
	print("MVP motes=%d hero_hp=%d" % [motes.size(), Game.quarters])
	await rig.capture(out.path_join("m_11_drop.png"))

	# Walk onto the drop -- LootMote answers overlap, not a button.
	#
	# On the PHYSICS clock: the pickup is an Area3D noticing a teleported body,
	# which is the one thing rendered frames have never been a unit of, and this
	# is also the window issue #14's hero kept dying in.
	if not motes.is_empty():
		_stand_at(rig, motes[0].global_position)
		await rig.wait_physics_frames(30)
	print("MVP after_pickup bag=%d value=%d" % [Run.bag_count(), Run.bag_value()])
	await rig.capture(out.path_join("m_12_picked_up.png"))
	# **`bag=0 value=0` with a mote on the floor was the whole of #14's tell**, and
	# it took a session to read because nothing said what it meant. `Run.die()` is
	# the only thing that empties a bag mid-floor, so an empty bag here is a run
	# that has already ended -- and the heal two lines up is what made the log say
	# the hero was on 12/12 throughout.
	if _ended(rig, "standing on the drop"):
		return false

	# Topped up again on the way to the chest, for the same reason.
	Game.heal(Game.max_quarters)

	# The chest, which is where the run-defining drops live.
	var chest := _chest(rig)
	if chest == null:
		# Said out loud rather than skipped in silence: a floor whose only chests
		# are unsolved prizes is a floor on which this beat proved nothing, and a
		# reader has to be able to tell that from a beat that passed.
		print("MVP no openable chest on this floor -- every one of them is still a"
			+ " prize waiting on its puzzle. Not a failure; nothing was tested.")
	else:
		print("MVP chest=%s" % chest.name)
		# Through `_approach` for the reason it exists: a chest is an Interactable
		# and being next to one is not being noticed by one.
		if not await _approach(rig, chest,
				chest.global_position + Vector3(0.0, 0.0, 1.3)):
			return false
		await rig.capture(out.path_join("m_13_chest_prompt.png"))
		await rig.tap(["interact"])
		if not await rig.until(func() -> bool: return chest.opened):
			rig.fail("MVP FAIL the chest took the interact button and never opened")
			return false
		await rig.wait_frames(40)
		# **Re-checked every turn, and this is not belt-and-braces.** A `LootMote`
		# frees itself the instant the hero overlaps it, the chest fans its drops
		# 1.15 m apart, and standing on one routinely collects its neighbour too --
		# so the next turn of this loop reads `global_position` off an object that
		# is already gone. That is a hard SCRIPT ERROR, and a SCRIPT ERROR aborts
		# `_fight` outright: the chest opened, the loot went in the bag, and the
		# beat printed neither `MVP after_chest` nor `m_14_chest_loot.png` while
		# reporting no failure at all. It had been doing that for as long as it has
		# existed and nobody could see it, because #36 stopped the run one line
		# earlier on two seeds in three. Same lesson as `_nearest_foe` below.
		for m in _motes(rig):
			if not is_instance_valid(m):
				continue
			_stand_at(rig, m.global_position)
			await rig.wait_frames(18)
		print("MVP after_chest bag=%d value=%d fee=%d" % [
			Run.bag_count(), Run.bag_value(), Run.extract_cost()])
		await rig.capture(out.path_join("m_14_chest_loot.png"))
	return not _ended(rig, "on the way out of the fight beat")


## Leaving. There is no pad to walk to any more -- the way out is the Escape
## Rope, used from the menu, which then channels in the world. This drives the
## rope directly rather than the menu; the menu path is the equip director's
## job, and duplicating it here would only test the same buttons twice.
func _extract(rig) -> void:
	var hero = rig.get_nodes_in_group(&"player")[0]
	var rope: EscapeRope = hero.rope
	if rope == null:
		rig.fail("MVP FAIL the hero is carrying no way out")
		return

	# Break off the fight first. An unblocked hit cancels the channel on purpose
	# (hero.gd, "you do not get to walk out of a fight you are losing"), so this
	# beat has to do what a player does and disengage before using the rope.
	# It did not have to before the monsters chased: they stood where they spawned,
	# the hero channelled in the middle of them, and the beat passed. The first run
	# after the AI landed reported "the rope stopped channelling on its own",
	# which was the game working and the director standing in a mob.
	await _break_off(rig, hero)
	await rig.wait_frames(20)

	# THE POOR CASE, ON PURPOSE. This beat used to leave the purse wherever the
	# fight had left it, which meant it exercised the expensive exit only on the
	# seeds that happened to roll a rich bag -- and on exactly those seeds it
	# failed, because the rope refused and the run had nowhere to go. Two things
	# were wrong with that: the dead end (fixed -- the fee is capped at the purse),
	# and a director that tested the interesting half of its own beat by luck.
	#
	# One gold under the toll is the sharpest version: the cap has to bite, the
	# charge has to be the whole purse, and he has to reach the receipt at zero.
	var toll := Run.extract_cost()
	if Game.gold > toll - 1:
		Game.spend_gold(Game.gold - (toll - 1))
	var purse := Game.gold
	print("MVP pre_extract gold=%d toll=%d charge=%d value=%d" % [
		purse, toll, Run.extract_charge(), Run.bag_value()])
	if Run.extract_charge() != purse:
		rig.fail("MVP FAIL the fee was not capped at the purse (toll=%d gold=%d charge=%d)"
			% [toll, purse, Run.extract_charge()])

	# Shot AFTER the purse is spent down, which is the whole point of the frame:
	# it is the only capture in the suite that shows the HUD in the state this
	# beat exists for. There is no EXTRACT line to photograph any more -- the
	# standing readout is gone (`Hud._draw_extraction`) -- so what this frame is
	# now proving is the SWEEP, which is the whole announcement that remains.
	# A wait, because `set_extract_dear` rides `gold_changed` and the sweep it
	# fires needs frames to be worth photographing.
	await rig.wait_frames(20)
	await rig.capture(out.path_join("m_15_before_rope.png"))

	if not rope.begin():
		# begin() has two refusals left and they mean different things: already
		# channelling, or not underground. "Too poor" was the third and is gone --
		# printing only gold and the fee named the one cause that was almost never
		# the real one, and sent a session hunting the economy for a state bug.
		rig.fail("MVP FAIL the rope refused to start (gold=%d toll=%d in_dungeon=%s active=%s)"
			% [Game.gold, toll, Run.in_dungeon, rope.active()])
		return

	# Caught mid-channel, so the ring is closing and the column of light is
	# halfway up him rather than absent or finished.
	await rig.wait_seconds(EscapeRope.CHANNEL_TIME * 0.5)
	if not rope.active():
		rig.fail("MVP FAIL the rope stopped channelling on its own")
	await rig.capture(out.path_join("m_16_channelling.png"))

	await rig.wait_seconds(EscapeRope.CHANNEL_TIME)
	await rig.wait_frames(30)
	if Run.in_dungeon:
		rig.fail("MVP FAIL the rope finished and he is still underground")
	# The purse is the proof the cap actually charged rather than merely allowed.
	# He went in one gold short of the toll, so he comes out at nothing -- and the
	# receipt has to say the same number, because the receipt is what the player
	# reads and a fee that disagrees with the purse is the bug this beat exists for.
	print("MVP post_extract gold=%d fee_on_receipt=%d" % [
		Game.gold, int(Run.summary.get("fee", -1))])
	if Game.gold != 0:
		rig.fail("MVP FAIL the whole purse should have gone to the toll (gold=%d, was %d)"
			% [Game.gold, purse])
	if int(Run.summary.get("fee", -1)) != purse:
		rig.fail("MVP FAIL the receipt names a fee the purse did not pay (fee=%d purse=%d)"
			% [int(Run.summary.get("fee", -1)), purse])
	await rig.capture(out.path_join("m_17_extracting.png"))


## The receipt, and then the ride home.
##
## The rope no longer lands you in the garrison by itself: a run now ends on the
## floor it ended on, under `RunEndScreen`, and BACK TO THE GARRISON is the press
## that goes home (scripts/ui/run_end/). This beat used to be a wait and a
## capture, and after the screen landed it still passed -- while photographing
## the ending screen into `m_18_home.png` and printing "MVP home
## scene=DungeonRun". A beat that asserts nothing cannot notice that it has
## stopped testing the thing in its name.
func _return(rig) -> void:
	await rig.wait_frames(150)
	var screen := _run_end(rig)
	print("MVP receipt screen=%s paused=%s kills=%d" % [
		screen != null, rig.paused, int(Run.summary.get("kills", -1))])
	if screen == null:
		rig.fail("MVP FAIL no ending screen after the rope")
		return
	await rig.capture(out.path_join("m_18_receipt.png"))

	await rig.wait_seconds(RunEndScreen.SETTLE + 0.2)
	await rig.hold_seconds([&"ui_accept"], 0.2)
	await rig.wait_frames(240)

	print("MVP home scene=%s in_dungeon=%s gold=%d bag=%d hearts=%d/%d" % [
		rig.scene().name, Run.in_dungeon, Game.gold, Run.bag_value(),
		Game.quarters, Game.max_quarters])
	if rig.scene() is not Garrison:
		rig.fail("MVP FAIL BACK TO THE GARRISON did not reach the garrison (scene=%s)" % rig.scene().name)
	if rig.paused:
		rig.fail("MVP FAIL the tree is still paused in the garrison")
	await rig.capture(out.path_join("m_19_home.png"))


func _run_end(rig) -> RunEndScreen:
	for n in _walk(rig.scene()):
		if n is RunEndScreen:
			return n
	return null


func _walk(root: Node) -> Array:
	var found := [root]
	for c in root.get_children():
		found.append_array(_walk(c))
	return found


# --- Helpers ----------------------------------------------------------------

## Every body in the `enemy` group, split by whether a player could ever reach it.
##
## Returns `{"all", "walked", "sealed", "owner_of"}` -- the group verbatim, the
## bodies parented to a ROOM ROOT, the bodies parented to anything else, and the
## room-root -> cell map the attribution is made through.
##
## **Parentage, not position, and that is the whole of the attribution.**
## `Dungeon._spawn_foe` parents every room body to `rooms[cell]["node"]`, so this
## is the generator's own answer to "whose is it". A body that has walked out into
## the corridor is still its room's; attributing it by where it stands would let a
## conga line read as a tidy census, and would let a vault guard that happened to
## stand near a doorway read as walkable. `floor_crowd._census` makes the same
## call for the same reason -- these two are the only places in the repo that
## divide this group, and they must agree.
##
## Anything NOT under a room root belongs to something the generator built beside
## the room tree: the vault (`Vault`), the boss's `Arena`, the miniboss's
## `MinibossArena`. Every one of those is behind a door the player cannot open on
## the way past (`docs/BESTIARY.md` §7), and every one of them is nevertheless in
## the `enemy` group.
func _split_foes(rig, dun: Dungeon) -> Dictionary:
	var owner_of: Dictionary = {}
	for cell: Vector2i in dun.rooms:
		var node: Node = dun.rooms[cell].get("node")
		if node != null:
			owner_of[node] = cell
	var all: Array = rig.scene().get_tree().get_nodes_in_group(&"enemy")
	var walked: Array = []
	var sealed: Array = []
	for e in all:
		if owner_of.has((e as Node).get_parent()):
			walked.append(e)
		else:
			sealed.append(e)
	return {"all": all, "walked": walked, "sealed": sealed, "owner_of": owner_of}


## Walk out of the fight and wait for the pack to lose interest.
##
## Uses the leash rather than deleting anything: monsters give up and go home
## when the hero gets far enough away, and a beat that despawned the room to get
## a clean channel would pass just as happily on a build where they never gave
## up at all.
func _break_off(rig, hero: Hero) -> void:
	var foes: Array = rig.get_nodes_in_group(&"enemy")
	if foes.is_empty():
		return

	# The emptiest ROOM on the floor, not an offset off somebody's position: a
	# hero moved 24 m along an axis lands in the void outside the map as often as
	# not, and a hero standing in the void is not a hero who walked away.
	var dun := _dungeon(rig)
	if dun == null:
		return
	var away := hero.global_position
	var best := -1.0
	for cell: Vector2i in dun.rooms:
		var spot := dun.centre_of(cell)
		var gap := _nearest_foe(rig, spot)
		if gap > best:
			best = gap
			away = spot
	hero.global_position = Vector3(away.x, 0.05, away.z)

	# Long enough for the leash to run: they walk home at a little over half
	# speed, so this is a slow beat by design.
	await rig.wait_frames(120)
	var gap := _nearest_foe(rig, hero.global_position)
	print("MVP broke off, nearest monster %.1f m" % gap)
	if gap < 6.0:
		rig.fail("MVP FAIL could not disengage: a monster is still %.1f m away with"
			% gap + " the hero in the far corner of the floor -- the leash is not"
			+ " letting go, and nothing in the dungeon can be walked away from")


## Distance to the nearest LIVE monster, asked of the GROUP and not of a snapshot.
##
## The loop variable is deliberately UNTYPED. `for f: Node3D in foes` assigns each
## element to a typed local BEFORE the body runs, and assigning a freed instance is
## a hard SCRIPT ERROR that aborts the whole function -- so it returns 0.0, the
## default for its return type, and `is_instance_valid` never gets a body to guard.
## That 0.0 lies twice: every room reads as equally awful, so `_break_off` keeps
## `rooms[0]` and teleports the hero into the pack he was leaving, and the final
## measurement then reports "a monster is standing on top of you" for a skeleton he
## killed forty seconds earlier. It only bit when that corpse happened to be
## collected before this ran, which is why the beat looked flaky rather than broken.
##
## Re-fetched from the group each call rather than handed a snapshot, which is the
## second half of the same bug: a list taken before the fight has the corpse in it
## by definition, and misses anything that spawned since.
func _nearest_foe(rig, at: Vector3) -> float:
	var best := 1e9
	for f in rig.get_nodes_in_group(&"enemy"):
		if not is_instance_valid(f):
			continue
		var n := f as Node3D
		if n == null:
			continue
		best = minf(best, K.plane(n.global_position - at).length())
	return best


## Put the hero on a spot, optionally facing something.
##
## Facing is not cosmetic here: the sword's arc test rejects anything outside
## `arc_degrees` of the hero's forward, so a hero teleported next to a monster
## while still facing his spawn direction swings through empty air forever --
## which reads in the log exactly like "damage is broken".
## Walk up to `it` and wait until it actually owns the interact button.
##
## **This is the only correct way for this director to arrive anywhere it intends
## to press a button.** Standing next to an Interactable is not the same event as
## being NOTICED by one: `Interactable.player_inside` is set from an Area3D's
## `body_entered`, which lands about two PHYSICS ticks after a teleport, and
## `Prompt` only takes focus on the frame after that.
##
## The beat this replaces waited 20 rendered frames and pressed. That was the
## flake -- roughly one run in four on some machines, none at all on others, and
## the reason for the difference is the whole lesson: rendered frames and physics
## ticks are two different clocks, and their ratio belongs to the panel. 20 frames
## is ~10 physics ticks on the 120 Hz Mac this was written on and ~2 on a machine
## rendering twice as fast, and two is exactly the margin the trigger needs. The
## gate beat below had already learned this once (see `_descend`); the sell and
## buy beats had not, and they are the ones that broke.
##
## Returns false, having said why, when the prompt never arrives. The caller is
## expected to STOP -- see `run`.
func _approach(rig, it: Interactable, at: Vector3, look_at = null) -> bool:
	_stand_at(rig, at, look_at)
	var seen: bool = await rig.until(func() -> bool: return Prompt.focus == it)
	if not seen:
		# **Say "he died" when he died — and only then.** A hero killed on the walk
		# over is freed, so `Prompt._nearest` has no hero to measure from and takes
		# focus off everything -- while `player_inside` stays true, because
		# `body_exited` never fires for a body that was deleted rather than moved.
		# The generic line below then reads as "the chest is broken" for a run that
		# simply ended, and two of the four runs that produced it were spent looking
		# at `Interactable` instead of at the health bar.
		#
		# **THREE CAUSES, THREE LINES, AND THAT IS THE POINT (#14).** This branch
		# used to be one `if` over `no player node OR not Run.in_dungeon` printing
		# "the hero died" for both -- so a prompt that failed in the GARRISON, where
		# `_sell` sets `in_dungeon = false` on purpose, reported a death that had not
		# happened and sent the card's first reader to the health bar. `Game.deaths`
		# is the only one of the three that actually means somebody died.
		if Game.deaths > _deaths:
			rig.fail(("MVP FAIL the hero died before he reached %s -- deaths %d -> %d,"
				+ " and the run ended with him") % [it.prompt, _deaths, Game.deaths])
			return false
		if rig.scene().get_tree().get_first_node_in_group(&"player") == null:
			rig.fail(("MVP FAIL there is no hero in the scene at all while waiting on"
				+ " %s -- nobody died (deaths=%d), the player node is simply gone")
				% [it.prompt, Game.deaths])
			return false
		# **`enabled` is in this line because its absence cost #36 a session.**
		# The three facts printed before it — focus, inside, blocked — were the
		# three that `Prompt._nearest` does NOT gate on in the failing case, so the
		# report read "the hero is standing in it, nothing is refusing, and the
		# prompt never came" and sent two readers into `Prompt`. `enabled` is the
		# fourth term of the same `if`, and it was the false one. Print every term
		# of the condition you are complaining about.
		rig.fail(("MVP FAIL %s never took the interact button after three seconds of"
			+ " GAME TIME standing in front of it (focus=%s, inside=%s, enabled=%s,"
			+ " blocked=%s, in_dungeon=%s)") % [
			it.prompt, Prompt.focus.prompt if Prompt.focus != null else "<none>",
			it.player_inside, it.enabled, Prompt.blocked, Run.in_dungeon])
		return false
	# One more physics tick before the press. Focus is live the frame the trigger
	# reports the hero, and `Prompt.drop_focus` DISARMS on that same frame -- so a
	# press issued in it is swallowed and the hold can never begin.
	await rig.wait_physics_frames(2)
	return true


func _stand_at(rig, at: Vector3, look_at = null) -> void:
	var hero: Hero = rig.scene().get_tree().get_first_node_in_group(&"player")
	if hero == null:
		return
	hero.global_position = Vector3(at.x, 0.05, at.z)
	if look_at != null:
		var to := K.flat(look_at - hero.global_position)
		if to != Vector3.ZERO:
			hero.facing_yaw = atan2(to.x, to.z)
			hero.rotation.y = hero.facing_yaw + PI


func _screen(rig) -> TradeScreen:
	for n in _all(rig.scene()):
		if n is TradeScreen:
			return n
	return null


func _dungeon(rig) -> Dungeon:
	for n in _all(rig.scene()):
		if n is Dungeon:
			return n
	return null


## A chest the player could actually walk up to and open.
##
## **`enabled` IS HALF THE QUESTION AND LEAVING IT OUT WAS #36.** Three of the
## floor's chests are prizes that do not exist yet: the gate room's, the maze's
## and the shortcut landing's are each built up-front with `visible = false` and
## `enabled = false`, and land only when the puzzle they belong to is solved
## (`Dungeon._land_prize`). This used to take the first unopened `Chest` in TREE
## ORDER — and on any floor that rolled one of those three, tree order handed
## back an invisible box that `Prompt._nearest` is right to skip. The beat then
## teleported the hero into it and printed `MVP FAIL OPEN ... (inside=true,
## blocked=false)`, which reads as a broken prompt system and is a game working
## exactly as designed. Two seeds in three, for as long as the beat existed.
##
## `visible` as well as `enabled`, because the three sites set them together and
## a chest that answered the button while being invisible would be a different
## bug — one this beat should notice rather than photograph its way past.
func _chest(rig) -> Chest:
	for n in _all(rig.scene()):
		if n is Chest and not n.opened and n.enabled and n.visible:
			return n
	return null


func _motes(rig) -> Array:
	var found := []
	for n in _all(rig.scene()):
		if n is LootMote:
			found.append(n)
	return found


func _all(root: Node) -> Array:
	var found := [root]
	for c in root.get_children():
		found.append_array(_all(c))
	return found
