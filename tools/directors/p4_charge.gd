extends RefCounted
## The sword is two buttons: the light chain on RB, the heavy on RT. Does the
## trigger give you the heavy on the press AND the spin on the hold?
##
## This is the third layout this director has measured. It replaced p4_heavy.gd,
## which pressed a `heavy_attack` action that no longer exists; then it measured
## one button that was tap-light / hold-heavy; and now the two verbs have a
## button each and the HOLD on the heavy's button buys the spin. What is worth
## measuring did not change much, because the failure mode did not: a button
## that carries a press meaning and a hold meaning can always eat one of them.
##
##   1. `heavy_attack` is GONE and both `attack` and `heavy` exist. A layout edit
##      that did not take is the cheapest failure here and the hardest to see in
##      a frame.
##   2. A tap on `attack` still swings immediately, with no charge latency.
##   3. A tap on `heavy` lands a BIGGER blow than the light, and LATER. Its cost
##      is the commitment; a heavy that lands as fast as a light is free.
##   4. A SHORT hold of `heavy` is just that heavy — one blow, nothing extra on
##      the release. Otherwise the spin is not a choice, it is a side effect.
##   5. A LONG hold arms `combat.charged`, and letting go lands a SECOND blow.
##      That is the whole feature.
##   6. The shield still works, on a layout that moved two buttons around it.
##   7. An EMPTY stamina bar refuses the swing outright. That is the new gate
##      (K.STAMINA_SWING / _HEAVY / _SPIN) and nothing else in the project
##      photographs it.
##
## Stamina is refilled before each MEASURED press, deliberately. A director that
## measures the swing must not also be measuring the bar — the same reason the
## hero is placed on the post rather than walked onto it. Claim 7 is the one
## place the bar is allowed to be the subject, and it empties it on purpose.
##
## Damage is read off the post's `struck` signal, NOT off `total_damage`. The
## post clears its running total after 4 s of quiet, and this director both holds
## buttons for a second at a time and writes a contact sheet to disk — so a diff
## across any of that is measuring the reset. (p4_combo.gd found this the hard
## way and reported a swing dealing -2.)
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/p4_charge.gd --out=/tmp/p4h/x.png

## Long enough to be past chain_window (0.34 s) and past the tail of the longest
## swing, so every measured press starts the chain at step one.
const LAPSE := 1.4

