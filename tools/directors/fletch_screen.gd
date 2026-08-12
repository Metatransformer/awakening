extends RefCounted
## Card #106 — fletching leaves POUCH and becomes one repeatable row on
## Brannoc's existing forge board.
##
## This director photographs both screens and proves the transaction at the UI
## seam: live bag tallies, atomic refusals, exact cost and yield, the deliberate
## near-full partial batch, and focus surviving every board rebuild.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/ui/menu/_menu_test.tscn \
##     --director=res://tools/directors/fletch_screen.gd \
##     --out=/tmp/fletch/f.png --size=1280x720 --warmup=50

var _fails: int = 0
var _out: String = ""


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_fails += 1
		print("FLETCH FAIL %s" % label)


func run(rig) -> void:
	_out = rig.arg("out", "/tmp/fletch/f.png").get_base_dir()
	Game.grant(&"bow")
	Game.grant(&"hookshot")
	Run.enter(20190920)
	Run.bag.clear()
	Run.premium = 0
	Game.arrows = 0

	await _pouch(rig)
	await _smith(rig)

	if _fails == 0:
		print("FLETCH OK")
	else:
		print("FLETCH FAIL -- %d check(s) failed" % _fails)


## POUCH now owns one verb: the rope. The bag grid spills straight to it, then
## to Back, with no hidden fletch button left in the tree or the focus walk.
func _pouch(rig) -> void:
	if bool(Menu.get(&"_is_open")):
		Menu.call(&"close")
		await rig.wait_frames(6)
	Menu.call(&"open_pouch")
	await rig.wait_frames(12)

	var pouch = Menu.get_node("Root/Screens/PouchScreen")
	_ck("P0 the POUCH screen exists", pouch != null)
	if pouch == null:
		return
	pouch.call(&"refresh")
	await rig.wait_frames(6)
	await rig.capture(_out.path_join("pouch_no_fletch.png"))

	_ck("P1 no Fletch control exists on POUCH",
		pouch.find_child("Fletch", true, false) == null)
	_ck("P2 the bag grid spills directly to Escape Rope",
		pouch._grid.spill_down == pouch._rope)
	_ck("P3 Escape Rope spills directly to Back",
		pouch._rope.find_valid_focus_neighbor(SIDE_BOTTOM) == pouch._back)

	var reached: Array[String] = await _walk_down(rig, pouch)
	_ck("P4 the focus walk contains no fletch stop (%s)" % [reached],
		not reached.has("Fletch"))
	_ck("P5 the focus walk reaches Rope then Back (%s)" % [reached],
		reached.has("Rope") and reached.has(String(pouch._back.name)))
	print("POUCH focus walk reached %s" % [reached])

	Menu.call(&"close")
	await rig.wait_frames(10)


