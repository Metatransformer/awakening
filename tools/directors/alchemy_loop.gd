extends RefCounted
## The alchemist, end to end: glass off a body becomes a draught you drink.
##
## Point it at TOWN. It descends on its own, because half the claims here are
## about what reaches the bench and you cannot test that from one side of it.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/town.tscn \
##     --director=res://tools/directors/alchemy_loop.gd \
##     --out=/tmp/alchemy/x.png --warmup=60
##
## What it claims, in the order it proves them:
##
##   A  The materials are in the catalogue, on the drop tables, and marked for
##      the alchemist rather than the forge.
##   B  She stands in town, she is addressable, and her board is four lines.
##   C  Gold alone will not buy a draught, and the refusal names what is short.
##   D  A brew costs gold AND materials, and lands IN a bottle.
##   E  With every bottle full, brewing is refused for the right reason.
##   F  Blowing a bottle raises the ceiling, and the ceiling is K.BOTTLE_MAX.
##   G  A bottle binds to a D-pad button, and the PRESS DRINKS IT -- health goes
##      up, the bottle empties, and the lasting draughts move the numbers the
##      gear reads.
##   H  Materials are swept off the dungeon floor with no button pressed, and
##      extraction banks them.
##   I  Bottles and their contents survive quitting the game.
##
## G is the one that matters. Everything else is bookkeeping; G is the claim
## that the money bought something the player can feel, and it is checked
## against `Game.sword_bonus()` / `armour_soak()` -- the accessors the sword and
## the hero's own `hurt` read -- rather than against a counter, because a potion
## that set a flag and changed no behaviour is exactly the bug a "buff" system
## produces.

var out := ""
var _fails := 0


