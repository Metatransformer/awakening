extends RefCounted
## Photographs ss_strafe_01..04 so somebody can say which way each one steps.
##
## Locked-on locomotion wants a 4-way strafe blend, and the library ships four
## strafe clips under names that say nothing about direction.
##
## **Finding, and the reason this tool is a camera and not a ruler:** the clips
## carry NO root translation. An earlier version of this sampled the hips' pose
## across each clip expecting to read the travel off it, and got a flat zero for
## all six clips including mg_walk_forward -- `tools/build_anim_lib.gd` bakes the
## library in place, so every clip animates the legs and moves the character
## nowhere. There is no number in the rig to measure. That also means the strafe
## blend, when it is built, is driven entirely by code velocity; the clip only
## has to *look* like the direction the hero is already sliding.
##
## So: a burst per clip, and eyes on the contact sheet. CLAUDE.md §2 is right
## that a single frame cannot show direction of motion -- BURST is the point.
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
