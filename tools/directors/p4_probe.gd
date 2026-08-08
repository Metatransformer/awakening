extends RefCounted
## P4 scratch probe: dumps the hero rig's node tree, skeleton bones and the
## rest-pose transforms of the four socket bones. Not a proof — a measurement
## aid, kept so the socket numbers in hero_weapons.gd can be re-derived.


func run(rig) -> void:
	await rig.wait_seconds(0.3)
	var hero: Node = rig.scene().get_node_or_null(^"Hero")
	if hero == null:
		print("PROBE: no hero")
		return
	_dump(hero, 0)
	var skel := hero.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		print("PROBE: no Skeleton3D")
		return
	print("PROBE skeleton path=", hero.get_path_to(skel), " bones=", skel.get_bone_count())
	for i in skel.get_bone_count():
		print("  %2d %-28s parent=%d" % [i, skel.get_bone_name(i), skel.get_bone_parent(i)])
	for bone_name in ["mixamorig_RightHand", "mixamorig_LeftForeArm", "mixamorig_LeftHand", "mixamorig_Spine2"]:
		var idx := skel.find_bone(bone_name)
		if idx < 0:
			print("PROBE missing bone ", bone_name)
			continue
		var gp := skel.get_bone_global_pose(idx)
		print("PROBE %s idx=%d global_pose_origin=%v basis_x=%v basis_y=%v basis_z=%v" % [
			bone_name, idx, gp.origin, gp.basis.x, gp.basis.y, gp.basis.z])
	print("PROBE skel global scale=%v xform=%s" % [skel.global_transform.basis.get_scale(), skel.global_transform])


func _dump(n: Node, depth: int) -> void:
	print("  ".repeat(depth), n.name, " [", n.get_class(), "]")
	if depth > 4:
		return
	for c in n.get_children():
		_dump(c, depth + 1)
