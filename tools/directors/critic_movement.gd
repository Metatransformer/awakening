extends RefCounted
## CRITIC-OWNED director. Not the builder's. Drives locomotion and records
## per-physics-frame telemetry INCLUDING world-space foot bone positions, so
## "ice skating" is measured rather than eyeballed.
##
## The planted foot of a correctly-tuned gait is stationary in world space.
## If the slower foot is still moving forward at a large fraction of body
## speed, the feet are sliding on the ground.

var _i := 0
var _rows: PackedStringArray = []
var _running := true
var _hero: Node3D
var _skel: Skeleton3D
var _lf := -1
var _rf := -1
var _prev_l := Vector3.ZERO
var _prev_r := Vector3.ZERO
var _prev_p := Vector3.ZERO
var _have_prev := false
var _t := 0.0
var _tag := "init"
var _capture := false


func run(rig) -> void:
	_hero = rig.scene().find_child("Hero", true, false) as Node3D
	_skel = _hero.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skel != null:
		_lf = _skel.find_bone("mixamorig_LeftFoot")
		_rf = _skel.find_bone("mixamorig_RightFoot")
	print("CRITIC hero=%s skel=%s lf=%d rf=%d bones=%d" % [_hero, _skel, _lf, _rf,
		(_skel.get_bone_count() if _skel else -1)])
	_sample_loop(rig)

	_capture = rig.arg("cap", "") != ""

	# 0) settle
	_tag = "idle"
	await rig.wait_seconds(0.6)
	await _shot(rig, "idle")

	# 1) speed sweep: does an intermediate stick give a real walk?
	for m in [0.40, 0.55, 0.70, 0.85, 1.00]:
		Input.action_press(&"move_up", m)
		_tag = "sweep_%.2f" % m
		await rig.wait_seconds(0.9)
		await _shot(rig, "s%02d" % int(m * 100))
		await rig.wait_seconds(0.5)
		await _shot(rig, "s%02db" % int(m * 100))

	# 2) hard stop from a full sprint — 5 frames at 0.06 s
	Input.action_release(&"move_up")
	_tag = "stop"
	for i in 6:
		await rig.wait_seconds(0.06)
		await _shot(rig, "stop")

	await rig.wait_seconds(0.8)

	# 3) run cycle at cap, tight cadence, for the foot-slip read
	Input.action_press(&"move_up", 1.0)
	await rig.wait_seconds(0.5)
	_tag = "runcap"
	for i in 8:
		await rig.wait_seconds(0.06)
		await _shot(rig, "run")

	# 4) 180 reversal
	Input.action_release(&"move_up")
	Input.action_press(&"move_down", 1.0)
	_tag = "turn180"
	for i in 10:
		await rig.wait_seconds(0.07)
		await _shot(rig, "turn")
	_tag = "post180"
	await rig.wait_seconds(0.6)
	Input.action_release(&"move_down")
	await rig.wait_seconds(1.0)

	# 5) roll out of a full run
	Input.action_press(&"move_up", 1.0)
	await rig.wait_seconds(0.6)
	_tag = "preroll"
	await _shot(rig, "preroll")
	Input.action_press(&"context")
	await rig.wait_seconds(0.03)
	Input.action_release(&"context")
	_tag = "roll"
	for i in 12:
		await rig.wait_seconds(0.07)
		await _shot(rig, "roll")
	_tag = "rollrec"
	for i in 4:
		await rig.wait_seconds(0.08)
		await _shot(rig, "rec")
	Input.action_release(&"move_up")
	await rig.wait_seconds(0.6)

	_running = false
	await rig.wait_seconds(0.1)
	var f := FileAccess.open(rig.arg("csv", "/tmp/critic_move.csv"), FileAccess.WRITE)
	f.store_string("t,tag,px,pz,speed,footslip_min,footslip_max,lfy,rfy,yawdeg\n")
	f.store_string("\n".join(_rows))
	f.close()
	print("CRITIC csv rows=%d" % _rows.size())


func _sample_loop(rig) -> void:
	while _running:
		await rig.physics_frame
		_t += 1.0 / 60.0
		if _hero == null or _skel == null:
			continue
		var st := _skel.global_transform
		var l: Vector3 = st * _skel.get_bone_global_pose(_lf).origin
		var r: Vector3 = st * _skel.get_bone_global_pose(_rf).origin
		var p: Vector3 = _hero.global_position
		if _have_prev:
			var dt := 1.0 / 60.0
			var ls := Vector2(l.x - _prev_l.x, l.z - _prev_l.z).length() / dt
			var rs := Vector2(r.x - _prev_r.x, r.z - _prev_r.z).length() / dt
			var bs := Vector2(p.x - _prev_p.x, p.z - _prev_p.z).length() / dt
			_rows.append("%.3f,%s,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.2f" % [
				_t, _tag, p.x, p.z, bs, minf(ls, rs), maxf(ls, rs),
				l.y - p.y, r.y - p.y, rad_to_deg(_hero.rotation.y)])
		_prev_l = l
		_prev_r = r
		_prev_p = p
		_have_prev = true


func _shot(rig, tag: String) -> void:
	if not _capture:
		return
	await rig.capture("movement_%03d_%s.png" % [_i, tag])
	_i += 1
