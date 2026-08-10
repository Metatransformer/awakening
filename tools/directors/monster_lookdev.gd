extends RefCounted
## Lines the whole roster up and photographs it, so "the monsters render" is a
## thing someone looked at rather than a thing the log implied.
##
## Spawned in the garrison, which is lit: a monster that fails to load its model
## is a black gap in a dungeon and an obvious hole in a courtyard.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/monster_lookdev.gd --out=/tmp/mon/x.png

const KINDS: Array[StringName] = [&"skeleton", &"goblin", &"kobold", &"orc", &"wraith"]


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/mon/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var scene: Node = rig.current_scene
	var hero: Node3D = rig.get_nodes_in_group(&"player")[0]

	# Well clear of the hero: these chase on sight, and a lookdev shot of five
	# monsters piling onto the player is not a lookdev shot.
	hero.global_position = Vector3(0.0, 0.05, 26.0)
	await rig.wait_frames(10)

	var made: Array[Enemy] = []
	for i in KINDS.size():
		var e := Enemy.new()
		e.kind = KINDS[i]
		e.drop_seed = 1000 + i
		scene.add_child(e)
		e.global_position = Vector3(-6.0 + 3.0 * float(i), 0.05, 0.0)
		made.append(e)
	await rig.wait_frames(45)

	for e in made:
		var meshes := _meshes(e)
		print("MON %-9s meshes=%d verts=%d" % [e.kind, meshes[0], meshes[1]])

	# Look at the line-up from in front.
	hero.global_position = Vector3(0.0, 0.05, 9.0)
	Bus.camera_recenter.emit()
	await rig.wait_frames(40)
	await rig.capture(out.path_join("mon_00_lineup.png"))

	for i in made.size():
		hero.global_position = made[i].global_position + Vector3(0.0, 0.0, 3.4)
		Bus.camera_recenter.emit()
		await rig.wait_frames(34)
		await rig.capture(out.path_join("mon_%02d_%s.png" % [i + 1, made[i].kind]))


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
