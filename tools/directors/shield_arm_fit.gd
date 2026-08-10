extends RefCounted
## Does the forearm actually sit IN the shield's straps?
##
## `shield_lookdev.gd` answers two other questions — which face meets the blow
## (yaw) and which way the kite point hangs (roll) — and it answers them from a
## metre and a half away, where a shield that is merely NEAR the arm looks
## mounted. This one asks the question those frames cannot show: where the arm
## is relative to the two strap loops on the inner face, in centimetres.
##
## Two failures it exists to catch, both reported off a play session:
##
##  1. Only ONE strap is over the arm. The straps run down the shield's length
##     and are spaced across its WIDTH — the forearm is meant to lie between
##     them, grazing both — so a seat that is a few cm off across the width puts
##     the arm under one band and out in the open past the other.
##  2. The arm punches THROUGH the boards. The seat shipped with zero offset
##     along the shield's face normal, which puts the forearm exactly in the
##     plane of the shield: the sleeve pokes out of the painted face.
##
## Both are measurements in the SHIELD's own frame, not the bone's, so that is
## the frame this prints in:
##     +x across the width, +y up the length, +z out through the painted face
##     (WeaponModels' grip convention).
## What we want to read: arm x ~= 0 (centred between the straps) and arm z
## comfortably NEGATIVE (behind the boards, on the strap side).
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/shield_arm_fit.gd --out=/tmp/saf/x.png
##     [--sweep=x|z]   one axis of the seat, in the shield's own frame

## Sweep steps, in metres, along whichever shield-local axis `--sweep` names.
const STEPS: Array[float] = [-0.06, -0.03, 0.0, 0.03, 0.06]

## Where the forearm's centreline wants to sit along the shield's face normal.
## The boards are dished: their concave inner surface runs from +0.028 at the
## boss out to -0.021 at the rim, and the two strap bands stand proud of it to
## -0.049. So the tunnel an arm goes through is roughly z -0.04 .. +0.02, and its
## middle is a couple of centimetres behind the origin. Zero — what shipped —
## is not "against the boards", it is INSIDE them.
const TUNNEL_Z := -0.030

## The two poses the shield is ever seen in. The seat has to work in both: the
## forearm bone points down the arm in the idle and across the chest in the
## block, and an offset tuned in one is not automatically right in the other.
const POSES := ["idle", "block"]


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/saf/x.png").get_base_dir()
	var scene: Node = rig.scene()
	await rig.wait_frames(24)

	var hero: Node3D = scene.get_node_or_null(^"Hero") as Node3D
	if hero == null:
		print("ARMFIT FAIL no Hero")
		return
	var combat = hero.get("combat")
	var holder: Node3D = combat.get("shield") as Node3D
	var skel: Skeleton3D = combat.get("_skel") as Skeleton3D
	if holder == null or skel == null:
		print("ARMFIT FAIL no shield / no skeleton")
		return

	_print_model_box(holder)

	var cam := Camera3D.new()
	cam.fov = 35.0
	scene.add_child(cam)
	cam.make_current()
	# Close work needs a light that is not the room's torches: the inner face is
	# turned away from every one of them and photographs as a brown smear. It
	# also needs to be WEAK and far off — a bright omni a hand's width from the
	# boards blows the straps to white, and a white band has no edge to read a
	# 2 cm gap against (shield_lookdev learned the same lesson at body scale).
	var key := OmniLight3D.new()
	key.light_energy = 1.6
	key.omni_range = 9.0
	scene.add_child(key)

	var axis: String = rig.arg("sweep", "")
	var seat: Vector3 = holder.position
	for pose: String in POSES:
		await _set_pose(rig, pose)
		for step: float in (STEPS if axis != "" else [0.0] as Array[float]):
			holder.position = seat + _shield_dir(holder, axis) * step
			await rig.wait_frames(2)
			_measure(skel, holder, pose, step)
			var tag := pose if axis == "" else "%s_%s%+03d" % [
				pose, axis, int(round(step * 100.0))]
			await _shoot(rig, cam, key, holder, out, tag)
	holder.position = seat
	await _set_pose(rig, "idle")
	key.queue_free()
	cam.queue_free()
	print("ARMFIT done")


## The shield's own axes in the BONE frame the seat is expressed in — and NOT
## normalised, on purpose.
##
## The bone frame is not in metres. `_mount` gives the holder scale 1/s to undo
## the rig's own s, so a seat of 0.10 in that frame is 0.10*s metres on the body
## — and s is about 1.62 here. `holder.transform.basis` carries exactly that 1/s,
## so multiplying a distance in MODEL metres by it lands the shield that far.
## Orthonormalising throws the factor away and overshoots every step by 62%,
## which is what the first pass of this director did.
func _shield_dir(holder: Node3D, axis: String) -> Vector3:
	var b := holder.transform.basis
	match axis:
		"x": return b.x
		"y": return b.y
		"z": return b.z
	return Vector3.ZERO


