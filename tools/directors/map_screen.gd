extends RefCounted
## The map, both sizes, and the corner it moved out of.
##
## Six claims, and only some of them can be checked without looking:
##
##   1. the kit cluster (hands + item cell) is in the BOTTOM-LEFT, not the top
##      right, and the minimap is where it used to be;
##   2. the minimap and the MAP screen draw the SAME plan -- fogged rooms hidden,
##      walked rooms outlined, chests and stairs marked;
##   3. fog lifts by walking: a room the player has not stood in is not drawn;
##   4. `map` (M) opens the MAP tab, and the tab strip pages
##      EQUIP <-> INVENTORY <-> MAP <-> GARRISON on the arrows and on the D-pad;
##   5. what is behind an anchored door is ON the map -- both landings, the
##      treasure chamber and the vault's three rooms (`_annexes`);
##   6. the corner minimap FOLLOWS the hero: he does not move on it, the floor
##      moves under him (`_following`).
##
## (1) and (2) are frames. Look at them. (3) and (5) are asserted against
## `Atlas` before and after, because a fogged room and a room that failed to draw
## are the same pixels. (4) is asserted against which panel is visible.
##
## (6) is asserted in PIXELS, and with a control that runs the other way -- the
## hero blob has to be at the centre of the frame from two different rooms AND
## the rest of the frame has to differ between them. Either half alone passes on
## something broken: the first on a map that draws a pip and no floor, the second
## on the fitted map this replaced. See `_following`.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
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

	# The count moved off the subtitle line and into the header's ROOMS cell, so
	# the check reads the whole screen's text rather than one Label. What is
	# being asserted is unchanged: the map says how much of this floor has been
	# walked, in the same breath as showing it.
	var said := _all_text(map)
	print("  header: %s" % " | ".join(said.slice(0, 12)))
	_check("the map counts what has been walked",
		" ".join(said).contains("%d / %d" % [Atlas.explored_count(), Atlas.rooms.size()]))

	# --- The tab strip pages, and the MAP is the screen that proves it --------
	#
	# **This used to be RB / LB and Q / R** and card #120 removed all four: the
	# owner asked for the shoulder ring to go. What replaced it is the strip
	# itself, which now takes focus — ↑ out of the top of the page lands on the
	# lit tab, ← / → walk the ring one page per press, ↓ drops back into the body.
	#
	# The MAP is where that has to be tested rather than a nicer-looking screen,
	# because the MAP is the trap: its ONLY focusable control is the Back button,
	# so before the strip was focusable a pad player who paged here had no input
	# left that could page away again. If ↑ misses the strip on this screen, the
	# player is stuck on it.
	var pouch: Control = menu.get_node("Root/Screens/PouchScreen")
	var items: Control = menu.get_node("Root/Screens/EquipScreen")
	var garrison: Control = menu.get_node("Root/Screens/GarrisonScreen")
	_key(KEY_UP)
	await rig.wait_seconds(0.3)
	var focus: Control = rig.root.gui_get_focus_owner()
	_check("↑ off the map's Back button reached the tab strip (%s)"
		% ["<nothing>" if focus == null else focus.name],
		focus != null and focus.get_parent() is MenuPageTabs)
	await rig.capture("m_03_tab_focus.png")

	_key(KEY_RIGHT)
	await rig.wait_seconds(PauseMenu.PAGE_TURN_DURATION + 0.08)
	_check("→ paged off the map onto GARRISON", garrison.visible and not map.visible)

	_key(KEY_RIGHT)
	await rig.wait_seconds(PauseMenu.PAGE_TURN_DURATION + 0.08)
	_check("→ again wrapped to EQUIP", items.visible and not garrison.visible)
	await rig.capture("m_04_tab_equip.png")

	_key(KEY_RIGHT)
	await rig.wait_seconds(PauseMenu.PAGE_TURN_DURATION + 0.08)
	_check("→ again -> INVENTORY", pouch.visible and not items.visible)

	_key(KEY_LEFT)
	await rig.wait_seconds(PauseMenu.PAGE_TURN_DURATION + 0.08)
	_check("← came back to EQUIP", items.visible and not pouch.visible)

	_key(KEY_LEFT)
	await rig.wait_seconds(PauseMenu.PAGE_TURN_DURATION + 0.08)
	_check("← again -> GARRISON", garrison.visible)

	_key(KEY_LEFT)
	await rig.wait_seconds(PauseMenu.PAGE_TURN_DURATION + 0.08)
	_check("← again -> back on the MAP", map.visible)

	# And the D-PAD, with real joypad buttons rather than an `InputEventAction`.
	# `shoot.gd` strips every joypad binding in the InputMap so a controller on
	# somebody's desk cannot drive a run, which takes Godot's own D-pad events off
	# `ui_left` / `ui_right` with it; the four are put back here for the length of
	# the run. Without this beat the whole removal is only proven on a keyboard,
	# and it is the PAD that lost its buttons.
	_arm_pad_dpad()
	_pad(JOY_BUTTON_DPAD_RIGHT)
	await rig.wait_seconds(PauseMenu.PAGE_TURN_DURATION + 0.08)
	_check("the D-pad pages the strip like the arrows do",
		garrison.visible and not map.visible)
	_pad(JOY_BUTTON_DPAD_LEFT)
	await rig.wait_seconds(PauseMenu.PAGE_TURN_DURATION + 0.08)
	_check("...and back, so a pad is never stuck on the map", map.visible)

	# --- and M closes it ----------------------------------------------------
	_tap(&"map")
	await rig.wait_seconds(0.35)
	_check("M closed it again", not menu.is_open)
	await rig.capture("m_05_closed.png")

	await _annexes(rig)
	await _following(rig)

	print("MAP OK" if _fail == 0 else "MAP FAILED (%d)" % _fail)


