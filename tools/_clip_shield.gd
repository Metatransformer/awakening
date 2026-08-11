extends SceneTree
## How far does a clip THROW THE SHIELD, and does the body go with it?
##
## `_clip_windup.gd` asks the same shape of question about the sword hand, and
## everything here is its machinery pointed at the other arm. The parry is not a
## swing: nothing about it is legible in the right hand, and the number that
## decides whether it reads across a room is how far the LEFT FOREARM — which is
## where the shield is mounted (`HeroCombat._mount_left`) — is thrown forward.
##
##   arm   the forearm's forward EXCURSION along the hero's facing, hips-local:
##         max minus min, so a clip that opens with the shield already out scores
##         what it adds and not where it began. Metres.
##   peak  the fastest the forearm ever travels, m/s of clip time. THIS is the
##         column that ranks a shove, because `arm` favours long clips: excursion
##         is max-minus-min and a 3.7 s idle has more of the cycle to wander over
##         than a 0.5 s move has. `ss_idle_01` — a man standing there breathing —
##         scores 0.129 of excursion against `ex_parry`'s 0.076, which is a true
##         number and a misleading one until you put the speeds beside it.
##   rise  the hips' vertical excursion. A brace sinks, a shove rises; either way
##         a shield thrown by an arm over a body that does nothing at all reads
##         as a man reaching for a door handle.
##
## THERE IS NO BODY-TRAVEL COLUMN, and the first cut of this file had one that
## printed 0.000 for all seventeen candidates including `ex_dive_forward`.
## `build_anim_lib._strip_root_translation` zeroes hips XZ so clips play in place
## — the CharacterBody3D owns position — so forward travel is deleted from
## `hero_anims.res` before anything downstream can see it, and a column reading
## zero for a forward dive is an instrument, not a finding (CLAUDE.md §2).
## `_clip_travel.gd` reads the raw FBX for exactly this reason. It is moot here
## anyway: `Hero.request_parry` zeroes the velocity on purpose, so the parry is
## authored rooted and no clip's own travel would survive into the game.
##
## Hips-local for the arm, as `_clip_windup` is for the hand: a clip that turns
## the body must not read as the arm travelling.
##
##   godot --path . --headless -s tools/_clip_shield.gd -- ex_parry ss_kick_01
##
## `--quiet` prints only the summary lines, which is the mode to use when
## ranking a dozen candidates at once.

const MODEL := "res://assets/characters/hero.fbx"
const LIB := "res://assets/animations/hero_anims.res"
const STEP := 1.0 / 30.0
## Mixamo's naming. The shield rides the left FOREARM and not the hand — see the
## mount comment in hero_combat.gd, which explains at length why.
const ARM := "mixamorig_LeftForeArm"
const HIPS := "mixamorig_Hips"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var quiet := args.has("--quiet")
	# `OS.get_cmdline_user_args` hands back a PackedStringArray, which has no
	# `filter`. Walked by hand rather than converted, so the element type stays
	# String and the `begins_with` below needs no annotation.
	var clips: Array[String] = []
	for a in args:
		if not a.begins_with("--"):
			clips.append(a)
	if clips.is_empty():
		print("usage: _clip_shield.gd -- [--quiet] <clip_name> [<clip_name> ...]")
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

	var arm := skel.find_bone(ARM)
	var hips := skel.find_bone(HIPS)
	if arm < 0 or hips < 0:
		print("rig has no %s / %s" % [ARM, HIPS])
		quit(1)
		return

	print("%-30s %5s  %6s %6s %6s" % ["clip", "len", "arm", "peak", "rise"])
	for name in clips:
		if not lib.has_animation(StringName(name)):
			print("MISSING ", name)
			continue
		_report(skel, arm, hips, lib.get_animation(StringName(name)), name, quiet)
	quit(0)


## Posed by hand rather than through an AnimationPlayer, for the reason
## `_clip_windup._report` gives: a `-s` script has no frame loop, so a mixer that
## is never processed hands back the REST POSE at every seek — a clip that reads
## as motionless, which is the single most convincing wrong answer this tool
## could give about a move somebody already suspects of not moving.
func _report(skel: Skeleton3D, arm: int, hips: int, anim: Animation, name: String,
		quiet: bool) -> void:
	var rot := {}
	var pos := {}
	for i in anim.get_track_count():
		var bone := skel.find_bone(anim.track_get_path(i).get_concatenated_subnames())
		if bone < 0:
			continue
		match anim.track_get_type(i):
			Animation.TYPE_ROTATION_3D: rot[bone] = i
			Animation.TYPE_POSITION_3D: pos[bone] = i

	var arm_fwd: Array[float] = []
	var body_up: Array[float] = []
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
		var h: Transform3D = globals[hips]
		arm_fwd.append(-(h.affine_inverse() * (globals[arm] as Transform3D).origin).z)
		# Y only. See the header for why there is no Z here.
		body_up.append(h.origin.y)
		t += STEP

	var arm_span: float = arm_fwd.max() - arm_fwd.min()
	var rise: float = body_up.max() - body_up.min()
	var speeds: Array[float] = []
	var peak := 0.0
	for i in arm_fwd.size():
		var v := 0.0 if i == 0 else absf(arm_fwd[i] - arm_fwd[i - 1]) / STEP
		speeds.append(v)
		peak = maxf(peak, v)
	print("%-30s %5.2f  %6.3f %6.3f %6.3f" % [name, anim.length, arm_span, peak, rise])
	if quiet:
		return
	print("     t     arm    spd   rise")
	for i in arm_fwd.size():
		print("  %.2f  %+6.3f %5.2f %+6.3f" % [
			float(i) * STEP, arm_fwd[i] - arm_fwd[0], speeds[i], body_up[i] - body_up[0]])
