extends RefCounted
## Where does the SHEATHED sword hang when something else is in his hand?
##
## `hero_combat.gd` has cited this file by name since the scabbard was written,
## and until now the file did not exist -- the mount was a guess wearing a
## "MEASURED BY RENDERING" comment. CONTRACT §4 forbids exactly that, and the
## comment being the confident part is what makes it worth fixing: the next
## author would have trusted it.
##
## The scabbard only exists when the sword is NOT in the right hand, which is a
## state the game entered rarely until the weapon ring arrived. Now D-pad → is
## one press away from it at all times, so it is on screen constantly and its
## numbers have to be real.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/sheathe_lookdev.gd --out=/tmp/sheathe/x.png
##
## Every capture also prints the sword's world AABB in HERO-LOCAL metres, because
## a screenshot of a 92 cm blade against a leg is exactly the picture the eye
## argues about. +x is his right, +z his back. A sword worn on the LEFT hip reads
## centre right≈-0.15, up≈-0.05, back≈+0.05, and `out` -- the distance from his
## midline to the blade's nearest point -- wants to be positive and small: 0 or
## negative means the blade is inside the leg, past ~0.25 means it is floating.

## The Hips bone's local axes live in the rotated FBX space `hero_combat.gd`'s
## opening note warns about. `x` is his LATERAL and `z` is his DEPTH only because
## these frames say so -- do not re-derive them from the bone matrix (CONTRACT
## §4: facing and mounts are measured, never derived).
##
## The hookshot rides his RIGHT hip at x=-0.16, so the sword takes his left,
## which is the side a right-handed draw reaches across to. `shipped` is first
## and is what ships; the rest are the comparison that earns it.
const CANDIDATES := [
	{"name": "shipped", "pos": Vector3(0.0, 0.06, -0.11), "rot": Vector3(12.0, 0.0, 180.0)},
	# What it replaced, kept so the improvement is not a claim. The blade came out
	# of his hip HORIZONTALLY, a metre of it, and it had shipped that way for as
	# long as there was a scabbard.
	{"name": "was", "pos": Vector3(0.17, 0.02, 0.06), "rot": Vector3(0.0, 0.0, -90.0)},
	# The roll. z=0 stands the blade POINT-UP out of his waist, which is how the
	# sword model's own +Y is oriented: 180 is what makes it hang.
	{"name": "roll_0", "pos": Vector3(0.0, 0.06, -0.11), "rot": Vector3(12.0, 0.0, 0.0)},
	# Lateral (bone z, his LEFT is negative). -0.04 buries it in the thigh, -0.20
	# hangs it in the air beside him.
	{"name": "lat_-04", "pos": Vector3(0.0, 0.06, -0.04), "rot": Vector3(12.0, 0.0, 180.0)},
	{"name": "lat_-20", "pos": Vector3(0.0, 0.06, -0.20), "rot": Vector3(12.0, 0.0, 180.0)},
	# Height (bone y). Low puts the tip through the floor; high carries the grip
	# at his ribs, which is a baldric and not a belt.
	{"name": "low_-02", "pos": Vector3(0.0, -0.02, -0.11), "rot": Vector3(12.0, 0.0, 180.0)},
	{"name": "high_16", "pos": Vector3(0.0, 0.16, -0.11), "rot": Vector3(12.0, 0.0, 180.0)},
	# The lean. 0 lays the blade flat against the tunic; 25 stands it off the leg
	# far enough to read as a separate object hanging in the air.
	{"name": "lean_0", "pos": Vector3(0.0, 0.06, -0.11), "rot": Vector3(0.0, 0.0, 180.0)},
	{"name": "lean_25", "pos": Vector3(0.0, 0.06, -0.11), "rot": Vector3(25.0, 0.0, 180.0)},
]
const STOW_BONE := &"mixamorig_Hips"

## The two poses the scabbard is actually seen in, in the order the player meets
## them: standing with the bow, and mid-draw. Both are stances the hips take
## differently, and a mount that only survives one of them is not mounted.
const STANCES := [
	{"clip": &"ss_idle_01", "label": "idle"},
	{"clip": &"bow_draw_arrow", "label": "bow draw"},
]