var _hits: Array[int] = []


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/p4h/x.png").get_base_dir()
	var scene: Node = rig.scene()
	var hero: Node3D = scene.get_node_or_null(^"Hero") as Node3D
	var fails := 0

	if hero == null:
		print("CHARGE FAIL no Hero in the scene")
		return
	# The hero owns its combat node and publishes it; do not go fishing in the
	# scene tree for it (docs/CONTRACT.md §8).
	var combat: Node = hero.get(&"combat")
	if combat == null:
		print("CHARGE FAIL no HeroCombat on the Hero")
		return

	# The layout, before anything else is worth measuring. This is the check that
	# catches a project.godot edit that did not take — including the DELETION,
	# because a leftover `heavy_attack` still bound to X would fire a heavy on
	# every press of the button that is now the light chain.
	for action in [&"attack", &"heavy", &"shield"]:
		if not InputMap.has_action(action):
			print("CHARGE FAIL action missing from the InputMap: ", action)
			fails += 1
	if InputMap.has_action(&"heavy_attack"):
		print("CHARGE FAIL `heavy_attack` still exists — the heavy is the hold now")
		fails += 1
	print("CHARGE binds attack=%s heavy=%s shield=%s"
		% [_binds(&"attack"), _binds(&"heavy"), _binds(&"shield")])

	var post: Node = scene.get_node_or_null(^"PostA")
	if post == null:
		print("CHARGE FAIL no PostA to hit")
		return
	post.connect(&"struck", _on_struck)

	await rig.wait_frames(24)

	# PLACE the hero on the post rather than walking him onto it. p4_combat walks
	# for 40 frames and lands ~2.8 m short — which is why it has been reporting
	# total_hits=0 and reading as a passing run. A director measuring the swing
	# must not also be measuring the pathing; put him in reach and face him at it.
	#
	# facing_yaw is the HEADING yaw (docs/CONTRACT.md §2.5): heading is
	# (sin y, 0, cos y), so PI is heading (0,0,-1) — straight at a post that sits
	# on -Z from him.
	var post_pos: Vector3 = (post as Node3D).global_position
	hero.global_position = post_pos + Vector3(0.0, 0.05, 1.1)
	hero.set(&"facing_yaw", PI)
	await rig.wait_frames(20)
	print("CHARGE range=%.2fm reach=%.2fm"
		% [hero.global_position.distance_to(post_pos), float(combat.get(&"reach"))])
	await rig.capture(out.path_join("h_00_approach.png"))

	var charge_time: float = float(combat.get(&"charge_time"))

	# --- the light tap, for the numbers the heavy has to beat ----------------
	_refill()
	var mark := _hits.size()
	await rig.tap(["attack"])
	var light_frames := await _frames_to_hit(rig, mark)
	var light_dmg := _hit(mark)
	await rig.wait_seconds(LAPSE)
	await rig.capture(out.path_join("h_01_after_light.png"))
	await rig.wait_seconds(LAPSE)

	# --- the heavy tap -------------------------------------------------------
	_refill()
	mark = _hits.size()
	await rig.tap(["heavy"])
	var heavy_frames := await _frames_to_hit(rig, mark)
	var heavy_dmg := _hit(mark)
	await rig.wait_seconds(LAPSE)
	await rig.capture(out.path_join("h_01b_after_heavy.png"))
	await rig.wait_seconds(LAPSE)

	# --- a hold too short to charge is just that heavy -----------------------
	# Held to 60% of the way, deliberately not "one frame under": what is being
	# checked is that a hurried press does not accidentally charge, and a player
	# mashing holds the button for a good fraction of the window every time.
	_refill()
	mark = _hits.size()
	Input.action_press(&"heavy")
	await rig.wait_seconds(charge_time * 0.6)
	var short_charged: bool = bool(combat.get(&"charged"))
	Input.action_release(&"heavy")
	await rig.wait_seconds(LAPSE)
	var short_blows := _hits.size() - mark
	var short_dmg := _hit(mark)
	await rig.wait_seconds(LAPSE)

	# --- the long hold, photographed across the wind-up ----------------------
	# The sheet cannot also be the thing that times the swing: capture() stalls
	# the frame clock, so the numbers come from the untouched runs either side.
	_refill()
	Input.action_press(&"heavy")
	for i in 4:
		await rig.wait_frames(5)
		await rig.capture(out.path_join("h_02_charge_%d.png" % i))
	var sheet_charged: bool = bool(combat.get(&"charged"))
	Input.action_release(&"heavy")
	for i in 4:
		await rig.wait_frames(5)
		await rig.capture(out.path_join("h_02_charge_%d.png" % (i + 4)))
	await rig.wait_seconds(LAPSE)
	await rig.capture(out.path_join("h_03_after_spin.png"))
	await rig.wait_seconds(LAPSE)

	# --- the same hold again, timed instead of photographed ------------------
	_refill()
	mark = _hits.size()
	Input.action_press(&"heavy")
	await rig.wait_seconds(charge_time + 0.35)
	var charged: bool = bool(combat.get(&"charged"))
	Input.action_release(&"heavy")
	# Counted from the RELEASE, which is when the spin is asked for. Counting
	# from the press would measure the hold, and the hold is the player's choice
	# rather than a property of the blow.
	var spin_frames := await _frames_to_hit(rig, mark + 1)
	var held_heavy := _hit(mark)
	var spin_dmg := _hit(mark + 1)
	await rig.wait_seconds(LAPSE)

	# --- an empty bar refuses ------------------------------------------------
	# Both buttons, because the gate is on the SWING rather than on either button.
	# Emptied through `spend_stamina` and not by assigning the field: spending is
	# what arms the regen delay, and without it the bar hands 16 units back -- a
	# whole light swing -- inside the 0.35 s between these two taps.
	_drain()
	mark = _hits.size()
	print("DBG drained stamina=%.2f hits=%d" % [Game.stamina, _hits.size()])
	await rig.tap(["attack"])
	await rig.wait_seconds(0.3)
	print("DBG after attack stamina=%.2f hits=%d" % [Game.stamina, _hits.size()])
	print("DBG pre-heavy stamina=%.6f hold_hits=%d" % [Game.stamina, _hits.size()])
	await rig.tap(["heavy"])
	print("DBG mid-heavy stamina=%.6f hits=%d" % [Game.stamina, _hits.size()])
	for _d in 40:
		await rig.wait_frames(1)
		if _hits.size() > mark:
			print("DBG blow landed at frame %d stamina=%.6f dmg=%d charged=%s" % [_d, Game.stamina, _hits[mark], bool(combat.get(&"charged"))])
			break
	await rig.wait_seconds(0.6)
	print("DBG after heavy stamina=%.2f hits=%d" % [Game.stamina, _hits.size()])
	var spent_blows := _hits.size() - mark
	await rig.capture(out.path_join("h_03b_no_stamina.png"))
	_refill()
	await rig.wait_seconds(LAPSE)

	# --- the shield still works, on its new binding -------------------------
	# The trigger is an axis now. This presses the ACTION, so it proves the
	# shield still reads its action; the binding itself is proved by the runtime
	# dump in tools/scenes/_padnames.tscn, which is the only honest source.
	await rig.hold(["shield"], 30)
	await rig.capture(out.path_join("h_04_block.png"))
	var blocked_up: bool = bool(combat.get(&"blocking"))
	await rig.wait_frames(24)
	var blocked_down: bool = bool(combat.get(&"blocking"))

	print("CHARGE light tap dmg=%d contact_frame=%d" % [light_dmg, light_frames])
	print("CHARGE heavy tap dmg=%d contact_frame=%d" % [heavy_dmg, heavy_frames])
	print("CHARGE short hold (%.2fs) blows=%d dmg=%d charged=%s"
		% [charge_time * 0.6, short_blows, short_dmg, short_charged])
	print("CHARGE long hold press dmg=%d release dmg=%d release_to_contact=%d charged=%s/%s"
		% [held_heavy, spin_dmg, spin_frames, charged, sheet_charged])
	print("CHARGE empty bar blows=%d" % spent_blows)

	if light_dmg <= 0:
		print("CHARGE FAIL the light tap did not land"); fails += 1
	if light_frames < 0:
		print("CHARGE FAIL the light tap never connected"); fails += 1
	if heavy_dmg <= light_dmg:
		print("CHARGE FAIL the heavy dealt %d against a light's %d"
			% [heavy_dmg, light_dmg]); fails += 1
	if heavy_frames <= light_frames:
		print("CHARGE FAIL heavy lands on frame %d, light on %d — no commitment"
			% [heavy_frames, light_frames]); fails += 1
	if short_charged:
		print("CHARGE FAIL a hold of %.2f s charged, under a charge_time of %.2f"
			% [charge_time * 0.6, charge_time]); fails += 1
	if short_blows != 1:
		print("CHARGE FAIL a short hold threw %d blows, not 1 — the release is not free"
			% short_blows); fails += 1
	if short_dmg != heavy_dmg:
		print("CHARGE FAIL a short hold dealt %d against the heavy tap's %d — it is not a tap"
			% [short_dmg, heavy_dmg]); fails += 1
	if not charged:
		print("CHARGE FAIL holding past charge_time never armed the charge"); fails += 1
	if not sheet_charged:
		print("CHARGE FAIL the photographed hold never armed — the sheet shows nothing"); fails += 1
	if held_heavy != heavy_dmg:
		print("CHARGE FAIL the press that started the hold dealt %d, not the tap's %d — the hold ate the press"
			% [held_heavy, heavy_dmg]); fails += 1
	if spin_dmg <= heavy_dmg:
		print("CHARGE FAIL the release dealt %d against the press's %d"
			% [spin_dmg, heavy_dmg]); fails += 1
	if spent_blows != 0:
		print("CHARGE FAIL an empty stamina bar still threw %d blow(s)"
			% spent_blows); fails += 1
	if not blocked_up:
		print("CHARGE FAIL shield never rose"); fails += 1
	if blocked_down:
		print("CHARGE FAIL shield never lowered"); fails += 1

	print("CHARGE %s (fails=%d)" % ["OK" if fails == 0 else "FAIL", fails])


