extends SceneTree
## Which WAY does a locomotion clip step?
##
## `strafe_lookdev.gd` concluded there was no number to measure and reached for a
## camera instead. It was reading the BAKED library, where
## `build_anim_lib._strip_root_translation` has already zeroed hips XZ so clips
## play in place. The raw FBX still has it -- same hole `_clip_travel` documents,
## and this is the directional half of that number.
##
## Prints the net hip displacement as a signed model-space XZ vector plus its
## angle relative to whichever clip is passed FIRST, so a "run" as argument one
## defines forward and every other clip is reported as an offset from it.
##
##   godot --path . --headless -s tools/_clip_dir.gd -- \
##     res://assets/animations/sword_shield/run_01.fbx ...

var _ref := Vector2.ZERO


func _initialize() -> void:
	for path in OS.get_cmdline_user_args():
		await _report(path)
	quit(0)


func _report(path: String) -> void:
	var ps := load(path) as PackedScene
	if ps == null:
		print("NOT A SCENE %s" % path)
		return
	var node := ps.instantiate()
	root.add_child(node)
	await process_frame
	var ap := _find(node, "AnimationPlayer") as AnimationPlayer
	if ap == null:
		print("NO RIG %s" % path.get_file())
		node.queue_free()
		return
	var clip := ""
	for n in ap.get_animation_list():
		if ap.get_animation(n).length > 0.05:
			clip = n
			break
	var anim := ap.get_animation(clip)
	var d := _hips_delta(anim)
	if _ref == Vector2.ZERO and d.length() > 0.01:
		_ref = d.normalized()
	var ang := NAN
	if _ref != Vector2.ZERO and d.length() > 0.01:
		ang = rad_to_deg(_ref.angle_to(d.normalized()))
	print("%-18s len=%.2f  dxz=(%+.3f, %+.3f) |%.3f|  rel=%s" % [
		path.get_file(), anim.length, d.x, d.y, d.length(),
		("%+7.1f deg" % ang) if not is_nan(ang) else "   n/a "])
	node.queue_free()


func _hips_delta(anim: Animation) -> Vector2:
	for i in anim.get_track_count():
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		if not str(anim.track_get_path(i)).ends_with(":mixamorig_Hips"):
			continue
		var a: Vector3 = anim.position_track_interpolate(i, 0.0)
		var b: Vector3 = anim.position_track_interpolate(i, anim.length)
		return Vector2(b.x - a.x, b.z - a.z)
	return Vector2.ZERO


func _find(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r:
			return r
	return null
