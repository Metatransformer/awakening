extends RefCounted
## Deterministic transaction and visual proof for exact gathering cargo.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --boot-here --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/gathering_cargo.gd \
##     --out=/tmp/gathering-cargo/proof.png --warmup=60


func run(rig) -> void:
	var garrison := rig.scene() as Garrison
	if not rig.check(garrison != null, "scene is the authored garrison"):
		return
	Clock.running = false
	Game.restore_garrison({})
	Run.reset()
	await rig.wait_frames(8)

	var box := garrison.supply_box as SupplyBox
	if not rig.check(box != null and is_instance_valid(box),
			"the garrison builds one live SupplyBox"):
		return
	rig.check(box.name == &"SupplyBox"
		and box.global_position.distance_to(garrison.gate.global_position) < 10.0
		and box.global_position.z < garrison.gate.global_position.z,
		"SupplyBox stands beside and just inside the south gate")
	rig.check(box.prompt == "DEPOSIT SUPPLIES",
		"the gate crate owns the explicit deposit interaction")
	var hero := rig.root.get_tree().get_first_node_in_group(&"player") as Hero
	if hero != null:
		hero.global_position = box.global_position + Vector3(-1.65, 0.08, 0.0)
		hero.velocity = Vector3.ZERO
		await rig.wait_physics_frames(5)
		rig.check(await rig.until(func() -> bool: return Prompt.focus == box, 2.0),
			"the south-gate approach gives the crate real interaction focus")

	var cam := Camera3D.new()
	cam.fov = 38.0
	garrison.add_child(cam)
	cam.global_position = box.global_position + Vector3(3.4, 2.25, -3.6)
	cam.look_at(box.global_position + Vector3(0.0, 0.72, 0.0), Vector3.UP)
	cam.make_current()
	await rig.wait_frames(5)
	_check_visible_stock(rig, box, 0, 0, "empty")
	await rig.capture("gathering_00_empty_crate.png")

	_check_catalogue_and_sale_policy(rig)
	_check_stack_rules(rig)
	_check_partial_deposit(rig)
	_check_full_no_op(rig)
	_check_home_snapshot(rig)

	Game.restore_garrison({"firewood_stock": Game.FIREWOOD_CAP,
		"fish_stock": Game.FISH_CAP})
	await rig.wait_frames(5)
	_check_visible_stock(rig, box, Game.FIREWOOD_CAP, Game.FISH_CAP, "stocked")
	await rig.capture("gathering_01_stocked_crate.png")

	Run.reset()
	Game.restore_garrison({})
	Clock.running = true
	if rig.fails == 0:
		print("GATHERING CARGO OK")


func _check_catalogue_and_sale_policy(rig) -> void:
	rig.check(SupplyCargoDb.SUPPLY_IDS.size() == 10
		and SupplyCargoDb.FISH_IDS.size() == 4
		and SupplyCargoDb.FOOD_IDS.size() == 9,
		"catalogue exposes Firewood plus four fish and five garden foods")
	for id: StringName in SupplyCargoDb.SUPPLY_IDS:
		var def := ItemDb.get_def(id)
		var expected_category := SupplyCargoDb.CATEGORY_FIREWOOD \
			if id == SupplyCargoDb.FIREWOOD_ID else SupplyCargoDb.CATEGORY_FOOD
		rig.check(def != null and def.is_supply() and def.value == 0
			and SupplyCargoDb.is_supply(id)
			and SupplyCargoDb.category_of(id) == expected_category,
			"%s is exact zero-value %s supply cargo" % [id, expected_category])
		if id == SupplyCargoDb.FIREWOOD_ID:
			rig.check(not SupplyCargoDb.is_fish(id)
				and SupplyCargoDb.food_units(id) == 0,
				"Firewood is not food or fish")
		else:
			rig.check((SupplyCargoDb.is_fish(id) or GardenDb.is_produce(id))
				and SupplyCargoDb.food_units(id) == 1,
				"%s is one exact Food unit" % id)

		Run.reset()
		rig.check(Run.collect(id, 2) == 2, "%s enters the Run bag" % id)
		var before := Run.bag.duplicate()
		var gold_before := Game.gold
		rig.check(Run.line_value(id) == 0
			and Run.sale_value([id]) == 0
			and Run.sell(id) == 0
			and Run.sell_ids([id]) == 0
			and Run.sell_all() == 0
			and Run.bag == before and Game.gold == gold_before,
			"vendor sale paths refuse %s and preserve its cargo" % id)


