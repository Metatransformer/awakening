extends RefCounted
## The MAP screen's view: the right stick pans it, the mouse drags it, the wheel
## zooms, and the corner minimap does not move at all. Card #122.
##
## **Everything here is checked twice, once in each direction.** A director that
## only proves the plan MOVED passes on a panel that redraws something different
## every frame, and a director that only proves it SAT STILL passes on a panel
## whose input never arrived. So every beat that shows motion has a null case
## beside it that must read exactly zero:
##
##   * an untouched stick, with the pad's bindings LIVE, moves the plan by 0 px;
##   * letting the stick go leaves the pan where it was, to the float;
##   * mouse motion with no button held moves it by 0 px;
##   * reopening the screen puts the view back bit-for-bit where it opened;
##   * and the corner minimap is the same pixels before the screen was opened
##     and after it was closed -- which is the whole of the "one map at two
##     sizes, and this card must not make it two" rule in `MapDraw`'s header.
##
## The zeros are the load-bearing half. `map_screen.gd` already shows that the
## MAP screen draws a floor; nothing but a zero can show that it draws the SAME
## floor when nobody has touched it.
##
## **The pad's bindings are put back, deliberately, and taken away again.**
## `shoot.gd._deafen_the_gamepad` strips every joypad binding out of the InputMap
## for the life of a run, because a stick resting outside its deadzone reports
## `cam_*` held and walks the hero off mid-beat -- and that is the right default
## for 140 directors. It also makes the right stick unreachable through the
## action map, which is the one thing this card is about. So `_rebind_pad`
## restores the four `cam_*` axis bindings from `project.godot` for the length of
## the pad beats and `_unbind_pad` takes them off again; everything after that
## point runs deafened like every other director.
##
## While they are live a REAL stick on this Mac could push the plan, and that is
## exactly what the null case above is positioned to catch -- it runs first, with
## the bindings already restored, and prints `Input.get_connected_joypads()` and
## the live axis strengths next to its verdict. A resting pad fails it loudly
## rather than quietly biasing the beats after it.
##
## The events are real `InputEventJoypadMotion` and real `InputEventMouseButton`
## / `InputEventMouseMotion`, never `Input.action_press` -- CLAUDE.md §3.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/map_pan.gd \
##     --out=/tmp/mappan/x.png --warmup=60

## The four axis bindings `project.godot` gives the right stick, which
## `_deafen_the_gamepad` erased. Restored verbatim rather than approximated: an
## action bound to an axis this file invented would prove that THIS FILE can pan
## the map, which is not the claim.
const PAD_AXES := [
	[&"cam_left", JOY_AXIS_RIGHT_X, -1.0],
	[&"cam_right", JOY_AXIS_RIGHT_X, 1.0],
	[&"cam_up", JOY_AXIS_RIGHT_Y, -1.0],
	[&"cam_down", JOY_AXIS_RIGHT_Y, 1.0],
]
## Per-channel difference that counts as ink, summed over RGB. The same coarse
## threshold `map_screen.gd` uses and for the same reason -- §4.5's internal
## buffer quantizes to RGB555 and anything finer measures the quantizer.
const INK := 0.08

var _fail := 0
var _rig
var _map: MenuMapPanel
var _plan := Rect2()


