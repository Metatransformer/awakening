extends RefCounted
## Deterministic behavioral and visual proof for the garrison garden.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --boot-here --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/garrison_garden.gd \
##     --out=/tmp/garrison-garden/proof.png --warmup=60


func run(rig) -> void:
	var garrison := rig.scene() as Garrison
	if not rig.check(garrison != null, "scene is the authored garrison"):
		return
	Clock.running = false
	Clock.set_time(1, 8.0)
	Game.restore_garrison({})
	Run.reset()
	await rig.wait_frames(8)

	rig.check(garrison.garden != null
		and garrison.garden_plots.size() == GardenDb.PLOT_SLOTS
		and garrison.fruit_tree_sites.size() == GardenDb.TREE_SITES,
		"the live yard exposes four garden beds and two fruit-tree sites")
	rig.check(Clock.dawn_started.is_connected(Game.advance_garden_dawn),
		"the canonical dawn signal owns garden growth")
	_check_catalogue(rig)

	var camera := Camera3D.new()
	camera.fov = 42.0
	garrison.add_child(camera)
	camera.global_position = Vector3(-7.7, 3.25, 6.25)
	camera.look_at(Vector3(-7.7, 0.50, 0.95), Vector3.UP)
	camera.make_current()
	var hero := rig.root.get_tree().get_first_node_in_group(&"player") as Hero
	if hero != null:
		hero.global_position = garrison.garden_plots[0].global_position \
			+ Vector3(0.0, 0.08, 1.05)
		hero.velocity = Vector3.ZERO
	await rig.wait_frames(6)
	await rig.capture("garden_00_empty_sites.png")

	await _check_crop_loop(rig, garrison, hero)
	hero = rig.root.get_tree().get_first_node_in_group(&"player") as Hero
	await _check_tree_loop(rig, garrison, hero)
	await _check_save_round_trip(rig)
	await _capture_mixed_garden(rig)
	hero = rig.root.get_tree().get_first_node_in_group(&"player") as Hero
	await _check_supply_crate(rig, garrison, hero)

	Game.restore_garrison({})
	Run.reset()
	Clock.running = true
	if rig.fails == 0:
		print("GARRISON GARDEN OK")


func _check_catalogue(rig) -> void:
	rig.check(GardenDb.CROP_IDS.size() == 3
		and GardenDb.TREE_IDS.size() == 2
		and GardenDb.PLANTING_IDS.size() == 5
		and GardenDb.PRODUCE_IDS.size() == 5,
		"catalogue owns three crops, two fruit trees, and their exact items")
	for id: StringName in GardenDb.PLANTING_IDS:
		var definition := ItemDb.get_def(id)
		rig.check(definition != null and not definition.is_supply()
			and definition.stack == GardenDb.planting_stack(id)
			and SupplyDb.STOCK_IDS.has(id),
			"%s is stackable quartermaster planting stock" % id)
	for id: StringName in GardenDb.PRODUCE_IDS:
		var definition := ItemDb.get_def(id)
		rig.check(definition != null and definition.is_supply()
			and definition.value == 0 and definition.stack == 8
			and SupplyCargoDb.FOOD_IDS.has(id),
			"%s is exact zero-value Food cargo" % id)

	Game.gold = 500
	var turnip_line := _supply_line(&"turnip_seed")
	var apple_line := _supply_line(&"apple_sapling")
	var before_gold := Game.gold
	rig.check(not turnip_line.is_empty() and SupplyDb.buy(turnip_line),
		"quartermaster sells a repeatable batch of Turnip Seed")
	rig.check(int(Run.bag.get(&"turnip_seed", 0)) == 4
		and Game.gold == before_gold - int(turnip_line.get("cost", 0)),
		"seed purchase pays exact gold and enters the ordinary bag")
	rig.check(not apple_line.is_empty() and SupplyDb.buy(apple_line)
		and int(Run.bag.get(&"apple_sapling", 0)) == 1,
		"quartermaster sells one Apple Sapling into the same bag")


func _check_crop_loop(rig, garrison: Garrison, hero: Hero) -> void:
	var plot := garrison.garden_plots[0]
	var seeds_before := int(Run.bag.get(&"turnip_seed", 0))
	plot.activate(hero)
	await rig.wait_frames(3)
	var planted := Game.garden_plot(0)
	rig.check(StringName(planted.get(&"crop_id", &"")) == &"turnip"
		and int(Run.bag.get(&"turnip_seed", 0)) == seeds_before - 1
		and plot.prompt == "WATER TURNIP",
		"one carried seed plants directly, is consumed once, and asks for water")

	Game.advance_garden_dawn(2)
	rig.check(int(Game.garden_plot(0).get(&"growth", -1)) == 0,
		"an unwatered dawn gives a crop no growth")
	plot.activate(hero)
	await rig.wait_frames(2)
	rig.check(bool(Game.garden_plot(0).get(&"watered", false))
		and plot.prompt == "TENDED TURNIP",
		"the bed interaction visibly darkens and marks a planted crop tended")
	await rig.capture("garden_01_watered_crop.png")

	Game.advance_garden_dawn(3)
	rig.check(int(Game.garden_plot(0).get(&"growth", -1)) == 1
		and not bool(Game.garden_plot(0).get(&"watered", true)),
		"one watered dawn grows exactly once and dries the bed")
	rig.check(Game.water_plot(0), "the crop can be watered for its second dawn")
	Game.advance_garden_dawn(4)
	await rig.wait_frames(3)
	rig.check(int(Game.garden_plot(0).get(&"growth", -1)) == 2
		and plot.prompt == "HARVEST TURNIP",
		"Turnip becomes visibly harvestable after two watered dawns")
	await rig.capture("garden_02_ripe_crop.png")

	var original_slots := Game.bag_slots
	Game.bag_slots = Run.CASE_SLOTS
	for filler_id: StringName in [&"iron_scrap", &"oak_plank", &"cold_iron_core",
			&"fired_cullet", &"bitter_root"]:
		Run.collect(filler_id, 1)
	var ready_before := Game.garden_plot(0)
	rig.check(Run.room_for(&"turnip") == 0 and not Game.harvest_plot(0)
		and Game.garden_plot(0) == ready_before,
		"a full bag refuses harvest atomically and leaves the ripe crop standing")
	Game.bag_slots = original_slots
	Run.reset()
	plot.activate(hero)
	await rig.wait_frames(3)
	rig.check(int(Run.bag.get(&"turnip", 0)) == 1
		and StringName(Game.garden_plot(0).get(&"crop_id", &"x")) == &"",
		"harvesting picks one Turnip into the bag and empties its bed")