func _check_stack_rules(rig) -> void:
	var stack_cases: Array[Dictionary] = [{
		"id": SupplyCargoDb.FIREWOOD_ID,
		"stack": 5,
	}]
	for fish_id: StringName in SupplyCargoDb.FISH_IDS:
		stack_cases.append({"id": fish_id, "stack": 6})
	for produce_id: StringName in GardenDb.PRODUCE_IDS:
		stack_cases.append({"id": produce_id, "stack": 8})
	for row: Dictionary in stack_cases:
		var id: StringName = row["id"]
		var stack: int = row["stack"]
		Run.reset()
		rig.check(Run.stack_of(id) == stack,
			"%s stack rule is exactly %d per slot" % [id, stack])
		rig.check(Run.collect(id, stack) == stack
			and int(Run.bag.get(id, 0)) == stack
			and Run.slots_used() == 1,
			"%s fills one exact stack in one bag slot" % id)
		rig.check(Run.collect(id, 1) == 1
			and int(Run.bag.get(id, 0)) == stack + 1
			and Run.slots_used() == 2,
			"%s stacks in place, then opens a second slot at %d" % [id, stack + 1])


func _check_partial_deposit(rig) -> void:
	Run.reset()
	Game.restore_garrison({"firewood_stock": 2, "fish_stock": 2})
	Run.collect(SupplyCargoDb.FIREWOOD_ID, 3)
	Run.collect(SupplyCargoDb.POND_SHINER_ID, 2)
	rig.check(Game.supply_deposit_available(),
		"a partial crate advertises room for carried provisions")
	var receipt := Game.deposit_supplies()
	var moved := receipt.get(&"moved", {}) as Dictionary
	rig.check(int(receipt.get(&"firewood_units", 0)) == 1
		and int(receipt.get(&"food_units", 0)) == 1,
		"partial deposit receipt reports one Firewood and one Food unit")
	rig.check(int(moved.get(SupplyCargoDb.FIREWOOD_ID, 0)) == 1
		and int(moved.get(SupplyCargoDb.POND_SHINER_ID, 0)) == 1,
		"partial deposit receipt preserves both exact moved IDs")
	rig.check(Game.firewood_stock == Game.FIREWOOD_CAP
		and Game.fish_stock == Game.FISH_CAP
		and int(Run.bag.get(SupplyCargoDb.FIREWOOD_ID, 0)) == 2
		and int(Run.bag.get(SupplyCargoDb.POND_SHINER_ID, 0)) == 1,
		"crate fills both remaining capacities and leaves exact overflow in the bag")


func _check_full_no_op(rig) -> void:
	Game.restore_garrison({"firewood_stock": Game.FIREWOOD_CAP,
		"fish_stock": Game.FISH_CAP})
	var before := Run.snapshot()
	rig.check(not Game.supply_deposit_available(),
		"a full crate reports no depositable carried provision")
	var receipt := Game.deposit_supplies()
	rig.check((receipt.get(&"moved", {}) as Dictionary).is_empty()
		and int(receipt.get(&"firewood_units", -1)) == 0
		and int(receipt.get(&"food_units", -1)) == 0
		and Run.snapshot() == before,
		"full-crate no-op returns zero receipt and preserves all cargo state")


func _check_home_snapshot(rig) -> void:
	Run.reset()
	Run.collect(SupplyCargoDb.FIREWOOD_ID, 2)
	Run.collect(SupplyCargoDb.RIVER_PERCH_ID, 3)
	var home := Run.snapshot()
	rig.check(not bool(home.get("in_dungeon", true)),
		"home cargo snapshot is explicitly outside a dungeon")
	Run.reset()
	rig.check(Run.restore(home) and not Run.in_dungeon
		and Run.bag == home.get("bag", {})
		and Run.cased == home.get("cased", {}),
		"Run snapshot/restore round-trips exact Firewood and fish cargo at home")
	Run.enter(188016)
	rig.check(not Run.bag.has(SupplyCargoDb.FIREWOOD_ID)
		and not Run.bag.has(SupplyCargoDb.RIVER_PERCH_ID),
		"starting a new run clears undeposited home cargo with the rest of the Run bag")
	Run.reset()


func _check_visible_stock(rig, box: SupplyBox, firewood: int, food: int,
		label: String) -> void:
	var stock := box.get_node_or_null(^"ProvisionCrate/VisibleStock") as Node3D
	if not rig.check(stock != null, "%s crate exposes its visible stock rack" % label):
		return
	var visible_firewood := 0
	var visible_food := 0
	for child: Node in stock.get_children():
		if not (child as Node3D).visible:
			continue
		if String(child.name).begins_with("Firewood"):
			visible_firewood += 1
		elif String(child.name).begins_with("Food"):
			visible_food += 1
	rig.check(visible_firewood == firewood and visible_food == food,
		"%s crate renders %d Firewood and %d Food tokens"
		% [label, firewood, food])
