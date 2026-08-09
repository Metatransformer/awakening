extends SceneTree
## Where does a swing clip STOP WINDING UP and start striking?
##
## `_clip_motion.gd` answers the other end of the same question — where a clip
## stops moving — by summing rotation across every bone. That measure cannot see
## a wind-up, because a wind-up is bones moving briskly in the WRONG DIRECTION:
## ss_slash_01 reads 48% of peak motion on frame 0 while the sword is travelling
## backwards over the hero's shoulder.
##
## So this samples the SWORD HAND instead, in the hero's own space (hips-local,
## so the clip's body turn does not read as hand travel), and prints:
##
##   fwd   the hand's position along the hero's facing. Negative is drawn back.
##   spd   how fast the hand is moving, m/s of clip time.
##
## The strike is the first sustained run of fast FORWARD travel — the frame the
## `fwd` column bottoms out and turns around. Everything before it is the
## anticipation, and `Hero._SWING_START_OFFSET` is what skips it.
##
##   godot --path . --headless -s tools/_clip_windup.gd -- ss_slash_01 ss_slash_03

const MODEL := "res://assets/characters/hero.fbx"
const LIB := "res://assets/animations/hero_anims.res"
const STEP := 1.0 / 30.0
## Mixamo's naming. The right hand carries the sword (see HeroCombat's socket).
const HAND := "mixamorig_RightHand"
const HIPS := "mixamorig_Hips"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: _clip_windup.gd -- <clip_name> [<clip_name> ...]")
		quit(1)
		return

	var lib := load(LIB) as AnimationLibrary
	var rig := (load(MODEL) as PackedScene).instantiate() as Node3D
	root.add_child(rig)
	var skel := rig.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		print("rig has no Skeleton3D")
		quit(1)
		return

	var hand := skel.find_bone(HAND)
	var hips := skel.find_bone(HIPS)
	if hand < 0 or hips < 0:
		print("rig has no %s / %s" % [HAND, HIPS])
		quit(1)
		return

	for name in args:
		if not lib.has_animation(StringName(name)):
			print("MISSING ", name)
			continue
		_report(skel, hand, hips, lib.get_animation(StringName(name)), name)
	quit(0)


## The pose is computed by hand rather than played through an AnimationPlayer.
## A `-s` script has no frame loop, and a mixer that is never processed hands
## back the REST POSE at every seek — which prints as a clip that does not move,
## the single most convincing wrong answer this tool could give. Sampling the
## tracks and walking the bone hierarchy has no such failure mode.
func _report(skel: Skeleton3D, hand: int, hips: int, anim: Animation, name: String) -> void:
	var rot := {}
	var pos := {}
	for i in anim.get_track_count():
		var bone := skel.find_bone(anim.track_get_path(i).get_concatenated_subnames())
		if bone < 0:
			continue
		match anim.track_get_type(i):
			Animation.TYPE_ROTATION_3D: rot[bone] = i
			Animation.TYPE_POSITION_3D: pos[bone] = i

	var pts: Array[Vector3] = []
	var t := 0.0
	while t <= anim.length:
		var globals := {}
		for b in skel.get_bone_count():
			var rest := skel.get_bone_rest(b)
			var basis := rest.basis
			if rot.has(b):
				basis = Basis(anim.rotation_track_interpolate(rot[b], t))
			var origin := rest.origin
			if pos.has(b):
				origin = anim.position_track_interpolate(pos[b], t)
			var local := Transform3D(basis, origin)
			var parent := skel.get_bone_parent(b)
			globals[b] = local if parent < 0 else (globals[parent] as Transform3D) * local
		# Hips-local, so the body's own turn is not counted as hand travel: on a
		# 360 spin it would swamp everything else.
		var h: Transform3D = globals[hips]
		pts.append(h.affine_inverse() * (globals[hand] as Transform3D).origin)
		t += STEP

	var peak := 0.0
	var speeds: Array[float] = []
	for i in pts.size():
		var v := 0.0 if i == 0 else (pts[i] - pts[i - 1]).length() / STEP
		speeds.append(v)
		peak = maxf(peak, v)

	print("=== %s  len=%.2fs ===" % [name, anim.length])
	print("     t     fwd     up     spd    (bar = speed, %% of peak)")
	for i in pts.size():
		var frac := speeds[i] / maxf(peak, 0.0001)
		print("  %.2f  %+6.2f %+6.2f  %5.2f  %s" % [
			float(i) * STEP, -pts[i].z, pts[i].y, speeds[i],
			"#".repeat(int(frac * 40.0))])
