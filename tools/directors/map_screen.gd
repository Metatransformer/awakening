extends RefCounted
## The map, both sizes, and the corner it moved out of.
##
## Four claims, and only the last two can be checked without looking:
##
##   1. the kit cluster (hands + item cell) is in the BOTTOM-LEFT, not the top
##      right, and the minimap is where it used to be;
##   2. the minimap and the MAP screen draw the SAME plan -- fogged rooms hidden,
##      walked rooms outlined, chests and stairs marked;
##   3. fog lifts by walking: a room the player has not stood in is not drawn;
##   4. `map` (M) opens the MAP tab, and RB/LB page ITEMS <-> POUCH <-> MAP.
##
## (1) and (2) are frames. Look at them. (3) is asserted against `Atlas.seen`
## before and after, because a fogged room and a room that failed to draw are
## the same pixels. (4) is asserted against which panel is visible.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/map_screen.gd \
##     --out=/tmp/map/x.png --warmup=60

var _fail := 0


func run(rig) -> void:
	Input.use_accumulated_input = false
	var menu: PauseMenu = Menu

	await rig.wait_seconds(0.5)

	# --- The plan got published ---------------------------------------------
	_check("the run is underground", Run.in_dungeon)
	_check("Atlas has a floor (level %d)" % Atlas.level, Atlas.has_floor())
	_check("...with rooms in it (%d)" % Atlas.rooms.size(), Atlas.rooms.size() > 1)
	var marked := 0
	for cell: Vector2i in Atlas.marks:
		marked += (Atlas.marks[cell] as Array).size()
	_check("...and markers on it (%d across %d rooms)" % [marked, Atlas.marks.size()],
		marked >= 2)
	print("  bounds %s  entrance %s  spacing %.1f"
		% [Atlas.bounds(), Atlas.entrance, Atlas.spacing])

	# --- Fog: one room walked, one room drawn -------------------------------
	_check("only the arrival room is off the fog (%d seen)" % Atlas.explored_count(),
		Atlas.explored_count() == 1)
	await rig.capture("m_00_fog_full.png")

	# --- The corner it moved out of -----------------------------------------
	# Asserted against the HUD's own geometry, not pixels: an empty top-right is
	# also what a HUD that failed to draw looks like.
	var s: Vector2 = rig.scene().get_viewport().get_visible_rect().size
	var hands: Vector2 = Hud.call(&"_hands_origin", s)
	_check("the kit cluster is on the LEFT (x=%.0f of %.0f)" % [hands.x, s.x],
		hands.x < s.x * 0.25)
	_check("...and low (y=%.0f of %.0f)" % [hands.y, s.y], hands.y > s.y * 0.60)
	_check("the minimap is on the right (%.2f)" % Pal.MINIMAP_RIGHT,
		Pal.MINIMAP_RIGHT > 0.8)
	_check("...and at the top (%.2f)" % Pal.MINIMAP_TOP, Pal.MINIMAP_TOP < 0.2)

	# --- Walk the floor, the way the game does ------------------------------
	# Through the same door the room trigger writes: `Atlas.see`. Teleporting the
	# hero into each room would exercise the trigger too, but at eight rooms it is
	# eight physics settles and a director that takes a minute to say one thing.
	var walked := 0
	for cell: Vector2i in Atlas.rooms:
		if walked >= maxi(2, Atlas.rooms.size() * 2 / 3):
			break
		Atlas.see(cell)
		walked += 1
	await rig.wait_frames(4)
	_check("walking lifted the fog (%d of %d rooms)"
		% [Atlas.explored_count(), Atlas.rooms.size()],
		Atlas.explored_count() > 1 and Atlas.explored_count() < Atlas.rooms.size())
	await rig.capture("m_01_fog_partial.png")

	# --- M opens the MAP ----------------------------------------------------
	_tap(&"map")
	await rig.wait_seconds(0.4)
	_check("M opened the menu", menu.is_open)
	var map: MenuMapPanel = menu.get_node("Root/Screens/MapScreen")
	_check("...straight onto the MAP, not the root", map.visible)
	await rig.capture("m_02_map_screen.png")

	var sub := _find_label(map, "rooms walked")
	if sub != null:
		print("  subtitle: %s" % sub.text.replace("\n", " / "))
		_check("the map counts what has been walked",
			sub.text.contains("%d of %d" % [Atlas.explored_count(), Atlas.rooms.size()]))
	else:
		_check("the map counts what has been walked", false)

	# --- RB / LB page the tabs ----------------------------------------------
	var pouch: Control = menu.get_node("Root/Screens/PouchScreen")
	var items: Control = menu.get_node("Root/Screens/EquipScreen")
	_tap(&"ui_tab_next")
	await rig.wait_seconds(0.3)
	_check("RB paged off the map onto ITEMS", items.visible and not map.visible)
	await rig.capture("m_03_tab_items.png")

	_tap(&"ui_tab_next")
	await rig.wait_seconds(0.3)
	_check("RB again -> POUCH", pouch.visible and not items.visible)
	await rig.capture("m_04_tab_pouch.png")

	_tap(&"ui_tab_prev")
	await rig.wait_seconds(0.3)
	_check("LB came back to ITEMS", items.visible and not pouch.visible)

	_tap(&"ui_tab_prev")
	await rig.wait_seconds(0.3)
	_check("LB again -> back on the MAP (the ring wraps)", map.visible)

	# The same ring on the KEYBOARD, and with real key events rather than
	# InputEventAction. `ui_tab_prev`/`ui_tab_next` are registered at runtime by
	# `PauseMenu._ensure_pad_ui_actions` -- they are in no .tscn and not in
	# project.godot -- so this is the beat that proves the registration actually
	# happened rather than that the action name exists.
	_key(KEY_E)
	await rig.wait_seconds(0.3)
	_check("E paged the tabs like RB does", items.visible and not map.visible)
	_key(KEY_Q)
	await rig.wait_seconds(0.3)
	_check("Q paged back like LB does", map.visible and not items.visible)

	# --- and M closes it ----------------------------------------------------
	_tap(&"map")
	await rig.wait_seconds(0.35)
	_check("M closed it again", not menu.is_open)
	await rig.capture("m_05_closed.png")

	print("MAP OK" if _fail == 0 else "MAP FAILED (%d)" % _fail)


## Depth-first search for the first Label whose text contains `needle`. The map
## panel builds its whole tree in code, so there is no scene path to name.
func _find_label(root: Node, needle: String) -> Label:
	var l := root as Label
	if l != null and l.text.contains(needle):
		return l
	for c in root.get_children():
		var hit := _find_label(c, needle)
		if hit != null:
			return hit
	return null


## A real event, not `Input.action_press`: `PauseMenu` reads these in
## `_unhandled_input`, and `action_press` dispatches no InputEvent at all
## (CLAUDE.md §3).
func _tap(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)


## A real key, pressed and released. `physical_keycode` because that is what
## Settings writes and what the InputMap is matched on.
func _key(code: int) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % what)
	else:
		_fail += 1
		print("MAP FAIL %s" % what)
