extends RefCounted
## Every prop the shop booths are built from, lined up against a one-metre cube.
##
## The booths are authored in code from a pack this repo has never used before,
## and the two things you cannot get from a filename are **how big a thing is**
## and **which way it faces**. Guessing produced an anvil the size of a cart the
## first time somebody tried it in another project; measuring takes one run.
##
## Prints the measured bounds of each prop and photographs the row, so the
## numbers in `shop_booth.gd` are transcribed from this output rather than
## invented.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/_lookdev.tscn \
##     --director=res://tools/directors/booth_props.gd --out=/tmp/booth/x.png

const DIR := "res://assets/props/booth/"

## Grouped the way the booths use them, so the sheet reads as three shops.
const GROUPS := {
	"forge": ["forge_pit.glb", "anvil.glb", "stump.glb", "grindstone.glb",
		"hammer01.glb", "tongs01.glb", "Bucket_Metal.gltf", "Barrel.gltf",
		"WeaponStand.gltf", "Whetstone.gltf"],
	"alchemy": ["Workbench.gltf", "Cauldron.gltf", "Shelf_Small_Bottles.gltf",
		"Potion_1.gltf", "Potion_2.gltf", "Potion_4.gltf", "SmallBottles_1.gltf",
		"Book_Stack_1.gltf", "CandleStick.gltf"],
	"stall": ["Stall_Empty.gltf", "Chest_Wood.gltf", "Crate_Wooden.gltf",
		"Coin_Pile.gltf", "Chalice.gltf", "Pouch_Large.gltf", "Lantern_Wall.gltf"],
}


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/booth/x.png").get_base_dir()
	var scene: Node = rig.current_scene

	var cam := Camera3D.new()
	cam.fov = 45.0
	scene.add_child(cam)
	cam.make_current()

	for group in GROUPS:
		var row := Node3D.new()
		scene.add_child(row)
		var x := 0.0
		var widest := 0.0
		# Annotated because indexing an untyped const Dictionary hands back a
		# Variant, and the parser then cannot infer anything downstream of it
		# (CLAUDE.md §3).
		var files: Array = GROUPS[group]
		for file in files:
			var path: String = DIR + String(file)
			if not ResourceLoader.exists(path):
				print("PROP MISSING %s" % path)
				continue
			var n := (load(path) as PackedScene).instantiate() as Node3D
			row.add_child(n)
			var box := _box(n)
			# Space each prop by its own width, so a big one does not sit inside
			# its neighbour and a small one does not vanish in a gap.
			x += box.size.x * 0.5 + 0.35
			n.position = Vector3(x, -box.position.y, 0.0)
			x += box.size.x * 0.5
			widest = maxf(widest, box.size.y)
			print("PROP %-10s %-24s size=(%.2f, %.2f, %.2f) base_y=%.2f" % [
				group, String(file).get_basename(), box.size.x, box.size.y, box.size.z,
				box.position.y])

		# A one-metre cube at the origin of every row: the only honest scale bar.
		var ref := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE
		ref.mesh = bm
		ref.position = Vector3(0.0, 0.5, 0.0)
		row.add_child(ref)

		cam.global_position = Vector3(x * 0.5, maxf(widest, 1.2) * 0.9, x * 0.85 + 3.0)
		cam.look_at(Vector3(x * 0.5, maxf(widest, 1.2) * 0.35, 0.0), Vector3.UP)
		await rig.wait_frames(8)
		await rig.capture(out.path_join("props_%s.png" % group))
		row.queue_free()
		await rig.wait_frames(2)
	print("BOOTHPROPS done")


## Bounds of a prop in its own space. These are plain static meshes, so the
## mesh AABB is the honest measure here -- unlike the skinned race bodies, where
## it is a trap (see `RaceBody._native_height`).
func _box(n: Node3D) -> AABB:
	var acc := AABB()
	var first := true
	for pair in _meshes(n, Transform3D.IDENTITY):
		var b: AABB = (pair[1] as Transform3D) * (pair[0] as MeshInstance3D).mesh.get_aabb()
		if first:
			acc = b
			first = false
		else:
			acc = acc.merge(b)
	return acc


func _meshes(n: Node, xform: Transform3D) -> Array:
	var out: Array = []
	for c in n.get_children():
		var c3 := c as Node3D
		var here: Transform3D = xform * c3.transform if c3 != null else xform
		var mi := c as MeshInstance3D
		if mi != null and mi.mesh != null:
			out.append([mi, here])
		out.append_array(_meshes(c, here))
	return out