# --- What is behind the anchored doors ----------------------------------------

## The landings, the treasure chamber and the vault's three rooms. None of them
## is a cell (`Atlas.annexes` carries why), and before they were published none
## of them was drawn -- going through a boss door walked you off the edge of the
## map.
##
## Asserted against `Atlas` and then LOOKED AT, the same split the fog beats use
## and for the same reason: a fogged annex and an annex that failed to draw are
## the same pixels.
func _annexes(rig) -> void:
	print("  --- annexes ---")
	for a in Atlas.annexes.size():
		var an: Dictionary = Atlas.annexes[a]
		var boxes: Array = an["boxes"]
		print("  %d: off %s by %s, %d boxes, reaching %.2f cells"
			% [a, an["cell"], an["dir"], boxes.size(),
				float(boxes[boxes.size() - 1]["far"])])
	# The Cistern authors a boss door, a shortcut, a vault and a treasure puzzle
	# (`FloorDb.ANCHORS_STANDARD`), so a floor with none of them published is the
	# bug this beat exists for rather than a floor that happens to be plain.
	_check("the floor published annexes (%d)" % Atlas.annexes.size(),
		not Atlas.annexes.is_empty())
	var deep := 0
	for a in Atlas.annexes.size():
		deep = maxi(deep, (Atlas.annexes[a]["boxes"] as Array).size())
	_check("...and one of them is a chain, not a single box (%d deep)" % deep,
		deep >= 4)
	_check("...all of it still fogged (%d lit)" % _annex_lit(), _annex_lit() == 0)
	await rig.capture("m_06_annex_fogged.png")

	# --- The trigger, walked into -------------------------------------------
	# The grid loop above lifts fog by calling `Atlas.see` directly, which is
	# fine there because `_add_room_trigger` has been in this game for months.
	# The annex triggers are NEW and are the whole of what was missing, so this
	# beat does not get to call `see_annex` -- it puts the hero in the box and
	# checks that the box lit itself.
	#
	# The deepest box of the longest chain, which is the vault's last room: the
	# furthest thing on the floor from the entrance, and the one a bug in the
	# per-box `slot` capture would light the wrong index for.
	var deepest := 0
	for a in Atlas.annexes.size():
		if (Atlas.annexes[a]["boxes"] as Array).size() \
				> (Atlas.annexes[deepest]["boxes"] as Array).size():
			deepest = a
	var chain: Array = Atlas.annexes[deepest]["boxes"]
	var last := chain.size() - 1
	var hero := rig.scene().get_tree().get_first_node_in_group(&"player") as Node3D
	if hero != null:
		hero.global_position = _box_centre(Atlas.annexes[deepest], last)
		await rig.wait_physics_frames(8)
		await rig.wait_frames(4)
		_check("standing in annex %d box %d lit it" % [deepest, last],
			bool(chain[last]["seen"]))
		_check("...and lit ONLY it (%d boxes out of the fog)" % _annex_lit(),
			_annex_lit() == 1)
		await rig.capture("m_06b_annex_walked_in.png")
	else:
		_check("there is a hero to walk into the vault", false)

	# The rest by hand, so the MAP screen frame below has the whole shape in it.
	for a in Atlas.annexes.size():
		for i in (Atlas.annexes[a]["boxes"] as Array).size():
			Atlas.see_annex(a, i)
	await rig.wait_frames(4)
	_check("and every annex box is drawable (%d)" % _annex_lit(),
		_annex_lit() > 0)

	_tap(&"map")
	await rig.wait_seconds(0.4)
	await rig.capture("m_07_annex_walked.png")
	_tap(&"map")
	await rig.wait_seconds(0.35)


