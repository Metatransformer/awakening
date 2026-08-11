extends RefCounted
## The five authored bodies, fitted, retargeted, and holding every idle they
## might be given.
##
## `NpcBody._install_clips` maps a 24-bone T-posed clip library onto a 41-bone
## A-posed Tripo rig. The derivation there is exact, which is a claim about
## algebra and not about a person -- a sign error in it produces a body that is
## still perfectly animated and has its arms on backwards, and no log line
## anywhere says so. So: every body, every idle, front and three-quarter, next
## to a `RaceBody` that is known to work and a post at the hero's height.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/_lookdev.tscn \
##     --director=res://tools/directors/npc_lookdev.gd --out=/tmp/npc/x.png

## Left to right, and in the order the garrison meets them.
const WHO: Array[String] = ["smith", "quartermaster", "lanternkeeper", "jewelcrafter", "alchemist"]
## The idle each is actually given in `Npc.LOOKS`, so this sheet photographs the
## garrison and not a line of bodies in a pose nobody holds.
const IDLE: Array[StringName] = [&"idle3", &"idle", &"idle9", &"idle4", &"idle3"]
const STEP := 1.35
## The line-up sits a metre and a half forward of the origin, because
## `_lookdev.tscn` parks a one-metre green box there and the first sheet off this
## director had the smith standing waist-deep in it.
const FORWARD := 1.6


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/npc/x.png").get_base_dir()
	var scene: Node = rig.current_scene

	var cam := Camera3D.new()
	cam.fov = 42.0
	scene.add_child(cam)
	cam.make_current()

	# The hero, as a stick, at the far left. Every height judgement below is a
	# comparison against this and not against a memory of one.
	var post := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.05, K.HERO_H, 0.05)
	post.mesh = pm
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.9, 0.2, 0.2)
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	post.material_override = red
	post.position = Vector3(-STEP, K.HERO_H * 0.5, FORWARD)
	scene.add_child(post)

	# The control -- a `RaceBody`, which is the kind the elder is still built as
	# and the kind the whole monster roster runs on. It is here as the thing a
	# broken retarget is told apart from: if every body in the frame looks stiff,
	# the frame is the problem and not the map. (It was the alchemist until she
	# got a model of her own; it stays because the comparison is the point.)
	var control := RaceBody.make("vyr")
	if control != null:
		scene.add_child(control)
		control.wear("cloth", Color(0.56, 0.88, 0.68))
		control.global_position = Vector3(STEP * float(WHO.size()), 0.0, FORWARD)

	var made: Array[NpcBody] = []
	for i in WHO.size():
		var b := NpcBody.make(WHO[i])
		if b == null:
			print("NPCLOOK FAIL could not build '%s'" % WHO[i])
			continue
		scene.add_child(b)
		b.global_position = Vector3(STEP * float(i), 0.0, FORWARD)
		made.append(b)
	await rig.wait_frames(20)

	# A body whose tracks failed to bind is a bind-pose statue, and a bind-pose
	# statue photographs exactly like a working idle on a still frame. Say the
	# numbers out loud as well as taking the picture.
	for i in made.size():
		var b := made[i]
		var box := _world_box(b)
		var skel := b.find_child("Skeleton3D", true, false) as Skeleton3D
		var ap := b.find_child("AnimationPlayer", true, false) as AnimationPlayer
		print("NPCLOOK %-14s want=%.2f m drawn=%.2f m box=%v bones=%d clips=%s" % [
			WHO[i], b.height, box.size.y, box.size,
			skel.get_bone_count() if skel != null else -1,
			str(ap.get_animation_list()) if ap != null else "<none>"])

	# Wide first: a close shot of an empty patch of sky cannot tell you whether
	# the subject is mis-framed or missing.
	#
	# The centre and the distance are DERIVED from how many bodies are in the row
	# (plus the control on the end), not written down. The fifth body went into
	# WHO against a camera still centred on four and the alchemist stood half out
	# of the frame -- in the sheet whose entire job is showing her.
	var wide := STEP * float(made.size())
	var mid := Vector3(wide * 0.5, 0.9, FORWARD)
	await _shot(rig, cam, out, "npc_0_wide", mid + Vector3(0.0, 3.1, 6.0 + wide), mid)

	for i in made.size():
		made[i].play(IDLE[i])
	if control != null:
		control.play(&"idle4")
	await rig.wait_frames(34)

	await _shot(rig, cam, out, "npc_1_lineup", mid + Vector3(0.0, 0.7, 2.6 + wide), mid)
	await _shot(rig, cam, out, "npc_2_threequarter", mid + Vector3(1.6 + wide * 0.5, 1.2, 1.6 + wide * 0.5), mid)
	await _shot(rig, cam, out, "npc_3_behind", mid + Vector3(0.0, 0.7, -2.6 - wide), mid)

	# Every idle on every body: the map has to survive all four, not the one each
	# role happens to be given today.
	for clip in NpcBody.CLIPS:
		for b in made:
			b.play(clip)
		await rig.wait_frames(34)
		await _shot(rig, cam, out, "npc_pose_%s" % clip, mid + Vector3(0.0, 0.7, 2.6 + wide), mid)

	# And one close read each, from the distance a shopkeeper is judged at:
	# standing at their own counter.
	for i in made.size():
		var b := made[i]
		b.play(IDLE[i])
		await rig.wait_frames(20)
		await _shot(rig, cam, out, "npc_10_%s" % WHO[i],
			b.global_position + Vector3(0.45, 1.45, 2.0),
			b.global_position + Vector3(0.0, b.height * 0.62, 0.0))
	print("NPCLOOK done")


func _shot(rig, cam: Camera3D, out: String, name: String, at: Vector3, look: Vector3) -> void:
	cam.global_position = at
	cam.look_at(look, Vector3.UP)
	await rig.wait_frames(6)
	await rig.capture(out.path_join(name + ".png"))


## The body's bounds in the WORLD -- where the art IS, as opposed to where its
## node says it is. A body whose mesh sits metres from its own origin
## photographs as an empty frame from a camera aimed at that origin.
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


func _all(n: Node) -> Array:
	var found := [n]
	for c in n.get_children():
		found.append_array(_all(c))
	return found
