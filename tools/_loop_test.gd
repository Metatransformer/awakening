extends Node
## Headless drive of the whole metagame loop, so the thing can be exercised
## without a human at the keyboard: town -> dungeon -> kill -> loot -> extract
## -> sell -> forge. Prints what it observed; run it with
##   godot --path . --headless tools/scenes/_loop_test.tscn

var main: Main = null
var _fails: int = 0


func _ready() -> void:
	main = Main.new()
	add_child(main)
	await _frames(6)
	_town_checks()
	await _dungeon_checks()
	await _economy_checks()
	print("\n=== LOOP TEST %s ===" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ok(label: String, cond: bool, detail: String = "") -> void:
	if not cond:
		_fails += 1
	print("%s %s%s" % ["  ok  " if cond else " FAIL ", label,
		("   [%s]" % detail) if detail != "" else ""])


# --- Town -------------------------------------------------------------------

func _town_checks() -> void:
	print("\n--- town")
	var town := main.world as Town
	_ok("town built", town != null)
	if town == null:
		return
	var stations: Array[Node] = []
	for c in town.get_children():
		if c is Station:
			stations.append(c)
	_ok("three stations", stations.size() == 3, "found %d" % stations.size())
	_ok("hero placed at spawn",
		main.hero.global_position.distance_to(Town.SPAWN) < 0.5,
		str(main.hero.global_position))
	_ok("camera found the hero", main.camera.get_node("SpringArm3D") != null)


# --- Dungeon ----------------------------------------------------------------

func _dungeon_checks() -> void:
	print("\n--- dungeon")
	Game.gold = 500
	main.enter_dungeon()
	await _frames(6)

	var d := main.world as Dungeon
	_ok("dungeon built", d != null)
	if d == null:
		return
	_ok("floor plan has rooms", d.map.size() >= 12, "%d rooms" % d.map.size())
	_ok("every room reachable", d.map.all_reachable())
	_ok("entrance pre-cleared", bool(d.map.room_at(d.map.entrance).get("cleared", false)))
	_ok("one room instanced", d.room != null)
	_ok("hero is in the dungeon", Game.in_dungeon)

	# Walk to the first neighbour and prove a populated room spawns enemies.
	var exits: Array = d.map.exits_of(d.map.entrance)
	_ok("entrance has an exit", not exits.is_empty())
	if exits.is_empty():
		return
	d._on_exit_taken(exits[0])
	await _frames(6)

	var live: Array[Node] = []
	for c in d.room.get_children():
		if c is Enemy:
			live.append(c)
	_ok("second room spawned enemies", live.size() > 0, "%d" % live.size())
	_ok("room is sealed until cleared", not d.room.is_cleared)

	# Kill them the way the sword would, through the health component.
	for e: Node in live:
		(e as Enemy).health.apply_hit(Hit.make(99, main.hero.global_position))
	await _frames(4)
	_ok("room cleared by killing everything", d.room.is_cleared)
	_ok("depth advanced", Game.rooms_cleared >= 1, "rooms_cleared=%d" % Game.rooms_cleared)

	var drops: Array[Node] = []
	for c in d.room.get_children():
		if c is LootPickup:
			drops.append(c)
	_ok("enemies dropped ingredients", drops.size() > 0, "%d pickups" % drops.size())

	# Fill the bag the way walking over pickups would.
	Game.bag.add(LootDB.BONE_SHARD, 6)
	Game.bag.add(LootDB.GOBLIN_FANG, 4)
	_ok("bag holds the haul", Game.bag.total_items() == 10,
		"%d items worth %d" % [Game.bag.total_items(), Game.bag.total_value()])

	var fee := Game.extract_fee()
	_ok("fee priced by depth", fee == K.EXTRACT_BASE + K.EXTRACT_PER_ROOM * Game.rooms_cleared,
		"%d gold at depth %d" % [fee, Game.rooms_cleared])

	var before := Game.gold
	_ok("extraction succeeded", Game.end_run_extracted(true))
	_ok("fee was charged", Game.gold == before - fee, "%d -> %d" % [before, Game.gold])
	_ok("haul banked to stash", Game.stash_count(LootDB.BONE_SHARD) == 6
		and Game.stash_count(LootDB.GOBLIN_FANG) == 4)
	_ok("bag emptied", Game.bag.total_items() == 0)

	await _frames(6)
	_ok("returned to town", main.world is Town and not Game.in_dungeon)


# --- Vendor and smith -------------------------------------------------------

func _economy_checks() -> void:
	print("\n--- economy")
	var value := Game.stash_total_value()
	var gold_before := Game.gold
	var earned := Game.sell(LootDB.BONE_SHARD, 6)
	_ok("vendor paid for the shards", earned == 6 * LootDB.sell_value(LootDB.BONE_SHARD),
		"%d gold" % earned)
	_ok("gold went up by exactly that", Game.gold == gold_before + earned)
	_ok("stash shrank", Game.stash_total_value() == value - earned)

	# Stock up so the first blade rung is affordable, then forge it.
	Game.gold = 5000
	for id in Gear.next_materials(Gear.Track.BLADE, 0):
		Game.stash_add(id, 99)
	_ok("blade rung affordable", Game.can_craft(Gear.Track.BLADE),
		str(Game.craft_shortfall(Gear.Track.BLADE)))
	var price := Gear.next_gold(Gear.Track.BLADE, 0)
	var g := Game.gold
	_ok("forged the blade", Game.craft(Gear.Track.BLADE))
	_ok("blade tier advanced", Game.blade_tier == 1)
	_ok("gold spent", Game.gold == g - price, "%d -> %d" % [g, Game.gold])
	_ok("damage went up", Gear.blade_damage(1) > Gear.blade_damage(0),
		"%d -> %d" % [Gear.blade_damage(0), Gear.blade_damage(1)])

	var hearts_before := Game.max_quarters
	for id in Gear.next_materials(Gear.Track.ARMOR, 0):
		Game.stash_add(id, 99)
	_ok("forged the armour", Game.craft(Gear.Track.ARMOR))
	_ok("heart containers added", Game.max_quarters > hearts_before,
		"%d -> %d quarters" % [hearts_before, Game.max_quarters])
	_ok("healed to the new maximum", Game.quarters == Game.max_quarters)

	# Death must keep the belt and nothing else.
	Game.start_run()
	Game.bag.add(LootDB.WRAITH_CORE, 3)
	Game.bag.add(LootDB.ORC_PLATE, 3)
	Game.bag.add(LootDB.GRAVE_EMBER, 3)
	Game.bag.add(LootDB.KOBOLD_ICHOR, 3)
	var belt_id := Game.bag.id_at(0)
	var lost := Game.end_run_died()
	_ok("death lost the tail of the bag", not lost.is_empty(), str(lost))
	_ok("belt survived", Game.stash_count(belt_id) >= 3,
		"%s x%d banked" % [belt_id, Game.stash_count(belt_id)])
	_ok("gold untouched by death", Game.gold > 0)
	await _frames(6)
	_ok("death returned to town", main.world is Town and not Game.in_dungeon)