## The world position at the middle of one annex box. Cell space and world space
## differ by `Atlas.spacing` and nothing else, and the annex runs down its `dir`
## from its host room's centre -- so this is the same arithmetic `MapDraw` does,
## in metres instead of pixels.
func _box_centre(an: Dictionary, i: int) -> Vector3:
	var box: Dictionary = (an["boxes"] as Array)[i]
	var cell: Vector2i = an["cell"]
	var step := Atlas.step_of(an["dir"])
	var mid: float = (float(box["near"]) + float(box["far"])) * 0.5
	var at := (Vector2(cell) + Vector2(step) * mid) * Atlas.spacing
	return Vector3(at.x, 0.0, at.y)


## Annex boxes out of the fog.
func _annex_lit() -> int:
	var n := 0
	for a in Atlas.annexes.size():
		for box: Dictionary in (Atlas.annexes[a]["boxes"] as Array):
			if bool(box["seen"]):
				n += 1
	return n


# --- The corner minimap follows the hero ---------------------------------------

## The claim is "the hero does not move on the minimap; the floor moves under
## him", and it is checked in PIXELS because that is the only place the claim
## lives -- re-deriving `MapDraw`'s origin here would be the instrument restating
## the code it is measuring.
##
## Two readings and they run in opposite directions, which is the whole point
## (CLAUDE.md §2): the hero blob at the centre of the frame must be there for
## BOTH hero positions, and the rest of the frame must be DIFFERENT between them.
## The first alone passes on a map that draws a hero pip at the centre and
## nothing else; the second alone passes on the fitted map this replaced.
func _following(rig) -> void:
	print("  --- the following minimap ---")
	var hero := rig.scene().get_tree().get_first_node_in_group(&"player") as Node3D
	if hero == null:
		_check("there is a hero to follow", false)
		return
	var rects: Dictionary = Hud.layout_rects()
	if not rects.has(&"minimap"):
		_check("the HUD published a minimap rect", false)
		return
	var frame: Rect2 = rects[&"minimap"][&"rect"]
	print("  minimap frame %s" % frame)

	# Two rooms the player has walked, so both are drawn. Their centres, because
	# a cell centre is a world position this file can name without asking
	# `MapDraw` anything.
	var walked: Array[Vector2i] = []
	for cell: Vector2i in Atlas.rooms:
		if Atlas.is_seen(cell):
			walked.append(cell)
	if walked.size() < 2:
		_check("two rooms are out of the fog to stand in", false)
		return

	# Explicit types: `_stand` is a coroutine, and `await` on one yields Variant
	# however the function is annotated (CLAUDE.md §3's inference trap again).
	var a: Image = await _stand(rig, hero, walked[0], "m_08_follow_a.png")
	var b: Image = await _stand(rig, hero, walked[1], "m_09_follow_b.png")
	if a == null or b == null:
		_check("both minimap frames came back", false)
		return

	var lit_a := _bright_centre(a, frame)
	var lit_b := _bright_centre(b, frame)
	_check("the hero is at the centre of the frame in room %s (%d px)"
		% [walked[0], lit_a], lit_a > 0)
	_check("...and still there from room %s (%d px)" % [walked[1], lit_b],
		lit_b > 0)
	# The control that runs the other way. Without it "centred" is also what a
	# minimap that stopped drawing the floor would look like.
	var moved := _differs(a, b, frame)
	_check("...while the floor under him moved (%d px of the frame changed)"
		% moved, moved > 200)


