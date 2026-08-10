extends RefCounted
## The three peoples, rendered, in every pose a shopkeeper might hold.
##
## This exists because the shared clip library is authored on one rig and played
## on three bodies of different proportions, and there is exactly one way to
## know whether a re-based clip looks like a person: look at it. The pack's own
## notes warn that some of its idle presets hold the hands splayed forward,
## which reads as a stiff "hands behind the back" stance -- true or not, that is
## a judgement about a picture, so the picture gets taken and the roles pick
## their pose from this sheet.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/_lookdev.tscn \
##     --director=res://tools/directors/race_lookdev.gd --out=/tmp/race/x.png

## Race, fabric and tint per shopkeeper, mirroring `Npc.COUNTERS` so this sheet
## photographs the people the garrison actually gets rather than three nude
## bases.
const RACES: Array[String] = ["stoneborn", "reshi", "vyr"]
const FABRIC: Array[String] = ["homespun", "wool", "silk"]
## Tints MULTIPLY the fabric's own texture, which is already a dark weave, so
## these are much lighter than the robe colours the box placeholders used --
## feeding those straight in (0.22, 0.26, 0.30 and friends) produced three
## silhouettes in black and cost a render to notice.
const TINT: Array[Color] = [
	Color(0.62, 0.70, 0.82),   # smith, cold slate
	Color(0.86, 0.52, 0.58),   # pawnbroker, wine
	Color(0.56, 0.88, 0.68),   # alchemist, green
]
## The four that survived. `cast`, `cast_buff`, `block`, `collect` and `wave`
## were on this list for one round and are the reason `RaceBody.CLIPS` is now
## idles only: dropping the position tracks takes the Hips with them, and this
## sheet is where you could SEE `cast_buff` hovering a hand's width off the
## floor. Do not add a clip back here without adding it to `CLIPS` too -- `play`
## ignores names it does not have, so an unknown pose photographs as whatever
## was playing before it and looks like a duplicate frame, not a failure.
const POSES: Array[StringName] = [&"idle", &"idle3", &"idle4", &"idle9"]


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/race/x.png").get_base_dir()
	var scene: Node = rig.current_scene

	var cam := Camera3D.new()
	cam.fov = 42.0
	scene.add_child(cam)
	cam.make_current()

	var made: Array[RaceBody] = []
	for i in RACES.size():
		var b := RaceBody.make(RACES[i])
		if b == null:
			print("RACE FAIL could not build '%s'" % RACES[i])
			continue
		scene.add_child(b)
		b.wear(FABRIC[i], TINT[i])
		b.global_position = Vector3(-1.6 + 1.6 * float(i), 0.0, 0.0)
		made.append(b)
	await rig.wait_frames(20)

	# A body that failed to bind its skeleton is a bind-pose statue, and a
	# bind-pose statue photographs exactly like a working idle on a still frame.
	# Count the meshes and say the fitted height out loud instead.
	for i in made.size():
		var b := made[i]
		var box := _world_box(b)
		print("RACE %-10s meshes=%d verts=%d height=%.2f m at=%s size=%s node=%s" % [
			RACES[i], _meshes(b)[0], _meshes(b)[1], _crown(b),
			box.get_center(), box.size, b.global_position])
		for c in _all(b):
			var n3 := c as Node3D
			if n3 == null:
				continue
			print("     %-14s %-30s local_scale=%s global_scale=%s" % [
				c.get_class(), c.name, n3.transform.basis.get_scale(),
				n3.global_transform.basis.get_scale()])
			var sk := c as Skeleton3D
			if sk != null:
				var hi := sk.find_bone("head_end")
				print("        bones=%d motion_scale=%.4f head_end rest y=%.3f global_pose y=%.3f" % [
					sk.get_bone_count(), sk.motion_scale,
					sk.get_bone_global_rest(hi).origin.y if hi >= 0 else -1.0,
					sk.get_bone_global_pose(hi).origin.y if hi >= 0 else -1.0])
			var mi := c as MeshInstance3D
			if mi != null and mi.mesh != null:
				print("        aabb_skinned=%s aabb_mesh=%s" % [mi.get_aabb(), mi.mesh.get_aabb()])

	# Wide first. A close shot of an empty patch of sky cannot tell you whether
	# the subject is mis-framed or missing, and this director has already spent a
	# round on that question.
	cam.global_position = Vector3(0.0, 4.0, 12.0)
	cam.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
	await rig.wait_frames(6)
	print("RACE cam current=%s viewport_cam=%s" % [
		cam.current, str(rig.root.get_viewport().get_camera_3d())])
	await rig.capture(out.path_join("race_0a_wide.png"))

	# The line-up, from the height a player stands at.
	cam.global_position = Vector3(0.0, 1.5, 4.4)
	cam.look_at(Vector3(0.0, 0.95, 0.0), Vector3.UP)
	await rig.wait_frames(6)
	await rig.capture(out.path_join("race_00_lineup.png"))

	# Every pose on every body. The clip is held a moment before the shutter so
	# the frame is somewhere in the motion, not on the blend into it.
	for p in POSES:
		for b in made:
			b.play(p)
		await rig.wait_frames(34)
		await rig.capture(out.path_join("race_pose_%s.png" % p))

	# And one close read per body at the pose each will actually hold, from the
	# distance a shopkeeper is judged from: standing in front of the counter.
	for i in made.size():
		var b := made[i]
		cam.global_position = b.global_position + Vector3(0.35, 1.45, 2.1)
		cam.look_at(b.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)
		await rig.wait_frames(4)
		await rig.capture(out.path_join("race_10_%s.png" % RACES[i]))
	print("RACELOOK done")


