extends RefCounted
## Is the heavy attack a different blow from the light one, or just a second
## button that does the same thing?
##
## Three claims, and this fails loudly on each:
##   1. X/F lands at all — a new action bound to nothing swings nothing.
##   2. It hurts more than the light swing. `total_damage` on the post is the
##      proof; the pose is not.
##   3. It takes longer to arrive. The heavy's whole cost is the commitment, so
##      a heavy that connects on the same frame as a light is a free upgrade and
##      the light button is dead content.
##
## The swing frames are a contact sheet on purpose. A single frame cannot tell
## you whether a wind-up reads — you have to see the pose move through it, which
## is exactly the mistake this project has made before with facing.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/p4_heavy.gd --out=/tmp/p4h/x.png

func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/p4h/x.png").get_base_dir()
	var scene: Node = rig.scene()
	var hero: Node3D = scene.get_node_or_null(^"Hero") as Node3D
	var fails := 0

	if hero == null:
		print("HEAVY FAIL no Hero in the scene")
		return
	# The hero owns its combat node and publishes it; do not go fishing in the
	# scene tree for it (docs/CONTRACT.md §8).
	var combat: Node = hero.get(&"combat")
	if combat == null:
		print("HEAVY FAIL no HeroCombat on the Hero")
		return

	# Both actions must exist before anything else is worth measuring — this is
	# the check that catches a project.godot edit that did not take.
	for action in [&"attack", &"heavy_attack", &"shield"]:
		if not InputMap.has_action(action):
			print("HEAVY FAIL action missing from the InputMap: ", action)
			fails += 1
	print("HEAVY binds attack=%s heavy=%s shield=%s"
		% [_binds(&"attack"), _binds(&"heavy_attack"), _binds(&"shield")])

	var post: Node = scene.get_node_or_null(^"PostA")
	if post == null:
		print("HEAVY FAIL no PostA to hit")
		return

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
	print("HEAVY range=%.2fm reach=%.2fm"
		% [hero.global_position.distance_to(post_pos), float(combat.get(&"reach"))])
	await rig.capture(out.path_join("h_00_approach.png"))

	# --- the light swing, for the number the heavy has to beat ---------------
	var light_before: int = int(post.get(&"total_damage"))
	var light_frames := await _swing_and_time(rig, combat, post, "attack")
	var light_dmg: int = int(post.get(&"total_damage")) - light_before
	await rig.wait_frames(24)
	await rig.capture(out.path_join("h_01_after_light.png"))

	# --- the heavy, sampled across the wind-up ------------------------------
	var heavy_before: int = int(post.get(&"total_damage"))
	await rig.tap(["heavy_attack"])
	for i in 8:
		await rig.wait_frames(4)
		await rig.capture(out.path_join("h_02_heavy_%d.png" % i))
	await rig.wait_frames(30)
	var heavy_dmg: int = int(post.get(&"total_damage")) - heavy_before
	await rig.capture(out.path_join("h_03_after_heavy.png"))

	# Time it separately from the contact sheet: capture() stalls the frame
	# clock, so a swing measured while screenshotting is measuring the disk.
	var heavy_before2: int = int(post.get(&"total_damage"))
	var heavy_frames := await _swing_and_time(rig, combat, post, "heavy_attack")
	var heavy_dmg2: int = int(post.get(&"total_damage")) - heavy_before2

	# --- the shield still works, on its new binding -------------------------
	# The trigger is an axis now. This presses the ACTION, so it proves the
	# shield still reads its action; the binding itself is proved by the runtime
	# dump in tools/scenes/_padnames.tscn, which is the only honest source.
	await rig.hold(["shield"], 30)
	await rig.capture(out.path_join("h_04_block.png"))
	var blocked_up: bool = bool(combat.get(&"blocking"))
	await rig.wait_frames(24)
	var blocked_down: bool = bool(combat.get(&"blocking"))

	print("HEAVY light dmg=%d contact_frame=%d" % [light_dmg, light_frames])
	print("HEAVY heavy dmg=%d contact_frame=%d (sheet run dmg=%d)"
		% [heavy_dmg2, heavy_frames, heavy_dmg])

	if light_dmg <= 0:
		print("HEAVY FAIL the light swing did not land"); fails += 1
	if heavy_dmg2 <= 0:
		print("HEAVY FAIL the heavy swing did not land — is X bound?"); fails += 1
	if heavy_dmg2 <= light_dmg:
		print("HEAVY FAIL heavy (%d) does not out-damage light (%d)"
			% [heavy_dmg2, light_dmg]); fails += 1
	if heavy_frames <= light_frames:
		print("HEAVY FAIL heavy lands on frame %d, light on %d — no commitment"
			% [heavy_frames, light_frames]); fails += 1
	if not blocked_up:
		print("HEAVY FAIL shield never rose"); fails += 1
	if blocked_down:
		print("HEAVY FAIL shield never lowered"); fails += 1

	print("HEAVY %s (fails=%d)" % ["OK" if fails == 0 else "FAIL", fails])


## Tap `action` and return how many frames passed before the post's damage
## total moved. That is the contact frame — the honest measure of a wind-up,
## because it is when the blow ARRIVES, not when the clip started.
func _swing_and_time(rig, _combat: Node, post: Node, action: String) -> int:
	var before: int = int(post.get(&"total_damage"))
	await rig.tap([action])
	var frames := 0
	while frames < 180:
		if int(post.get(&"total_damage")) != before:
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
