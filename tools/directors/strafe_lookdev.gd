extends RefCounted
## Photographs ss_strafe_01..04 so somebody can say which way each one steps.
##
## Locked-on locomotion wants a 4-way strafe blend, and the library ships four
## strafe clips under names that say nothing about direction.
##
## **ANSWERED, and this header was wrong about why it could not be.** It used to
## conclude: the clips carry no root translation, `build_anim_lib` bakes the
## library in place, every clip animates the legs and moves the character
## nowhere, so "there is no number in the rig to measure". The first half is
## true and the conclusion does not follow -- the number was never *in the rig*,
## it was UPSTREAM of the bake. `build_anim_lib._strip_root_translation` zeroes
## hips XZ when it bakes, and the raw FBX still carries the travel.
## `tools/_clip_dir.gd` reads it straight off the source file:
##
##     ss_strafe_01  -X 0.78 -> steps to his RIGHT, slower
##     ss_strafe_02  +X 0.76 -> steps to his LEFT,  slower
##     ss_strafe_03  +X 1.29 -> steps to his LEFT,  faster
##     ss_strafe_04  -X 1.33 -> steps to his RIGHT, faster
##
## (-X is the character's right: the rig is authored facing +Z, and its
## `mixamorig_LeftHand` sits at x=+0.37. `Hero.clip_guard_fwd_walk` carries the
## full derivation and the forward/back clips alongside these.)
##
## The cost of the wrong conclusion was real: the four-way strafe blend this
## tool was written to enable did not get built, and guarded locomotion shipped
## a one-axis SPEED blend whose run end was the BACKPEDAL -- so the hero
## moon-walked in every direction but backwards. `guard_locomotion.gd` is the
## director that now holds that ground.
##
## The tool is still useful and still a camera: a measured direction says which
## way the hips travel, not whether the clip READS as that step at the game
## camera. A burst per clip, and eyes on the contact sheet -- CLAUDE.md §2 is
## right that a single frame cannot show direction of motion, and BURST is the
## point. Take the numbers above as the label and this as the check on it.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/strafe_lookdev.gd --out=/tmp/strafe/x.png

const CLIPS: Array[StringName] = [
	&"ss_strafe_01", &"ss_strafe_02", &"ss_strafe_03", &"ss_strafe_04",
]

## Frames spread across each clip. Four is enough to read a step's direction and
## few enough to eyeball as one row.
const FRAMES := 4


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/strafe/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var hero: Node3D = rig.get_nodes_in_group(&"player")[0]
	hero.global_position = Vector3(0.0, 0.05, 0.0)
	await rig.wait_frames(10)

	# The AnimationTree drives the rig every frame; it has to let go before the
	# AnimationPlayer can be scrubbed by hand, or the clip is overwritten with
	# the locomotion blend on the very next tick.
	var tree: AnimationTree = hero.find_child("AnimTree", false, false)
	if tree != null:
		tree.active = false

	var skel: Skeleton3D = hero.skeleton()
	var player: AnimationPlayer = skel.get_parent().find_child("AnimationPlayer", true, false)
	if player == null:
		print("STRAFE FAIL no AnimationPlayer")
		return

	# Straight down -Z, so "the hero's right" is screen right in every capture.
	Bus.camera_recenter.emit()
	await rig.wait_frames(24)

	for clip in CLIPS:
		if not player.has_animation(clip):
			print("STRAFE %-16s MISSING" % clip)
			continue
		var length := player.get_animation(clip).length
		print("STRAFE %-16s len=%.2f -> %d frames" % [clip, length, FRAMES])
		for i in FRAMES:
			player.play(clip)
			player.seek(length * (float(i) + 0.5) / float(FRAMES), true)
			await rig.wait_frames(2)
			await rig.capture(out.path_join("%s_%d.png" % [clip, i]))

	if tree != null:
		tree.active = true
	print("STRAFE done")