## Two cameras per stance. The flank is where a stand-off from the leg is a gap
## you can see; the rear is the angle the game actually spends its time at, and
## a mount that only looks right from the flank is a mount for a screenshot.
const VIEWS := [
	{"name": "flank", "eye": Vector3(1.0, 0.0, 0.0)},
	{"name": "rear", "eye": Vector3(0.25, 0.0, 1.0)},
]
const FACE_OFFSET := 2.5


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/sheathe/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	await rig.wait_frames(20)

	var hero = rig.get_nodes_in_group(&"player")[0]
	var combat = hero.combat
	var player: AnimationPlayer = hero._anim_player
	var tree: AnimationTree = hero._tree
	var cam: Camera3D = hero.get_viewport().get_camera_3d()
	if cam == null or combat == null or player == null:
		print("SHEATHE FAIL no camera / no rig")
		return

	# Put something else in his hand, through the BUTTON, so the scabbard appears
	# for the reason the player would make it appear. Setting `Game.loadout`
	# directly here would photograph a state the D-pad might no longer reach.
	if not await rig.draw_weapon(&"bow"):
		print("SHEATHE FAIL the weapon ring never reached the bow")
		return
	await rig.wait_frames(10)
	if combat.sword_stow == null:
		print("SHEATHE FAIL no scabbard mount")
		return
	if not combat.sword_stow.visible:
		print("SHEATHE FAIL the scabbard is hidden with the bow in hand")
		return

	var to_cam: Vector3 = K.flat(cam.global_position - hero.global_position)
	hero.facing_yaw = atan2(to_cam.x, to_cam.z) + FACE_OFFSET
	# 90 frames, not 20: the body turns to meet `facing_yaw` at a capped rate, and
	# the first candidate photographed mid-turn is a candidate shot from a
	# different angle than the rest, which makes the whole sheet decoration.
	await rig.wait_frames(90)

	var lamp := OmniLight3D.new()
	lamp.light_energy = 3.0
	lamp.omni_range = 6.0
	lamp.shadow_enabled = false
	rig.scene().add_child(lamp)
	cam.set_physics_process(false)

	# Every candidate gets a real mount, built once, taking turns being visible.
	# Rebuilding a BoneAttachment3D between captures is the one thing
	# hero_combat's own comment warns against.
	var mounts: Array[Node3D] = []
	for c in CANDIDATES:
		var pos: Vector3 = c["pos"]
		var rot: Vector3 = c["rot"]
		var m: Node3D = combat._mount(combat.sword_id, STOW_BONE, pos, rot)
		if m == null:
			print("SHEATHE FAIL no bone %s" % STOW_BONE)
			return
		m.visible = false
		mounts.append(m)

	# The shipped scabbard is hidden for the whole run so it cannot be mistaken
	# for a candidate in a frame where a candidate lands near it.
	combat.sword_stow.visible = false
	await rig.wait_frames(6)

	for i in CANDIDATES.size():
		for m in mounts:
			m.visible = false
		mounts[i].visible = true

		tree.active = false
		var sheet: Image = null
		var col := 0
		for j in STANCES.size():
			var clip: StringName = STANCES[j]["clip"]
			if not player.has_animation(clip):
				print("SHEATHE FAIL missing clip %s" % clip)
				continue
			player.play(clip)
			# 60 %, not the first frame: the aim clip opens from a neutral stand
			# and only reaches the pose that moves the hips partway in.
			player.seek(player.get_animation(clip).length * 0.6, true)
			player.pause()

			# The camera basis comes off the BONE, not off `facing_yaw`. These
			# clips rotate the hips, so a camera placed from the heading points at
			# wherever he WOULD have been standing.
			var socket: Node3D = mounts[i].get_parent() as Node3D
			var back: Vector3 = K.flat(socket.global_transform.basis * Vector3.FORWARD)
			if back == Vector3.ZERO:
				back = Vector3.FORWARD
			back = back.normalized()
			var side: Vector3 = back.cross(Vector3.UP).normalized()
			var hip: Vector3 = socket.global_position

			for v in VIEWS:
				var e: Vector3 = v["eye"]
				var eye: Vector3 = (side * e.x + back * e.z).normalized()
				cam.global_position = hip + eye * 1.6 + Vector3.UP * 0.35
				cam.look_at(hip, Vector3.UP)
				cam.fov = 42.0
				lamp.global_position = hip + eye * 1.2 + Vector3.UP * 1.1
				await rig.wait_frames(2)
				print("SHEATHE %-10s %-8s %-6s %s" % [CANDIDATES[i]["name"],
					STANCES[j]["label"], v["name"], _describe(mounts[i], hero)])
				var frame: Image = await _grab(rig)
				if sheet == null:
					sheet = Image.create_empty(
						frame.get_width() * STANCES.size() * VIEWS.size(),
						frame.get_height(), false, frame.get_format())
				sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()),
					Vector2i(frame.get_width() * col, 0))
				col += 1
		player.stop()
		tree.active = true
		await rig.wait_frames(4)

		var path := out.path_join("sheathe_%d_%s.png" % [i, CANDIDATES[i]["name"]])
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		sheet.save_png(path)
		print("SHEATHE %-10s -> %s" % [CANDIDATES[i]["name"], path])

	var cols: Array[String] = []
	for st in STANCES:
		for v in VIEWS:
			cols.append("%s/%s" % [st["label"], v["name"]])
	print("SHEATHE done — columns are: %s" % ", ".join(cols))


## The sword's world bounds, said in the hero's own frame: right / up / BACK, in
## metres. `out` is how far the blade's nearest point clears his MIDLINE on the
## side it hangs -- negative is a blade inside the body, and no camera angle
## makes that acceptable.
func _describe(mount: Node3D, hero) -> String:
	var aabb := _world_aabb(mount)
	if aabb.size == Vector3.ZERO:
		return "no mesh"
	# -basis.z is forward (CONTRACT §2.5), so +z here means behind him.
	var body: Node3D = hero
	var inv := body.global_transform.affine_inverse()
	var c := inv * aabb.get_center()
	var side := signf(c.x)
	if side == 0.0:
		side = -1.0
	var out := INF
	for k in 8:
		var p := inv * aabb.get_endpoint(k)
		out = minf(out, p.x * side)
	return "centre right=%+.2f up=%+.2f back=%+.2f  out=%+.2f  span=%.2f" % [
		c.x, c.y, c.z, out, maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))]


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
