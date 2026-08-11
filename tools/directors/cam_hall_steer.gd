extends RefCounted
## P1 — CAN THE PLAYER STEER THE CAMERA IN A CORRIDOR?
##
## Not "does it jitter" (#11, closed) and not "does the eye end up in solid"
## (`p1_corridor_audit.gd`). This asks the one thing the player complains about:
## the stick is pushed and the view does not turn.
##
## The suspect is `GameCamera._place`. The wall logic latches a SWING BIAS, and
## `view` is built from `_yaw + _swing_bias_deg` — so the bias rotates what the
## player SEES, not merely where the eye sits. In a 4 m corridor with a 4.13 m
## boom the only directions that clear `min_distance` lie near the corridor axis,
## so as the stick walks `_yaw` off the axis `_arc_on` walks the bias back the
## other way and the two cancel.
##
## THE MEASUREMENT: hold `cam_right` and compare the yaw the player asked for
## (`_yaw`) against the yaw they got (the camera's own flattened forward).
##
##   * `gain`  = realized sweep / commanded sweep over the whole leg.
##   * `worst` = the lowest gain over any 0.4 s window — the stretch where the
##               stick is dead in the player's hand. A whole-leg average hides
##               it: live for a second, stone dead for half of one, "fine".
##   * `snap`  = the largest single-tick realized step, against what the stick
##               can physically ask for in a tick. The bias saturating at
##               `swing_max_deg` and letting go is a jump-cut, and it is the
##               other half of the same complaint.
##   * `bias`  = the widest `_swing_bias_deg` seen. This is what makes the report
##               name a CAUSE instead of inferring one.
##
## THE CONTROL LEG COMES FIRST AND IT CERTIFIES ITS OWN GROUND.
##
## CLAUDE.md §2 is explicit that a director pointed at a suspected false reading
## has to be shown a case whose answer is already known, and this one earned that
## paragraph the hard way: the first cut put the control at the middle of the
## 20x20 chamber, called it open, and reported the stick 60% DEAD there. The
## chamber is not open — `proving_ground.tscn` puts a 2x2 step block 1.1 m east
## of the centre, and two pillars and two more blocks along the west — so the arc
## was firing in the "control" and the corridor numbers underneath it meant
## nothing. A hardcoded second guess would have been the same mistake with better
## arithmetic, so `_find_open_ground` SWEEPS FOR a spot where the boom is clear
## at every yaw and FAILS THE RUN if it cannot find one. The control is now a
## measurement, not an assumption.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##       --scene=res://scenes/rooms/playtest.tscn \
##       --director=res://tools/directors/cam_hall_steer.gd \
##       --out=/tmp/cam/hall.png --warmup=30

## Seconds of held stick per leg. Long enough at `stick_speed_deg` 170°/s to
## sweep most of a circle, so the bias has room to latch, saturate and release.
const SWEEP_SECONDS := 2.2
const WINDOW_SECONDS := 0.4
## The corridor: walls at x=+-2 running to an end wall at z=-26.
const HALL_AT := Vector3(0.0, 0.05, -18.0)
## Backed up 1.5 m off the end wall, boxed in on three sides.
const END_AT := Vector3(0.0, 0.05, -24.5)
## What the control leg needs clear at every yaw: the longest boom plus the probe
## radius plus a little. Anything less and the arc can fire in the control.
const OPEN_CLEARANCE := 4.6

var _fails: int = 0


func run(rig) -> void:
	var hero: Node3D = rig.get_first_node_in_group(&"player")
	var cam: Camera3D = rig.root.get_camera_3d()
	if hero == null or cam == null:
		print("CAM_HALL FAIL - no hero (%s) or no camera (%s)" % [hero, cam])
		return

	# Annotated, not inferred: `_find_open_ground` returns null when there is no
	# clean ground, so its type is Variant and `:=` cannot infer it (CLAUDE.md §3).
	var open_at: Variant = _find_open_ground(hero)
	if open_at == null:
		print(("CAM_HALL FAIL - no unobstructed ground in this scene with %.2f m"
				+ " clear at every yaw, so there is no control leg and the corridor"
				+ " reading below would be unproven. Point this at a scene with an"
				+ " open floor.") % OPEN_CLEARANCE)
		_fails += 1
	else:
		# gain_min 0.97 rather than 1.00: the sweep crosses ticks where the eye is
		# still easing a residual bias out from the walk to the spot, and 3% of a
		# 170°/s stick is under a tenth of a degree a tick.
		await _sweep(rig, hero, cam, "OPEN", open_at, 0.97)

	# Mid-corridor, and then backed up almost against the end wall — the case where
	# no yaw clears at all, so the arc used to give up and hand over to the climb
	# and the pull-in. It is the hardest ground for a pull-in working alone and so
	# the likeliest place for the eye to leave the room.
	await _sweep(rig, hero, cam, "HALL", HALL_AT, 0.97)
	await _sweep(rig, hero, cam, "ENDWALL", END_AT, 0.97)

	if _fails == 0:
		print("CAM_HALL OK -- every check passed")
	else:
		print("CAM_HALL FAIL -- %d check(s) failed" % _fails)


