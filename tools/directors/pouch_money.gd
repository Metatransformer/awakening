extends RefCounted
## The money moved off the HUD. This photographs both halves of that claim.
##
## The HUD used to print a rolling gold total in the bottom-right corner — the
## bag's worth underground, the purse in the garrison. It is gone (hud.gd
## `_draw_bag`), and the inventory facts now live on the POUCH while carried
## provisions and Rope use live on EQUIPMENT.
##
## Three claims, and a screenshot cannot check the first one on its own — a
## corner that is empty because the HUD failed to draw looks exactly like a
## corner that is empty on purpose:
##
##   1. with a full bag and a fat purse, NO figure appears on the HUD;
##   2. the pouch button (`inventory` — I / Select) opens the menu already on
##      the pouch, in one press, from the world;
##   3. that screen names bag, purse and case but owns no Rope; Equipment does.
##
## So (1) is asserted against the HUD's own state rather than against pixels,
## and the frames are there to be looked at.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
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
	Game.add_escape_ropes(3)
	Game.add_charges(2)
	Game.add_rations(&"hardtack", 4)
	Game.add_rations(&"small_beer", 5)
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

	# The inventory facts live in the header's StatBand, one cell each — a caption
	# and a number in separate Labels — so the check is against everything the
	# screen says, not against one line. It used to be a single header string;
	# what matters was never that they shared a Label, only that a player who
	# stops on this screen can read all three at once.
	var said := _all_text(pouch)
	print("  band: %s" % " | ".join(said))
	var blob := " ".join(said)
	_check("the header names the bag's worth", blob.contains("BAG"))
	_check("the header names the purse", blob.contains("PURSE"))
	_check("the pouch names the document case and its Safe occupancy",
		blob.contains("DOCUMENT CASE") and blob.contains("SAFE"))
	_check("the purse is the real number (%d)" % Game.gold,
		blob.contains(str(Game.gold)))
	_check("Inventory contains no Rope and no old TO LEAVE fee",
		pouch.find_child("Rope", true, false) == null
		and not blob.to_upper().contains("ESCAPE ROPE")
		and not blob.to_upper().contains("TO LEAVE"))

	# Shoulder-page to Equipment through the same action a player uses.
	await _key(rig, KEY_Q)
	await rig.wait_seconds(0.5)
	var equip: MenuEquipPanel = menu.get_node("Root/Screens/EquipScreen")
	_check("the page action reached Equipment", equip.visible)
	var equip_blob := " ".join(_all_text(equip)).to_upper()
	_check("Equipment renders the Rope row and complete provision list",
		equip.find_child("Rope", true, false) is Button
		and equip_blob.contains("PROVISIONS")
		and equip_blob.contains("ESCAPE ROPE")
		and equip_blob.contains("ARROWS")
		and equip_blob.contains("BURST CHARGES")
		and equip_blob.contains("HARDTACK")
		and equip_blob.contains("SMALL BEER"))
	_check("Equipment renders the live Rope stock (3 / %d)" % K.ESCAPE_ROPE_STACK,
		equip_blob.contains("3 / %d" % K.ESCAPE_ROPE_STACK))
	await rig.capture("f_01a_equipment_provisions.png")

	# Pressing it again closes: a button that opens must close.
	_tap(&"inventory")
	await rig.wait_seconds(0.35)
	_check("the pouch button closed it again", not menu.is_open)
	await rig.capture("f_02_closed.png")

	print("POUCH OK" if _fail == 0 else "POUCH FAILED (%d)" % _fail)


## Every non-empty Label string in the subtree, in tree order. The pouch builds
## its whole tree in code, so there is no scene path to name — and the header is
## now a band of one-Label-per-fact cells, which is exactly what this flattens.
func _all_text(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	var l := root as Label
	if l != null and not l.text.strip_edges().is_empty():
		out.append(l.text)
	for c in root.get_children():
		out.append_array(_all_text(c))
	return out


## A real event, not `Input.action_press`: PauseMenu reads the pouch button in
## `_unhandled_input`, and `action_press` dispatches no InputEvent at all
## (CLAUDE.md §3).
func _tap(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _key(rig, code: int) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await rig.wait_frames(2)


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % what)
	else:
		_fail += 1
		print("POUCH FAIL %s" % what)
