extends RefCounted
## THE KEYBOARD, pressed as keys. Elden Ring's layout, end to end.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/keyboard_layout.gd \
##     --out=/tmp/kbd/x.png --warmup=60
##
## This is `rb_swing.gd`'s argument applied to the other device, and it is worth
## restating because it is the reason both files exist: every other director in
## this folder reaches the hero through `Input.action_press(&"attack")`, which
## sets action state DIRECTLY and never consults the InputMap. An action bound to
## nothing at all still swings for them, perfectly, forever. So this one
## synthesizes KEY AND MOUSE EVENTS and lets the InputMap do the lookup.
##
## THE CASE IT WAS WRITTEN FOR IS THE HEAVY, and it cannot be reached any other
## way. `attack` is plain LMB and `heavy` is Shift+LMB, and Godot does not treat
## those as mutually exclusive — a modified press matches the unmodified action
## too and merely records the mismatch as a separate `exact` flag. Without
## `HeroCombat.ATTACK_EXACT` the player gets the light chain AND the heavy for
## one click, and NOTHING ELSE IN THIS PROJECT CAN SEE THAT: the pad path is
## unaffected, every action_press() harness is unaffected, and the hero's state
## enum reads ATTACK either way.
##
## The discriminator is timing, and it is exact rather than clever: the light
## swing comes out on the PRESS and the heavy comes out on the RELEASE
## (project.godot, `heavy`). So a Shift+LMB that is still not swinging two
## physics frames after the press is proof the light did not fire, and a swing
## that appears on the release is proof the heavy did.

const STATE_ROLL := 2       ## Hero.MoveState.ROLL
const STATE_ATTACK := 4     ## Hero.MoveState.ATTACK

## The layout, as `Glyph.long` will print it to the player in the options screen.
## Read from the LIVE InputMap, after Settings.apply_binds has replayed any saved
## config over the shipped one — a saved config outranks project.godot, and that
## is exactly the failure rb_swing.gd was written for.
const LAYOUT := {
	&"move_up": "W", &"move_down": "S", &"move_left": "A", &"move_right": "D",
	&"attack": "Mouse L",
	&"heavy": "Shift+Mouse L",
	&"shield": "Mouse R",
	&"context": "Space",
	&"jump": "F",
	&"use_item": "R",
	&"interact": "E",
	&"z_target": "Mouse M",
	&"first_person": "V",
	&"inventory": "I",
	&"map": "M",
	&"pause": "Escape",
}