func run(rig) -> void:
	out = rig.arg("out", "/tmp/alchemy/x.png").get_base_dir()
	# A tripwire, not a check. Three beats in a row drive one trade screen, and
	# the run where it vanished between two of them reported five failures in a
	# beat two functions later. If it ever closes when this director did not
	# close it, the line below is the one that says when.
	Bus.screen_closed.connect(func(what: StringName) -> void:
		print("ALCHEMY note: %s closed" % what))
	await rig.wait_frames(20)

	_catalogue()
	await _counter(rig)
	await _brew(rig)
	await _bottles(rig)
	await _bind(rig)
	await _screens(rig)
	await _drink(rig)
	await _underground(rig)
	await _save(rig)

	if _fails == 0:
		print("ALCHEMY OK")
	else:
		print("ALCHEMY FAIL -- %d check(s) failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_fails += 1
		print("ALCHEMY FAIL %s" % label)


# --- A. The catalogue -------------------------------------------------------

func _catalogue() -> void:
	var mats := ItemDb.components(ItemDef.BENCH_ALCHEMY)
	print("ALCHEMY materials=%s" % [mats])
	_ck("A0 four materials exist", mats.size() == 4)
	for id in mats:
		var def := ItemDb.get_def(id)
		_ck("A1 %s is a component the vendor will not take" % id,
			def != null and def.is_component())
		_ck("A2 %s is marked for the alchemist" % id,
			def != null and def.bench == ItemDef.BENCH_ALCHEMY)
		_ck("A3 %s drops from chests" % id, ItemDb.CHEST_DROPS.has(id))
	# Glass has to fall off bodies or the first bottle is a lottery; the dew must
	# NOT, or the fourth one is a grind. Same shape as the Cold Iron Core's rule
	# in forge_loop.gd, and asserted here for the same reason.
	_ck("A4 glass falls off bodies", ItemDb.ENEMY_DROPS.has(&"fired_cullet"))
	_ck("A5 mourning dew is chests-only",
		not ItemDb.ENEMY_DROPS.has(&"mourning_dew"))
	# Two benches, one workbench, no id in both -- a material both counters ate
	# would be a hidden competition the screens never mention.
	var forge := ItemDb.components(ItemDef.BENCH_FORGE)
	var overlap := false
	for id in mats:
		if forge.has(id):
			overlap = true
	_ck("A6 the two benches want different things", not overlap)
	# The recipe column prints `code()`, which is the LAST WORD of the name. Two
	# materials ending in the same word would draw two rows that read identically.
	var codes := {}
	for id in ItemDb.components():
		var c := ItemDb.get_def(id).code()
		_ck("A7 %s's recipe code (%s) is unique" % [id, c], not codes.has(c))
		codes[c] = true


# --- B and C. The counter ---------------------------------------------------

func _counter(rig) -> void:
	var town := rig.scene() as Town
	_ck("B0 the alchemist is in town", town.alchemist != null)
	if town.alchemist == null:
		return
	# Addressed the way a player addresses her: walk up, and press the button the
	# prompt names. Calling `activate()` directly would prove the screen opens and
	# nothing about whether she can be reached.
	_stand_at(rig, town.alchemist.global_position + Vector3(0.0, 0.0, 1.6))
	await rig.wait_frames(20)
	for _i in 60:
		if Prompt.focus == town.alchemist:
			break
		await rig.wait_frames(2)
	_ck("B1 she owns the interact button", Prompt.focus == town.alchemist)
	await rig.tap(["interact"])
	await rig.wait_frames(16)

	var screen := _screen(rig)
	if screen == null:
		print("ALCHEMY FAIL the alchemist did not open")
		_fails += 1
		return
	_ck("B2 her board is the bottle and three draughts",
		screen._rows.size() == 1 + PotionDb.IDS.size())
	_ck("B3 it is HER catalogue, not the smith's", screen.catalogue == AlchemyDb)

	# --- C. Refused, with the right reason ------------------------------------
	Game.gold = 40000
	Game.components.clear()
	screen._refresh()
	var heart := _row(screen, &"heart_draught")
	_ck("C0 the heart draught is on the board", not heart.is_empty())
	if heart.is_empty():
		return
	_ck("C1 it names a material cost", not (heart["parts"] as Dictionary).is_empty())
	_ck("C2 gold alone cannot buy it", not AlchemyDb.can_buy(heart["line"]))
	_ck("C3 the refusal names the root, not the money (%s)"
		% AlchemyDb.refusal(heart["line"]),
		AlchemyDb.refusal(heart["line"]).contains("ROOT"))
	screen._cursor = screen._rows.find(heart)
	screen._commit()
	await rig.wait_frames(12)
	_ck("C4 the press changed nothing", Game.bottle(0) == &"")
	await rig.capture(out.path_join("a_00_short.png"))


# --- D and E. Brewing -------------------------------------------------------

func _brew(rig) -> void:
	var screen := _counter_screen(rig, "the brew beat")
	if screen == null:
		return
	for id in ItemDb.components(ItemDef.BENCH_ALCHEMY):
		Game.add_component(id, 40)
	screen._refresh()

	# Snapshot the bench BEFORE the six idle frames the capture needs, and again
	# after, and say so if they differ.
	#
	# Those six frames are six frames of live input on an open shop. A run once
	# came back with "the brew took no gold" for a brew whose gold had already
	# gone -- the row under the cursor had been bought during the wait, so the
	# snapshot taken after it was of a bench that had already paid. Reading only
	# after the wait hides that; reading only before it makes the failure pass.
	# Reading both turns an invisible race into a named failure.
	var settled := {"gold": Game.gold, "root": Game.component_count(&"bitter_root"),
		"bottles": Game.bottle_count(), "empties": Game.empty_bottles()}

	await rig.wait_frames(6)
	await rig.capture(out.path_join("a_01_board.png"))

	var gold_before := Game.gold
	var root_before := Game.component_count(&"bitter_root")
	_ck("D0a nothing bought itself while the board was drawn (%s -> %d/%d)" % [
		settled, Game.gold, Game.component_count(&"bitter_root")],
		gold_before == settled["gold"] and root_before == settled["root"]
			and Game.bottle_count() == settled["bottles"]
			and Game.empty_bottles() == settled["empties"])
	_ck("D0 he starts with one empty bottle",
		Game.bottle_count() == K.BOTTLE_START and Game.empty_bottles() == 1)

	var heart := _row(screen, &"heart_draught")
	if heart.is_empty():
		_ck("D1 the draught is in the bottle", false)
		return
	screen._cursor = screen._rows.find(heart)
	screen._commit()
	await rig.wait_frames(10)
	print("ALCHEMY brewed bottles=%s gold=%d -> %d root=%d -> %d" % [
		Game.bottle_contents, gold_before, Game.gold,
		root_before, Game.component_count(&"bitter_root")])
	_ck("D1 the draught is in the bottle", Game.bottle(0) == &"heart_draught")
	_ck("D2 it took gold", Game.gold < gold_before)
	_ck("D3 it took the root as well", Game.component_count(&"bitter_root") < root_before)

	# --- E. Nowhere to put the next one ---------------------------------------
	screen._refresh()
	var again := _row(screen, &"heart_draught")
	_ck("E0 with the only bottle full, brewing is refused",
		not AlchemyDb.can_buy(again["line"]))
	_ck("E1 the refusal says so (%s)" % AlchemyDb.refusal(again["line"]),
		AlchemyDb.refusal(again["line"]) == "NO EMPTY BOTTLE")
	# Press it, so the capture below has the FOOTER in it and not just three grey
	# rows. `_refuse` is set by the press, not by the state, and the sentence in
	# that footer is the only place the game explains what is stopping you.
	screen._cursor = screen._rows.find(again)
	screen._commit()
	await rig.wait_frames(8)
	await rig.capture(out.path_join("a_02_full.png"))


# --- F. More glass ----------------------------------------------------------

func _bottles(rig) -> void:
	var screen := _counter_screen(rig, "the bottle beat")
	if screen == null:
		return
	for _i in K.BOTTLE_MAX + 2:
		var line := _row(screen, &"bottle")
		if line.is_empty() or not AlchemyDb.buy(line["line"]):
			break
		screen._refresh()
	print("ALCHEMY bottles=%d contents=%s" % [Game.bottle_count(), Game.bottle_contents])
	_ck("F0 the ceiling is K.BOTTLE_MAX (%d)" % Game.bottle_count(),
		Game.bottle_count() == K.BOTTLE_MAX)
	_ck("F1 a fifth is refused", not Game.add_bottle())
	var done := _row(screen, &"bottle")
	_ck("F2 the finished line is refused",
		not done.is_empty() and not AlchemyDb.can_buy(done["line"]))
	_ck("F3 the first bottle still has its draught in it",
		Game.bottle(0) == &"heart_draught")

	# Fill the rest, so the HUD cross has one of each to draw and the drink beat
	# below has all three to swallow.
	for id in PotionDb.IDS:
		if id == &"heart_draught":
			continue
		var line := _row(screen, id)
		if not line.is_empty():
			AlchemyDb.buy(line["line"])
	screen._refresh()
	await rig.wait_frames(8)
	print("ALCHEMY filled=%s" % [Game.bottle_contents])
	_ck("F4 three of the four are full", Game.empty_bottles() == 1)
	await rig.capture(out.path_join("a_03_stocked.png"))

	await rig.tap(["ui_cancel"])
	# Wait for the screen to be GONE, not for a frame count: it holds
	# `Prompt.block` for its whole life and a half-shut one makes every beat
	# after it report a failure it did not cause. forge_loop.gd learned this the
	# expensive way.
	for _i in 60:
		if _screen(rig) == null:
			break
		await rig.wait_frames(2)
	_ck("F5 her screen closed", _screen(rig) == null)
	await rig.wait_frames(10)


# --- G. Binding it, and drinking it -----------------------------------------

func _bind(rig) -> void:
	# Bound by the SAME call the equipment screen makes, to the same three
	# buttons, so this is the player's path and not a back door.
	_ck("G0 a bottle is bindable", Game.bind_quick(Game.QUICK_LEFT, Game.bottle_id(0)))
	_ck("G1 the button holds it",
		Game.quick(Game.QUICK_LEFT) == Game.bottle_id(0))
	Game.bind_quick(Game.QUICK_UP, Game.bottle_id(1))
	Game.bind_quick(Game.QUICK_RIGHT, Game.bottle_id(2))
	await rig.wait_frames(8)
	await rig.capture(out.path_join("a_04_bound.png"))


## Capture-only, and deliberately so. The pouch and the equipment screen are
## Label trees rather than PixelFont draws, so nothing here can be asserted that
## is not already asserted somewhere cheaper -- what they are for is that a
## human looks at them. Two claims live only in these two frames: that a
## material's detail sends the player to the RIGHT counter, and that a bound
## bottle says what drinking it does.
func _screens(rig) -> void:
	Run.in_dungeon = false
	for id in ItemDb.components(ItemDef.BENCH_ALCHEMY):
		Run.collect(id, 3)
	Run.collect(&"whetstone_grit", 2)
	await rig.wait_frames(6)

	Menu.open()
	await rig.wait_frames(6)
	Menu._push({"screen": PauseMenu.Screen.POUCH})
	await rig.wait_frames(14)
	await rig.capture(out.path_join("a_04a_pouch.png"))
	Menu.close()
	await rig.wait_frames(10)

	Menu.open()
	await rig.wait_frames(6)
	Menu._push({"screen": PauseMenu.Screen.EQUIP})
	await rig.wait_frames(14)
	await rig.capture(out.path_join("a_04b_equip.png"))
	Menu.close()
	await rig.wait_frames(20)


func _drink(rig) -> void:
	# --- The heal -------------------------------------------------------------
	Game.quarters = 2
	Bus.player_health_changed.emit(Game.quarters, Game.max_quarters)
	await rig.wait_frames(4)
	var hurt := Game.quarters
	await rig.tap(["item_left"])
	await rig.wait_frames(12)
	print("ALCHEMY drank heart quarters=%d -> %d bottle0=%s" % [
		hurt, Game.quarters, Game.bottle(0)])
	_ck("G2 the button drank it -- health went up",
		Game.quarters == mini(Game.max_quarters, hurt + K.DRAUGHT_HEAL))
	_ck("G3 the bottle emptied", Game.bottle(0) == &"")
	_ck("G4 the bottle itself stayed", Game.bottle_count() == K.BOTTLE_MAX)
	# An empty bottle on a button is a no-op, not a crash and not a free heal.
	var after := Game.quarters
	await rig.tap(["item_left"])
	await rig.wait_frames(8)
	_ck("G5 pressing it again does nothing", Game.quarters == after)

	# --- The two that last ----------------------------------------------------
	# Checked through the accessors the SWORD and `Hero.hurt` read, which is the
	# whole reason the draughts were built on top of the forge's ladders.
	var edge_before := Game.sword_bonus()
	var soak_before := Game.armour_soak()
	var which := [Game.bottle(1), Game.bottle(2)]
	await rig.tap(["item_up"])
	await rig.wait_frames(6)
	await rig.tap(["item_right"])
	await rig.wait_frames(6)
	print("ALCHEMY draughts=%s edge=+%d -> +%d soak=-%d -> -%d" % [
		which, edge_before, Game.sword_bonus(), soak_before, Game.armour_soak()])
	_ck("G6 emberblood sharpened the swing",
		Game.sword_bonus() == edge_before + K.DRAUGHT_EDGE)
	_ck("G7 ironhide thickened the hide",
		Game.armour_soak() == soak_before + K.DRAUGHT_PLATE)
	_ck("G8 both bottles emptied", Game.bottle(1) == &"" and Game.bottle(2) == &"")
	_ck("G9 the HUD has a clock to draw", Game.draughts.size() == 2)
	await rig.wait_frames(10)
	await rig.capture(out.path_join("a_05_draughts.png"))

	# And it RUNS OUT. A buff with no end is a permanent upgrade the smith did
	# not sell, which is the one thing a consumable must never quietly become.
	Game.start_draught(Game.DRAUGHT_EDGE_ID, 0.25)
	Game.start_draught(Game.DRAUGHT_PLATE_ID, 0.25)
	await rig.wait_seconds(0.6)
	print("ALCHEMY expired edge=+%d soak=-%d" % [Game.sword_bonus(), Game.armour_soak()])
	_ck("G10 the swing went back to the forge's number",
		Game.sword_bonus() == edge_before)
	_ck("G11 so did the hide", Game.armour_soak() == soak_before)


# --- H. Where the materials come from ---------------------------------------

func _underground(rig) -> void:
	var town := rig.scene() as Town
	_stand_at(rig, town.gate.global_position + Vector3(0.0, 0.0, 1.8))
	for _i in 90:
		if Prompt.focus == town.gate:
			break
		await rig.wait_frames(2)
	# Re-planted mid-hold: losing focus zeroes Prompt's bar with nothing printed,
	# and the beat then lies about why it failed. See forge_loop.gd's long note.
	Input.action_press(&"interact")
	for _i in 12:
		await rig.wait_frames(8)
		if Run.in_dungeon:
			break
		if Prompt.focus != town.gate:
			_stand_at(rig, town.gate.global_position + Vector3(0.0, 0.0, 1.8))
	Input.action_release(&"interact")
	await rig.wait_frames(140)
	_ck("H0 he went down", Run.in_dungeon)
	if not Run.in_dungeon:
		return

	# The column with EVERY bar in it. Underground the heat meter exists and the
	# control legend does not, so the draughts sit one slot lower than they did
	# in town -- and this is the frame that has to be looked at, because drinking
	# happens down here and a stack that only fits upstairs fits nowhere. There
	# is no assertion for it. A rectangle in the wrong place is not a thing a
	# check can see; that is the whole reason the first version of this HUD row
	# was drawn on top of the stamina bar with all sixty checks green.
	Game.start_draught(Game.DRAUGHT_EDGE_ID, K.DRAUGHT_TIME)
	Game.start_draught(Game.DRAUGHT_PLATE_ID, K.DRAUGHT_TIME * 0.6)
	await rig.wait_frames(12)
	await rig.capture(out.path_join("a_06_column.png"))

	var hero: Node3D = rig.get_nodes_in_group(&"player")[0]
	Run.bag.clear()
	Run.premium = 0
	Bus.bag_changed.emit(Run.bag, 0)
	Game.components.clear()
	await rig.wait_frames(4)

	# Glass on the floor, a stride away, with no button anywhere near it.
	var at := hero.global_position
	var drops: Array[LootMote] = []
	for i in 3:
		var id: StringName = [&"fired_cullet", &"bitter_root", &"ash_resin"][i]
		drops.append(LootMote.drop(rig.scene(), id,
			at + Vector3(0.9 * (float(i) - 1.0), 0.0, 1.4)))
	await rig.wait_frames(40)
	await rig.capture(out.path_join("a_06_motes.png"))
	for m in drops:
		if is_instance_valid(m):
			_stand_at(rig, m.global_position)
			await rig.wait_frames(20)
	print("ALCHEMY swept bag=%d value=%d" % [Run.bag_count(), Run.bag_value()])
	_ck("H1 walking over them picked them up, nothing pressed",
		Run.bag.has(&"fired_cullet") and Run.bag.has(&"bitter_root"))

	Game.gold = 5000
	_ck("H2 extraction succeeded", Run.extract())
	await rig.wait_frames(90)
	print("ALCHEMY home bench=%s bag=%s" % [Game.components, Run.bag])
	_ck("H3 the glass reached the bench", Game.component_count(&"fired_cullet") > 0)
	var left_over := false
	for id: StringName in Run.bag:
		if ItemDb.is_component(id):
			left_over = true
	_ck("H4 no material is left in the vendor's bag", not left_over)
	await rig.wait_frames(30)
	await rig.capture(out.path_join("a_07_home.png"))


# --- I. The trip through the save file --------------------------------------
##
## The failure this exists to catch is silent: JSON has no StringName, so a
## contents array reloaded without `StringName(c)` comes back full of Strings.
## `bottle_index()` still parses, the HUD still draws a full bottle, and the
## press does nothing -- a bottle that lies.
func _save(rig) -> void:
	# Let the ride home finish before touching a slot. game_flow.gd `_go`
	# autosaves at the very END of a transition, and `Saves.save(2)` below makes
	# 2 the active slot -- so a transition still in flight from H lands its
	# autosave inside this beat, and if it arrives after `Game.reset()` it
	# overwrites the slot with the wiped state. That is what was failing I1-I5
	# intermittently, and the same race was caught red-handed in forge_loop's
	# `_death`. A fixed frame count only moves the odds; this waits for the
	# thing itself.
	for _i in 240:
		await rig.wait_seconds(0.05)
		if not Flow.busy:
			break
	await rig.wait_seconds(0.25)

	# One full, one empty, so the reload has both states to get wrong. Built up
	# rather than assigned by index: an earlier beat that failed can leave fewer
	# bottles here than this expects, and `bottle_contents[1] = ...` on a
	# one-element array is a hard error that kills the rest of the run -- with
	# `Saves.erase(2)` never reached, so slot 2 is left on disk for whatever runs
	# next. A director must not be able to poison the next director.
	while Game.bottle_count() < 2:
		if not Game.add_bottle():
			break
	Game.bottle_contents[0] = &"heart_draught"
	for i in range(1, Game.bottle_count()):
		Game.bottle_contents[i] = &""
	Bus.bottles_changed.emit(Game.bottle_contents)
	var before := Game.bottle_contents.duplicate()

	# Check the WRITE before checking the read-back. A slot that never got
	# written reads back as five separate bottle failures -- "every bottle came
	# back", "what was in them came back", "it still drinks" -- and every one of
	# those sentences blames the bottles for a file that is not there. Two runs
	# in one batch failed exactly that way. Whatever the cause, the beat should
	# name it.
	var wrote := Saves.save(2)
	_ck("Ia the slot was actually written (wrote=%s exists=%s)" % [
		wrote, Saves.has_save(2)], wrote and Saves.has_save(2))
	await rig.wait_frames(10)
	Game.reset()
	await rig.wait_frames(10)
	# Wiped properly rather than by clearing a field, exactly as forge_loop.gd
	# does it: a reset that left the array in place would pass this whether the
	# loader worked or not.
	_ck("I0 the reset really cleared the glass", Game.bottle_count() == 0)

	Saves.load_slot(2)
	await rig.wait_frames(10)
	print("ALCHEMY reloaded %s (was %s)" % [Game.bottle_contents, before])
	_ck("I1 every bottle came back", Game.bottle_count() == before.size())
	_ck("I2 what was in them came back", Game.bottle_contents == before)
	# The one that a String-keyed reload would pass and then fail on: the potion
	# has to still be drinkable, which means the id has to still be a StringName
	# the catalogue knows.
	_ck("I3 the reloaded draught is still a draught PotionDb knows",
		PotionDb.has(Game.bottle(0)))
	var hurt := Game.max_quarters - K.DRAUGHT_HEAL
	Game.quarters = hurt
	_ck("I4 and it still drinks", Game.drink_bottle(0))
	_ck("I5 and it still heals", Game.quarters > hurt)
	Saves.erase(2)


# --- Helpers ----------------------------------------------------------------

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
	# More than one is a bug in its own right -- two boards taking presses at
	# once, the top one drawn and the other one buying. Say so rather than
	# returning the first and letting the beats downstream disagree about what
	# they are driving.
	if found.size() > 1:
		print("ALCHEMY FAIL %d trade screens are open at once" % found.size())
		_fails += 1
	return found[0] if not found.is_empty() else null


## The counter, or a loud failure. Three beats in a row drive the same screen,
## and the version of this director that just `return`ed when it had gone
## reported FIVE failures in the drink beat and none at the beat that actually
## broke -- a silent early return is how a director lies about where the bug is.
func _counter_screen(rig, beat: String) -> TradeScreen:
	var s := _screen(rig)
	if s == null:
		print("ALCHEMY FAIL the alchemist's screen was gone by %s" % beat)
		_fails += 1
	return s


func _all(root: Node) -> Array:
	var found := [root]
	for c in root.get_children():
		found.append_array(_all(c))
	return found


## Teleport. Pathing a hero across town with synthetic input is its own project
## and the thing under test here is the counter. See forge_loop.gd's note on why
## `facing_yaw` moves too.
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
