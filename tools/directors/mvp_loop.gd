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
##     --scene=res://scenes/rooms/town.tscn \
##     --director=res://tools/directors/mvp_loop.gd --out=/tmp/mvp/x.png

var out := ""


func run(rig) -> void:
	out = rig.arg("out", "/tmp/mvp/x.png").get_base_dir()
	await rig.wait_frames(30)

	await _town_arrival(rig)
	await _sell(rig)
	await _buy(rig)
	await _descend(rig)
	await _fight(rig)
	await _extract(rig)
	await _return(rig)


# --- Town -------------------------------------------------------------------

func _town_arrival(rig) -> void:
	print("MVP town gold=%d hearts=%d/%d" % [
		Game.gold, Game.quarters, Game.max_quarters])
	await rig.capture(out.path_join("m_00_town.png"))


func _sell(rig) -> void:
	# Arrive as though a run had just paid out, so the vendor has something to
	# buy and the bag corner has something to show.
	Run.in_dungeon = false
	Run.collect(&"iron_scrap", 5)
	Run.collect(&"ghost_silk", 3)
	Run.collect(&"deep_amber", 2)
	Run.collect(&"bone_shard", 11)
	await rig.wait_frames(10)

	var town := rig.scene() as Town
	_stand_at(rig, town.vendor.global_position + Vector3(0.0, 0.0, 1.6))
	await rig.wait_frames(20)
	print("MVP focus=%s bag=%d" % [
		Prompt.focus.prompt if Prompt.focus != null else "<none>", Run.bag_value()])
	await rig.capture(out.path_join("m_01_vendor_prompt.png"))

	await rig.tap(["interact"])
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
	await rig.tap(["ui_accept"])
	await rig.wait_frames(24)
	print("MVP after_sell gold=%d bag=%d" % [Game.gold, Run.bag_value()])
	await rig.capture(out.path_join("m_04_sold_all.png"))

	await rig.tap(["ui_cancel"])
	await rig.wait_frames(12)


func _buy(rig) -> void:
	var town := rig.scene() as Town
	_stand_at(rig, town.smith.global_position + Vector3(0.0, 0.0, 1.6))
	await rig.wait_frames(20)
	await rig.tap(["interact"])
	await rig.wait_frames(14)
	await rig.capture(out.path_join("m_05_shop.png"))

	# Second line is the bag slot -- cheap enough that one run pays for it.
	await rig.tap(["ui_down"])
	await rig.wait_frames(6)
	await rig.tap(["ui_accept"])
	await rig.wait_frames(24)
	print("MVP after_buy gold=%d slots=%d sword=+%d armour=+%d" % [
		Game.gold, Game.bag_slots, Game.sword_bonus(), Game.armour_soak()])
	await rig.capture(out.path_join("m_06_bought.png"))

	await rig.tap(["ui_cancel"])
	await rig.wait_frames(12)


func _descend(rig) -> void:
	var town := rig.scene() as Town
	_stand_at(rig, town.gate.global_position + Vector3(0.0, 0.0, 1.8))
	await rig.wait_frames(20)
	await rig.capture(out.path_join("m_07_gate.png"))

	# Wait for the GATE to actually own the interact button before holding it.
	#
	# This beat was flaky about one run in five, and the failure was expensive
	# out of all proportion: the hold went into the smith's screen while it was
	# still closing, the descent silently did not happen, and every beat after it
	# — the dungeon, the fight, the chest, the charm — then reported a failure it
	# did not cause. Two sessions have now gone hunting the economy for what was
	# a screen that had not finished shutting. A fixed frame count after
	# `ui_cancel` is the wrong instrument; wait for the state you need instead.
	for _i in 40:
		if Prompt.focus != null:
			break
		await rig.wait_frames(2)
	print("MVP gate focus=%s" % [
		Prompt.focus.prompt if Prompt.focus != null else "<none>"])
	if Prompt.focus == null:
		print("MVP FAIL nothing owns the interact button at the gate")

	# The gate is a 0.9 s hold, so tapping must NOT open it. Holding must.
	await rig.hold_seconds(["interact"], 1.3)
	await rig.wait_frames(120)
	print("MVP descended in_dungeon=%s scene=%s" % [
		Run.in_dungeon, rig.scene().name])
	await rig.capture(out.path_join("m_08_arrived.png"))


# --- Dungeon ----------------------------------------------------------------

