extends RefCounted
## Where does the SLUNG bow sit when the hero is not holding it?
##
## ANSWER: on Spine2 at `(0, 0.06, -0.09) / (0, 0, 28)`, which is what ships.
## The BONE has not moved since the sweep below settled it, and that part is not
## worth re-opening. The STAND-OFF along it was retuned from -0.16 the day this
## director was finally pointed at the gap instead of at the room.
##
## It was written to chase a bug that did not exist. A tight, brightened CROP of
## an aim stance shows the bow apparently hanging in the air off the hero's left,
## and that read cost a bone sweep — Spine2, Spine1, Spine, Hips — before the
## measurement below said all four sit within 0.1 m of each other and all four
## are already ON HIS BACK. The crop was lying: a 1.05 m bow slung at 28° puts
## its tips half a metre from the spine, and a crop tight enough to see the gap
## is tight enough to have cut the torso out of frame. Look at the WHOLE frame.
##
## Which is why every capture also prints the model's world AABB centre in
## HERO-LOCAL metres: +x is his right, +z his back. A slung bow reads within
## ~0.3 m of the spine at chest height with a ~1 m span. That is a claim a
## screenshot cannot talk you out of.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/bow_stow_lookdev.gd --out=/tmp/stow/x.png

## All on Spine2 — a slung bow SHOULD wind with the chest, that is what a strap
## does. `shipped` is first, and is the one that ships; the rest are kept as the
## comparison that proves it, and as the place to add a new candidate.
##
## The bone's local -Z is straight out of his back, so the third component of
## `pos` IS the gap: less of it is a bow worn against the shoulder blades, more
## is a bow floating behind him. The `near_*` rungs exist because that gap was
## the one thing the original sweep never varied — it swept bones and rolls, and
## every one of them kept the same 16 cm stand-off.
const CANDIDATES := [
	{"name": "shipped", "pos": Vector3(0.0, 0.06, -0.09), "rot": Vector3(0.0, 0.0, 28.0)},
	{"name": "far_16", "pos": Vector3(0.0, 0.06, -0.16), "rot": Vector3(0.0, 0.0, 28.0)},
	{"name": "near_12", "pos": Vector3(0.0, 0.06, -0.12), "rot": Vector3(0.0, 0.0, 28.0)},
	{"name": "near_06", "pos": Vector3(0.0, 0.06, -0.06), "rot": Vector3(0.0, 0.0, 28.0)},
	{"name": "standup", "pos": Vector3(0.0, 0.06, -0.16), "rot": Vector3(-96.0, 0.0, 28.0)},
	{"name": "standup_roll90", "pos": Vector3(0.0, 0.06, -0.16), "rot": Vector3(-96.0, 0.0, 118.0)},
	{"name": "standup_yaw90", "pos": Vector3(0.0, 0.06, -0.16), "rot": Vector3(-96.0, 90.0, 28.0)},
]
const STOW_BONE := &"mixamorig_Spine2"