func run(rig) -> void:
	_rig = rig
	# Accumulated motion merges a drag's events into one and this director counts
	# on each of six landing separately.
	Input.use_accumulated_input = false
	var menu: PauseMenu = Menu

	await rig.wait_seconds(0.5)
	_check("the run is underground", Run.in_dungeon)
	_check("Atlas has a floor (level %d, %d rooms, %d annexes)"
		% [Atlas.level, Atlas.rooms.size(), Atlas.annexes.size()],
		Atlas.has_floor())
	# A floor with an annex on it, which is half of what made the fit unreadable
	# and is what the card names as the thing to open the map on.
	_check("...with annexes hanging off the grid (%d)" % Atlas.annexes.size(),
		not Atlas.annexes.is_empty())

	# Everything out of the fog, so the plan being drawn is the whole floor and a
	# difference between two frames cannot be a room that lit itself.
	for cell: Vector2i in Atlas.rooms:
		Atlas.see(cell)
	for a in Atlas.annexes.size():
		for i in (Atlas.annexes[a]["boxes"] as Array).size():
			Atlas.see_annex(a, i)
	await rig.wait_frames(4)
	print("  bounds %s  spacing %.1f" % [Atlas.bounds(), Atlas.spacing])

	# CLAUDE.md §3: the volumetric fog is reprojected with a jitter that never
	# converges, so two captures of a STOPPED scene are not the same pixels
	# unless this is called. Every zero below depends on it.
	rig.still_the_frame()
	await rig.wait_frames(6)

	# --- The minimap, before the MAP screen has ever been opened -------------
	await rig.capture("n_00_hud_before.png")

	# --- Open the MAP -------------------------------------------------------
	_tap(&"map")
	await rig.wait_seconds(0.4)
	_check("M opened the menu on the MAP", menu.is_open)
	_map = menu.get_node("Root/Screens/MapScreen") as MenuMapPanel
	_check("...and the MAP panel is up", _map != null and _map.visible)
	if _map == null:
		print("MAP PAN FAILED (%d)" % _fail)
		return
	var canvas: Control = _map._canvas
	# The panel is on a CanvasLayer with no transform of its own, so a Control's
	# global rect is already viewport pixels, and `shoot.gd._size_the_window`
	# makes a capture 1:1 with the viewport. Grown by the same inset `_plan_box`
	# uses, so this rect is the plan and not the well it sits in.
	_plan = canvas.get_global_rect().grow(-MenuMapPanel.PLAN_PAD)
	print("  plan rect %s  fit pitch %.1f px/cell"
		% [_plan, MapDraw.fit_pitch(Rect2(Vector2.ZERO, canvas.size).grow(
			-MenuMapPanel.PLAN_PAD), Atlas.bounds())])

	var v := _map.view()
	var lim: Vector2 = v[&"limit"]
	_check("the view opens zoomed in (%.2fx, not the %.2fx fit)"
		% [float(v[&"zoom"]), MenuMapPanel.ZOOM_MIN],
		is_equal_approx(float(v[&"zoom"]), MenuMapPanel.OPEN_ZOOM))
	_check("...centred (pan %s)" % v[&"pan"], v[&"pan"] == Vector2.ZERO)
	# The decision the header argues for, asserted rather than described, and on
	# BOTH axes. `or` was not enough: the first run of this director passed it
	# with `limit (0.0, 147.75)` and then failed every horizontal beat, because
	# `pan_limit` was clamping to the overflow and a 6x7 floor in this 820x394
	# well does not overflow sideways until 2.4x. A pan control that is dead in
	# two directions out of four is the exact failure the card was written about.
	_check("...and the pan has somewhere to go on the first frame, both ways "
		+ "(limit %s)" % lim, lim.x > 1.0 and lim.y > 1.0)
	await rig.capture("p_00_open.png")

	await _null_stick()
	await _pad_pans()
	await _mouse_drags(canvas)
	await _zoom_to_the_fit()

	# --- The minimap, after ---------------------------------------------------
	_tap(&"map")
	await rig.wait_seconds(0.4)
	_check("M closed the menu again", not menu.is_open)
	await rig.wait_frames(6)
	await rig.capture("n_01_hud_after.png")
	var rects: Dictionary = Hud.layout_rects()
	if rects.has(&"minimap"):
		var frame: Rect2 = rects[&"minimap"][&"rect"]
		var moved := _differs("n_00_hud_before.png", "n_01_hud_after.png", frame)
		print("  minimap frame %s" % frame)
		# The rule in `MapDraw`'s header, in pixels. `draw_map` grew two optional
		# arguments and `Hud._draw_minimap` passes neither, so the corner map has
		# to be the same picture it was before this card -- and "has to be" is
		# not a proof.
		_check("the corner minimap is unchanged (%d px of its frame differ)"
			% moved, moved == 0)
	else:
		_check("the HUD published a minimap rect", false)

	print("MAP PAN OK" if _fail == 0 else "MAP PAN FAILED (%d)" % _fail)


# --- The null case ------------------------------------------------------------

