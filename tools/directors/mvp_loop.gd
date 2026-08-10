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
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/mvp_loop.gd --out=/tmp/mvp/x.png

var out := ""


func run(rig) -> void:
	out = rig.arg("out", "/tmp/mvp/x.png").get_base_dir()
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
		print("MVP ABORT the sell beat did not happen -- stopping rather than"
			+ " reporting four failures it would have caused")
		return
	if not await _buy(rig):
		print("MVP ABORT the buy beat did not happen -- stopping rather than"
			+ " reporting four failures it would have caused")
		return
	if not await _descend(rig):
		print("MVP ABORT never got underground -- stopping rather than reporting"
			+ " the dungeon, the fight and the rope as broken from up here")
		return

	await _fight(rig)
	await _extract(rig)
	await _return(rig)


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
		print("MVP FAIL the vendor would not offer to trade")
		return false
	# The screen is a state, not a frame count: `TradeScreen` is built inside
	# `Npc._choose_trade` and is up on the next frame, but a beat that assumed so
	# would be making the same mistake one layer along.
	var opened: bool = await rig.until(func() -> bool: return _screen(rig) != null)
	if not opened:
		print("MVP FAIL the vendor took the press and no shop screen came up")
		return false
	await rig.wait_frames(14)
	await rig.capture(out.path_join("m_02_sell_screen.png"))

	# Take the top line, then everything else.
	await rig.tap(["ui_accept"])
	await rig.wait_frames(20)
	await rig.capture(out.path_join("m_03_sold_one.png"))

	var screen := _screen(rig)
	if screen != null:
		screen._cursor = screen._rows.size() - 1
		screen.queue_redraw()

	# SELL EVERYTHING is a HOLD (`TradeScreen._hold_time`): one press should not
	# be able to empty the bag, and the row draws a gauge saying so. A tap first,
	# because a beat that only holds would pass with the hold deleted.
	await rig.tap(["ui_accept"])
	await rig.wait_frames(12)
	if Run.bag_value() == 0:
		print("MVP FAIL a tap emptied the bag -- SELL EVERYTHING is meant to be held")
	# Held in game seconds. A frame count is a duration of unknown length and the
	# gauge advances by `delta` (see `rig.hold_seconds`).
	await rig.hold_seconds(["ui_accept"], 0.9)
	await rig.wait_frames(24)
	var emptied := Run.bag_value() == 0
	if not emptied:
		print("MVP FAIL holding SELL EVERYTHING did not empty the bag (%d left)"
			% Run.bag_value())
	print("MVP after_sell gold=%d bag=%d" % [Game.gold, Run.bag_value()])
	await rig.capture(out.path_join("m_04_sold_all.png"))

	await rig.tap(["ui_cancel"])
	# The close is a state too, and it is the one that bit the gate beat: a hold
	# that lands while the screen is still shutting goes into the screen.
	await rig.until(func() -> bool: return _screen(rig) == null)
	return emptied


