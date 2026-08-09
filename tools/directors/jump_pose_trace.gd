extends RefCounted
## The jump POSE and the jump ARC on the same timeline, in numbers, with no
## captures in the loop.
##
## _jump_trace.gd photographs the same question, but every capture there costs
## physics frames, so its samples are not evenly spaced and it cannot answer
## "how far behind the body is the pose". This one never captures: it prints the
## hips height the ANIMATION is holding beside the height the BODY is at, every
## physics frame, so a pose that is a fixed number of seconds late shows up as
## the two curves peaking apart.
##
## Read the hips column against tools/_clip_hips.gd's table for `ex_jump`:
## stand 0.523, crouch bottoms 0.313 @0.33, feet leave @0.50, apex 0.879 @0.77,
## lands @1.10. If the hips are still at the crouch while the body is already
## rising, `jump_start_offset` is not being applied.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/jump_pose_trace.gd --out=/tmp/jpt/x.png

const FRAMES := 130


func run(rig) -> void:
	var hero: Node3D = rig.get_nodes_in_group(&"player")[0]
	hero.set(&"facing_yaw", 0.0)
	await rig.wait_seconds(0.8)

	var skel: Skeleton3D = hero.call(&"skeleton")
	var hips := skel.find_bone("mixamorig_Hips")
	if hips < 0:
		print("POSE FAIL no mixamorig_Hips bone")
		return
	var tree: AnimationTree = hero.find_child("AnimTree", false, false)

	var y0: float = hero.global_position.y
	print("POSE rest hips y=%.3f" % skel.get_bone_pose_position(hips).y)

	Input.action_press(&"jump")
	await rig.physics_frame
	Input.action_release(&"jump")

	for i in FRAMES:
		var dy: float = hero.global_position.y - y0
		var hy: float = skel.get_bone_pose_position(hips).y
		print("POSE t=%.2f dy=%+.3f floor=%s jump=%s hips=%.3f %s" % [
			i / 60.0, dy, "1" if hero.is_on_floor() else "0",
			"1" if bool(tree.get("parameters/Jump/active")) else "0",
			hy, "#".repeat(int(clampf((hy - 0.25) / 0.70, 0.0, 1.0) * 40.0))])
		await rig.physics_frame
	print("POSE done")