## The pad's bindings go live and NOTHING is sent. This is the control that runs
## the other way from every beat below it (CLAUDE.md §2): it is the only thing
## here that can catch a false positive, because a panel that drifted on its own
## -- off a resting stick, off a `_process` that integrates something it should
## not, off a container still settling its size -- would pass every "the plan
## moved" check in this file by moving for the wrong reason.
func _null_stick() -> void:
	print("  --- null case: the stick is not touched ---")
	_rebind_pad()
	print("  connected joypads: %s" % str(Input.get_connected_joypads()))
	print("  axis strength now: x %.3f  y %.3f"
		% [Input.get_axis(&"cam_left", &"cam_right"),
			Input.get_axis(&"cam_up", &"cam_down")])
	await _rig.wait_seconds(0.6)
	var v := _map.view()
	_check("36 frames with the pad live and untouched: pan %s" % v[&"pan"],
		v[&"pan"] == Vector2.ZERO)
	await _rig.capture("p_01_null.png")
	var moved := _differs("p_00_open.png", "p_01_null.png", _plan)
	_check("...and the plan is the same %d px it was (%d differ)"
		% [int(_plan.size.x * _plan.size.y), moved], moved == 0)


# --- The right stick ----------------------------------------------------------

## Push right, then down, with real `InputEventJoypadMotion`. Right is the beat
## the owner described; down is the one that finds the clamp.
func _pad_pans() -> void:
	print("  --- the right stick ---")
	_axis(JOY_AXIS_RIGHT_X, 1.0)
	await _rig.wait_seconds(0.5)
	_axis(JOY_AXIS_RIGHT_X, 0.0)
	await _rig.wait_frames(4)
	var v := _map.view()
	var pan: Vector2 = v[&"pan"]
	# Sign, not just magnitude. Pushing the stick right moves the VIEW right, so
	# the plan slides LEFT under the frame and `pan.x` goes negative -- the
	# camera convention this stick has in the world. A pan that went the other
	# way would still pass a check on `length()`.
	_check("half a second of stick-right slid the plan left (pan %s)" % pan,
		pan.x < -20.0)
	_check("...and did not drag it up or down (%.2f)" % pan.y,
		is_zero_approx(pan.y))
	await _rig.capture("p_02_pad_right.png")
	var moved := _differs("p_00_open.png", "p_02_pad_right.png", _plan)
	_check("...and the frame says so (%d px of the plan differ)" % moved,
		moved > 2000)

	# Letting go stops it. The second null case, and the one that would catch a
	# `_process` that kept integrating a stale axis.
	await _rig.wait_seconds(0.4)
	_check("letting the stick go left the pan exactly where it was (%s)"
		% _map.view()[&"pan"], _map.view()[&"pan"] == pan)

	# Two seconds of down against a limit that half a second reaches, so the
	# clamp is what stops it rather than the clock.
	var lim: Vector2 = _map.view()[&"limit"]
	_axis(JOY_AXIS_RIGHT_Y, 1.0)
	await _rig.wait_seconds(2.0)
	_axis(JOY_AXIS_RIGHT_Y, 0.0)
	await _rig.wait_frames(4)
	pan = _map.view()[&"pan"]
	_check("stick-down ran the plan to its stop and no further (%.1f of %.1f)"
		% [pan.y, -lim.y], is_equal_approx(pan.y, -lim.y))
	await _rig.capture("p_03_pad_down.png")
	var again := _differs("p_02_pad_right.png", "p_03_pad_down.png", _plan)
	_check("...which is a third picture (%d px differ from the second)" % again,
		again > 2000)
	_unbind_pad()


# --- The mouse ----------------------------------------------------------------

