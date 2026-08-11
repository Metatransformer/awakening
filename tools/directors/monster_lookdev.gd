extends RefCounted
## Lines the whole roster up and photographs it, so "the monsters render" is a
## thing someone looked at rather than a thing the log implied.
##
## Spawned in the garrison, which is lit: a monster that fails to load its model
## is a black gap in a dungeon and an obvious hole in a courtyard.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/monster_lookdev.gd --out=/tmp/mon/x.png

const KINDS: Array[StringName] = [&"skeleton", &"goblin", &"kobold", &"orc", &"wraith"]

## Metres between bodies in the line-up, and the eye that has to hold all five.
##
## **THIS SHEET USED TO BE SHOT THROUGH THE GAMEPLAY CAMERA and it does not any
## more (#55).** The old version teleported the hero next to each monster and
## emitted `Bus.camera_recenter`, which fails three ways that only became visible
## once `shoot.gd` stopped rendering 6880x2756 and squeezing it into the PNG:
##
##   1. `GameCamera.recenter` aims down `behind_yaw()` -- the HERO's heading --
##      and this director never set one, so which way the shot pointed was
##      whatever the hero happened to be facing. `mon_00_lineup` came back
##      photographing the courtyard wall with the roster in the right margin.
##   2. The boom collides (`collide_radius`, `_clear_distance`). The wraith sits
##      at x = +6, close to the curtain wall, so the camera was shoved into the
##      hero's shoulder blades and `mon_05_wraith` was a full-frame photograph of
##      his back with the subject cropped off the top edge.
##   3. The hero stood between the lens and the monster in every close-up.
##
## The ~40% of extra world the old ultrawide window saw sideways had been hiding
## all three -- the subject was in the wings, and there are no wings now. An
## explicit `Camera3D` removes the boom, the collision and the facing dependence
## at once, which is what `garrison_look`, `weapon_lookdev` and `npc_lookdev`
## already do; the hero is parked out of shot and a 1.65 m post carries the scale
## he used to, exactly and without a pose.
const STEP := 2.0
const RANK_Z := 2.5
const LINEUP_EYE := Vector3(0.0, 1.6, 9.5)
const LINEUP_AIM := Vector3(-0.6, 1.0, RANK_Z)
const LINEUP_FOV := 55.0
## Where the hero waits: far enough that nothing in the line-up wakes up and
## walks out of its own portrait.
const HERO_PARK := Vector3(0.0, 0.05, 26.0)


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/mon/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var scene: Node = rig.current_scene
	var hero: Node3D = rig.get_nodes_in_group(&"player")[0]

	# Well clear of the hero: these chase on sight, and a lookdev shot of five
	# monsters piling onto the player is not a lookdev shot. He stays there for
	# the whole sheet now -- the camera below does the moving.
	hero.global_position = HERO_PARK

	# The keepers go dark for the length of the sheet, and their booths with them
	# (a booth is a child of the `Npc` that keeps it). They are people-shaped and
	# they stand in the middle of the yard, so at rank height they read as a sixth
	# monster and they occlude a real one -- the Lanternkeeper stood exactly where
	# the goblin does. Hidden rather than moved: a keeper walked somewhere else is
	# still a keeper somewhere else, and this sheet is the ROSTER. What the
	# garrison is here for is its LIGHT -- a model that failed to load is a black
	# hole in a lit courtyard -- and the sun and the sky are not on the booths.
	var hidden := 0
	for n in _all(scene):
		if n is Npc:
			(n as Node3D).visible = false
			hidden += 1
	print("MON hid %d keeper(s) for the sheet" % hidden)
	await rig.wait_frames(10)

	var made: Array[Enemy] = []
	for i in KINDS.size():
		var e := Enemy.new()
		e.kind = KINDS[i]
		e.drop_seed = 1000 + i
		scene.add_child(e)
		e.global_position = Vector3(-4.0 + STEP * float(i), 0.05, RANK_Z)
		made.append(e)
	await rig.wait_frames(45)

	for e in made:
		var meshes := _meshes(e)
		print("MON %-9s meshes=%d verts=%d" % [e.kind, meshes[0], meshes[1]])

	# The scale reference, at the left end of the rank. It is a stick of exactly
	# `K.HERO_H` rather than the hero himself: a body in an idle is 1.65 m only if
	# it is standing straight, and "is the orc taller than the player" is the one
	# question this sheet exists to answer that a vertex count cannot.
	var post := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.06, K.HERO_H, 0.06)
	post.mesh = pm
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.9, 0.2, 0.2)
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	post.material_override = red
	scene.add_child(post)
	post.global_position = Vector3(-5.6, K.HERO_H * 0.5, RANK_Z)

	var cam := Camera3D.new()
	scene.add_child(cam)
	cam.make_current()

	# The whole rank, aimed at the CONTENT's centre rather than at the world
	# origin, because the post hangs off the left end and a rank centred on the
	# origin is a rank with all of its margin on one side.
	#
	# The rank is 2.0 m apart and not the 3.0 m it was: at 3.0 the ends stood
	# among the alchemist's bench and the jeweller's stall and the post at the far
	# left photographed as a stick behind a table. 8 m of rank fits inside the
	# plaza's stone circle, which is the only part of this yard with nothing in it.
	#
	# `RANK_Z` stands it 2.5 m in front of the plaza's centre, and the keepers are
	# hidden below, for the same reason: the Lanternkeeper idles on that centre
	# and photographed straight THROUGH the goblin. The lawn south of the plaza
	# was tried instead and the camera it needs is outside the curtain wall.
	await _look(rig, cam, LINEUP_EYE, LINEUP_AIM, LINEUP_FOV)
	await rig.capture(out.path_join("mon_00_lineup.png"))

	# And one each, from in front of ITS OWN FACE.
	#
	# **THE CAMERA IS DERIVED FROM THE BODY'S FACING, NOT FROM AN ASSUMED ONE**,
	# and this is CLAUDE.md §4 in its cheapest form. The obvious version -- park
	# the hero at +Z, assume the roster turns to look at him, stand the lens on
	# his side -- was written first and photographed the goblin's back and the
	# skeleton's ribs edge-on: an idling `Enemy` holds whatever heading it likes.
	# The next obvious version, `rotation.y = PI` on the body, does not survive
	# `_physics_process`, which rewrites the yaw every frame. So: read
	# `-global_transform.basis.z`, which IS the direction the art looks (`enemy.gd`
	# absorbs the +Z art-space quirk on `_model`, per §4), and put the eye on that
	# ray. Nothing to keep in sync, and it cannot photograph a back.
	# The rest of the rank goes dark for each portrait, and the scale post with it.
	# Standing on a body's forward ray means standing wherever it happens to be
	# looking, and it looks along the rank: the wraith's own ray put a full-frame
	# orc between the lens and the wraith. One monster in the frame is also just
	# what a portrait is.
	post.visible = false
	for i in made.size():
		for j in made.size():
			made[j].visible = (j == i)
		var at: Vector3 = made[i].global_position
		var fwd: Vector3 = -made[i].global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.BACK
		await _look(rig, cam, at + fwd * 3.0 + Vector3(0.0, 1.35, 0.0),
			at + Vector3(0.0, 0.9, 0.0), 45.0)
		await rig.capture(out.path_join("mon_%02d_%s.png" % [i + 1, made[i].kind]))
	for e in made:
		e.visible = true
	post.visible = true


func _look(rig, cam: Camera3D, eye: Vector3, at: Vector3, fov: float) -> void:
	cam.fov = fov
	cam.global_position = eye
	cam.look_at(at, Vector3.UP)
	await rig.wait_frames(6)


## Returns [mesh_count, vertex_count] under a node -- a model that failed to
## load reports zeroes, which is the thing worth catching.
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