## Crown height of the body as it stands in the world -- the fitted number, not
## the one in the table, so a broken fit shows up as a number and not just as a
## small person in a photograph.
## Crown height of the body in the WORLD, read off the skeleton.
##
## Deliberately not a mesh-AABB measurement, and this is the whole reason the
## number is worth printing. These bodies keep their vertices in metres and
## their bones in centimetres, with a 0.01 on the Armature that cancels against
## the skin's bind matrices (see `RaceBody._native_height`). Measure the crown
## from the mesh bounds and you reproduce, exactly, the same cancellation the
## fitting code can get wrong -- which is how an earlier pass of this director
## printed a confident "1.41 m" for a body that rendered a hundred metres tall
## and sat entirely outside the frame.
##
## The bone pose goes through `skel.global_transform`, so it is the position the
## renderer actually draws that joint at. A check has to be able to disagree
## with the thing it is checking.
func _crown(n: Node3D) -> float:
	var top := 0.0
	for c in _all(n):
		var sk := c as Skeleton3D
		if sk == null:
			continue
		for i in sk.get_bone_count():
			var world: Vector3 = sk.global_transform * sk.get_bone_global_pose(i).origin
			top = maxf(top, world.y)
	return top


## The body's actual bounds in the world -- where the art IS, as opposed to
## where its node says it is. A body whose mesh sits metres from its own origin
## photographs as an empty frame from a camera aimed at that origin, which is
## exactly what the first fitted render produced.
func _world_box(n: Node3D) -> AABB:
	var acc := AABB()
	var first := true
	for c in _all(n):
		var mi := c as MeshInstance3D
		if mi != null and mi.mesh != null:
			var b: AABB = mi.global_transform * mi.get_aabb()
			if first:
				acc = b
				first = false
			else:
				acc = acc.merge(b)
	return acc


func _meshes(n: Node) -> Array:
	var count := 0
	var verts := 0
	for c in _all(n):
		var mi := c as MeshInstance3D
		if mi != null and mi.mesh != null:
			count += 1
			for s in mi.mesh.get_surface_count():
				verts += mi.mesh.surface_get_array_len(s)
	return [count, verts]


func _all(n: Node) -> Array:
	var found := [n]
	for c in n.get_children():
		found.append_array(_all(c))
	return found
