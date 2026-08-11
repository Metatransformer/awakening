extends SceneTree
## Merges every per-file Mixamo FBX animation into one AnimationLibrary.
##
## Every animation FBX in assets/animations/** carries a single clip named
## "mixamo_com" on the same 33-bone mixamorig skeleton as the hero, so no
## retargeting is needed — we just rename each clip to its filename and stack
## them into one library that AnimationTree can address as "ss_slash_01".
##
##   godot --path . --headless -s tools/build_anim_lib.gd
##
## Writes assets/animations/hero_anims.res

const SETS := {
	"ss": "res://assets/animations/sword_shield",
	"ex": "res://assets/animations/extra",
	"mg": "res://assets/animations/magic",
	"bow": "res://assets/animations/longbow",
	"ax": "res://assets/animations/axe",
}
## Sets we want ONE clip out of, by stem. Everything else in that directory is
## skipped.
##
## `greatsword` and `axe` are other characters' movesets — a full idle/run/block
## set each, on the same mixamorig skeleton but posed around a weapon this hero
## does not carry. Baking them wholesale would double the library with clips
## nothing can ever play, and would put two more `idle`s in front of the next
## person who greps for one. The sword-and-shield set has no 360 in it, which is
## the one thing the spin attack needs, so it is borrowed a clip at a time.
## `melee_attack_360_low` is the spin attack, PICKED OFF THE RENDER
## (tools/directors/swing_lookdev.gd) against the other two 360s in the project:
## `ax_melee_attack_360_high` swings behind the body and reads as a shield-bash
## turn, and `gs_high_spin_attack_1` is posed around a two-handed hilt this hero
## is not holding. The low one crouches into the turn and carries the blade out
## at arm's length through the whole circle, which is the pose the hitbox is
## claiming to be.
## `melee_attack_downward` and `melee_run_jump_attack` are the two candidates for
## the AIR SLAM, and both are here so the choice can be made off a render rather
## than off a filename (see tools/directors/slam_lookdev.gd). The sword-and-shield
## set has no downward strike in it at all — its four `attack_*` and five
## `slash_*` are every one of them horizontal or diagonal, which is why this
## borrows from the axe set exactly as the spin does.
const ONLY := {
	"ax": ["melee_attack_360_low", "melee_attack_downward", "melee_run_jump_attack"],
}
const OUT := "res://assets/animations/hero_anims.res"
## Clips that should loop when played. Everything else is one-shot.
##
## Matched with `begins_with`, which is why "aim_walk" and "fall_loop" are listed
## separately: the longbow set's held-aim strafes are named `aim_walk_forward`,
## so neither "walk" nor "idle" catches them, and they are cycles like any other.
const LOOPING := [
	"idle", "walk", "run", "strafe", "block_idle", "crouch_idle", "crouching",
	"aim_walk", "fall_loop", "fast_run",
]
## Library-name -> the second the MOVE ends. Mixamo exports often carry a tail of
## the actor standing still after the action is over, and that tail is not free:
## the hero fires these through an AnimationNodeTimeScale sized as
## `clip_length / move_duration`, so every dead second both blurs the real motion
## (to make room for nothing) and leaves the one-shot running past the point the
## game has handed the hero back to locomotion — he lands, and then holds the
## export's settle pose while the controller thinks he is free.
##
## Cut it here rather than in the caller, so that `clip.length` keeps meaning
## "how long this move takes" for everyone who reads it.
##
## Read the number off the hips track; do not eyeball it. `ex_backflip` is 2.17 s
## of which 0.20–1.45 is crouch, launch, inversion and landing — apex at 1.10,
## grounded again by 1.45 — and the last 0.72 s is a man standing there.
##
## `ax_melee_attack_360_low` is 2.50 s and the SPIN is over by 1.35. Read off
## tools/_clip_motion.gd, which prints per-frame rotation across every bone: the
## turn peaks at 0.87 (the blade fully extended at the bottom of the sweep),
## falls to a fifth of that by 1.05, and what follows is a long settle back into
## the guard with a dead 0.33 s on the end. Left uncut, a 0.9 s spin runs the
## clip at 2.8x and the sweep — the one part anybody is looking at — goes past in
## a third of a second.
## The two jump clips are cut at the end of the LANDING RECOVERY, not at the end
## of the leap — a jump that ends the frame the feet touch leaves the hero
## snapping upright out of a crouch. Read off the hips Y track with
## tools/_clip_hips.gd — NOT _clip_motion.gd, which measures bone ROTATION and is
## blind to a jump, that being almost pure translation:
##
##   ex_jump          stand 0.523, crouch bottoms 0.313 @0.33, leaves the ground
##                    @0.50, apex 0.879 @0.77, lands @1.10, compression bottoms
##                    @1.30, standing again @1.67. After that: a man standing.
##   ex_jump_running  launches @0.47, apex 0.720 @0.77 (a FLATTER arc — 0.26 of
##                    rise against the standing jump's 0.57, which is what a
##                    running jump is), lands @1.10, back into run cadence @1.45.
##                    It has no dead tail to find because it ends running.
##
## Both are airborne for ~0.60 s, and K.JUMP_SPEED against K.GRAVITY is airborne
## for 0.59 s. That is not a coincidence to be proud of, it is why these clips
## play at scale 1.0 — see `jump_start_offset` in hero.gd for the other half,
## which is that the game has no room for the anticipation crouch at the front.
## `ax_melee_run_jump_attack` is the air slam and it is 3.67 s of which the game
## uses 1.50–2.75: the descent with the weapon overhead, the strike, the landing
## compression and the push back to standing. Everything before 1.50 is a run-up
## and a leap the hero has already done for real, and everything after 2.75 is a
## man standing there holding an axe. Cut here rather than in hero.gd so the
## clip's length keeps meaning "the move", which is what `_jump_anim` sizes the
## impact half of the slam off (see Hero.clip_slam for the frame table).
## `ex_parry` is 0.67 s of which the SHOVE is 0.00-0.43: bone rotation peaks at
## 0.20 and is down to a fifth of that by 0.50, while the hips climb 0.409 ->
## 0.480 and stop. Everything after is the actor standing in a guard. Cut at
## 0.50 so `K.PARRY_WINDOW` + `K.PARRY_RECOVER` (0.62 s) compresses onto the
## bash and not onto the bash plus a quarter-second of nothing.
## `ex_jump_attack` is the leaping overhead and it is 2.33 s of which the game
## uses all but the tail: it crouches to 0.467 by 0.37, leaves the ground,
## apexes at 1.001 around 0.87, comes down through the strike (the rotation
## peak, at 1.20), bottoms out in a deep kneeling landing at 0.202 by 1.50, and
## is back on its feet by 2.10. After that: a man standing there holding a
## sword. Unlike the other entries here this one is trimmed for the LANDING and
## not for the strike -- the kneel is what the clip is worth having.
const TRIM := {
	"ex_parry": 0.50,
	"ex_jump_attack": 2.10,
	"ex_backflip": 1.45,
	"ax_melee_attack_360_low": 1.35,
	"ex_jump": 1.67,
	"ex_jump_running": 1.45,
	"ax_melee_run_jump_attack": 2.75,
}