func _smith(rig) -> void:
	var screen := TradeScreen.open(rig.scene(), TradeScreen.Mode.PROGRESSION,
		"THE FORGE", ShopDb, &"smith", "Smithing")
	await rig.wait_frames(16)

	var line := _catalogue_line(ShopDb.FLETCH)
	_ck("S0 one stable fletch line exists", not line.is_empty())
	if line.is_empty():
		return
	_ck("S1 it is repeatable, free, and explicitly a tap",
		int(line["cost"]) == 0 and line.get("holds") == false
			and not ShopDb.crafts(line))
	_ck("S2 its recipe is Fletching.RECIPE", line.get("parts", {}) == Fletching.RECIPE)
	_ck("S3 it owns a named UpgradeLadder row", _has_fletch_group())

	# The default count still serves ordinary forge recipes from the permanent
	# bench; only this one line crosses to Run.bag.
	Game.components.clear()
	Game.add_component(&"whetstone_grit", 7)
	var edge := _catalogue_line(&"edge")
	_ck("S4 normal forge parts still read Game.component_count",
		not edge.is_empty()
			and ShopDb.part_count(edge, &"whetstone_grit")
				== Game.component_count(&"whetstone_grit"))

	# Empty bag: both costs are visibly 0/2 in the shared recipe column.
	screen._refresh()
	_ck("S5 the fletch row is on the smith board",
		await _aim(rig, screen, ShopDb.FLETCH))
	_ck("S6 a recipe-bearing fletch row still wants a TAP",
		is_zero_approx(screen._hold_time(screen._cursor)))
	_ck("S7 empty live bag tallies are 0/2",
		_recipe_have(screen, &"cracked_flint") == 0
			and _recipe_have(screen, &"bone_shard") == 0)
	await rig.capture(_out.path_join("smith_fletch_0_of_2.png"))

	# Fill exactly one recipe and repaint without reopening the counter.
	for id: StringName in Fletching.RECIPE:
		Run.collect(id, int(Fletching.RECIPE[id]))
	screen._refresh()
	await _aim(rig, screen, ShopDb.FLETCH)
	_ck("S8 live bag tallies refresh to 2/2",
		_recipe_have(screen, &"cracked_flint") == 2
			and _recipe_have(screen, &"bone_shard") == 2)
	_ck("S9 detail names batch yield and current quiver/cap",
		_detail_is_current(screen))
	await rig.capture(_out.path_join("smith_fletch_2_of_2.png"))

	# Missing material: the press refuses atomically and rebuilds back onto the
	# same named cell and detail.
	Run.consume(&"bone_shard", int(Fletching.RECIPE[&"bone_shard"]))
	screen._refresh()
	await _aim(rig, screen, ShopDb.FLETCH)
	var missing_before := _recipe_snapshot()
	var arrows_before := Game.arrows
	screen._commit()
	await rig.wait_frames(10)
	_ck("R0 missing material refuses without consuming anything",
		_recipe_snapshot() == missing_before and Game.arrows == arrows_before)
	_ck("R1 refusal refresh retains fletch focus and detail",
		_focused_on_fletch(screen) and _detail_is_current(screen))
	await rig.capture(_out.path_join("smith_fletch_missing.png"))

	# Exact success: the full recipe leaves through Run.consume and one whole
	# batch lands. Gold and permanent components are not part of the transaction.
	Run.collect(&"bone_shard", int(Fletching.RECIPE[&"bone_shard"]))
	screen._refresh()
	await _aim(rig, screen, ShopDb.FLETCH)
	var success_before := _recipe_snapshot()
	var gold_before := Game.gold
	arrows_before = Game.arrows
	screen._commit()
	await rig.wait_frames(10)
	_ck("T0 success consumes exactly the full recipe",
		_consumed_exactly(success_before, _recipe_snapshot()))
	_ck("T1 success adds exactly Fletching.batch arrows",
		Game.arrows - arrows_before == Fletching.batch())
	_ck("T2 fletching costs zero gold", Game.gold == gold_before)
	_ck("T3 success refresh retains fletch focus and detail",
		_focused_on_fletch(screen) and _detail_is_current(screen))
	await rig.capture(_out.path_join("smith_fletch_success.png"))

	# Full quiver: refusal is atomic even while both ingredients are available.
	for id: StringName in Fletching.RECIPE:
		Run.collect(id, int(Fletching.RECIPE[id]))
	Game.arrows = Game.max_arrows
	screen._refresh()
	await _aim(rig, screen, ShopDb.FLETCH)
	var full_before := _recipe_snapshot()
	screen._commit()
	await rig.wait_frames(10)
	_ck("Q0 full quiver refuses atomically",
		Game.arrows == Game.max_arrows and _recipe_snapshot() == full_before)
	_ck("Q1 full-quiver refusal retains fletch focus",
		_focused_on_fletch(screen))

	# Near full: the same full recipe is paid and only the room available lands.
	const ROOM := 2
	Game.arrows = Game.max_arrows - ROOM
	screen._refresh()
	await _aim(rig, screen, ShopDb.FLETCH)
	var near_before := _recipe_snapshot()
	arrows_before = Game.arrows
	screen._commit()
	await rig.wait_frames(10)
	_ck("Q2 near-full quiver receives only its available room",
		Game.arrows == Game.max_arrows and Game.arrows - arrows_before == ROOM)
	_ck("Q3 near-full partial yield still consumes the full recipe",
		_consumed_exactly(near_before, _recipe_snapshot()))
	_ck("Q4 near-full success retains fletch focus and refreshed detail",
		_focused_on_fletch(screen) and _detail_is_current(screen))
	await rig.capture(_out.path_join("smith_fletch_near_full.png"))

	print("FLETCH transaction arrows=%d/%d bag=%s" % [
		Game.arrows, Game.max_arrows, _recipe_snapshot()])