func _fight(rig) -> void:
	var dun := _dungeon(rig)
	if dun == null:
		print("MVP FAIL no dungeon in %s" % rig.scene().name)
		return
	print("MVP layout rooms=%d deepest=%s seed=%d" % [
		dun.rooms.size(), dun.deepest, Run.seed_used])

	var crawlers: Array = rig.scene().get_tree().get_nodes_in_group(&"enemy")
	print("MVP enemies=%d" % crawlers.size())
	if crawlers.is_empty():
		print("MVP FAIL no enemies spawned")
		return
	# CharacterBody3D, NOT Crawler. The dungeon spawns Crawler in the shallow
	# rooms and Enemy deeper, so a Crawler-typed assignment throws at runtime the
	# moment the nearest foe is a goblin -- and it aborted this whole beat
	# SILENTLY, straight past the fight, the drops and the chest, while the log
	# still ended with a tidy "MVP home". Anything that reaches for a specific
	# enemy class here will break again the next time the roster grows.
	var foe: CharacterBody3D = crawlers[0]
	print("MVP foe kind=%s" % ("crawler" if foe is Crawler else str(foe.get("kind"))))

	# Stand just outside its reach, facing it, so the telegraph is on camera.
	var toward := K.flat(foe.global_position - Vector3.ZERO)
	_stand_at(rig, foe.global_position - toward * 2.2, foe.global_position)
	await rig.wait_frames(30)
	await rig.capture(out.path_join("m_09_enemy.png"))

	var before: int = foe.health.quarters
	# Close, then swing until it dies or we run out of patience.
	for swing in 12:
		# `health.dead` rather than a state enum: Crawler.State and Enemy.State
		# are different enums, and the health component is the one thing both
		# kinds genuinely share.
		if not is_instance_valid(foe) or foe.health.dead:
			break
		var toe := K.flat(foe.global_position - Vector3.ZERO)
		_stand_at(rig, foe.global_position - toe * 1.1, foe.global_position)
		await rig.wait_frames(2)
		await rig.tap(["attack"])
		await rig.wait_frames(34)
	print("MVP foe hp %d -> %s" % [before,
		foe.health.quarters if is_instance_valid(foe) else "dead"])
	await rig.capture(out.path_join("m_10_swung.png"))

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

	# Patch the hero up before walking him through a dungeon full of crawlers.
	#
	# Not cheating the test -- the opposite. The tour teleports between beats
	# with no regard for what is standing nearby, so the hero routinely arrives
	# at the chest on his last heart and dies. That is `Run.die()` working
	# correctly, but it ends the run, sends Flow back to town, and every
	# remaining beat then reports a failure it did not cause: the bag reads
	# empty because death emptied it, and the extract pad is "missing" because
	# we are standing in the town square. Death has its own proof; this one is
	# about the seams between the screens.
	Game.heal(Game.max_quarters)

	# The chest, which is where the run-defining drops live.
	var chest := _chest(rig)
	if chest != null:
		_stand_at(rig, chest.global_position + Vector3(0.0, 0.0, 1.3))
		await rig.wait_frames(24)
		await rig.capture(out.path_join("m_13_chest_prompt.png"))
		await rig.tap(["interact"])
		await rig.wait_frames(40)
		for m in _motes(rig):
			_stand_at(rig, m.global_position)
			await rig.wait_frames(18)
		print("MVP after_chest bag=%d value=%d fee=%d" % [
			Run.bag_count(), Run.bag_value(), Run.extract_cost()])
		await rig.capture(out.path_join("m_14_chest_loot.png"))


## Leaving. There is no pad to walk to any more -- the way out is the Homeward
## Charm, used from the menu, which then channels in the world. This drives the
## charm directly rather than the menu; the menu path is the equip director's
## job, and duplicating it here would only test the same buttons twice.
func _extract(rig) -> void:
	var hero = rig.get_nodes_in_group(&"player")[0]
	var charm: HomewardCharm = hero.charm
	if charm == null:
		print("MVP FAIL the hero is carrying no way out")
		return

	await rig.wait_frames(20)
	await rig.capture(out.path_join("m_15_before_charm.png"))

	print("MVP pre_extract gold=%d fee=%d value=%d" % [
		Game.gold, Run.extract_cost(), Run.bag_value()])
	if not charm.begin():
		# begin() has three refusals and they mean completely different things:
		# already channelling, not underground, or too poor. Printing only gold
		# and the fee named the one cause that is almost never the real one, and
		# sent a session hunting the economy for what was a state bug.
		print("MVP FAIL the charm refused to start (gold=%d fee=%d in_dungeon=%s active=%s can=%s)"
			% [Game.gold, Run.extract_cost(), Run.in_dungeon, charm.active(),
				Run.can_extract()])
		return

	# Caught mid-channel, so the ring is closing and the column of light is
	# halfway up him rather than absent or finished.
	await rig.wait_seconds(HomewardCharm.CHANNEL_TIME * 0.5)
	if not charm.active():
		print("MVP FAIL the charm stopped channelling on its own")
	await rig.capture(out.path_join("m_16_channelling.png"))

	await rig.wait_seconds(HomewardCharm.CHANNEL_TIME)
	await rig.wait_frames(30)
	if Run.in_dungeon:
		print("MVP FAIL the charm finished and he is still underground")
	await rig.capture(out.path_join("m_17_extracting.png"))


func _return(rig) -> void:
	await rig.wait_frames(150)
	print("MVP home scene=%s in_dungeon=%s gold=%d bag=%d hearts=%d/%d" % [
		rig.scene().name, Run.in_dungeon, Game.gold, Run.bag_value(),
		Game.quarters, Game.max_quarters])
	await rig.capture(out.path_join("m_18_home.png"))


# --- Helpers ----------------------------------------------------------------

## Put the hero on a spot, optionally facing something.
##
## Facing is not cosmetic here: the sword's arc test rejects anything outside
## `arc_degrees` of the hero's forward, so a hero teleported next to a crawler
## while still facing his spawn direction swings through empty air forever --
## which reads in the log exactly like "damage is broken".
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