func _buy(rig) -> bool:
	var garrison := rig.scene() as Garrison
	if not await _approach(rig, garrison.smith,
			garrison.smith.global_position + Vector3(0.0, 0.0, 1.6)):
		return false
	await rig.tap(["interact"])
	if not await rig.talk("Trade"):
		print("MVP FAIL the smith would not offer to trade")
		return false
	var opened: bool = await rig.until(func() -> bool: return _screen(rig) != null)
	if not opened:
		print("MVP FAIL the smith took the press and no shop screen came up")
		return false
	await rig.wait_frames(14)
	await rig.capture(out.path_join("m_05_shop.png"))

	# Walk to the BAG SLOT line -- cheap enough that one run pays for it.
	#
	# By NAME, not by counting presses. This beat used to tap down once, on the
	# strength of a comment saying the bag slot was the second line. It is not:
	# the smith hides ARROWS until you own a bow, so on this save the bag slot is
	# the FIRST line and one press walked past it onto the heart container. The
	# board's length is a function of what you own, so no fixed count is safe.
	var screen := _screen(rig)
	var walked := 0
	while screen.cursor_label() != "BAG SLOT" and walked < screen.line_count():
		# RIGHT is one cell. Down is a whole ROW now that the counter is a grid.
		await rig.tap(["ui_right"])
		await rig.wait_frames(4)
		walked += 1
	if screen.cursor_label() != "BAG SLOT":
		print("MVP FAIL the smith has no BAG SLOT line to buy")
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
		print("MVP FAIL BAG SLOT did not buy (gold %d -> %d, slots %d -> %d)"
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

	# The gate is a 0.9 s hold, so tapping must NOT open it. Holding must.
	await rig.hold_seconds(["interact"], 1.3)
	var arrived: bool = await rig.until(
		func() -> bool: return Run.in_dungeon and _dungeon(rig) != null, 10.0)
	await rig.wait_frames(60)
	print("MVP descended in_dungeon=%s scene=%s" % [
		Run.in_dungeon, rig.scene().name])
	await rig.capture(out.path_join("m_08_arrived.png"))
	if not arrived:
		print("MVP FAIL holding DESCEND for 1.3 s did not open the gate")
	return arrived


# --- Dungeon ----------------------------------------------------------------

func _fight(rig) -> void:
	var dun := _dungeon(rig)
	if dun == null:
		print("MVP FAIL no dungeon in %s" % rig.scene().name)
		return
	print("MVP layout rooms=%d deepest=%s seed=%d" % [
		dun.rooms.size(), dun.deepest, Run.seed_used])

	var foes: Array = rig.scene().get_tree().get_nodes_in_group(&"enemy")
	print("MVP enemies=%d" % foes.size())
	if foes.is_empty():
		print("MVP FAIL no enemies spawned")
		return
	# CharacterBody3D, not a concrete enemy class. The dungeon spawns only `Enemy`
	# now, but this stays loose on purpose: it used to be typed to the box-built
	# `Crawler`, and the moment the nearest foe was a goblin the assignment threw
	# at runtime and aborted this whole beat SILENTLY -- straight past the fight,
	# the drops and the chest, while the log still ended with a tidy "MVP home".
	# Anything that reaches for a specific enemy class here will break again the
	# next time the roster grows.
	var foe: CharacterBody3D = foes[0]
	print("MVP foe kind=%s" % str(foe.get("kind")))

	# Stand just outside its reach, facing it, so the telegraph is on camera.
	var toward := K.flat(foe.global_position - Vector3.ZERO)
	_stand_at(rig, foe.global_position - toward * 2.2, foe.global_position)
	await rig.wait_frames(30)
	await rig.capture(out.path_join("m_09_enemy.png"))

	var before: int = foe.health.quarters
	# Close, then swing until it dies or we run out of patience.
	for swing in 12:
		# `health.dead` rather than a state enum. The health component is what
		# every hurtable thing in the game shares (docs/CONTRACT.md §8); a state
		# enum is per-class and this beat should not care which class it drew.
		if not is_instance_valid(foe) or foe.health.dead:
			break
		var toe := K.flat(foe.global_position - Vector3.ZERO)
		_stand_at(rig, foe.global_position - toe * 1.1, foe.global_position)
		await rig.wait_frames(2)
		await rig.tap(["attack"])
		await rig.wait_frames(34)
	print("MVP foe hp %d -> %s (hero %d/%d)" % [before,
		foe.health.quarters if is_instance_valid(foe) else "dead",
		Game.quarters, Game.max_quarters])
	await rig.capture(out.path_join("m_10_swung.png"))

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
	if not motes.is_empty():
		_stand_at(rig, motes[0].global_position)
		await rig.wait_frames(30)
	print("MVP after_pickup bag=%d value=%d" % [Run.bag_count(), Run.bag_value()])
	await rig.capture(out.path_join("m_12_picked_up.png"))

	# Topped up again on the way to the chest, for the same reason.
	Game.heal(Game.max_quarters)

	# The chest, which is where the run-defining drops live.
	var chest := _chest(rig)
	if chest != null:
		# Through `_approach` for the reason it exists: a chest is an Interactable
		# and being next to one is not being noticed by one.
		if not await _approach(rig, chest,
				chest.global_position + Vector3(0.0, 0.0, 1.3)):
			return
		await rig.capture(out.path_join("m_13_chest_prompt.png"))
		await rig.tap(["interact"])
		await rig.until(func() -> bool: return chest.opened)
		await rig.wait_frames(40)
		for m in _motes(rig):
			_stand_at(rig, m.global_position)
			await rig.wait_frames(18)
		print("MVP after_chest bag=%d value=%d fee=%d" % [
			Run.bag_count(), Run.bag_value(), Run.extract_cost()])
		await rig.capture(out.path_join("m_14_chest_loot.png"))


## Leaving. There is no pad to walk to any more -- the way out is the Escape
## Rope, used from the menu, which then channels in the world. This drives the
## rope directly rather than the menu; the menu path is the equip director's
## job, and duplicating it here would only test the same buttons twice.
func _extract(rig) -> void:
	var hero = rig.get_nodes_in_group(&"player")[0]
	var rope: EscapeRope = hero.rope
	if rope == null:
		print("MVP FAIL the hero is carrying no way out")
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
		print("MVP FAIL the fee was not capped at the purse (toll=%d gold=%d charge=%d)"
			% [toll, purse, Run.extract_charge()])

	# Shot AFTER the purse is spent down, which is the whole point of the frame:
	# it is the only capture in the suite that shows the HUD in the state this
	# beat exists for -- EXTRACT in RUST, naming the charge rather than the toll.
	# A wait, because `set_extract_dear` rides `gold_changed` and the sweep it
	# fires needs frames to be worth photographing.
	await rig.wait_frames(20)
	await rig.capture(out.path_join("m_15_before_rope.png"))

	if not rope.begin():
		# begin() has two refusals left and they mean different things: already
		# channelling, or not underground. "Too poor" was the third and is gone --
		# printing only gold and the fee named the one cause that was almost never
		# the real one, and sent a session hunting the economy for a state bug.
		print("MVP FAIL the rope refused to start (gold=%d toll=%d in_dungeon=%s active=%s)"
			% [Game.gold, toll, Run.in_dungeon, rope.active()])
		return

	# Caught mid-channel, so the ring is closing and the column of light is
	# halfway up him rather than absent or finished.
	await rig.wait_seconds(EscapeRope.CHANNEL_TIME * 0.5)
	if not rope.active():
		print("MVP FAIL the rope stopped channelling on its own")
	await rig.capture(out.path_join("m_16_channelling.png"))

	await rig.wait_seconds(EscapeRope.CHANNEL_TIME)
	await rig.wait_frames(30)
	if Run.in_dungeon:
		print("MVP FAIL the rope finished and he is still underground")
	# The purse is the proof the cap actually charged rather than merely allowed.
	# He went in one gold short of the toll, so he comes out at nothing -- and the
	# receipt has to say the same number, because the receipt is what the player
	# reads and a fee that disagrees with the purse is the bug this beat exists for.
	print("MVP post_extract gold=%d fee_on_receipt=%d" % [
		Game.gold, int(Run.summary.get("fee", -1))])
	if Game.gold != 0:
		print("MVP FAIL the whole purse should have gone to the toll (gold=%d, was %d)"
			% [Game.gold, purse])
	if int(Run.summary.get("fee", -1)) != purse:
		print("MVP FAIL the receipt names a fee the purse did not pay (fee=%d purse=%d)"
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
		print("MVP FAIL no ending screen after the rope")
		return
	await rig.capture(out.path_join("m_18_receipt.png"))

	await rig.wait_seconds(RunEndScreen.SETTLE + 0.2)
	await rig.hold_seconds([&"ui_accept"], 0.2)
	await rig.wait_frames(240)

	print("MVP home scene=%s in_dungeon=%s gold=%d bag=%d hearts=%d/%d" % [
		rig.scene().name, Run.in_dungeon, Game.gold, Run.bag_value(),
		Game.quarters, Game.max_quarters])
	if rig.scene() is not Garrison:
		print("MVP FAIL BACK TO THE GARRISON did not reach the garrison (scene=%s)" % rig.scene().name)
	if rig.paused:
		print("MVP FAIL the tree is still paused in the garrison")
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
		print("MVP FAIL could not disengage: a monster is still %.1f m away with"
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
		print(("MVP FAIL %s never took the interact button after three seconds"
			+ " standing in front of it (focus=%s, inside=%s, blocked=%s)") % [
			it.prompt, Prompt.focus.prompt if Prompt.focus != null else "<none>",
			it.player_inside, Prompt.blocked])
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


func _chest(rig) -> Chest:
	for n in _all(rig.scene()):
		if n is Chest and not n.opened:
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
