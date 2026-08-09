extends RefCounted
## The heavy has no button. Does holding the attack button still get you one?
##
## This replaces p4_heavy.gd, which pressed a `heavy_attack` action that no
## longer exists. The blow is the same blow; what changed is that reaching it
## costs TIME on a button you were already holding rather than a second button —
## which is the arrangement every Zelda spin attack has used, and which has one
## specific way of going wrong: the hold eats the tap. So the claims are:
##
##   1. `heavy_attack` is GONE and `use_item` exists. A layout edit that did not
##      take is the cheapest failure here and the hardest to see in a frame.
##   2. A tap still swings immediately. The light attack must not have acquired
##      `charge_time` of latency in exchange for the charge.
##   3. A SHORT hold is just a tap — one blow, nothing extra on release.
##      Otherwise every swing is a heavy and the light button is dead content.
##   4. A LONG hold arms `combat.charged`, and letting go lands a SECOND, bigger
##      blow. That is the whole feature.
##   5. The heavy still arrives later than the light. Its cost is the
##      commitment, so a heavy that connects as fast as a light is free.
##   6. The shield still works, on a layout that moved two buttons around it.
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
	for action in [&"attack", &"use_item", &"shield"]:
		if not InputMap.has_action(action):
			print("CHARGE FAIL action missing from the InputMap: ", action)
			fails += 1
	if InputMap.has_action(&"heavy_attack"):
		print("CHARGE FAIL `heavy_attack` still exists — the heavy is the hold now")
		fails += 1
	print("CHARGE binds attack=%s use_item=%s shield=%s"
		% [_binds(&"attack"), _binds(&"use_item"), _binds(&"shield")])

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

	# --- the tap, for the numbers the charge has to beat ---------------------
	var mark := _hits.size()
	await rig.tap(["attack"])
	var light_frames := await _frames_to_hit(rig, mark)
	var light_dmg := _hit(mark)
	await rig.wait_seconds(LAPSE)
	await rig.capture(out.path_join("h_01_after_light.png"))
	await rig.wait_seconds(LAPSE)

	# --- a hold too short to charge is just a tap ----------------------------
	# Held to 60% of the way, deliberately not "one frame under": what is being
	# checked is that a hurried press does not accidentally charge, and a player
	# mashing holds the button for a good fraction of the window every time.
	mark = _hits.size()
	Input.action_press(&"attack")
	await rig.wait_seconds(charge_time * 0.6)
	var short_charged: bool = bool(combat.get(&"charged"))
	Input.action_release(&"attack")
	await rig.wait_seconds(LAPSE)
	var short_blows := _hits.size() - mark
	var short_dmg := _hit(mark)
	await rig.wait_seconds(LAPSE)

	# --- the long hold, photographed across the wind-up ----------------------
	# The sheet cannot also be the thing that times the swing: capture() stalls
	# the frame clock, so the numbers come from the untouched runs either side.
	Input.action_press(&"attack")
	for i in 4:
		await rig.wait_frames(5)
		await rig.capture(out.path_join("h_02_charge_%d.png" % i))
	var sheet_charged: bool = bool(combat.get(&"charged"))
	Input.action_release(&"attack")
	for i in 4:
		await rig.wait_frames(5)
		await rig.capture(out.path_join("h_02_charge_%d.png" % (i + 4)))
	await rig.wait_seconds(LAPSE)
	await rig.capture(out.path_join("h_03_after_heavy.png"))
	await rig.wait_seconds(LAPSE)

	# --- the same hold again, timed instead of photographed ------------------
	mark = _hits.size()
	Input.action_press(&"attack")
	await rig.wait_seconds(charge_time + 0.35)
	var charged: bool = bool(combat.get(&"charged"))
	Input.action_release(&"attack")
	# Counted from the RELEASE, which is when the heavy is asked for. Counting
	# from the press would measure the hold, and the hold is the player's choice
	# rather than a property of the blow.
	var heavy_frames := await _frames_to_hit(rig, mark + 1)
	var held_light := _hit(mark)
	var heavy_dmg := _hit(mark + 1)
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

	print("CHARGE tap dmg=%d contact_frame=%d" % [light_dmg, light_frames])
	print("CHARGE short hold (%.2fs) blows=%d dmg=%d charged=%s"
		% [charge_time * 0.6, short_blows, short_dmg, short_charged])
	print("CHARGE long hold press dmg=%d release dmg=%d release_to_contact=%d charged=%s/%s"
		% [held_light, heavy_dmg, heavy_frames, charged, sheet_charged])

	if light_dmg <= 0:
		print("CHARGE FAIL the tap did not land"); fails += 1
	if light_frames < 0:
		print("CHARGE FAIL the tap never connected"); fails += 1
	if short_charged:
		print("CHARGE FAIL a hold of %.2f s charged, under a charge_time of %.2f"
			% [charge_time * 0.6, charge_time]); fails += 1
	if short_blows != 1:
		print("CHARGE FAIL a short hold threw %d blows, not 1 — the release is not free"
			% short_blows); fails += 1
	if short_dmg != light_dmg:
		print("CHARGE FAIL a short hold dealt %d against the tap's %d — it is not a tap"
			% [short_dmg, light_dmg]); fails += 1
	if not charged:
		print("CHARGE FAIL holding past charge_time never armed the charge"); fails += 1
	if not sheet_charged:
		print("CHARGE FAIL the photographed hold never armed — the sheet shows nothing"); fails += 1
	if held_light != light_dmg:
		print("CHARGE FAIL the press that started the hold dealt %d, not the tap's %d — the hold ate the tap"
			% [held_light, light_dmg]); fails += 1
	if heavy_dmg <= light_dmg:
		print("CHARGE FAIL the release dealt %d against a light's %d"
			% [heavy_dmg, light_dmg]); fails += 1
	if heavy_frames <= light_frames:
		print("CHARGE FAIL heavy lands %d frames after release, light %d after press — no commitment"
			% [heavy_frames, light_frames]); fails += 1
	if not blocked_up:
		print("CHARGE FAIL shield never rose"); fails += 1
	if blocked_down:
		print("CHARGE FAIL shield never lowered"); fails += 1

	print("CHARGE %s (fails=%d)" % ["OK" if fails == 0 else "FAIL", fails])


func _on_struck(amount: int, _from: Vector3) -> void:
	_hits.append(amount)


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
