extends RefCounted
## The money moved off the HUD. This photographs both halves of that claim.
##
## The HUD used to print a rolling gold total in the bottom-right corner — the
## bag's worth underground, the purse in town. It is gone (hud.gd `_draw_bag`),
## and everything it said now lives on the POUCH: the bag's worth, the purse,
## and the fee to leave, together, on a screen you have stopped to look at.
##
## Three claims, and a screenshot cannot check the first one on its own — a
## corner that is empty because the HUD failed to draw looks exactly like a
## corner that is empty on purpose:
##
##   1. with a full bag and a fat purse, NO figure appears on the HUD;
##   2. the pouch button (`inventory` — I / Select) opens the menu already on
##      the pouch, in one press, from the world;
##   3. that screen names both numbers and the fee.
##
## So (1) is asserted against the HUD's own state rather than against pixels,
## and the frames are there to be looked at.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/pouch_money.gd \
##     --out=/tmp/pouch/x.png --warmup=60

## Enough to be conspicuous. If a number were still being drawn anywhere, these
## are the digits that would be in the frame.
const PURSE := 1450
## Deliberately across the rarity band: the rim colours off the best thing in
## the bag and the slips only say anything when the stacks are uneven.
const HAUL := [
	[&"bone_shard", 9], [&"iron_scrap", 5], [&"ghost_silk", 3], [&"deep_amber", 2],
]

var _fail := 0


func run(rig) -> void:
	Input.use_accumulated_input = false
	var menu: PauseMenu = Menu

	Game.add_gold(PURSE - Game.gold)
	for entry: Array in HAUL:
		Run.collect(entry[0], entry[1])
	await rig.wait_seconds(0.5)

	_check("the run is underground, where the bag has a value",
		Run.in_dungeon)
	_check("the bag is worth something to look at (%d)" % Run.bag_value(),
		Run.bag_value() > 0)
	await rig.capture("f_00_hud_no_money.png")

	# The HUD's own account of itself. `_draw_bag` no longer takes a figure of
	# any kind — the rim and the slips are shapes — so the check is that the
	# corner's number-drawing state is simply not there any more. A drawn total
	# would have to come from `_shown_value`, which was deleted with it.
	var hud_props: Array = []
	for p in Hud.get_property_list():
		hud_props.append(String(p.get("name", "")))
	_check("the HUD kept no rolling total to draw",
		not hud_props.has("_shown_value"))

	# --- One press, from the world, straight to the pouch --------------------
	_tap(&"inventory")
	await rig.wait_seconds(0.4)
	_check("the pouch button opened the menu", menu.is_open)
	var pouch: MenuPouchPanel = menu.get_node("Root/Screens/PouchScreen")
	_check("...already ON the pouch, not at the root", pouch.visible)
	await rig.capture("f_01_pouch.png")

	var header := _find_label(pouch, "SLOTS")
	if header != null:
		print("  header: %s" % header.text)
		_check("the header names the bag's worth", header.text.contains("BAG"))
		_check("the header names the purse", header.text.contains("PURSE"))
		_check("the purse is the real number (%d)" % Game.gold,
			header.text.contains(str(Game.gold)))
	else:
		_fail += 1
		print("POUCH FAIL no header label found on the pouch")

	var fee: Label = _find_label(pouch, "◇")
	if fee != null and fee != header:
		print("  fee row: %s" % fee.text)
	_check("the way out is on this screen", pouch.find_child("Rope", true, false) != null)
	_check("...and it is gone from the items screen",
		menu.get_node("Root/Screens/EquipScreen").find_child("Rope", true, false) == null)

	# Pressing it again closes: a button that opens must close.
	_tap(&"inventory")
	await rig.wait_seconds(0.35)
	_check("the pouch button closed it again", not menu.is_open)
	await rig.capture("f_02_closed.png")

	print("POUCH OK" if _fail == 0 else "POUCH FAILED (%d)" % _fail)


## Depth-first search for the first Label whose text contains `needle`. The
## pouch builds its whole tree in code, so there is no scene path to name.
func _find_label(root: Node, needle: String) -> Label:
	var l := root as Label
	if l != null and l.text.contains(needle):
		return l
	for c in root.get_children():
		var hit := _find_label(c, needle)
		if hit != null:
			return hit
	return null


## A real event, not `Input.action_press`: PauseMenu reads the pouch button in
## `_unhandled_input`, and `action_press` dispatches no InputEvent at all
## (CLAUDE.md §3).
func _tap(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % what)
	else:
		_fail += 1
		print("POUCH FAIL %s" % what)
