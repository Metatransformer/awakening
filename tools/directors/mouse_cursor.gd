extends RefCounted
## THE POINTER, across every screen that takes it away — and back again.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/mouse_cursor.gd \
##     --out=/tmp/cursor/x.png --warmup=60
##
## WHAT THIS IS FOR. `GameCamera` grabs the cursor on spawn and mouse look is
## gated on it being grabbed (`mouse_look_requires_capture`) — so the pointer's
## mode IS whether the mouse steers the camera. Every full-screen UI hands it
## back so its own cells can be clicked, and every one of them is supposed to put
## it where it found it.
##
## THAT CONTRACT HAS NOW BROKEN THREE TIMES, always the same way and never
## visibly: something releases the pointer, something else saves THAT as the
## state to restore, and the mouse is dead for the rest of the run with no error
## anywhere. First the camera itself released on `pause` and `PauseMenu` saved
## the release (the long comment in `game_camera.gd`); then the dialogue box and
## the shop stacked, and the shop saved the box's release.
##
## No screenshot can see this. The frame after the shop closes looks exactly
## right — the camera is simply no longer listening. So it is asserted here, as
## numbers, on the paths a player actually walks:
##
##   A  the pointer starts grabbed in the garrison
##   B  a plain conversation gives it back on the way out
##   C  the SHOP REACHED THROUGH THE CONVERSATION gives it back — the stack
##   D  the pause menu gives it back
##   E  mouse motion still turns the camera at the end of all that
##
## The harness never grabs the cursor for real (that would hijack the machine
## mid-capture, `shoot.gd`), so beat A sets the mode by hand first and every beat
## after it is the save/restore chain under test, which is the half that broke.

var _pass := 0
var _fail := 0


func run(rig) -> void:
	var players: Array = rig.get_nodes_in_group(&"player")
	if players.is_empty():
		print("CURSOR FAIL no node in group `player`")
		return
	var hero: Node3D = players[0]
	var cam := hero.get_viewport().get_camera_3d() as GameCamera
	if cam == null:
		print("CURSOR FAIL no GameCamera")
		return
	await rig.wait_frames(20)

	# --- A. Stand in for the grab the harness is not allowed to take ----------
	# `may_capture` is off under `shoot.gd` -- a real grab would hijack the
	# machine mid-capture -- and it is exactly the thing this director has to
	# turn back on, because the pointer's mode is what is being asserted. Same
	# opt-in, and the same reason, as p1_orbit.gd's `mouse_look_requires_capture`.
	cam.may_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_ck("A the garrison holds the pointer", _captured())

	# --- B. A plain conversation ---------------------------------------------
	var garrison := rig.scene() as Garrison
	_stand_at(rig, garrison.smith.global_position + Vector3(0.0, 0.0, 1.6))
	await rig.wait_frames(20)
	await rig.tap(["interact"])
	await rig.wait_frames(10)
	var box: Node = rig.dialogue()
	_ck("B0 the smith opened a box", box != null)
	_ck("B1 the box freed the pointer", not _captured())
	if box != null:
		box.close()
	await rig.wait_frames(10)
	_ck("B2 the box gave the pointer back", _captured())

	# --- C. The shop, reached through the conversation. THE STACK ------------
	await rig.tap(["interact"])
	if not await rig.talk("Trade"):
		print("CURSOR FAIL the smith would not offer to trade")
		return
	await rig.wait_frames(16)
	var screen := _screen(rig)
	_ck("C0 the counter opened", screen != null)
	_ck("C1 the counter freed the pointer", not _captured())
	if screen != null:
		screen.close()
	await rig.wait_frames(20)
	# THE ONE THAT WAS FAILING. The box saved CAPTURED and the shop saved the
	# box's VISIBLE; the box then declined to restore because a screen was up,
	# and the shop faithfully put back "visible".
	_ck("C2 the counter gave the pointer back", _captured())

	# --- D. The pause menu ----------------------------------------------------
	# A REAL KEY, not `rig.tap(["pause"])`. `PauseMenu` reads the button as an
	# event and `Input.action_press` dispatches none (CLAUDE.md §3) -- driven
	# that way this beat photographs a menu that never opened and then passes its
	# "gave the pointer back" check for the wrong reason, which is worse than
	# failing. Same route `scripts/ui/menu/_menu_director.gd` takes.
	await _key(rig, KEY_ESCAPE)
	_ck("D0 the pause menu opened", Menu.is_open)
	_ck("D1 the pause menu freed the pointer", not _captured())
	await _key(rig, KEY_ESCAPE)
	_ck("D2 the pause menu closed", not Menu.is_open)
	_ck("D3 the pause menu gave the pointer back", _captured())

	# --- E. And the mouse still steers ---------------------------------------
	var yaw_before: float = cam.get("_yaw")
	for i in 14:
		var mm := InputEventMouseMotion.new()
		mm.relative = Vector2(24.0, 0.0)
		mm.screen_relative = Vector2(24.0, 0.0)
		mm.velocity = Vector2(24.0, 0.0) * 60.0
		Input.parse_input_event(mm)
	await rig.wait_seconds(0.25)
	var moved := rad_to_deg(absf(angle_difference(yaw_before, cam.get("_yaw"))))
	_ck("E the mouse still turns the camera (%.1f deg)" % moved, moved > 5.0)

	await rig.capture("cursor.png")
	print("CURSOR %d passed, %d failed" % [_pass, _fail])


## A real key press and release, down the InputMap. Lifted from
## `scripts/ui/menu/_menu_director.gd` — both keycodes are set so the `ui_*`
## actions (keycode-bound) and the game actions (physical-bound) both see it.
func _key(rig, code: int, settle: int = 14) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await rig.wait_frames(2)
	await rig.wait_frames(settle)


func _captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _ck(what: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("CURSOR ok   %s" % what)
	else:
		_fail += 1
		print("CURSOR FAIL %s (mouse_mode=%d)" % [what, Input.mouse_mode])


func _screen(rig) -> TradeScreen:
	var stack: Array[Node] = [rig.scene()]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is TradeScreen:
			return n
		for c in n.get_children():
			stack.append(c)
	return null


func _stand_at(rig, where: Vector3) -> void:
	var players: Array = rig.get_nodes_in_group(&"player")
	if players.is_empty():
		return
	(players[0] as Node3D).global_position = where
