extends Node
## What the four authored NPC bodies actually contain, next to the rig the
## shared idle clips were authored on.
##
## They arrived as Tripo FBX and nothing about a Tripo rig is guessable: the
## races in `assets/characters/races/` are Tripo too and carry MIXAMO bone names
## (Hips/LeftArm/...), while these carry Tripo's own (Hip/L_Upperarm/...).
## Whether the shared clip library can drive them is a question about names and
## about rest poses, and this prints both.
##
##   godot --path . --headless res://tools/scenes/_npc_facts.tscn

const BODIES := ["jewelcrafter", "pawnbroker", "lanternkeeper", "smith"]
const LIB := "res://assets/characters/races/_humanoid_anims.glb"


func _ready() -> void:
	_rig("clip library", LIB)
	for who in BODIES:
		_rig(who, "res://assets/characters/npc/%s.fbx" % who)
	get_tree().quit(0)


func _rig(label: String, path: String) -> void:
	if not ResourceLoader.exists(path):
		print("MISSING %s" % path)
		return
	var rig := (load(path) as PackedScene).instantiate() as Node3D
	add_child(rig)
	print("\n=== %s (%s) ===" % [label, path.get_file()])

	var skel := rig.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		print("  no Skeleton3D")
		return
	print("  %d bones" % skel.get_bone_count())
	var top := 0.0
	for i in skel.get_bone_count():
		var p := skel.get_bone_parent(i)
		var g := skel.get_bone_global_rest(i)
		top = maxf(top, g.origin.y)
		# The rest basis' three axes, so a bone-roll mismatch between the two
		# rigs shows up as a number rather than as a person with folded arms.
		print("  [%2d] %-22s parent=%-22s pos %v  x%v y%v" % [
			i, skel.get_bone_name(i),
			skel.get_bone_name(p) if p >= 0 else "-",
			g.origin, g.basis.x.snappedf(0.01), g.basis.y.snappedf(0.01)])
	var to_rig := Transform3D.IDENTITY
	var n: Node3D = skel
	while n != null and n != rig:
		to_rig = n.transform * to_rig
		n = n.get_parent() as Node3D
	print("  crown: %.4f skeleton-space, %.4f m in rig space" % [
		top, (to_rig * Vector3(0.0, top, 0.0)).y])

	for c in _all(rig):
		var mi := c as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		print("  mesh %s: %d surface(s), aabb %v, skin=%s" % [
			mi.name, mi.mesh.get_surface_count(), mi.mesh.get_aabb().size, mi.skin != null])
	var ap := rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
	print("  clips: %d" % (ap.get_animation_list().size() if ap != null else -1))


static func _all(n: Node) -> Array[Node]:
	var out: Array[Node] = [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out