var _pass := 0
var _fail := 0


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/kbd/x.png").get_base_dir()
	var players: Array = rig.get_nodes_in_group(&"player")
	if players.is_empty():
		print("KBD FAIL no node in group `player`")
		return
	var hero: Node3D = players[0]
	await rig.wait_frames(20)

	# --- 1. What is actually bound -------------------------------------------
	for action: StringName in LAYOUT:
		var e := Glyph.event_for(action, false)
		var got := Glyph.long(e) if e != null else "<nothing>"
		_check("%s is %s (got %s)" % [action, LAYOUT[action], got],
			got == LAYOUT[action])

	# X was `use_item` and is now free, held for a crouch this game has no
	# ability for. CONTRACT §4: the key stays unbound until the verb exists, so
	# the thing to assert is the ABSENCE.
	_check("X is unbound (reserved for crouch)", _owner_of_key(KEY_X) == &"")

	# --- 2. LMB is the light swing, and it fires on the PRESS -----------------
	_check("hero is idle before the click (state %d)" % int(hero.get(&"state")),
		int(hero.get(&"state")) != STATE_ATTACK)
	_click(false, true)
	# `parse_input_event` QUEUES — the action state is unchanged on the line after
	# the call and only lands on the next frame boundary. Reading it immediately
	# reports false for a press that is about to work perfectly, which is a very
	# convincing way to debug the wrong thing. Always let a frame pass first.
	await rig.wait_physics_frames(2)
	var light: bool = await rig.until(
		func() -> bool: return int(hero.get(&"state")) == STATE_ATTACK, 1.0)
	_check("LMB swung the sword on the press", light)
	_click(false, false)
	await _burst(rig, hero, out, "light")

	# Let the chain window and the swing itself run out, or the next press lands
	# as chain step 2 of the swing that is already going.
	await rig.wait_seconds(1.4)
	var idle: bool = await rig.until(
		func() -> bool: return int(hero.get(&"state")) != STATE_ATTACK, 2.0)
	_check("hero recovered before the heavy is tried", idle)

	# --- 3. Shift+LMB is the heavy, AND NOT ALSO THE LIGHT --------------------
	# THIS IS THE CHECK THE WHOLE FILE IS FOR. Before ATTACK_EXACT the press
	# below put the hero into ATTACK immediately, off the light chain, and the
	# heavy then came out on top of it.
	_click(true, true)
	await rig.wait_physics_frames(3)
	var early := int(hero.get(&"state"))
	_check("Shift+LMB did NOT fire the light swing on the press (state %d)" % early,
		early != STATE_ATTACK)
	_click(true, false)
	var heavy: bool = await rig.until(
		func() -> bool: return int(hero.get(&"state")) == STATE_ATTACK, 1.5)
	_check("Shift+LMB swung the heavy on the release", heavy)
	await _burst(rig, hero, out, "heavy")
	await rig.wait_seconds(1.6)

	# --- 4. Space TAPPED rolls; Space HELD runs ------------------------------
	# The two are EXCLUSIVE — Hero.sprint_hold_time — and this director got that
	# wrong on its first run in a way worth recording: it held the key and then
	# asserted a roll. There is no roll under a hold, on purpose ("a player who
	# holds the button expecting the roll that used to come out underneath the
	# run gets nothing", hud.gd). A tap and a hold are two presses, so they are
	# two beats here.
	await rig.until(func() -> bool: return int(hero.get(&"state")) != STATE_ATTACK, 2.0)
	# W IS HELD THROUGH THE TAP, and that is not stage-dressing. Free — nothing
	# locked, no guard — `_try_start_roll` refuses on `mag < roll_stick_gate`:
	# [oot], you cannot roll out of a walk, only out of a committed run. A tap
	# from a standing start is CORRECTLY nothing, which is what this director
	# asserted on its second run before reading the gate it was tripping.
	_key(KEY_W, true)
	await rig.wait_seconds(0.5)
	_key(KEY_SPACE, true)
	await rig.wait_physics_frames(2)
	_key(KEY_SPACE, false)
	var rolled: bool = await rig.until(
		func() -> bool: return int(hero.get(&"state")) == STATE_ROLL, 1.0)
	_check("Space TAPPED rolled (moving)", rolled)
	_key(KEY_W, false)
	await rig.until(func() -> bool: return int(hero.get(&"state")) == 0, 2.5)

	# Held past sprint_hold_time (0.36 s) the same key becomes the sprint instead.
	_key(KEY_SPACE, true)
	var ran: bool = await rig.until(func() -> bool: return bool(hero.get(&"sprinting")), 1.5)
	_check("Space HELD became the sprint", ran)
	_key(KEY_SPACE, false)
	await rig.wait_seconds(0.6)
	_check("the sprint stopped when Space came up", not bool(hero.get(&"sprinting")))

	# --- 5. F jumps ----------------------------------------------------------
	await rig.until(func() -> bool: return bool(hero.call(&"is_on_floor")), 2.0)
	_key(KEY_F, true)
	var jumped: bool = await rig.until(
		func() -> bool: return not bool(hero.call(&"is_on_floor")), 1.0)
	_check("F left the floor", jumped)
	_key(KEY_F, false)
	await rig.until(func() -> bool: return bool(hero.call(&"is_on_floor")), 3.0)

	# --- 6. The frame a human has to look at ---------------------------------
	# The HUD's key caps print the live bindings under the hands and the item
	# cross, and `heavy` now caps as "SHFT+LMB" — eight characters in a cell sized
	# for three. A state enum cannot tell anyone whether it still fits.
	# CLAUDE.md §2: look at it.
	#
	# This used to photograph the control LEGEND, which printed every cap in the
	# layout on one line across the bottom. Card #121 deleted it, so the caps in
	# the corner are the only surface left that renders a binding.
	await rig.wait_seconds(0.4)
	await rig.capture(out.path_join("caps.png"))

	print("KBD %d passed, %d failed" % [_pass, _fail])


## A synthesized key. `parse_input_event`, not `action_press`: the point is to go
## in as a KEY and come out the other side of the InputMap as an action.
func _key(code: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)


## The left mouse button, optionally with Shift down — which is the entire
## difference between the light attack and the heavy.
func _click(shift: bool, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.shift_pressed = shift
	e.pressed = down
	Input.parse_input_event(e)


## Which rebindable action, if any, has `code` on it. For asserting a key is FREE.
func _owner_of_key(code: int) -> StringName:
	for action in Settings.rebindable_actions():
		for e in InputMap.action_get_events(action):
			if e is InputEventKey and (e as InputEventKey).physical_keycode == code:
				return action
	return &""


## A few frames of the swing from a 3/4 front angle. A state enum going to 4 is
## not proof that a sword came out — CLAUDE.md §2 — and this is the half a human
## has to look at. Lifted from rb_swing.gd, including the reason the camera has
## to be stopped before it can be parked.
func _burst(rig, hero: Node3D, out: String, tag: String) -> void:
	var cam := hero.get_viewport().get_camera_3d()
	if cam == null:
		print("KBD no camera; skipping the frames")
		return
	var was := cam.is_physics_processing()
	cam.set_physics_process(false)
	for i in 6:
		cam.global_position = hero.global_position + Vector3(1.6, 1.6, 2.4)
		cam.look_at(hero.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)
		await rig.capture(out.path_join("%s_%02d.png" % [tag, i]))
		await rig.wait_frames(2)
	# Handed back, unlike rb_swing's — this director keeps running afterwards and
	# needs the camera behind the hero again for the key-cap shot.
	cam.set_physics_process(was)


func _check(what: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("PASS %s" % what)
	else:
		_fail += 1
		print("KBD FAIL %s" % what)
