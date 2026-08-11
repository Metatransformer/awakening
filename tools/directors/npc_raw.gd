extends RefCounted
## The four authored NPC bodies exactly as they import, and nothing else.
##
## Before any of the interesting questions -- what they are scaled to, which way
## they face, what idle they hold -- there is one that has to be answered by
## looking: WHAT ARRIVED. A Tripo body can come in holding a staff, wearing a
## hat that adds fifteen centimetres to its bounding box, or modelled facing the
## camera rather than away from it, and every one of those changes a number that
## the integration would otherwise guess (docs/CONTRACT.md §2.5: facing is
## measured).
##
## So: four bodies, unscaled, unposed, unrotated, beside a 1.65 m post that is
## exactly the hero's height. Front, side and back.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/_lookdev.tscn \
##     --director=res://tools/directors/npc_raw.gd --out=/tmp/npc/x.png

const DIR := "res://assets/characters/npc/"
const WHO: Array[String] = ["jewelcrafter", "quartermaster", "lanternkeeper", "smith", "alchemist"]
## Metres between bodies on the line-up. They import at roughly a unit tall, so
## this is generous on purpose -- a body that turns out to be five times its
## neighbours should overlap them visibly rather than vanish behind one.
const STEP := 1.2


## Where the line-up's middle is. Set in `run` from how many bodies actually
## got built, and read by `_shot`.
var _mid := 0.0


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/npc/x.png").get_base_dir()
	var scene: Node = rig.current_scene

	var cam := Camera3D.new()
	cam.fov = 42.0
	scene.add_child(cam)
	cam.make_current()

	# The hero's height, as a stick. Every judgement below about how tall these
	# people are is a comparison against this and not against a memory.
	var post := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.06, K.HERO_H, 0.06)
	post.mesh = pm
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.9, 0.2, 0.2)
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	post.material_override = red
	post.position = Vector3(-STEP * 1.2, K.HERO_H * 0.5, 0.0)
	scene.add_child(post)

	var made: Array[Node3D] = []
	for i in WHO.size():
		var path := DIR + WHO[i] + ".fbx"
		if not ResourceLoader.exists(path):
			print("NPCRAW FAIL missing %s" % path)
			continue
		var n := (load(path) as PackedScene).instantiate() as Node3D
		scene.add_child(n)
		n.position = Vector3(STEP * float(i), 0.0, 0.0)
		made.append(n)

	await rig.wait_frames(20)

	for i in made.size():
		var b := made[i]
		var box := _world_box(b)
		print("NPCRAW %-14s box_center=%v box_size=%v floor_y=%.3f" % [
			WHO[i], box.get_center() - b.global_position, box.size, box.position.y])

	# Front. The camera is on +Z looking back down -Z, which is where the player
	# stands relative to a shopkeeper (`Npc` yaws a keeper's +Z at the hero), so
	# "do they look at me from here" is the whole question this frame answers.
	# Derived from the line-up, not written down: the fifth body was added to WHO
	# and every one of these three cameras was still framing the middle of four,
	# which put the alchemist half out of the frame in the shot that is supposed
	# to prove she arrived.
	var mid := STEP * float(made.size() - 1) * 0.5
	var back := 3.4 + STEP * float(made.size())
	_mid = mid
	await _shot(rig, cam, out, "npc_raw_0_front", Vector3(mid, 1.5, back))
	await _shot(rig, cam, out, "npc_raw_1_back", Vector3(mid, 1.5, -back))
	await _shot(rig, cam, out, "npc_raw_2_side", Vector3(mid + back, 1.5, 0.6))
	print("NPCRAW done")


func _shot(rig, cam: Camera3D, out: String, name: String, at: Vector3) -> void:
	cam.global_position = at
	cam.look_at(Vector3(_mid, 0.85, 0.0), Vector3.UP)
	await rig.wait_frames(6)
	await rig.capture(out.path_join(name + ".png"))


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