func _walk_down(rig, pouch) -> Array[String]:
	var seen: Array[String] = []
	pouch.call(&"focus_first")
	await rig.wait_frames(2)
	for _i in 32:
		var focused: Control = pouch.get_viewport().gui_get_focus_owner()
		if focused == null:
			break
		var label := String(focused.name)
		if not seen.has(label):
			seen.append(label)
		if focused == pouch._back:
			break
		var next: Control = focused.find_valid_focus_neighbor(SIDE_BOTTOM)
		if next == null:
			break
		next.grab_focus()
		await rig.wait_frames(1)
	return seen


func _catalogue_line(id: StringName) -> Dictionary:
	for line: Dictionary in ShopDb.lines():
		if StringName(line["id"]) == id:
			return line
	return {}


func _has_fletch_group() -> bool:
	var lines := ShopDb.lines()
	var line := _catalogue_line(ShopDb.FLETCH)
	var at := lines.find(line)
	for group: Dictionary in ShopDb.groups():
		if String(group.get("title", "")) != "FLETCHING":
			continue
		var tracks: Array = group.get("tracks", [])
		return tracks.size() == 1 and int(tracks[0].get("line", -1)) == at \
			and int(tracks[0].get("rungs", 0)) == 1
	return false


func _row(screen, id: StringName) -> Dictionary:
	for row: Dictionary in screen._rows:
		if row.get("kind") == &"buy" and StringName(row["line"]["id"]) == id:
			return row
	return {}


func _aim(rig, screen, id: StringName) -> bool:
	var row := _row(screen, id)
	if row.is_empty():
		return false
	screen._point_at(screen._rows.find(row))
	await rig.wait_frames(8)
	row = _row(screen, id)
	return not row.is_empty() and screen._cursor == screen._rows.find(row)


## Read the number actually painted in the recipe column, paired with the need
## painted beside it. Returning -1 means the UI did not draw that part at all.
func _recipe_have(screen, id: StringName) -> int:
	var def := ItemDb.get_def(id)
	if def == null:
		return -1
	for child in screen._recipe.get_children():
		if child.get_child_count() < 2:
			continue
		var what := child.get_child(0) as Label
		var tally := child.get_child(1) as Label
		if what == null or tally == null:
			continue
		if not String(what.text).begins_with(def.display_name):
			continue
		var need: int = Fletching.RECIPE[id]
		if not String(what.text).ends_with("×%d" % need):
			return -1
		return String(tally.text).trim_prefix("have ").to_int()
	return -1


func _recipe_snapshot() -> Dictionary:
	var out := {}
	for id: StringName in Fletching.RECIPE:
		out[id] = int(Run.bag.get(id, 0))
	return out


func _consumed_exactly(before: Dictionary, after: Dictionary) -> bool:
	for id: StringName in Fletching.RECIPE:
		if int(before.get(id, 0)) - int(after.get(id, 0)) \
				!= int(Fletching.RECIPE[id]):
			return false
	return true


func _focused_on_fletch(screen) -> bool:
	var row := _row(screen, ShopDb.FLETCH)
	if row.is_empty() or screen._cursor != screen._rows.find(row):
		return false
	var cell: Button = screen._ladder.cell_at(
		screen._ladder.slot_of_line(screen._cursor))
	return cell != null and screen.get_viewport().gui_get_focus_owner() == cell


func _detail_is_current(screen) -> bool:
	var text := String(screen._tip.blurb.text)
	return text.contains("Makes %d arrows per batch" % Fletching.batch()) \
		and text.contains("Quiver %d / %d" % [Game.arrows, Game.max_arrows])