## The three shapes the torso actually takes, in the order the player meets them.
const STANCES := [
	{"clip": &"ss_idle_01", "label": "sword idle"},
	{"clip": &"ex_hookshot_fire", "label": "hookshot aim"},
]
const FACE_OFFSET := 2.5


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/stow/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	await rig.wait_frames(20)

	var hero = rig.get_nodes_in_group(&"player")[0]
	var combat = hero.combat
	var player: AnimationPlayer = hero._anim_player
	var tree: AnimationTree = hero._tree
	var cam: Camera3D = hero.get_viewport().get_camera_3d()
	if cam == null or combat == null or player == null:
		print("STOW FAIL no camera / no rig")
		return

	# Seen from behind and a little to the side — a slung bow is a back-of-the-
	# hero detail, and photographing it head on hides exactly the gap in question.
	var to_cam: Vector3 = K.flat(cam.global_position - hero.global_position)
	hero.facing_yaw = atan2(to_cam.x, to_cam.z) + FACE_OFFSET
	# 90, not 20. The body TURNS to meet `facing_yaw` at a capped rate, and 143
	# degrees of it takes longer than the old wait: the first candidate used to be
	# photographed mid-turn and the rest after it had settled, so candidate 0 was
	# shot from a different angle than candidates 1..n and the sweep compared
	# nothing. Every frame in this sheet has to be the same camera on the same
	# body or the whole exercise is decoration.
	await rig.wait_frames(90)

	# Then CLOSE, and lit. The first version of this director shot the room from
	# the gameplay camera and the whole argument — a few centimetres of air
	# between a bow and a shoulder blade — came out as a dozen dark pixels. A
	# torso-height lamp and a 1.7 m stand-off is what makes the gap something you
	# can actually see, without cropping the body out of frame (see the note at
	# the top: the crop is what lied last time).
	var lamp := OmniLight3D.new()
	lamp.light_energy = 3.0
	lamp.omni_range = 6.0
	lamp.shadow_enabled = false
	rig.scene().add_child(lamp)
	cam.set_physics_process(false)

	# Every candidate gets a real mount, built once, and they take turns being
	# visible. Rebuilding a BoneAttachment3D between captures is the one thing
	# hero_combat's own comment warns against.
	var mounts: Array[Node3D] = []
	for c in CANDIDATES:
		var pos: Vector3 = c["pos"]
		var rot: Vector3 = c["rot"]
		var m: Node3D = combat._mount(combat.bow_id, STOW_BONE, pos, rot)
		if m == null:
			print("STOW FAIL no bone %s" % STOW_BONE)
			return
		m.visible = false
		mounts.append(m)

	# The shipped stow is hidden for the whole run so it cannot be mistaken for a
	# candidate in a frame where a candidate happens to land near it.
	var shipped: Node3D = combat._items[&"bow"]["stow"]
	shipped.visible = false
	await rig.wait_frames(6)

	for i in CANDIDATES.size():
		for m in mounts:
			m.visible = false
		mounts[i].visible = true

		tree.active = false
		var sheet: Image = null
		for j in STANCES.size():
			var clip: StringName = STANCES[j]["clip"]
			if not player.has_animation(clip):
				print("STOW FAIL missing clip %s" % clip)
				continue
			player.play(clip)
			# Held at 60 % rather than at the start: the aim clips open from a
			# neutral stand and only reach the pose that breaks the mount partway
			# in, and a strip shot at t=0 would show two identical torsos.
			player.seek(player.get_animation(clip).length * 0.6, true)
			player.pause()
			# Framed from his flank, not his back. A stand-off is a distance along
			# the one axis a rear view has no depth in; from the side it is the
			# space between two silhouettes and cannot be argued with.
			#
			# And the flank is taken off the BONE, not off `facing_yaw`. These
			# clips rotate the hips — the aim clip turns him most of a quarter
			# turn out of his heading — so a camera placed from the heading is
			# pointing at wherever he WOULD have been standing. The socket's own
			# -Z is the axis `pos.z` slides along, so a camera perpendicular to it
			# always has the gap running left-to-right across the frame.
			var socket: Node3D = mounts[i].get_parent() as Node3D
			var away: Vector3 = K.flat(socket.global_transform.basis * Vector3.FORWARD)
			if away == Vector3.ZERO:
				away = Vector3.FORWARD
			away = away.normalized()
			var eye: Vector3 = away.cross(Vector3.UP).normalized()
			var chest: Vector3 = socket.global_position
			cam.global_position = chest + eye * 1.5 + Vector3.UP * 0.15
			cam.look_at(chest, Vector3.UP)
			cam.fov = 42.0
			lamp.global_position = chest + eye * 1.2 + Vector3.UP * 0.9
			await rig.wait_frames(2)
			print("STOW %-16s %-14s %s" % [CANDIDATES[i]["name"],
				STANCES[j]["label"], _describe(mounts[i], hero)])
			var frame: Image = await _grab(rig)
			if sheet == null:
				sheet = Image.create_empty(frame.get_width() * STANCES.size(),
					frame.get_height(), false, frame.get_format())
			sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()),
				Vector2i(frame.get_width() * j, 0))
		player.stop()
		tree.active = true
		await rig.wait_frames(4)

		var path := out.path_join("stow_%d_%s.png" % [i, CANDIDATES[i]["name"]])
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		sheet.save_png(path)
		print("STOW %-16s -> %s" % [CANDIDATES[i]["name"], path])

	print("STOW done — columns are: %s" % ", ".join(STANCES.map(
		func(s): return String(s["label"]))))


## The bow's world bounds, said in the hero's own frame: right / up / BACK, in
## metres. A bow that is actually slung reads roughly (0, +0.2, +0.15) with a
## long extent — anything a metre out on `right` is hanging in the air.
func _describe(mount: Node3D, hero) -> String:
	var aabb := _world_aabb(mount)
	if aabb.size == Vector3.ZERO:
		return "no mesh"
	# -basis.z is forward (CONTRACT §2.5), so +z here means behind him.
	var body: Node3D = hero
	var inv := body.global_transform.affine_inverse()
	var c := inv * aabb.get_center()
	var span := aabb.size
	# The centre says where the bow hangs; `near` says how far its closest point
	# is from the plane of his spine, which is the number the eye is reacting to
	# when it says "that is floating". His back surface is roughly 0.10 m behind
	# the spine, so a bow reading much past 0.15 is worn off the body.
	var near := INF
	for k in 8:
		var p := inv * aabb.get_endpoint(k)
		near = minf(near, -p.z)
	return "centre right=%+.2f up=%+.2f back=%+.2f  near=%+.2f  span=%.2f" % [
		c.x, c.y, -c.z, near, maxf(span.x, maxf(span.y, span.z))]


func _world_aabb(n: Node3D) -> AABB:
	var out := AABB()
	var seeded := false
	for child in _all(n):
		var mi := child as VisualInstance3D
		if mi == null:
			continue
		var box := mi.global_transform * mi.get_aabb()
		if not seeded:
			out = box
			seeded = true
		else:
			out = out.merge(box)
	return out


func _all(n: Node) -> Array[Node]:
	var acc: Array[Node] = [n]
	for c in n.get_children():
		acc.append_array(_all(c))
	return acc


func _grab(rig) -> Image:
	await RenderingServer.frame_post_draw
	var img: Image = rig.root.get_texture().get_image()
	img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	return img
