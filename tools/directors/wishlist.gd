extends RefCounted
## Card #105 -- live loot uses, recipe wishlists, and a bulk sale that keeps what
## the current town game needs.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/ui/menu/_menu_test.tscn \
##     --director=res://tools/directors/wishlist.gd \
##     --out=/tmp/wishlist/w.png --size=1280x720 --warmup=50

const TRASH := &"deep_amber"
const COMPONENT := &"whetstone_grit"
const RELIC := &"tally_ledger"

var _fails: int = 0
var _out: String = ""


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_fails += 1
		print("WISHLIST FAIL %s" % label)


func run(rig) -> void:
	_out = rig.arg("out", "/tmp/wishlist/w.png").get_base_dir()
	Game.grant(&"bow")
	Game.grant(&"sword")
	Game.restore_wishlist_lines([])
	Settings.auto_wishlist = true
	Run.enter(105105)
	_seed_bag()

	await _auto_and_pouch(rig)
	await _manual_pin(rig)
	_save_shape()
	await _safe_sale(rig)
	await _current_rung(rig)

	Input.action_release(&"jump")
	if _fails == 0:
		print("WISHLIST OK")
	else:
		print("WISHLIST FAIL -- %d check(s) failed" % _fails)


func _seed_bag() -> void:
	Run.bag.clear()
	Run.premium = 37
	Run.bag[&"bone_shard"] = 4
	Run.bag[&"cracked_flint"] = 4
	Run.bag[TRASH] = 2
	Run.bag[COMPONENT] = 1
	Run.bag[RELIC] = 1
	Bus.bag_changed.emit(Run.bag, Run.bag_value())


func _auto_and_pouch(rig) -> void:
	var bone_uses := Wishlist.current_uses(&"bone_shard")
	_ck("A0 current tables name FLETCH ARROWS for Bone Shard",
		_has_label(bone_uses, "FLETCH ARROWS"))
	_ck("A1 fletching inputs auto-star while the option is on",
		Wishlist.is_auto_wishlisted(&"bone_shard")
			and Wishlist.is_auto_wishlisted(&"cracked_flint"))
	_ck("A2 unrelated loot is explicitly safe to sell",
		Wishlist.current_uses(TRASH).is_empty()
			and Wishlist.usage_sentence(TRASH).to_lower().contains("safe to sell"))

	if bool(Menu.get(&"_is_open")):
		Menu.call(&"close")
		await rig.wait_frames(6)
	Menu.call(&"open_pouch")
	await rig.wait_frames(12)
	var pouch = Menu.get_node("Root/Screens/PouchScreen")
	pouch.call(&"refresh")
	await rig.wait_frames(4)
	_ck("A3 POUCH paints the fletching ingredient with a star",
		_pouch_star(pouch, &"bone_shard"))
	_ck("A4 POUCH leaves unrelated loot unstarred", not _pouch_star(pouch, TRASH))
	_focus_pouch_item(pouch, &"bone_shard")
	_ck("A5 POUCH detail carries the live usage sentence",
		String(pouch._tip.blurb.text).contains("FLETCH ARROWS"))
	await rig.capture(_out.path_join("pouch_item_usage.png"))
	await rig.wait_frames(6)
	Menu.call(&"close")
	await rig.wait_frames(8)

	var setting_changed := [false]
	var watch: Callable = func(section: StringName, key: StringName,
			_value: Variant) -> void:
		if section == &"game" and key == &"auto_wishlist":
			setting_changed[0] = true
	Settings.changed.connect(watch)
	Settings.set_auto_wishlist(false)
	Settings.changed.disconnect(watch)
	_ck("A6 the persisted option emits and removes automatic stars",
		bool(setting_changed[0]) and not Wishlist.is_wishlisted(&"bone_shard")
			and not Wishlist.is_wishlisted(&"cracked_flint"))