func _check_tree_loop(rig, garrison: Garrison, hero: Hero) -> void:
	Run.collect(&"apple_sapling", 1)
	var site := garrison.fruit_tree_sites[0]
	site.activate(hero)
	await rig.wait_frames(2)
	rig.check(StringName(Game.garden_tree(0).get(&"tree_id", &"")) == &"apple"
		and not Run.bag.has(&"apple_sapling"),
		"one Apple Sapling plants permanently in an empty orchard site")

	for day: int in range(4, 8):
		rig.check(Game.water_tree(0), "young Apple tree accepts water before dawn %d" % day)
		Game.advance_garden_dawn(day)
	var mature := Game.garden_tree(0)
	rig.check(int(mature.get(&"age", 0)) == GardenDb.growth_days(&"apple")
		and not bool(mature.get(&"fruit_ready", true))
		and int(mature.get(&"next_fruit_day", 0)) == 10,
		"four tended dawns mature the tree and schedule fruit three dawns later")
	Game.advance_garden_dawn(8)
	Game.advance_garden_dawn(9)
	rig.check(not bool(Game.garden_tree(0).get(&"fruit_ready", true)),
		"fruit does not arrive before its authored cadence")
	Game.advance_garden_dawn(10)
	await rig.wait_frames(3)
	rig.check(bool(Game.garden_tree(0).get(&"fruit_ready", false))
		and site.prompt == "PICK APPLE",
		"the mature tree grows visible pickable fruit on its cadence")
	await rig.capture("garden_03_ripe_apple_tree.png")
	Clock.set_time(10, 8.0)
	site.activate(hero)
	await rig.wait_frames(2)
	rig.check(int(Run.bag.get(&"apple", 0)) == 2
		and not bool(Game.garden_tree(0).get(&"fruit_ready", true))
		and int(Game.garden_tree(0).get(&"next_fruit_day", 0)) == 13,
		"picking yields two Apples and schedules the next fruiting without replanting")


func _check_save_round_trip(rig) -> void:
	const SAVE_SLOT := 2
	var saved_garden: Dictionary = Game.garrison_snapshot().get("garden", {})
	rig.check(Saves.save(SAVE_SLOT), "a live home save writes the planted garden")
	Game.restore_garrison({})
	rig.check(StringName(Game.garden_tree(0).get(&"tree_id", &"x")) == &"",
		"clearing garrison state clears all garden sites")
	var destination := Saves.load_slot(SAVE_SLOT)
	await rig.wait_frames(3)
	var restored := Game.garden_tree(0)
	rig.check(not destination.is_empty()
		and StringName(restored.get(&"tree_id", &"")) == &"apple"
		and int(restored.get(&"age", 0)) == 4
		and int(restored.get(&"next_fruit_day", 0)) == 13,
		"SaveGame round-trips permanent tree age and next-fruit day")
	rig.check(Game.garrison_snapshot().get("garden", {}) == saved_garden,
		"SaveGame round-trips the entire exact garden payload")
	Saves.erase(SAVE_SLOT)


func _capture_mixed_garden(rig) -> void:
	Game.restore_garrison({
		"garden": {
			"plots": [
				{"crop_id": &"turnip", "growth": 0, "watered": true},
				{"crop_id": &"cabbage", "growth": 2, "watered": false},
				{"crop_id": &"sunpepper", "growth": 4, "watered": false},
				{"crop_id": &"turnip", "growth": 1, "watered": false},
			],
			"trees": [
				{"tree_id": &"apple", "age": 4, "watered": false,
					"fruit_ready": true, "next_fruit_day": 10},
				{"tree_id": &"pear", "age": 3, "watered": true,
					"fruit_ready": false, "next_fruit_day": 0},
			],
		},
	})
	await rig.wait_frames(6)
	await rig.capture("garden_04_mixed_yard.png")


func _check_supply_crate(rig, garrison: Garrison, hero: Hero) -> void:
	Game.restore_garrison({"garden": Game.garrison_snapshot().get("garden", {})})
	Run.reset()
	Run.collect(&"turnip", 1)
	Run.collect(&"cabbage", 1)
	Run.collect(&"apple", 2)
	Game.fish_stock = 0
	garrison.supply_box.activate(hero)
	await rig.wait_frames(3)
	rig.check(Game.fish_stock == Game.FISH_CAP
		and not Run.bag.has(&"turnip") and not Run.bag.has(&"cabbage")
		and int(Run.bag.get(&"apple", 0)) == 1,
		"the gate crate stores harvested crops and fruit as Food and preserves exact overflow")


func _supply_line(id: StringName) -> Dictionary:
	for line: Dictionary in SupplyDb.lines():
		if StringName(line.get("id", &"")) == id:
			return line
	return {}
