extends RefCounted
## Does the RIGHT SHOULDER BUTTON swing the sword? Not "does `attack` swing the
## sword" — does the physical button.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/rb_swing.gd \
##     --out=/tmp/rb/x.png --warmup=60 --keep-pad
##
## `--keep-pad` IS REQUIRED and this refuses to run without it: shoot.gd strips
## every joypad binding out of the InputMap by default, which would delete the
## exact thing under test. Read shoot.gd's `_deafen_the_gamepad` before passing
## it with a controller actually plugged in — a resting stick will walk the hero
## out of the shot.
##
## WHY THIS EXISTS, AND WHY NOTHING ELSE HERE CAUGHT THE BUG IT WAS WRITTEN FOR:
## RB stopped swinging for a day. `attack` had been rebound to the N key alone
## in `user://settings.cfg` by a screenshot run — Settings replays saved binds
## over the shipped layout at boot, and `apply_binds` erases an action before it
## replays, so the pad event was simply gone. Every combat director in this
## folder passed throughout, because they all reach the hero through
## `Input.action_press(&"attack")` or `rig.hold(["attack"])`. Those set action
## state DIRECTLY. They never consult the InputMap, so an `attack` with no
## button on it at all still swings for them, perfectly, forever.
##
## So this one presses a BUTTON INDEX and lets the InputMap do the lookup. It is
## the only test here that can fail when the binding is the broken thing.
##
## The three checks are deliberately separate. The binding assertions say WHICH
## link broke without needing a human to read a frame; the swing assertion is
## the one that actually proves the chain end to end; the frames are so somebody
## can see it is the sword coming out and not a flinch (CLAUDE.md §2).

## JoyButton 10. Godot's enum, NOT the SDL/Xbox raw numbering — project.godot's
## input section has the full table and the story of getting it wrong twice.
const RB := JOY_BUTTON_RIGHT_SHOULDER

## Hero.MoveState.ATTACK.
const STATE_ATTACK := 4

var _pass := 0
var _fail := 0


func run(rig) -> void:
	if rig.arg("keep-pad", "") == "":
		print("RB FAIL run me with --keep-pad; without it shoot.gd has already "
			+ "stripped the binding this director exists to check")
		return

	var out: String = rig.arg("out", "/tmp/rb/x.png").get_base_dir()
	var players: Array = rig.get_nodes_in_group(&"player")
	if players.is_empty():
		print("RB FAIL no node in group `player`")
		return
	var hero: Node3D = players[0]
	await rig.wait_frames(20)

	# --- 1. The binding, as the game will actually see it at boot -------------
	# Read AFTER Settings.apply_binds has run, not out of project.godot: a saved
	# config outranks the shipped layout, and that is precisely the failure.
	var pad_btn := -1
	var has_mouse := false
	for e in InputMap.action_get_events(&"attack"):
		if e is InputEventJoypadButton:
			pad_btn = (e as InputEventJoypadButton).button_index
		elif e is InputEventMouseButton:
			has_mouse = true
	_check("attack carries a joypad button (got %d, want %d)" % [pad_btn, RB],
		pad_btn == RB)
	# The mouse went with it last time — same erase, same cause. If only one of
	# the two is missing the report should say so.
	_check("attack still carries its mouse button", has_mouse)

	if pad_btn != RB:
		print("RB FAIL the button is not bound; not pressing anything")
		_summary()
		return

	# --- 2. The press ---------------------------------------------------------
	# parse_input_event, not action_press: the whole point is to go in as a
	# button and come out the other side of the InputMap as an action.
	var idle_state: int = hero.get(&"state")
	_check("hero is not already swinging (state %d)" % idle_state,
		idle_state != STATE_ATTACK)

	_press(RB, true)
	await rig.wait_physics_frames(2)
	_press(RB, false)

	# Typed explicitly: `rig` is untyped, so `:=` cannot infer through it.
	var swung: bool = await rig.until(
		func() -> bool: return int(hero.get(&"state")) == STATE_ATTACK, 1.0)
	_check("RB put the hero into ATTACK (state %d)" % int(hero.get(&"state")), swung)

	# --- 3. The frames --------------------------------------------------------
	await _burst(rig, hero, out)
	_summary()


## A synthesized pad button, device 0. `parse_input_event` feeds the same path a
## real controller does, so `Input.is_action_just_pressed(&"attack")` in
## hero_combat's `_tick_light_button` sees it exactly as it would a real press.
func _press(button: int, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = button
	e.pressed = down
	Input.parse_input_event(e)


## A few frames of the swing from a 3/4 front angle. A state enum going to 4 is
## not proof that a sword came out — CLAUDE.md §2 — and this is the half a human
## has to look at.
func _burst(rig, hero: Node3D, out: String) -> void:
	var cam := hero.get_viewport().get_camera_3d()
	if cam == null:
		print("RB no camera; skipping the frames")
		return
	# GameCamera re-derives its transform every physics frame, so it has to be
	# stopped before it can be parked (swing_lookdev.gd learned this first).
	cam.set_physics_process(false)
	for i in 8:
		cam.global_position = hero.global_position + Vector3(1.6, 1.6, 2.4)
		cam.look_at(hero.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)
		await rig.capture(out.path_join("rb_%02d.png" % i))
		await rig.wait_frames(2)


func _check(what: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("PASS %s" % what)
	else:
		_fail += 1
		print("RB FAIL %s" % what)


func _summary() -> void:
	print("RB %d passed, %d failed" % [_pass, _fail])
