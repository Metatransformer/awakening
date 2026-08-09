extends SceneTree
## Where does a clip STOP MOVING?
##
## Mixamo exports carry a tail of the actor standing still after the action is
## over, and build_anim_lib's TRIM table is what cuts it. The comment on that
## table says to read the number off the tracks rather than eyeball it, and this
## is what reads it: total per-frame rotation across every bone, sampled at
## 30 Hz, printed as a fraction of the clip's own peak.
##
## A tail reads as a run of near-zero rows. Cut at the first sample of the run.
##
##   godot --path . --headless -s tools/_clip_motion.gd -- ax_melee_attack_360_low

const LIB := "res://assets/animations/hero_anims.res"
const STEP := 1.0 / 30.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: _clip_motion.gd -- <clip_name>")
		quit(1)
		return
	var lib := load(LIB) as AnimationLibrary
	for name in args:
		var key := StringName(name)
		if not lib.has_animation(key):
			print("MISSING ", name)
			continue
		_report(lib.get_animation(key), name)
	quit(0)


func _report(anim: Animation, name: String) -> void:
	var rows: Array[float] = []
	var peak := 0.0
	var t := 0.0
	while t + STEP <= anim.length:
		var d := 0.0
		for i in anim.get_track_count():
			if anim.track_get_type(i) != Animation.TYPE_ROTATION_3D:
				continue
			var a: Quaternion = anim.rotation_track_interpolate(i, t)
			var b: Quaternion = anim.rotation_track_interpolate(i, t + STEP)
			d += absf(a.angle_to(b))
		rows.append(d)
		peak = maxf(peak, d)
		t += STEP

	print("=== %s  len=%.2fs  samples=%d ===" % [name, anim.length, rows.size()])
	for i in rows.size():
		var frac := rows[i] / maxf(peak, 0.0001)
		print("  t=%.2f  %5.1f%%  %s" % [
			float(i) * STEP, frac * 100.0, "#".repeat(int(frac * 40.0))])