## Put the hero at a cell's centre, let the HUD repaint, and read the frame back.
func _stand(rig, hero: Node3D, cell: Vector2i, shot: String) -> Image:
	hero.global_position = Vector3(float(cell.x) * Atlas.spacing, 0.0,
		float(cell.y) * Atlas.spacing)
	await rig.wait_frames(6)
	await rig.capture(shot)
	var img := Image.load_from_file("%s/%s" % [rig.out_base().get_base_dir(), shot])
	if img != null and img.get_format() != Image.FORMAT_RGB8:
		img.convert(Image.FORMAT_RGB8)
	return img


## BONE pixels in an 11x11 window at the middle of the frame -- the hero arrow,
## which is the brightest thing on the plate and the only one drawn there.
func _bright_centre(img: Image, frame: Rect2) -> int:
	var c := frame.get_center()
	var n := 0
	for y in range(int(c.y) - 5, int(c.y) + 6):
		for x in range(int(c.x) - 5, int(c.x) + 6):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var p := img.get_pixel(x, y)
			if p.r > 0.7 and p.g > 0.65 and p.b > 0.55:
				n += 1
	return n


## Pixels of the minimap frame that are not the same in the two shots. A coarse
## threshold on purpose: §4.5's internal buffer quantizes to RGB555 and the
## volumetric fog behind the 0.88 plate crawls by one step (CLAUDE.md §3), so
## anything finer than this would be measuring the fog.
func _differs(a: Image, b: Image, frame: Rect2) -> int:
	var n := 0
	for y in range(int(frame.position.y), int(frame.end.y)):
		for x in range(int(frame.position.x), int(frame.end.x)):
			if x < 0 or y < 0 or x >= a.get_width() or y >= a.get_height():
				continue
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			if absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b) > 0.08:
				n += 1
	return n


## Every non-empty Label string in the subtree, in tree order.
func _all_text(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	var l := root as Label
	if l != null and not l.text.strip_edges().is_empty():
		out.append(l.text)
	for c in root.get_children():
		out.append_array(_all_text(c))
	return out


## A real event, not `Input.action_press`: `PauseMenu` reads these in
## `_unhandled_input`, and `action_press` dispatches no InputEvent at all
## (CLAUDE.md §3).
func _tap(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)


## A real joypad button, pressed and released.
func _pad(btn: int) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.device = 0
		ev.button_index = btn
		ev.pressed = pressed
		ev.pressure = 1.0 if pressed else 0.0
		Input.parse_input_event(ev)


## Give `ui_up/down/left/right` their D-pad back for this run — see the beat
## above. These are Godot's own defaults, not anything this game authored, so
## putting them back is restoring what a real pad player has rather than the
## harness inventing a capability.
func _arm_pad_dpad() -> void:
	var want := {
		&"ui_up": JOY_BUTTON_DPAD_UP, &"ui_down": JOY_BUTTON_DPAD_DOWN,
		&"ui_left": JOY_BUTTON_DPAD_LEFT, &"ui_right": JOY_BUTTON_DPAD_RIGHT,
	}
	for action: StringName in want:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var have := false
		for e in InputMap.action_get_events(action):
			var j := e as InputEventJoypadButton
			if j != null and j.button_index == want[action]:
				have = true
		if have:
			continue
		var ev := InputEventJoypadButton.new()
		ev.device = -1
		ev.button_index = want[action]
		InputMap.action_add_event(action, ev)


## A real key, pressed and released.
##
## **Both `keycode` and `physical_keycode`, and that is not belt-and-braces.**
## This used to set the physical one alone, on the reasoning that physical is
## what `Settings` writes and what the InputMap is matched on — true of every
## action this GAME authors, and false of the four the ENGINE ships. Godot's
## built-in `ui_up` / `ui_down` / `ui_left` / `ui_right` carry `keycode` and
## leave `physical_keycode` at 0, so a physical-only event misses them entirely
## and the press lands nowhere.
##
## It cost a whole director's worth of green. When paging moved onto the arrows
## (card #120) the strip beats were pressing ↑ and ← at a menu that never heard
## them: three beats went red and TWO WENT GREEN, because "the map is still
## showing" is what both a working ← and a dropped ← look like from a screen you
## never left.
func _key(code: int) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % what)
	else:
		_fail += 1
		print("MAP FAIL %s" % what)
