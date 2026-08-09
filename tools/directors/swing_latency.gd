extends RefCounted
## How long after the button does the BLADE ACTUALLY MOVE?
##
## The number the player feels is not `swing_time` and it is not the fade-in. It
## is the gap between the press and the first frame the sword is visibly
## travelling, and until this director existed nothing in the project measured
## it — every swing test here asks whether the post's hit counter went up, which
## a swing that starts a fifth of a second late passes perfectly.
##
## So this presses the button and then watches the sword hand, one physics frame
## at a time, in HERO SPACE (the hero re-faces on the swing; in world space that
## turn reads as blade travel and swamps everything). It prints, per swing:
##
##   swing@  ms until the hand is moving at half its peak speed for this swing
##   peak@   ms until the fastest frame — the moment of contact
##   live@   ms until the hitbox opens, straight out of the combat numbers
##
## `swing@` should land on `live@`. A blade that goes live before it moves is
## damage the player cannot see coming; a blade that moves long after the press
## is the lag this was written for.
##
## The threshold is a FRACTION OF THIS SWING'S OWN PEAK, never an absolute speed,
## and the first version of this director got that wrong in a way worth keeping a
## note about. It gated on 2 m/s, read off tools/_clip_windup.gd — but that tool
## walks the clip at 1x and the game plays it at up to 2.5x to fit `swing_time`.
## Every speed in the clip multiplies by the same factor, so the wind-up crosses
## a fixed threshold as easily as the strike does. It reported the swing starting
## at 67 ms both before and after a change that demonstrably moved it, which is
## the most dangerous kind of measurement: one that agrees with you.
##
## The burst of PNGs is the other half and is not optional — see CLAUDE.md §2.
## A number cannot tell you the hero POPPED into the pose, and popping is the
## thing a start_offset gets wrong when it is set too deep.
##
##   godot --path . -s tools/directors/swing_latency.gd  # (via shoot.gd:)
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/swing_latency.gd --out=/tmp/lat/x.png

## Fraction of the swing's own peak hand speed that counts as "swinging". Half,
## because every clip in tools/_clip_windup.gd has its wind-up topping out around
## a third of its strike — the gap is wide and the midpoint sits in it.
const SWINGING := 0.5
## Frames at the head of the window that the summary ignores. They are the
## CROSSFADE, and on the dash they are the largest number in the whole run:
## coming off a raised guard, the one-shot eases a block pose into a coiled
## thrust in 0.04 s, and the hand covers more ground doing it than it does in the
## thrust itself. Reading that as the strike put the dash's contact at 67 ms, on
## a move whose hitbox does not open until 211 ms.
##
## The cost of this is a blind spot: a swing that genuinely struck inside 100 ms
## would be reported from its recovery instead. Nothing in the kit is close —
## the fastest is the light at ~215 ms — but the PROFILE below the summary is
## printed for exactly this reason. Read it before believing the line above it.
const BLEND := 6
## Physics frames to watch. 48 is 0.8 s, comfortably past the longest commitment
## in the kit (the spin's 0.68 s).
##
## It was 30 — half a second — on the reasoning that no swing takes that long to
## reach contact. The spin does: its sweep peaks around 520 ms after the release,
## so the window closed while the profile was still climbing and the summary
## reported the last frame it happened to see as the peak. A window that ends
## mid-swing does not report a missing measurement, it reports a wrong one.
const FRAMES := 48


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/lat/x.png").get_base_dir()
	var players: Array = rig.get_nodes_in_group(&"player")
	if players.is_empty():
		print("LATENCY FAIL no node in group `player`")
		return
	var hero: Node3D = players[0]
	var combat: Node = hero.get(&"combat")
	if combat == null or combat.get(&"sword") == null:
		print("LATENCY FAIL hero has no sword")
		return
	await rig.wait_frames(30)

	# Every swing is measured from a standing start with nothing in reach, so
	# what is being timed is the animation and not a walk or a hit-stop.
	var fails := 0
	fails += await _time(rig, hero, combat, "LIGHT1", [], "attack", 0,
		combat.get(&"swing_time"), (combat.get(&"damage_window") as Vector2).x)
	fails += await _time(rig, hero, combat, "DASH", ["shield"], "attack", 0,
		combat.get(&"dash_swing_time"), (combat.get(&"dash_damage_window") as Vector2).x)
	# The spin is the one swing that is not a press: the button has to be HELD
	# past charge_time and the RELEASE is the swing, so the clock starts there.
	fails += await _time(rig, hero, combat, "SPIN", [], "attack",
		int(ceil((float(combat.get(&"charge_time")) + 0.12) * 60.0)),
		combat.get(&"spin_swing_time"), (combat.get(&"spin_damage_window") as Vector2).x)

	await _burst(rig, hero, out)
	print("LATENCY %s" % ("done" if fails == 0 else "FAIL %d swing(s)" % fails))