func _on_struck(amount: int, _from: Vector3) -> void:
	_hits.append(amount)


## Full bar before a measured press. Every swing costs stamina now, and this
## director throws six of them inside a few seconds — without this, the last
## measurement would be of the regen curve rather than of the blow.
func _refill() -> void:
	Game.stamina = Game.max_stamina
	Bus.stamina_changed.emit(Game.stamina, Game.max_stamina)


## Empty it the way the game empties it, so the regen delay is armed too.
func _drain() -> void:
	Game.spend_stamina(Game.stamina)


## What the blow at index `i` dealt, or 0 if it never arrived.
func _hit(i: int) -> int:
	return _hits[i] if _hits.size() > i else 0


## Frames until blow number `i` lands, or -1 if it never does. The wait is on
## the BLOW rather than a fixed count: a swing that is slower than expected
## should read as slow, not as a miss.
func _frames_to_hit(rig, i: int) -> int:
	var frames := 0
	while frames < 180:
		if _hits.size() > i:
			return frames
		await rig.wait_frames(1)
		frames += 1
	return -1


func _binds(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "MISSING"
	var parts := PackedStringArray()
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			parts.append(OS.get_keycode_string((e as InputEventKey).physical_keycode))
		elif e is InputEventMouseButton:
			parts.append("Mouse%d" % (e as InputEventMouseButton).button_index)
		elif e is InputEventJoypadButton:
			parts.append("pad%d" % (e as InputEventJoypadButton).button_index)
		elif e is InputEventJoypadMotion:
			var m := e as InputEventJoypadMotion
			parts.append("axis%d%s" % [m.axis, "+" if m.axis_value > 0.0 else "-"])
	return "/".join(parts)
