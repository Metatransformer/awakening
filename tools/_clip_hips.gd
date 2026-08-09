extends SceneTree
## Hip HEIGHT over time, which is what a jump clip actually is: ground, launch,
## apex, land.
##
## The companion to _clip_motion.gd, and the reason both exist: _clip_motion
## measures total bone ROTATION, which is the right question for a swing and
## completely blind to a jump. A leap is almost pure translation, so a jump clip
## reads as a flat, unremarkable line there while the hips are describing a
## metre-high parabola nobody can see.
##
## This is what build_anim_lib's TRIM entries for `ex_jump` and `ex_jump_running`
## were read off, and what `Hero.jump_start_offset` was read off — the frame the
## feet leave the ground is the frame the hips start climbing.
##
##   godot --path . --headless -s tools/_clip_hips.gd -- ex_jump ex_jump_running
const LIB := "res://assets/animations/hero_anims.res"
const STEP := 1.0 / 30.0

func _initialize() -> void:
	var lib := load(LIB) as AnimationLibrary
	for name in OS.get_cmdline_user_args():
		var key := StringName(name)
		if not lib.has_animation(key):
			print("MISSING ", name); continue
		_report(lib.get_animation(key), name)
	quit(0)

func _report(anim: Animation, name: String) -> void:
	var idx := -1
	for i in anim.get_track_count():
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		if str(anim.track_get_path(i)).ends_with(":mixamorig_Hips"):
			idx = i; break
	if idx < 0:
		print("no hips track in ", name); return
	var ys: Array[float] = []
	var t := 0.0
	while t <= anim.length:
		var v: Vector3 = anim.position_track_interpolate(idx, t)
		ys.append(v.y)
		t += STEP
	var lo: float = ys.min()
	var hi: float = ys.max()
	print("=== %s len=%.2f  hips y %.3f..%.3f (rise %.3f) ===" % [name, anim.length, lo, hi, hi - lo])
	for i in ys.size():
		var f := 0.0 if hi - lo < 0.0001 else (ys[i] - lo) / (hi - lo)
		print("  t=%.2f  y=%.3f  %s" % [i * STEP, ys[i], "#".repeat(int(f * 46.0))])