## Find a spot on this floor where a full boom is clear at EVERY yaw, or null.
##
## Grid-searched and probed rather than read off the scene file, because the
## scene file is what fooled the first cut of this director: "the chamber is
## 20x20 and the walls are at +-10" is true and is not the question.
func _find_open_ground(hero: Node3D):
	var space := hero.get_world_3d().direct_space_state
	var probe := SphereShape3D.new()
	probe.radius = 0.3
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = probe
	q.collision_mask = K.L_WORLD
	q.collide_with_areas = false

	var best: Variant = null
	var best_clear := 0.0
	var x := -6.0
	while x <= 6.0:
		var z := -6.0
		while z <= 8.0:
			var at := Vector3(x, 0.05, z)
			var eye := at + Vector3.UP * K.HERO_EYE_Y
			var worst := 1e9
			var a := 0.0
			while a < TAU:
				# The resting boom's elevation, the one `_place` sweeps.
				var dir := Vector3(sin(a) * cos(deg_to_rad(K.CAM_PITCH)),
						sin(deg_to_rad(K.CAM_PITCH)),
						cos(a) * cos(deg_to_rad(K.CAM_PITCH)))
				q.transform = Transform3D(Basis(), eye)
				q.motion = dir * OPEN_CLEARANCE
				var res := space.cast_motion(q)
				var got := OPEN_CLEARANCE
				if res.size() == 2:
					got = OPEN_CLEARANCE * float(res[0])
				worst = minf(worst, got)
				a += deg_to_rad(15.0)
			if worst > best_clear:
				best_clear = worst
				best = at
			z += 0.5
		x += 0.5

	if best_clear < OPEN_CLEARANCE - 0.01:
		print("CAM_HALL control search: best ground was %.2f m clear, wanted %.2f"
				% [best_clear, OPEN_CLEARANCE])
		return null
	print("CAM_HALL control ground (%.1f, %.1f) is %.2f m clear at every yaw"
			% [best.x, best.z, best_clear])
	return best


func _sweep(rig, hero: Node3D, cam: Camera3D, tag: String, at: Vector3,
		gain_min: float) -> void:
	# Put him there and let the rig settle. The at-point is deliberately laggy
	# (§1.5) and `at_leash` only bounds it to 2.2 m, so a sweep started on the
	# frame after a teleport would be measuring the follow and not the steering.
	hero.global_position = at
	if hero is CharacterBody3D:
		(hero as CharacterBody3D).velocity = Vector3.ZERO
	await rig.wait_seconds(1.6)

	var commanded: Array[float] = []
	var realized: Array[float] = []
	var bias := 0.0
	var engaged := 0
	commanded.append(_cam_yaw(cam))
	realized.append(_view_yaw(cam))

	# THE OTHER HALF OF THE CARD, AND THE HALF A GAIN NUMBER CANNOT SEE.
	#
	# Freeing the stick means the wall's ARC no longer keeps the eye out of the
	# geometry — the pull-in is the only thing left doing it. So the sweep has to
	# prove the pull-in carries that alone, or the fix for "I cannot move the
	# camera" would be a licence to look through the corridor into whatever is on
	# the other side. `solid` is the yes/no: is the eye inside collision. `nearest`
	# is the softer version of the same question, because an eye 4 cm off a wall
	# renders the far side just as badly as an eye 4 cm past it (`near` = 0.05).
	var space := hero.get_world_3d().direct_space_state
	var probe := SphereShape3D.new()
	probe.radius = 0.05
	var solid_q := PhysicsShapeQueryParameters3D.new()
	solid_q.shape = probe
	solid_q.collision_mask = K.L_WORLD
	solid_q.collide_with_areas = false
	var in_solid := 0
	var near_risk := 0
	var boom_min := 1e9

	# Off `Engine` and not `rig.root.get_physics_process_delta_time()`: `rig` is an
	# untyped parameter, so that call's return type cannot be inferred and the
	# director will not parse (CLAUDE.md §3).
	var step := 1.0 / float(Engine.get_physics_ticks_per_second())
	# Sampled on `physics_frame`, because the camera runs in `_physics_process` at
	# 60 Hz while the harness renders UNCAPPED — a render frame is not a camera
	# update, and some carry two ticks while some carry none.
	await rig.press(&"cam_right")
	var spent := 0.0
	while spent < SWEEP_SECONDS:
		await rig.physics_frame
		spent += step
		commanded.append(_cam_yaw(cam))
		realized.append(_view_yaw(cam))
		if absf(float(cam.get("_swing_bias_deg"))) > absf(bias):
			bias = float(cam.get("_swing_bias_deg"))
		if bool(cam.get("_wall_engaged")):
			engaged += 1
		solid_q.transform = Transform3D(Basis(), cam.global_position)
		if space.intersect_shape(solid_q, 1).size() > 0:
			in_solid += 1
		if _nearest_surface(space, cam.global_position) < 0.12:
			near_risk += 1
		boom_min = minf(boom_min,
				cam.global_position.distance_to(hero.global_position + Vector3.UP * K.HERO_EYE_Y))
	rig.release(&"cam_right")

	# Totals, unwrapped per step because a sweep crosses +-PI.
	var c_total := 0.0
	var r_total := 0.0
	var snap := 0.0
	var steps: Array[float] = []
	var c_steps: Array[float] = []
	for i in range(1, commanded.size()):
		var dc := absf(wrapf(commanded[i] - commanded[i - 1], -PI, PI))
		var dr := absf(wrapf(realized[i] - realized[i - 1], -PI, PI))
		c_total += dc
		r_total += dr
		c_steps.append(dc)
		steps.append(dr)
		snap = maxf(snap, rad_to_deg(dr))

	var gain := r_total / maxf(c_total, 0.0001)

	# What the stick can physically ask for in one tick. The first cut hardcoded
	# `snap_max` at 2.0° and flagged the ordinary 170°/s sweep — 2.83°/tick — as a
	# jump-cut in the CONTROL. A threshold has to be derived from the rate, not
	# guessed under it.
	var per_tick := float(cam.get("stick_speed_deg")) * step
	var snap_max := per_tick * 1.6

	var w := _worst_window(c_steps, steps, step)
	var worst: float = w[0]
	print(("CAM_HALL %s commanded=%.1fdeg realized=%.1fdeg gain=%.2f worst=%.2f@%.2fs"
			+ " snap=%.1fdeg (stick=%.2fdeg/tick) bias=%.1fdeg engaged=%d/%d")
			% [tag, rad_to_deg(c_total), rad_to_deg(r_total), gain, worst, w[1],
			snap, per_tick, bias, engaged, steps.size()])
	if worst < gain_min:
		print(("CAM_HALL FAIL %s - the stick goes dead: %.0f%% of the commanded turn"
				+ " reaches the screen over a %.1f s window at %.2f s (want >= %.0f%%)")
				% [tag, worst * 100.0, WINDOW_SECONDS, w[1], gain_min * 100.0])
		_fails += 1
	if snap > snap_max:
		print(("CAM_HALL FAIL %s - the view jump-cuts: %.1f deg in one tick, and the"
				+ " stick only asks for %.2f (want <= %.1f)")
				% [tag, snap, per_tick, snap_max])
		_fails += 1
	print("CAM_HALL %s eye_in_solid=%d near_clip=%d boom_min=%.2f of %d ticks"
			% [tag, in_solid, near_risk, boom_min, steps.size()])
	# ZERO, not "a few". An eye inside collision is a player looking through the
	# level, and freeing the stick is exactly what put the whole burden on the
	# pull-in — so this is the check that says the trade was safe.
	if in_solid > 0 or near_risk > 0:
		print(("CAM_HALL FAIL %s - the eye left the room while the player steered:"
				+ " %d tick(s) inside collision, %d within 0.12 m of a surface."
				+ " The pull-in is not holding the angles the arc used to.")
				% [tag, in_solid, near_risk])
		_fails += 1
	await rig.capture("cam_hall_%s.png" % tag.to_lower())