## Close and reopen -- which resets the view, and is itself a null case worth
## having: the third zero in this file is that the screen opens the same way
## twice.
func _mouse_drags(canvas: Control) -> void:
	print("  --- the mouse ---")
	_tap(&"map")
	await _rig.wait_seconds(0.35)
	_tap(&"map")
	await _rig.wait_seconds(0.4)
	var v := _map.view()
	_check("reopening reset the view (%.2fx, pan %s)"
		% [float(v[&"zoom"]), v[&"pan"]],
		is_equal_approx(float(v[&"zoom"]), MenuMapPanel.OPEN_ZOOM)
			and v[&"pan"] == Vector2.ZERO)
	await _rig.capture("p_04_reopened.png")
	var same := _differs("p_00_open.png", "p_04_reopened.png", _plan)
	_check("...to the same pixels it opened on (%d differ)" % same, same == 0)

	# Motion with no button down. The mouse's own null case -- a `_gui_input`
	# that panned on every motion would sail through the drag beat below.
	var mid := canvas.get_global_rect().get_center()
	for i in 4:
		_motion(mid + Vector2(20.0 * i, 0.0), Vector2(20.0, 0.0), false)
		await _rig.wait_frames(2)
	_check("hovering the plan with no button held moved nothing (%s)"
		% _map.view()[&"pan"], _map.view()[&"pan"] == Vector2.ZERO)

	# The drag. Six steps rather than one, because `relative` is what the handler
	# reads and a single 180 px jump would not tell a per-event handler from one
	# that snapped to the cursor. 30 px a step keeps the cursor on the plan for
	# the whole drag -- the viewport would keep routing to the Control that took
	# the press either way, but a beat that leaves the surface it is testing is
	# a beat that stops testing the routing.
	var lim: Vector2 = _map.view()[&"limit"]
	_button(mid, true)
	await _rig.wait_frames(2)
	var at := mid
	for i in 6:
		at += Vector2(30.0, 0.0)
		_motion(at, Vector2(30.0, 0.0), true)
		await _rig.wait_frames(2)
	_button(at, false)
	await _rig.wait_frames(4)
	var pan: Vector2 = _map.view()[&"pan"]
	# The paper follows the hand: drag right, the plan goes right, `pan.x` up.
	# Opposite in sign to the stick above, on purpose, and both are checked so
	# neither can silently take the other's convention.
	_check("dragging 180 px right took the plan with it (pan %s, stop %.1f)"
		% [pan, lim.x], pan.x > 20.0)
	_check("...by the drag distance, or the stop if that came first (%.1f)"
		% minf(180.0, lim.x), is_equal_approx(pan.x, minf(180.0, lim.x)))
	await _rig.capture("p_05_drag.png")
	var moved := _differs("p_00_open.png", "p_05_drag.png", _plan)
	_check("...and the frame moved with it (%d px)" % moved, moved > 2000)

	# Released, and walked back the way it came so every one of these lands on
	# the plan too. The last mouse null case.
	for i in 3:
		at -= Vector2(30.0, 0.0)
		_motion(at, Vector2(-30.0, 0.0), false)
		await _rig.wait_frames(2)
	_check("motion after the button came up moved nothing more (%s)"
		% _map.view()[&"pan"], _map.view()[&"pan"] == pan)


# --- The wheel, all the way back to the fit -----------------------------------

## The zoom's bottom stop is the plan this screen used to draw, and the reason
## the pan was allowed to cost the fit at all. If this beat cannot get back to
## `zoom == 1.0` with a zero pan limit, the card took the whole-floor picture
## away and did not give it back.
func _zoom_to_the_fit() -> void:
	print("  --- the wheel, back to the fit ---")
	for i in 24:
		_wheel(false)
		await _rig.wait_frames(1)
	await _rig.wait_frames(4)
	var v := _map.view()
	_check("the wheel reached the fit (%.3fx)" % float(v[&"zoom"]),
		is_equal_approx(float(v[&"zoom"]), MenuMapPanel.ZOOM_MIN))
	# What "the fit" MEANS, measured rather than trusted to the name: at
	# `ZOOM_MIN` the whole floor -- annexes folded in by `Atlas.bounds()` -- is
	# inside the frame, so the picture this screen used to draw is still one
	# gesture away and the card cost the player nothing.
	var box := Rect2(Vector2.ZERO, (_map._canvas as Control).size).grow(
		-MenuMapPanel.PLAN_PAD)
	var grid := Vector2(Atlas.bounds().size) * MapDraw.fit_pitch(
		box, Atlas.bounds()) * float(v[&"zoom"])
	_check("...where the whole floor is inside the frame (%s in %s)"
		% [grid, box.size],
		grid.x <= box.size.x + 0.5 and grid.y <= box.size.y + 0.5)
	_check("...and zooming out pulled the pan back with it (pan %s, limit %s)"
		% [v[&"pan"], v[&"limit"]],
		absf((v[&"pan"] as Vector2).x) <= (v[&"limit"] as Vector2).x + 0.5
			and absf((v[&"pan"] as Vector2).y)
				<= (v[&"limit"] as Vector2).y + 0.5)
	await _rig.capture("p_06_fit.png")
	var moved := _differs("p_00_open.png", "p_06_fit.png", _plan)
	_check("...and it is a different picture from the one it opened on (%d px)"
		% moved, moved > 2000)

	# Back in, to leave the last frame on something readable and to prove the
	# wheel is not one-way.
	for i in 6:
		_wheel(true)
		await _rig.wait_frames(1)
	await _rig.wait_frames(4)
	_check("...and the wheel goes back in (%.3fx)"
		% float(_map.view()[&"zoom"]),
		float(_map.view()[&"zoom"]) > MenuMapPanel.ZOOM_MIN + 0.05)
	await _rig.capture("p_07_zoomed_in.png")