## Where the forearm runs, said in the shield's frame. Elbow and wrist both,
## because the arm is a segment and a single point cannot tell a seat that is
## off across the width from one that is merely rotated.
func _measure(skel: Skeleton3D, holder: Node3D, pose: String, step: float) -> void:
	var elbow := _bone_pos(skel, &"mixamorig_LeftForeArm")
	var wrist := _bone_pos(skel, &"mixamorig_LeftHand")
	var inv := holder.global_transform.affine_inverse()
	# affine_inverse carries the holder's inverse scale, which is exactly the
	# 1/rig-scale that makes the model's own metres readable here.
	var e := inv * elbow
	var w := inv * wrist
	print("ARM %-5s step%+.2f  elbow(x%+.3f y%+.3f z%+.3f)  wrist(x%+.3f y%+.3f z%+.3f)"
		% [pose, step, e.x, e.y, e.z, w.x, w.y, w.z])
	# The seat that would centre the forearm between the straps and drop it into
	# the tunnel, said in the BONE frame `HeroCombat._mount` takes. The y stays
	# whatever it is: where the arm crosses the shield ALONG its length is what
	# decides how low the point hangs, and that one is already right.
	var mid := (e + w) * 0.5
	var delta := Vector3(mid.x, 0.0, mid.z - TUNNEL_Z)
	var seat: Vector3 = holder.position + holder.transform.basis * delta
	print("SEAT-FIX %-5s local delta(%+.3f %+.3f %+.3f) -> bone Vector3(%.3f, %.3f, %.3f)"
		% [pose, delta.x, delta.y, delta.z, seat.x, seat.y, seat.z])


func _bone_pos(skel: Skeleton3D, bone: StringName) -> Vector3:
	var idx := skel.find_bone(bone)
	if idx < 0:
		return Vector3.ZERO
	return (skel.global_transform * skel.get_bone_global_pose(idx)).origin


## The model's box in its own metres, so the numbers above have something to be
## compared against: half the z extent is where the boards are, and half the x
## extent is how far the straps can be from the centre.
func _print_model_box(holder: Node3D) -> void:
	var model := holder.get_child(0) as Node3D
	if model == null:
		return
	var inv := holder.global_transform.affine_inverse()
	var acc := AABB()
	var first := true
	for mi: MeshInstance3D in _meshes(model):
		# Corner by corner, not `xform * aabb`. Transforming an AABB by a rotated
		# basis returns the box AROUND the rotated box, and doing it twice (mesh
		# space -> world -> holder) inflated a 4 cm plank into a 45 cm slab —
		# which is how a shield with no depth problem measures as if it had one.
		var box: AABB = mi.mesh.get_aabb()
		var xf := inv * mi.get_global_transform()
		var sub := AABB()
		for i in 8:
			var p: Vector3 = xf * box.get_endpoint(i)
			if i == 0:
				sub = AABB(p, Vector3.ZERO)
			else:
				sub = sub.expand(p)
		print("  MESH %-24s centre(%+.3f %+.3f %+.3f) size(%.3f %.3f %.3f)"
			% [mi.name, sub.get_center().x, sub.get_center().y, sub.get_center().z,
			sub.size.x, sub.size.y, sub.size.z])
		if first:
			acc = sub
			first = false
		else:
			acc = acc.merge(sub)
	print("BOX centre(%+.3f %+.3f %+.3f) size(%.3f %.3f %.3f)"
		% [acc.get_center().x, acc.get_center().y, acc.get_center().z,
		acc.size.x, acc.size.y, acc.size.z])
	_print_strap_profile(model, inv)


## The straps are not a separate mesh — they are welded into the shield — so the
## only way to say where they are in numbers is to look at the geometry that
## stands PROUD of the back face. This walks the vertices, buckets them across
## the width, and prints how far back each column reaches. Two columns reach much
## further than the boards do: those are the bands, and the gap between them is
## where the forearm is supposed to lie.
func _print_strap_profile(model: Node3D, inv: Transform3D) -> void:
	const BUCKET := 0.02
	var depth := {}
	for mi: MeshInstance3D in _meshes(model):
		var mesh := mi.mesh
		var xf := inv * mi.get_global_transform()
		for s in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for v: Vector3 in verts:
				var p: Vector3 = xf * v
				var k := int(floor(p.x / BUCKET))
				var cur: float = depth.get(k, 999.0)
				if p.z < cur:
					depth[k] = p.z
	var keys: Array = depth.keys()
	keys.sort()
	for k: int in keys:
		var z: float = depth[k]
		print("  PROFILE x%+.2f  back z%+.3f %s"
			% [k * BUCKET, z, "#".repeat(int(-z * 200.0))])


func _meshes(root: Node) -> Array:
	var found: Array = []
	for child in root.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			found.append(child)
		found.append_array(_meshes(child))
	return found


## Three close-ups, all framed off the shield itself rather than off the hero,
## because the thing being judged is a 3 cm relationship and a body-framed
## camera puts it eight pixels wide.
##
##   inner — down the strap side. Answers "is the arm between the two bands".
##   edge  — along the width. Answers "is the arm behind the boards or in them".
##   down  — up the length from the kite point. Both at once, in cross-section.
func _shoot(rig, cam: Camera3D, key: OmniLight3D, holder: Node3D,
		out: String, tag: String) -> void:
	var b := holder.global_transform.basis.orthonormalized()
	var at := holder.global_position
	for view in [["inner", -b.z], ["edge", b.x], ["down", -b.y]]:
		var dir: Vector3 = view[1]
		cam.global_position = at + dir * 1.5
		var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.9 else b.z
		cam.look_at(at, up)
		key.global_position = at + dir * 1.6 + b.y * 0.9
		await rig.wait_frames(3)
		await rig.capture(out.path_join("saf_%s_%s.png" % [tag, view[0]]))


## Hold or release the guard. `Input.action_press` sets action STATE and
## dispatches no event (CLAUDE.md §3) — fine here, because HeroCombat polls
## `shield` rather than listening for it.
func _set_pose(rig, pose: String) -> void:
	if pose == "block":
		Input.action_press(&"shield")
	else:
		Input.action_release(&"shield")
	await rig.wait_frames(40)