## Distance to the nearest surface around `p`, probed on the six axes. The softer
## half of "is the eye in solid": `near` is 0.05, so an eye a few centimetres off
## a wall renders the far side just as well as one a few centimetres past it.
func _nearest_surface(space: PhysicsDirectSpaceState3D, p: Vector3) -> float:
	var nearest := 99.0
	for d in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK,
			Vector3.UP, Vector3.DOWN]:
		var rq := PhysicsRayQueryParameters3D.create(p, p + d * 1.0)
		rq.collision_mask = K.L_WORLD
		var h := space.intersect_ray(rq)
		if not h.is_empty():
			nearest = minf(nearest, p.distance_to(h.position))
	return nearest


## [worst gain, seconds into the sweep it happened].
func _worst_window(c_steps: Array[float], steps: Array[float], step: float) -> Array:
	var per_window := int(maxf(WINDOW_SECONDS / maxf(step, 0.001), 4.0))
	var worst := 1.0
	var worst_at := 0.0
	for start in range(0, maxi(steps.size() - per_window, 1)):
		var cw := 0.0
		var rw := 0.0
		for k in range(start, mini(start + per_window, steps.size())):
			cw += c_steps[k]
			rw += steps[k]
		if cw <= deg_to_rad(5.0):
			continue      # the stick barely moved here; no ratio worth taking
		var g := rw / cw
		if g < worst:
			worst = g
			worst_at = float(start) * step
	return [worst, worst_at]


## The yaw the PLAYER asked for. `_yaw` is the orbit azimuth the look code writes
## and nothing else touches it.
func _cam_yaw(cam: Camera3D) -> float:
	return float(cam.get("_yaw"))


## The yaw the player GOT. Taken off the camera's own basis rather than any field,
## because the whole question is whether the field reaches the screen — CLAUDE.md
## §4, facing is measured and not derived. A Node3D's forward is `-basis.z`.
func _view_yaw(cam: Camera3D) -> float:
	var f := -cam.global_transform.basis.z
	f.y = 0.0
	if f.length_squared() < 0.000001:
		return 0.0
	f = f.normalized()
	return atan2(f.x, f.z)