# --- The pad's bindings -------------------------------------------------------

## Put `project.godot`'s four right-stick axis bindings back. See the class note
## for why a director is allowed to undo `shoot.gd._deafen_the_gamepad` and why
## the null case has to run immediately after this call.
func _rebind_pad() -> void:
	var added := 0
	for row: Array in PAD_AXES:
		var action: StringName = row[0]
		if not InputMap.has_action(action):
			continue
		var ev := InputEventJoypadMotion.new()
		ev.axis = int(row[1])
		ev.axis_value = float(row[2])
		InputMap.action_add_event(action, ev)
		added += 1
	print("  restored %d right-stick bindings that shoot.gd had stripped" % added)


## And take them off again, so everything after the pad beats runs as deaf as
## every other director on this machine.
func _unbind_pad() -> void:
	for row: Array in PAD_AXES:
		var action: StringName = row[0]
		if not InputMap.has_action(action):
			continue
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadMotion:
				InputMap.action_erase_event(action, ev)
	print("  right-stick bindings stripped again")


## One axis, held or released. `axis_value` of 0.0 is the release:
## `InputEventJoypadMotion.action_match` matches the action whatever the
## direction and reports "not pressed" below the deadzone, which is what clears
## the held state -- a second event in the opposite direction would instead pan
## the other way for a frame.
func _axis(axis: int, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = 0
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)


# --- Real mouse events --------------------------------------------------------

func _button(at: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = at
	ev.global_position = at
	ev.pressed = down
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(ev)


func _motion(at: Vector2, rel: Vector2, held: bool) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.global_position = at
	ev.relative = rel
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(ev)


## A wheel notch over the middle of the plan. A wheel event is a BUTTON in
## Godot, and only its press half is dispatched by the wheel on a real mouse --
## but the release is sent too, so the viewport's own button bookkeeping does not
## end the run believing a button is still down.
func _wheel(up: bool) -> void:
	var mid := _plan.get_center()
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
		ev.position = mid
		ev.global_position = mid
		ev.pressed = pressed
		ev.factor = 1.0
		Input.parse_input_event(ev)


# --- Plumbing -----------------------------------------------------------------

## Pixels of `rect` that differ between two captures. Zero is the answer half the
## beats in this file want, which is only meaningful because `still_the_frame`
## was called before the first capture.
func _differs(a_name: String, b_name: String, rect: Rect2) -> int:
	# `String`, not `:=`. `_rig` is untyped, so everything off it is Variant and
	# an inferred local has nothing to infer from -- CLAUDE.md §3.
	var dir: String = _rig.out_base().get_base_dir()
	var a := Image.load_from_file("%s/%s" % [dir, a_name])
	var b := Image.load_from_file("%s/%s" % [dir, b_name])
	if a == null or b == null:
		_check("both frames (%s, %s) came back off disk" % [a_name, b_name], false)
		return -1
	if a.get_format() != Image.FORMAT_RGB8:
		a.convert(Image.FORMAT_RGB8)
	if b.get_format() != Image.FORMAT_RGB8:
		b.convert(Image.FORMAT_RGB8)
	var n := 0
	for y in range(int(rect.position.y), int(rect.end.y)):
		for x in range(int(rect.position.x), int(rect.end.x)):
			if x < 0 or y < 0 or x >= a.get_width() or y >= a.get_height():
				continue
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			if absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b) > INK:
				n += 1
	return n


## A real event, not `Input.action_press`: `PauseMenu` reads `map` in
## `_unhandled_input` and `action_press` dispatches no InputEvent (CLAUDE.md §3).
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
		print("MAP PAN FAIL %s" % what)
