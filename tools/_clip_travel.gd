extends SceneTree
## How fast is a locomotion clip AUTHORED to travel?
##
## The third member of the `_clip_*` family, and it exists because the other two
## cannot answer this. `_clip_motion` measures bone ROTATION and `_clip_hips`
## measures hip HEIGHT; a run's ground speed is horizontal STRIDE, and both are
## blind to it.
##
## It reads the RAW FBX rather than the baked library on purpose:
## `build_anim_lib._strip_root_translation` zeroes hips XZ so clips play in place
## (the CharacterBody3D owns position), which means one of the two numbers below
## has been deleted from `hero_anims.res` by the time anything else can see it.
## strafe_lookdev found the same hole the hard way and concluded there was no
## number in the rig to measure — there is, it is just upstream of the bake.
##
## TWO numbers, because the first one is missing from half the library:
##
##   HIPS  net horizontal displacement of the hips over the cycle, / length.
##         The clip's own authored ground speed, when it has one. Mixamo offers
##         every locomotion clip as "in place" or "with motion" and this project
##         was handed a mix of the two: `ss_run_01` and `ex_fast_run` travel,
##         `ex_running` is a flat 0.00 because it was exported in place. A zero
##         here is not a clip that stands still — it is a clip whose speed has
##         to be read off the legs.
##
##   STRIDE the widest horizontal gap between the two toe bones across the
##         cycle, read off the POSED skeleton. That is one step. A run cycle is
##         two steps, so the speed the legs are authored to read as is
##         2 * stride / length — which is the number that decides whether the
##         feet skate, and the only one available for an in-place clip.
##
## Both are in model space, which is only comparable between clips off the same
## rig — which every clip here is.
##
##   godot --path . --headless -s tools/_clip_travel.gd -- \
##     res://assets/animations/sword_shield/run_01.fbx \
##     res://assets/animations/extra/running.fbx

const STEP := 1.0 / 60.0
## Mixamo's toe bones. The TOE and not the foot: at full extension the trailing
## foot is up on its toe and the ankle has already started forward, so an ankle
## measurement quietly clips the back half of every stride.
const LEFT_TOE := "mixamorig_LeftToeBase"
const RIGHT_TOE := "mixamorig_RightToeBase"


func _initialize() -> void:
	for path in OS.get_cmdline_user_args():
		await _report(path)
	quit(0)


func _report(path: String) -> void:
	if not ResourceLoader.exists(path):
		print("MISSING %s" % path)
		return
	var ps := load(path) as PackedScene
	if ps == null:
		print("NOT A SCENE %s" % path)
		return
	var root_node := ps.instantiate()
	root.add_child(root_node)
	await process_frame

	var ap := _find(root_node, "AnimationPlayer") as AnimationPlayer
	var skel := _find(root_node, "Skeleton3D") as Skeleton3D
	if ap == null or skel == null:
		print("NO RIG %s (ap=%s skel=%s)" % [path.get_file(), ap != null, skel != null])
		root_node.queue_free()
		return

	var clip := ""
	for n in ap.get_animation_list():
		if ap.get_animation(n).length > 0.05:
			clip = n
			break
	if clip == "":
		print("NO CLIP %s" % path.get_file())
		root_node.queue_free()
		return
	var anim := ap.get_animation(clip)

	var hips := _hips_speed(anim)
	var li := skel.find_bone(LEFT_TOE)
	var ri := skel.find_bone(RIGHT_TOE)
	if li < 0 or ri < 0:
		print("NO TOES %s" % path.get_file())
		root_node.queue_free()
		return

	# Sample the posed skeleton rather than the tracks: a bone's own track is in
	# PARENT space, so a foot track says how the ankle sits in the shin and
	# nothing at all about where the foot is on the floor.
	var stride := 0.0
	var t := 0.0
	while t <= anim.length:
		ap.play(clip)
		ap.seek(t, true)
		await process_frame
		var lp := skel.get_bone_global_pose(li).origin
		var rp := skel.get_bone_global_pose(ri).origin
		stride = maxf(stride, Vector2(lp.x - rp.x, lp.z - rp.z).length())
		t += STEP
	# The skeleton poses in the FBX's own units; the hips track is in the same
	# space, so the two are directly comparable and the ratio between clips is
	# what this tool is for.
	var legs := 2.0 * stride / maxf(anim.length, 0.001)
	print("%-24s len=%.3fs  HIPS %.2f m/s  STRIDE %.3f m -> LEGS %.2f m/s" % [
		path.get_file(), anim.length, hips, stride, legs])
	root_node.queue_free()


## Net horizontal hip displacement over the cycle, per second. Net and not the
## sum of per-step distance: a run's hips also weave sideways and surge inside
## the stride, and summing would count that weave as forward travel.
func _hips_speed(anim: Animation) -> float:
	var idx := -1
	for i in anim.get_track_count():
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		if str(anim.track_get_path(i)).ends_with(":mixamorig_Hips"):
			idx = i
			break
	if idx < 0:
		return -1.0
	var a: Vector3 = anim.position_track_interpolate(idx, 0.0)
	var b: Vector3 = anim.position_track_interpolate(idx, anim.length)
	return Vector2(b.x - a.x, b.z - a.z).length() / maxf(anim.length, 0.001)


func _find(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r:
			return r
	return null