func _initialize() -> void:
	var lib := AnimationLibrary.new()
	var n := 0
	var failed: Array[String] = []

	for prefix in SETS:
		var dir_path: String = SETS[prefix]
		var dir := DirAccess.open(dir_path)
		if dir == null:
			push_warning("no such dir: %s" % dir_path)
			continue
		var files := dir.get_files()
		files.sort()
		for f in files:
			if not f.ends_with(".fbx"):
				continue
			var stem := f.get_basename()
			if ONLY.has(prefix) and not (ONLY[prefix] as Array).has(stem):
				continue
			var anim := _extract(dir_path.path_join(f))
			if anim == null:
				failed.append(f)
				continue
			# Mixamo clips carry root motion in the hips; we drive position in
			# code, so the hips translation track would fight the controller.
			_strip_root_translation(anim)
			anim.loop_mode = (
				Animation.LOOP_LINEAR if _is_looping(stem) else Animation.LOOP_NONE
			)
			# "/" is reserved as the library/animation separator, so sets are
			# namespaced with an underscore: "ss_slash_01".
			var key := "%s_%s" % [prefix, stem]
			if TRIM.has(key):
				var cut: float = TRIM[key]
				if cut < anim.length:
					print("TRIM %s %.2f -> %.2f" % [key, anim.length, cut])
					anim.length = cut
				else:
					push_warning("TRIM %s is %.2f, past the clip's %.2f" % [
						key, cut, anim.length])
			lib.add_animation(key, anim)
			n += 1

	var err := ResourceSaver.save(lib, OUT)
	print("ANIMS=%d SAVED=%s err=%d" % [n, OUT, err])
	if not failed.is_empty():
		print("FAILED: ", failed)
	quit(0 if err == OK else 1)


func _extract(path: String) -> Animation:
	if not ResourceLoader.exists(path):
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var root := ps.instantiate()
	var ap := _find_ap(root)
	var out: Animation = null
	if ap:
		for name in ap.get_animation_list():
			var a := ap.get_animation(name)
			if a and a.length > 0.05:
				out = a.duplicate(true)
				break
	root.queue_free()
	return out


## Remove the hips XZ translation so clips play in place; the CharacterBody3D
## owns horizontal position. Vertical hip motion is kept — it is what gives
## jumps and attack lunges their weight.
func _strip_root_translation(anim: Animation) -> void:
	for i in anim.get_track_count():
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		var p := str(anim.track_get_path(i))
		if not p.ends_with(":mixamorig_Hips"):
			continue
		for k in anim.track_get_key_count(i):
			var v: Vector3 = anim.track_get_key_value(i, k)
			anim.track_set_key_value(i, k, Vector3(0.0, v.y, 0.0))


func _is_looping(stem: String) -> bool:
	for tag in LOOPING:
		if stem.begins_with(tag):
			return true
	return false


func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_ap(c)
		if r:
			return r
	return null