## Press `action` (after `mods` are already down), hold it `hold_frames`, and
## watch the sword hand for half a second. Returns 1 if the swing never came out.
func _time(rig, hero: Node3D, combat: Node, label: String, mods: Array,
		action: String, hold_frames: int, duration: float, live01: float) -> int:
	for m in mods:
		Input.action_press(m)
	# Guarding pins the facing and takes a moment to raise; the dash measured
	# without it is a light swing wearing the wrong label.
	if not mods.is_empty():
		await rig.wait_frames(20)

	# `hold()`'s note applies here and is the reason this presses at the top of a
	# frame: a press stamped on a frame the game has already polled is a press
	# the game never sees.
	await rig.process_frame
	Input.action_press(action)

	# The clock starts at the RELEASE for anything held, and the first version of
	# this director got that wrong in a way that produced a confident number for a
	# swing it never saw. The spin's press throws a swing on its way past (that is
	# the design — `HeroCombat._tick_heavy_button` fires the overhead on the press
	# and winds up only if you keep holding), so a window opened at the press
	# watches that swing and times out ~40 ms before the spin comes out. The
	# giveaway was SPIN's profile being byte-identical to the press swing's from
	# 133 ms on.
	if hold_frames > 0:
		await rig.wait_frames(hold_frames)
		Input.action_release(action)
		await rig.process_frame

	var sword: Node3D = combat.get(&"sword")
	var prev := _local(hero, sword)
	var speeds: Array[float] = []
	var swung := false
	for i in FRAMES:
		await rig.physics_frame
		if hold_frames == 0 and i == 1:
			Input.action_release(action)
		var p := _local(hero, sword)
		if hero.get(&"state") == 4:  # Hero.MoveState.ATTACK
			swung = true
		speeds.append(p.distance_to(prev) * 60.0)
		prev = p
	Input.action_release(action)
	for m in mods:
		Input.action_release(m)
	await rig.wait_frames(40)

	if not swung:
		print("LATENCY %-7s FAIL never swung" % label)
		return 1

	var peak := 0.0
	var peak_at := 0
	for i in range(BLEND, speeds.size()):
		if speeds[i] > peak:
			peak = speeds[i]
			peak_at = i
	var swing_at := -1
	for i in range(BLEND, speeds.size()):
		if speeds[i] >= peak * SWINGING:
			swing_at = i
			break

	print("LATENCY %-7s swing@%4dms  peak@%4dms  live@%4dms  (commits %.0fms)" % [
		label, _ms(swing_at), _ms(peak_at), roundi(live01 * duration * 1000.0),
		duration * 1000.0])
	# The profile, because the summary above is three numbers off a curve and the
	# curve is what says whether the swing has one strike in it or two.
	for i in speeds.size():
		print("    %-7s %4dms %5.1f %s" % [label, _ms(i), speeds[i],
			"#".repeat(int(speeds[i] / maxf(peak, 0.001) * 40.0))])
	return 0


func _ms(frame: int) -> int:
	return -1 if frame < 0 else roundi(float(frame) * 1000.0 / 60.0)


## The sword in the hero's own space. In world space the swing's own re-facing
## turn moves the blade metres before the arm has done anything.
func _local(hero: Node3D, sword: Node3D) -> Vector3:
	return hero.global_transform.affine_inverse() * sword.global_position


## One PNG per physics frame across the first quarter-second of a light swing,
## from a 3/4 front angle where the blade's travel is legible. This is the part
## that catches a pose POP, which no timing number can.
func _burst(rig, hero: Node3D, out: String) -> void:
	var cam := hero.get_viewport().get_camera_3d()
	if cam == null:
		print("LATENCY no camera; skipping the burst")
		return
	# GameCamera re-derives its own transform every physics frame, so it has to
	# be stopped before it can be parked (swing_lookdev.gd learned this first).
	cam.set_physics_process(false)
	cam.global_position = hero.global_position + Vector3(1.6, 1.6, 2.4)
	cam.look_at(hero.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("lat_00_idle.png"))

	await rig.process_frame
	Input.action_press(&"attack")
	for i in 14:
		await rig.wait_frames(1)
		if i == 1:
			Input.action_release(&"attack")
		cam.global_position = hero.global_position + Vector3(1.6, 1.6, 2.4)
		cam.look_at(hero.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)
		await rig.capture(out.path_join("lat_%02d.png" % (i + 1)))
	Input.action_release(&"attack")
