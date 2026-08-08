extends Node
## Prints what the monster assets actually ship with: whether each .glb has a
## skeleton and an AnimationPlayer of its own, and what is inside the prebuilt
## monster_library.res. A brute animation set is useless if its bone names do
## not match the creature you want to play it on, so print both and compare.
##
##   godot --path . --headless res://tools/scenes/_monster_facts.tscn

const MONSTERS := ["goblin", "skeleton", "kobold", "orc", "wraith", "ogre", "troll", "golem", "knight_iron"]


func _ready() -> void:
	var lib_path := "res://assets/animations/monster_library.res"
	if ResourceLoader.exists(lib_path):
		var lib := load(lib_path) as AnimationLibrary
		if lib != null:
			var names: Array[StringName] = lib.get_animation_list()
			print("=== monster_library.res : %d clips ===" % names.size())
			for n in names:
				print("  %-34s %5.2fs" % [n, lib.get_animation(n).length])
	else:
		print("=== no monster_library.res ===")

	for id in MONSTERS:
		var p := "res://assets/monsters/%s.glb" % id
		if not ResourceLoader.exists(p):
			print("\n[%s] MISSING" % id)
			continue
		var root := (load(p) as PackedScene).instantiate() as Node3D
		add_child(root)
		var skel := root.find_child("Skeleton3D", true, false) as Skeleton3D
		var ap := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var meshes := _mesh_count(root)
		var aabb := _extent(root)
		print("\n[%s] meshes=%d height=%.2fm skeleton=%s bones=%d anim_player=%s" % [
			id, meshes, aabb.size.y,
			"yes" if skel != null else "NO",
			skel.get_bone_count() if skel != null else 0,
			"yes" if ap != null else "NO"])
		if ap != null:
			print("   clips: ", ap.get_animation_list())
		if skel != null:
			var sample: Array = []
			for i in mini(skel.get_bone_count(), 6):
				sample.append(skel.get_bone_name(i))
			print("   first bones: ", sample)
		root.queue_free()

	get_tree().quit(0)


func _mesh_count(n: Node) -> int:
	var c := 1 if (n is MeshInstance3D and (n as MeshInstance3D).mesh != null) else 0
	for ch in n.get_children():
		c += _mesh_count(ch)
	return c


func _extent(n: Node) -> AABB:
	var acc := AABB()
	var first := true
	for mi in _meshes(n):
		var b: AABB = mi.global_transform * mi.mesh.get_aabb()
		if first:
			acc = b
			first = false
		else:
			acc = acc.merge(b)
	return acc


func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out