func _manual_pin(rig) -> void:
	var screen := TradeScreen.open(rig.scene(), TradeScreen.Mode.PROGRESSION,
		"THE FORGE", ShopDb, &"smith", "Smithing")
	await rig.wait_frames(14)
	var i := _buy_index(screen, ShopDb.FLETCH)
	_ck("M0 fletching is a current recipe row", i >= 0)
	if i < 0:
		return
	screen._point_at(i)

	# The exact polled/release-armed seam the live screen uses. There is no raw Y
	# key and no director-only mutation standing in for the player's press.
	Input.action_release(&"jump")
	screen._armed_jump = false
	screen._tick_input(0.0)
	Input.action_press(&"jump")
	screen._tick_input(0.0)
	Input.action_release(&"jump")
	screen._tick_input(0.0)
	await rig.wait_frames(4)

	var key := Wishlist.line_key(ShopDb, _line(ShopDb, ShopDb.FLETCH))
	_ck("M1 jump/Y pins the stable forge line key", Game.is_wishlist_line_pinned(key))
	_ck("M2 manual pin marks both recipe inputs with auto off",
		Wishlist.is_manual_wishlisted(&"bone_shard")
			and Wishlist.is_manual_wishlisted(&"cracked_flint"))
	screen._refresh()
	i = _buy_index(screen, ShopDb.FLETCH)
	_ck("M3 refresh keeps a visible star on the pinned row",
		i >= 0 and String(screen._rows[i]["sub"]).contains("★"))
	screen._point_at(i)
	await rig.capture(_out.path_join("manual_recipe_pin.png"))
	screen.close()
	await rig.wait_frames(8)


func _save_shape() -> void:
	var fletch_key := Wishlist.line_key(ShopDb, _line(ShopDb, ShopDb.FLETCH))
	var encoded := Game.wishlist_save_data()
	Game.wishlist_lines.clear()
	Game.restore_wishlist_lines(encoded)
	var source := FileAccess.get_file_as_string("res://scripts/autoload/save_game.gd")
	_ck("S0 save data contains stable strings, not derived item ids",
		encoded.has(String(fletch_key)) and not encoded.has("bone_shard"))
	_ck("S1 load reconstruction restores a StringName-keyed pin",
		Game.wishlist_lines.has(fletch_key)
			and typeof(Game.wishlist_lines.keys()[0]) == TYPE_STRING_NAME)
	_ck("S2 the additive save writer and reader both own wishlist_lines",
		source.contains("\"wishlist_lines\": Game.wishlist_save_data()")
			and source.contains("Game.restore_wishlist_lines"))


func _safe_sale(rig) -> void:
	_seed_bag()
	var screen := TradeScreen.open(rig.scene(), TradeScreen.Mode.TRADE,
		"THE STALL", SupplyDb, &"quartermaster", "Trade", SupplyDb.STOCK_IDS)
	await rig.wait_frames(14)
	var bulk_i := _kind_index(screen, &"all")
	_ck("B0 the vendor offers one bulk action", bulk_i >= 0)
	if bulk_i < 0:
		return
	var bulk: Dictionary = screen._rows[bulk_i]
	var ids: Array[StringName] = bulk["ids"]
	var quoted := Run.sale_value(ids)
	_ck("B1 bulk intent is SELL UNMARKED", bulk["label"] == "SELL UNMARKED")
	_ck("B2 quote is the exact premium-prorated payout",
		int(bulk["price"]) == quoted and String(bulk["sub"]).contains(str(quoted)))
	_ck("B3 only ordinary trash is in the sale slice", ids == [TRASH])
	screen._point_at(bulk_i)
	await rig.capture(_out.path_join("sell_unmarked.png"))

	var gold_before := Game.gold
	var premium_before := Run.premium
	screen._commit()
	await rig.wait_frames(6)
	_ck("B4 displayed payout is what lands", Game.gold - gold_before == quoted)
	_ck("B5 trash sold while wished inputs, component and relic remain",
		not Run.bag.has(TRASH)
			and Run.bag.get(&"bone_shard", 0) == 4
			and Run.bag.get(&"cracked_flint", 0) == 4
			and Run.bag.get(COMPONENT, 0) == 1
			and Run.bag.get(RELIC, 0) == 1)
	_ck("B6 only the sold slice's heat premium left",
		Run.premium >= 0 and Run.premium < premium_before)

	var bone_i := _sell_index(screen, &"bone_shard")
	_ck("B7 wished item is still an individually sellable starred row",
		bone_i >= 0 and bool(screen._rows[bone_i]["star"]))
	if bone_i >= 0:
		screen._point_at(bone_i)
		gold_before = Game.gold
		screen._commit()
		await rig.wait_frames(5)
		_ck("B8 individual starred sale succeeds",
			not Run.bag.has(&"bone_shard") and Game.gold > gold_before)
	screen.close()
	await rig.wait_frames(8)


