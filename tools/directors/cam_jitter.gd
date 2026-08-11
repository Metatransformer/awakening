extends RefCounted
## The corridor shake, measured per PHYSICS TICK.
##
## p1_corridor_audit answers "is the eye inside a wall". It samples ten times a
## second, which is exactly the wrong instrument for the complaint this exists
## for: the camera VIBRATES in a tight hallway. A 60 Hz wobble sampled at 10 Hz
## is invisible — every sample looks like a plausible camera position.
##
## So this parks the hero in the proving ground's 4 m corridor (the same width
## the generated dungeon lays, K.CORRIDOR_W), sweeps the camera yaw right round
## him, and at each angle samples EVERY tick. It reports, per channel (swing
## bias, lift bias, boom length, eye position), how often the sign of the
## frame-to-frame delta REVERSES. A camera easing somewhere has a reversal rate
## near zero. A camera dithering between two decisions reverses on most frames,
## and that is what the eye reads as shake.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##       --scene=res://scenes/rooms/playtest.tscn \
##       --director=res://tools/directors/cam_jitter.gd --warmup=20

## Corridor centre, from scenes/rooms/proving_ground.tscn: floor at z -18,
## interior walls at x = ±2.
const IN_CORRIDOR := Vector3(0.0, 0.05, -18.0)

var _worst := 0.0
var _worst_yaw := 0.0


func run(rig) -> void:
	var hero: Node3D = rig.get_first_node_in_group(&"player")
	var cam: Camera3D = rig.root.get_camera_3d()

	hero.global_position = IN_CORRIDOR
	await rig.wait_seconds(0.6)

	print("--- CAM_JITTER standing in a 4 m corridor, yaw swept 360° ---")
	print("  yaw   swing rev%%  lift rev%%  boom rev%%   eye rev%%  peak_step  boom_range")
	for step in 24:
		var yaw := deg_to_rad(step * 15.0)
		cam.set(&"_yaw", yaw)
		# Let the rig settle into whatever it wants to do at this angle before
		# measuring: the first ticks after a yaw shove are a legitimate ease, and
		# a full one is a 78° arc (0.4 s) followed by the boom pushing back out at
		# push_out_speed (0.6 s). Measuring inside that window reports transit as
		# though it were a resting pose, and did — the settled boom came out
		# different on every run until this wait covered the whole ease.
		await rig.wait_seconds(2.0)
		var rows := await _sample(rig, hero, cam, 60)
		_report(rows, step * 15.0)
		# Numbers say the rig has stopped moving; only a frame says the shot it
		# stopped at is one you would want to play in. These four are the middle
		# of the band that used to dither.
		if step * 15 in [45, 60, 75, 90]:
			await rig.capture("yaw_%03d.png" % (step * 15))

	print("CAM_JITTER worst eye reversal rate %.0f%% at yaw %.0f°" % [_worst, _worst_yaw])

	await _turning(rig, hero, cam)


## The other half of the question. The sweep above proves the rig does not
## vibrate while the player HOLDS an angle; this proves it does not lurch while
## they turn through one. The stick is played at its own documented rate
## (`stick_speed_deg`), all the way round, and the worst single-tick jump of the
## eye is what a whip would show up as.
func _turning(rig, hero: Node3D, cam: Camera3D) -> void:
	cam.set(&"_yaw", 0.0)
	cam.set(&"_swing_bias_deg", 0.0)
	await rig.wait_seconds(1.5)

	var rate := deg_to_rad(170.0) / 60.0
	var prev: Vector3 = cam.global_position
	var worst := 0.0
	var worst_at := 0.0
	var over := 0
	# A tick of the plain rig at 4.13 m turning 170°/s moves the eye about 0.20 m.
	# Anything much past that is the wall logic adding motion of its own.
	var budget := 0.30
	for i in 200:
		cam.set(&"_yaw", float(cam.get(&"_yaw")) + rate)
		await rig.physics_frame
		var step := cam.global_position.distance_to(prev)
		prev = cam.global_position
		if i < 6:
			continue
		if step > budget:
			over += 1
		if step > worst:
			worst = step
			worst_at = rad_to_deg(cam.get(&"_yaw"))
	print("CAM_JITTER turning: worst eye step %.3f m/tick at yaw %.0f°, %d/194 ticks over %.2f m"
			% [worst, worst_at, over, budget])


func _sample(rig, hero: Node3D, cam: Camera3D, n: int) -> Array:
	var rows: Array = []
	for i in n:
		await rig.physics_frame
		rows.append({
			"swing": float(cam.get(&"_swing_bias_deg")),
			"lift": float(cam.get(&"_lift_bias_deg")),
			"boom": float(cam.get(&"_dist")),
			"pos": cam.global_position,
		})
	return rows


func _report(rows: Array, yaw_deg: float) -> void:
	# The eye itself, which is what the player actually sees moving. Measured as
	# the position delta REVERSING direction — a camera easing along an arc never
	# does; one dithering does it every other tick.
	var flips := 0
	var peak := 0.0
	for i in range(2, rows.size()):
		var a: Vector3 = rows[i]["pos"] - rows[i - 1]["pos"]
		var b: Vector3 = rows[i - 1]["pos"] - rows[i - 2]["pos"]
		if a.length() > 0.0005 and b.length() > 0.0005 and a.normalized().dot(b.normalized()) < -0.3:
			flips += 1
		peak = maxf(peak, a.length())
	var eye_rate := 100.0 * flips / maxf(rows.size() - 2, 1)
	if eye_rate > _worst:
		_worst = eye_rate
		_worst_yaw = yaw_deg
	var lo := 9e9
	var hi := -9e9
	for r in rows:
		lo = minf(lo, r["boom"])
		hi = maxf(hi, r["boom"])
	var last: Dictionary = rows[rows.size() - 1]
	print("  %4.0f°   %5.0f%%      %5.0f%%      %5.0f%%     %5.0f%%   %.4f m   [%.2f %.2f]  rest: swing=%6.1f lift=%4.1f" % [
			yaw_deg, _rate(rows, "swing"), _rate(rows, "lift"), _rate(rows, "boom"),
			eye_rate, peak, lo, hi, last["swing"], last["lift"]])


## How often this scalar channel's frame-to-frame delta changes sign.
func _rate(rows: Array, key: String) -> float:
	var flips := 0
	for i in range(2, rows.size()):
		var a: float = rows[i][key] - rows[i - 1][key]
		var b: float = rows[i - 1][key] - rows[i - 2][key]
		if absf(a) > 1e-4 and absf(b) > 1e-4 and signf(a) != signf(b):
			flips += 1
	return 100.0 * flips / maxf(rows.size() - 2, 1)
