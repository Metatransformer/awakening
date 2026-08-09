extends RefCounted
## The forge, end to end: a component on the floor becomes a longer chain.
##
## Point it at TOWN. It descends on its own, because half the claims here are
## about what survives the trip and you cannot test that from one side of it.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/town.tscn \
##     --director=res://tools/directors/forge_loop.gd \
##     --out=/tmp/forge/x.png --warmup=60
##
## What it claims, in the order it proves them:
##
##   A  Components are in the catalogue and on the drop tables.
##   B  The pouch draws `Game.bag_slots` cells and marks the components.
##   C  The smith names a component cost and REFUSES when the bench is short.
##   D  Buying a rung moves the number the gear actually reads -- the arc, the
##      draw, the reach, the edge, the plate -- not just a counter.
##   E  A component on the dungeon floor is picked up by WALKING OVER IT.
##   F  Extraction sorts components onto the bench and leaves the vendor the rest.
##   G  Death takes the bag, components included.
##
## D is the one that matters. Every other claim is bookkeeping; D is the claim
## that the money bought something the player can feel, and it is checked against
## `Game`'s own accessors rather than against `upgrades`, because a rung that
## incremented a counter and changed no behaviour is exactly the bug a "level"
## system produces.

var out := ""
var _fails := 0


func run(rig) -> void:
	out = rig.arg("out", "/tmp/forge/x.png").get_base_dir()
	await rig.wait_frames(20)

	_catalogue()
	await _pouch(rig)
	await _smith(rig)
	await _descend(rig)
	await _sweep(rig)
	await _bank(rig)
	await _death(rig)
	await _save(rig)

	if _fails == 0:
		print("FORGE OK")
	else:
		print("FORGE FAIL -- %d check(s) failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_fails += 1
		print("FORGE FAIL %s" % label)


# --- A. The catalogue -------------------------------------------------------

func _catalogue() -> void:
	var parts := ItemDb.components()
	print("FORGE components=%s" % [parts])
	_ck("A0 four components exist", parts.size() == 4)
	for id in parts:
		var def := ItemDb.get_def(id)
		_ck("A1 %s is marked a component" % id, def != null and def.is_component())
	# A component nothing drops is a recipe nobody can fill. Both tables are
	# checked because they are tuned separately and the rare one is chest-only
	# on purpose -- if it ever leaks onto the enemy table, grinding room one
	# finishes every ladder.
	var on_enemy := 0
	for id in parts:
		if ItemDb.ENEMY_DROPS.has(id):
			on_enemy += 1
		_ck("A2 %s drops from chests" % id, ItemDb.CHEST_DROPS.has(id))
	_ck("A3 three of the four drop off bodies; the core does not",
		on_enemy == 3 and not ItemDb.ENEMY_DROPS.has(&"cold_iron_core"))


# --- B. The pouch -----------------------------------------------------------

func _pouch(rig) -> void:
	# A bag with one of everything in it, so the grid has a component cell, an
	# ingredient cell and empty cells all on screen at once.
	Run.in_dungeon = false
	Run.collect(&"whetstone_grit", 6)
	Run.collect(&"tension_coil", 4)
	Run.collect(&"deep_amber", 2)
	Run.collect(&"bone_shard", 9)
	await rig.wait_frames(6)

	Menu.open()
	await rig.wait_frames(6)
	# Straight to the screen rather than walking the root list: the root list is
	# critic_menu.gd's job and driving it here would only test the same buttons
	# twice.
	Menu._push({"screen": PauseMenu.Screen.POUCH})
	await rig.wait_frames(12)

	var pouch: MenuPouchPanel = Menu.get_node("Root/Screens/PouchScreen")
	_ck("B0 the pouch screen is showing", pouch.visible)
	_ck("B1 it draws one cell per bag slot (%d of %d)" % [
		pouch._cells.size(), Game.bag_slots],
		pouch._cells.size() == Game.bag_slots)
	var filled := 0
	for id in pouch._cell_ids:
		if id != &"":
			filled += 1
	_ck("B2 filled cells match Run.slots_used() (%d of %d)" % [
		filled, Run.slots_used()], filled == Run.slots_used())
	_ck("B3 something is focused",
		Menu.get_viewport().gui_get_focus_owner() != null)
	# The frame has to fit on the screen, and nothing else here notices when it
	# does not. Six columns of 150 px built a 1400 px frame inside a 1280 px
	# viewport: every check above still passed while the detail column and the
	# Back button rendered off the right edge. A CenterContainer clips an
	# oversized child, it does not shrink it.
	var frame: Control = pouch.get_node("Center/Frame")
	var screen_size := Vector2(Menu.get_viewport().get_visible_rect().size)
	print("FORGE pouch frame=%.0fx%.0f viewport=%.0fx%.0f" % [
		frame.size.x, frame.size.y, screen_size.x, screen_size.y])
	_ck("B4 the pouch frame fits on the screen",
		frame.size.x <= screen_size.x and frame.size.y <= screen_size.y)
	await rig.capture(out.path_join("f_00_pouch.png"))

	Menu.close()
	await rig.wait_frames(10)


# --- C and D. The smith -----------------------------------------------------

func _smith(rig) -> void:
	var town := rig.scene() as Town
	_stand_at(rig, town.smith.global_position + Vector3(0.0, 0.0, 1.6))
	await rig.wait_frames(20)
	await rig.tap(["interact"])
	await rig.wait_frames(16)

	var screen := _screen(rig)
	if screen == null:
		print("FORGE FAIL the smith did not open")
		return
	_ck("C0 the smith lists eight lines", screen._rows.size() == 8)

	# --- C. Refusal, with the right reason ------------------------------------
	# Rich, and holding nothing. The chain is the track the owner named by its
	# number, so it is the one driven here.
	Game.gold = 40000
	Game.components.clear()
	screen._refresh()
	var chain := _row(screen, &"chain")
	_ck("C1 the chain line exists", not chain.is_empty())
	if chain.is_empty():
		return
	_ck("C2 it names a component cost", not (chain["parts"] as Dictionary).is_empty())
	_ck("C3 gold alone cannot buy it", not ShopDb.can_buy(chain["line"]))
	_ck("C4 the refusal names the component, not the money (%s)"
		% ShopDb.refusal(chain["line"]),
		ShopDb.refusal(chain["line"]).contains("COIL"))
	screen._cursor = screen._rows.find(chain)
	screen._commit()
	await rig.wait_frames(20)
	_ck("C5 the press changed nothing", Game.forge_level(Game.FORGE_CHAIN) == 0)
	await rig.capture(out.path_join("f_01_short.png"))

	# --- D. Buy every rung of every ladder, and watch the gear move -----------
	var before := {
		"edge": Game.sword_bonus(),
		"plate": Game.armour_soak(),
		"guard": Game.guard_arc(),
		"string": Game.bow_draw_time(),
		"chain": Game.hook_reach(),
	}
	print("FORGE base edge=+%d plate=-%d guard=%.0f draw=%.2f reach=%.2f" % [
		before["edge"], before["plate"], before["guard"],
		before["string"], before["chain"]])

	# Stock the bench past the total of every recipe on the board. 40 of each was
	# NOT enough and the shortfall read as "the chain ladder stops at rung two":
	# coil is wanted by both the bow and the chain, 43 between them, so the last
	# rung silently refused. A director whose own stock is a hidden variable will
	# blame the game for the director's arithmetic.
	for id in ItemDb.components():
		Game.add_component(id, 120)
	screen._refresh()
	await rig.wait_frames(8)
	await rig.capture(out.path_join("f_02_forge.png"))

	for track in Game.FORGE_TRACKS:
		for _rung in K.FORGE_MAX:
			var line := ShopDb.lines().filter(
				func(l: Dictionary) -> bool: return l["id"] == track)
			if line.is_empty() or not ShopDb.buy(line[0]):
				break
		_ck("D0 %s reached the top rung (%d of %d)" % [
			track, Game.forge_level(track), K.FORGE_MAX],
			Game.forge_level(track) == K.FORGE_MAX)

	print("FORGE full edge=+%d plate=-%d guard=%.0f draw=%.2f reach=%.2f" % [
		Game.sword_bonus(), Game.armour_soak(), Game.guard_arc(),
		Game.bow_draw_time(), Game.hook_reach()])
	_ck("D1 the blade bites deeper", Game.sword_bonus() > before["edge"])
	_ck("D2 the armour soaks more", Game.armour_soak() > before["plate"])
	_ck("D3 the guard arc widened", Game.guard_arc() > before["guard"])
	_ck("D4 the bow draws faster", Game.bow_draw_time() < before["string"])
	_ck("D5 the chain got longer (%.2f m -> %.2f m)" % [
		before["chain"], Game.hook_reach()], Game.hook_reach() > before["chain"])
	# The top of the chain ladder IS [oot]'s Longshot. If this drifts, the table
	# stopped meaning what its comment says it means.
	_ck("D6 the finished chain is exactly the Longshot",
		is_equal_approx(Game.hook_reach(), K.HOOK_LONGSHOT_RANGE))
	# A finished ladder must be refused, or gold buys a fourth rung off the end
	# of the array and the game crashes indexing K.
	var done := _row(screen, &"chain")
	if not done.is_empty():
		_ck("D7 a finished ladder is refused", not ShopDb.can_buy(done["line"]))

	screen._refresh()
	await rig.wait_frames(8)
	await rig.capture(out.path_join("f_03_forged.png"))

	# Close it and WAIT FOR IT TO BE GONE. The trade screen holds `Prompt.block`
	# for its whole life, so a screen still shutting means `Prompt.focus` is null
	# at the gate, the hold goes nowhere, and every beat after it reports a
	# failure it did not cause. mvp_loop.gd learned this the expensive way and
	# left a comment about it; a fixed frame count is the wrong instrument.
	await rig.tap(["ui_cancel"])
	for _i in 60:
		if _screen(rig) == null:
			break
		await rig.wait_frames(2)
	_ck("D8 the smith's screen closed", _screen(rig) == null)
	await rig.wait_frames(10)

	# The hero standing in town was built before any of that. Prove the SPAWNED
	# gear reads the ladder, not just the accessor -- hero_combat applies the arc
	# in _ready, so only a fresh hero has it, and that is exactly why the descent
	# below is part of this director rather than a separate one.
	var hero: Node = rig.get_nodes_in_group(&"player")[0]
	print("FORGE town hero block_cone=%.0f (built before the forge)"
		% hero.combat.block_cone)


# --- E and F. Underground ---------------------------------------------------

func _descend(rig) -> void:
	var town := rig.scene() as Town
	_stand_at(rig, town.gate.global_position + Vector3(0.0, 0.0, 1.8))
	# Wait for THE GATE to own the button, not for "something" to. The teleport
	# out of the smith's trigger takes a physics frame or two to register as an
	# exit, and until it does `Prompt.focus` is still the smith -- non-null, so a
	# "focus != null" wait breaks instantly and the 0.9 s hold that follows
	# re-opens the shop instead of opening the gate. That is exactly how this
	# beat failed here, and the whole run then reported an economy bug it did not
	# have. `Prompt.focus != null` is not the state you need; the gate is.
	for _i in 90:
		if Prompt.focus == town.gate:
			break
		await rig.wait_frames(2)
	print("FORGE gate focus=%s blocked=%s" % [
		Prompt.focus.prompt if Prompt.focus != null else "<none>", Prompt.blocked])
	_ck("E0a the gate owns the interact button", Prompt.focus == town.gate)
	# The gate wants a 0.9 s hold. A tap must not open it -- that is the whole
	# point of the hold, and it is one press to prove.
	await rig.tap(["interact"])
	await rig.wait_frames(20)
	_ck("E0b a tap does not open the gate", not Run.in_dungeon)

	# Hold until the descent registers, rather than for a fixed 1.3 s and a shrug.
	# `rig.hold_seconds` was what this used and it left `Prompt._hold` at 0.00
	# with `_armed` false -- the button never reached Prompt at all.
	#
	# This beat is also what found the bug that made every director on this
	# machine flaky: a GAMEPAD on the desk. Sticks resting just outside the
	# deadzone reported `move_up` / `move_right` held, the hero walked out of the
	# gate's radius mid-hold, `Prompt` dropped focus, and the run reported five
	# economy failures for a gate it had never reached. `shoot.gd` now strips
	# joypad bindings for the life of a capture run.
	#
	# The re-plant stays: the hero has physics, and losing focus zeroes `_hold`
	# with nothing printed, so the bar restarts and the beat lies about why.
	Input.action_press(&"interact")
	for _i in 12:
		await rig.wait_frames(8)
		if Run.in_dungeon:
			break
		if Prompt.focus != town.gate:
			_stand_at(rig, town.gate.global_position + Vector3(0.0, 0.0, 1.8))
	Input.action_release(&"interact")
	print("FORGE post_hold in_dungeon=%s busy=%s scene=%s" % [
		Run.in_dungeon, Flow.busy, rig.scene().name])
	await rig.wait_frames(140)
	_ck("E0 he went down", Run.in_dungeon)

	var hero: Node = rig.get_nodes_in_group(&"player")[0]
	print("FORGE dungeon hero block_cone=%.0f" % hero.combat.block_cone)
	_ck("E1 the freshly spawned hero carries the forged guard arc",
		is_equal_approx(hero.combat.block_cone, Game.guard_arc()))


func _sweep(rig) -> void:
	var hero: Node3D = rig.get_nodes_in_group(&"player")[0]
	Run.bag.clear()
	Run.premium = 0
	Bus.bag_changed.emit(Run.bag, 0)
	await rig.wait_frames(4)

	# Three components on the floor, a stride away, with no button anywhere near
	# them. Walking over a drop IS the pickup (LootMote answers overlap), and
	# this is the claim the owner asked for by name.
	var at := hero.global_position
	var drops: Array[LootMote] = []
	for i in 3:
		var id: StringName = [&"whetstone_grit", &"tension_coil", &"riveted_plate"][i]
		drops.append(LootMote.drop(rig.scene(), id,
			at + Vector3(0.9 * (float(i) - 1.0), 0.0, 1.4)))
	await rig.wait_frames(40)
	_ck("E2 three motes are on the floor", _motes(rig).size() >= 3)
	await rig.capture(out.path_join("f_04_motes.png"))

	var before := Run.bag_count()
	for m in drops:
		if is_instance_valid(m):
			_stand_at(rig, m.global_position)
			await rig.wait_frames(20)
	print("FORGE swept bag=%d value=%d" % [Run.bag_count(), Run.bag_value()])
	_ck("E3 walking over them picked them up, with no button pressed",
		Run.bag_count() >= before + 3)
	_ck("E4 they are in the bag by name",
		Run.bag.has(&"whetstone_grit") and Run.bag.has(&"tension_coil"))
	await rig.capture(out.path_join("f_05_swept.png"))


func _bank(rig) -> void:
	# Something for the vendor too, so the sort has two kinds to separate.
	Run.collect(&"void_pearl", 1)
	await rig.wait_frames(4)
	var stock_before := Game.component_count(&"whetstone_grit")
	var fee := Run.extract_cost()
	var value := Run.bag_value()
	print("FORGE pre_extract bag=%d fee=%d" % [value, fee])
	# The fee is charged on the WHOLE bag. A component that dodged the toll
	# would make carrying one strictly better than carrying a pearl, and the
	# slot decision would evaporate.
	_ck("F0 the fee is a quarter of the bag, components included",
		fee == maxi(Run.EXTRACT_MIN, int(round(value * Run.EXTRACT_RATE))))

	Game.gold = 5000
	_ck("F1 extraction succeeded", Run.extract())
	await rig.wait_frames(90)

	print("FORGE home bench=%s bag=%s" % [Game.components, Run.bag])
	_ck("F2 the components reached the bench",
		Game.component_count(&"whetstone_grit") > stock_before)
	var left_over := false
	for id: StringName in Run.bag:
		if ItemDb.is_component(id):
			left_over = true
	_ck("F3 no component is left in the vendor's bag", not left_over)
	_ck("F4 the merchandise stayed", Run.bag.has(&"void_pearl"))
	await rig.wait_frames(30)
	await rig.capture(out.path_join("f_06_home.png"))


# --- G. What death takes ----------------------------------------------------

func _death(rig) -> void:
	# Simulated rather than fought: `Run.die()` is the rule under test, and
	# arranging a real death underground is p4_combat.gd's job.
	Run.enter(4242)
	Run.collect(&"cold_iron_core", 1)
	Run.collect(&"tension_coil", 3)
	var bench := Game.component_count(&"cold_iron_core")
	_ck("G0 a core is in the bag", Run.bag.has(&"cold_iron_core"))
	Run.die()
	await rig.wait_frames(20)
	_ck("G1 death took the bag", Run.bag.is_empty())
	_ck("G2 death did NOT touch the bench",
		Game.component_count(&"cold_iron_core") == bench)
	print("FORGE after_death bench_cores=%d bag=%d" % [
		Game.component_count(&"cold_iron_core"), Run.bag_count()])


# --- H. The trip through the save file --------------------------------------

## Everything above is worthless if a rung does not survive quitting the game,
## and this is the one part of it that fails SILENTLY. `JSON.parse` hands back
## `String` keys, so a `components`/`upgrades` dictionary rebuilt without
## `StringName(k)` loads without an error and reads back empty: `forge_level(
## &"edge")` misses, every ladder is at rung 0, and the save file looks fine.
func _save(rig) -> void:
	var rungs := {}
	for track in Game.FORGE_TRACKS:
		rungs[track] = Game.forge_level(track)
	var bench := Game.components.duplicate()
	var slots := Game.bag_slots

	Saves.save(2)
	await rig.wait_frames(10)
	# Wipe it properly rather than clearing a field or two. A reset that left the
	# dictionaries in place would pass this whether the loader worked or not.
	Game.reset()
	await rig.wait_frames(10)
	_ck("H0 the reset really cleared the bench", Game.components.is_empty())

	Saves.load_slot(2)
	await rig.wait_frames(10)
	print("FORGE reloaded rungs=%s bench=%s slots=%d" % [
		rungs, Game.components, Game.bag_slots])
	var kept := true
	for track: StringName in rungs:
		if Game.forge_level(track) != int(rungs[track]):
			kept = false
	_ck("H1 every forged rung came back", kept)
	var stocked := true
	for id: StringName in bench:
		if Game.component_count(id) != int(bench[id]):
			stocked = false
	_ck("H2 the workbench came back, keyed by StringName", stocked)
	_ck("H3 the bag size came back", Game.bag_slots == slots)
	# And the gear still reads it, which is the thing the player would notice.
	_ck("H4 the reloaded chain is still the Longshot",
		is_equal_approx(Game.hook_reach(), K.CHAIN_REACH[rungs[&"chain"]]))
	Saves.erase(2)


# --- Helpers ----------------------------------------------------------------

func _row(screen, id: StringName) -> Dictionary:
	for r in screen._rows:
		if r.get("kind") == &"buy" and r["line"]["id"] == id:
			return r
	return {}


func _screen(rig) -> TradeScreen:
	for n in _all(rig.scene()):
		if n is TradeScreen:
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


## Teleport. Pathing a hero across a procedural dungeon with synthetic input is
## its own project, and the thing under test here is the economy. `facing_yaw`
## as well as `rotation.y`, because the hero turns toward his own heading every
## frame and setting only the node would be undone before the next capture --
## see docs/CONTRACT.md §2.5, facing is measured, not derived.
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