func _current_rung(rig) -> void:
	for relic: StringName in RelicDb.RUNG_RELICS:
		Game.set_flag(RelicDb.flag_donated(relic))
	Game.upgrades[&"edge"] = 2
	var edge := _line(ShopDb, &"edge")
	var key := Wishlist.line_key(ShopDb, edge)
	if not Game.is_wishlist_line_pinned(key):
		Game.toggle_wishlist_line(key)
	Game.components.clear()
	Game.add_component(&"whetstone_grit", 10)
	Game.add_component(&"cold_iron_core", 1)
	if Game.gold < 10000:
		Game.add_gold(10000 - Game.gold)
	_ck("R0 current third edge rung manually needs its core",
		Wishlist.is_manual_wishlisted(&"cold_iron_core"))

	var screen := TradeScreen.open(rig.scene(), TradeScreen.Mode.PROGRESSION,
		"THE FORGE", ShopDb, &"smith", "Smithing")
	await rig.wait_frames(14)
	var i := _buy_index(screen, &"edge")
	_ck("R1 current edge rung is on the board", i >= 0)
	if i >= 0:
		screen._point_at(i)
		screen._commit()
		await rig.wait_frames(6)
	_ck("R2 successful purchase advances the authored ladder", Game.forge_level(&"edge") == 3)
	_ck("R3 completed line drops its stale manual ingredient need",
		not Wishlist.is_manual_wishlisted(&"cold_iron_core"))
	screen.close()


func _line(db: GDScript, id: StringName) -> Dictionary:
	for line: Dictionary in db.lines():
		if StringName(line.get("id", &"")) == id:
			return line
	return {}


func _has_label(uses: Array[Dictionary], label: String) -> bool:
	for use: Dictionary in uses:
		if String(use.get("label", "")) == label:
			return true
	return false


func _buy_index(screen, id: StringName) -> int:
	for i in screen._rows.size():
		var row: Dictionary = screen._rows[i]
		if row.get("kind") == &"buy" and StringName(row["line"].get("id", &"")) == id:
			return i
	return -1


func _sell_index(screen, id: StringName) -> int:
	for i in screen._rows.size():
		var row: Dictionary = screen._rows[i]
		if row.get("kind") == &"item" and StringName(row.get("id", &"")) == id:
			return i
	return -1


func _kind_index(screen, kind: StringName) -> int:
	for i in screen._rows.size():
		if screen._rows[i].get("kind") == kind:
			return i
	return -1


func _pouch_star(pouch, id: StringName) -> bool:
	for case_side: bool in [true, false]:
		var ids: Array[StringName] = pouch._case_ids if case_side else pouch._cell_ids
		var counts: Array[int] = pouch._case_counts if case_side else pouch._cell_counts
		var entries: Array = pouch._cells_of(ids, counts)
		var at: int = ids.find(id)
		if at >= 0:
			return bool(entries[at].get("star", false))
	return false


func _focus_pouch_item(pouch, id: StringName) -> void:
	var at: int = pouch._case_ids.find(id)
	if at >= 0:
		pouch._describe(at, true)
		return
	at = pouch._cell_ids.find(id)
	if at >= 0:
		pouch._describe(at, false)
