extends Node
## Measures every imported weapon/item model: its AABB in metres, whether its
## surfaces carry a texture, and how it compares to the 1.65 m hero.
##
## The weapons_hq GLBs ship with no embedded images (their diffuse lives beside
## them as `<name>_diff.jpg`), so "does it have an albedo texture" is a real
## question with a real answer, not a formality — a model that imports fine and
## renders untextured grey is a silent failure otherwise.
##
##   godot --path . --headless res://tools/scenes/_weapon_probe.tscn

const PATHS := [
	"res://assets/weapons/sword_knightly.glb",
	"res://assets/weapons/sword_noble.glb",
	"res://assets/weapons/sword_elegant.glb",
	"res://assets/weapons/sword_common.glb",
	"res://assets/weapons/sword_crude.glb",
	"res://assets/weapons/sword_simple.glb",
	"res://assets/weapons/shield_knightly.glb",
	"res://assets/weapons/shield_noble.glb",
	"res://assets/weapons/shield_elegant.glb",
	"res://assets/weapons/shield_common.glb",
	"res://assets/weapons/shield_crude.glb",
	"res://assets/weapons/kite_shield.glb",
	"res://assets/weapons/shield_heater.glb",
	"res://assets/weapons/shield_round.glb",
	"res://assets/items/hookshot_pistol.glb",
]


func _ready() -> void:
	print("model                          size (m)              longest  surfaces  textured")
	print("-".repeat(88))
	for p in PATHS:
		var ps := load(p) as PackedScene
		if ps == null:
			print("%-30s  MISSING" % p.get_file())
			continue
		var root: Node3D = ps.instantiate() as Node3D
		add_child(root)
		var aabb := _aabb(root)
		var surfaces := 0
		var textured := 0
		for mi in _meshes(root):
			var m: Mesh = mi.mesh
			for i in m.get_surface_count():
				surfaces += 1
				var mat := mi.get_active_material(i) as BaseMaterial3D
				if mat and mat.albedo_texture != null:
					textured += 1
		var s := aabb.size
		print("%-30s  %5.2f x %5.2f x %5.2f   %5.2f    %2d       %d/%d %s" % [
			p.get_file(), s.x, s.y, s.z,
			maxf(s.x, maxf(s.y, s.z)), surfaces, textured, surfaces,
			"" if textured == surfaces else "  <-- UNTEXTURED",
		])
		root.queue_free()
		await get_tree().process_frame
	print("-".repeat(88))
	print("hero is 1.65 m tall. An OOT-scale one-handed sword reads ~0.85-1.00 m,")
	print("a Hylian-style shield ~0.65-0.80 m tall.")
	get_tree().quit(0)


func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out


## Union of every mesh AABB, expressed in the root's own space.
func _aabb(root: Node3D) -> AABB:
	var acc := AABB()
	var first := true
	for mi in _meshes(root):
		var local := root.global_transform.affine_inverse() * mi.global_transform
		var box := local * mi.mesh.get_aabb()
		if first:
			acc = box
			first = false
		else:
			acc = acc.merge(box)
	return acc
