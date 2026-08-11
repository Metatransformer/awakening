extends RefCounted
## Every surface in a live scene that is drawing Godot's fallback white.
##
## ## The failure, and why nothing else catches it
##
## When the glTF importer cannot resolve a material -- most often because the
## texture the model's `uri` points at was not in the tree at the moment the
## model was imported -- it does not fail the import and it does not leave the
## surface without a material. It substitutes a **default `StandardMaterial3D`**:
## `albedo_color = white`, no `albedo_texture`, `vertex_color_use_as_albedo` off.
## That is a real material, so every "has it got a material?" check passes, and
## the prop renders as a flat untextured white slab in the middle of the frame.
##
## Worse, it is **sticky**. `godot --path . --import` will not repair it: the
## `[deps]` block of a scene `.import` lists only the source file, so adding the
## missing texture later does not invalidate the cached `.scn`, and the import
## reports DONE having rebuilt nothing. That is how commit 68bc85e could add the
## three missing `T_Trim_Props_*` maps, verify "import is clean now", and leave
## every prop that uses them white on disk for a day.
##
## Only two things find it: a person looking at a frame, and this. The repair is
## to delete the cached scene and import again --
##
##   p=$(grep '^path=' assets/props/booth/Pouch_Large.gltf.import | cut -d'"' -f2)
##   rm -f "${p#res://}" && godot --path . --import --headless
##
## ## What it flags, and what it deliberately does not
##
## Only surfaces whose mesh came out of an imported file (`.glb`/`.gltf`/`.fbx`).
## A `BoxMesh` built in code with a flat colour is this project's house style
## (STYLEGUIDE §7.10 asks for procedural polygons), and the garrison is full of
## deliberately untextured props -- the relic lamps' near-black heads, the
## smithy's authored `smithy_iron`, the statue's cold `Statue.STONE`. None of
## those is white, because somebody chose their colour. Godot's fallback is the
## one colour nobody chooses, so WHITE + no texture + came-from-a-file is the
## signature, and it has no false positives in this project.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/art_audit.gd --out=/tmp/art/x.png
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/art_audit.gd --out=/tmp/art/x.png

## How close to `Color.WHITE` an albedo has to be to be the importer's and not a
## person's. Godot's fallback is exactly 1.0; nothing authored in this project
## sits above 0.9 on all three channels (`Pal.BONE` is 0.93, 0.91, 0.85 -- and it
## is never used as an untextured albedo on imported geometry).
const WHITE := 0.97

var _fails: int = 0


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/art/x.png").get_base_dir()
	# Long enough for the garrison's booths and the dungeon's rooms to be built
	# and for `Flow` to have let go of the frame.
	await rig.wait_seconds(2.5)

	var seen: Dictionary = {}
	_walk(rig.scene().get_tree().root, seen)
	var keys: Array = seen.keys()
	keys.sort()
	for k in keys:
		_fail("%s x%d" % [k, seen[k]])

	await rig.capture(out.path_join("art_00.png"))
	if _fails == 0:
		print("ART OK")


func _walk(n: Node, seen: Dictionary) -> void:
	var mi := n as MeshInstance3D
	if mi != null and mi.mesh != null and mi.is_visible_in_tree():
		# Imported geometry only -- see the class note. A code-built mesh has no
		# resource path, or one that is a `.tscn`/`.tres` rather than a model.
		var from := mi.mesh.resource_path
		if from.contains(".glb") or from.contains(".gltf") or from.contains(".fbx"):
			for s in mi.mesh.get_surface_count():
				# The three places a material can come from, nearest first. A
				# tinted surface override is how `ShopBooth` already answers this
				# pack's white glassware, and a surface that HAS been answered is
				# not a defect.
				var m: Material = mi.material_override
				if m == null:
					m = mi.get_surface_override_material(s)
				if m == null:
					m = mi.mesh.surface_get_material(s)
				if not _is_fallback(m):
					continue
				var key := "%s [%s surface %d] draws Godot's fallback white" % [
					from.get_file(), mi.name, s]
				seen[key] = int(seen.get(key, 0)) + 1
	for c in n.get_children():
		_walk(c, seen)


## True for the material Godot substitutes when it could not build the real one:
## white, untextured, and not even falling back to the mesh's vertex colours.
func _is_fallback(m: Material) -> bool:
	if m == null:
		# No material at all is the same picture on screen and the same bug class.
		return true
	var bm := m as BaseMaterial3D
	if bm == null:
		return false
	if bm.albedo_texture != null or bm.vertex_color_use_as_albedo:
		return false
	var c := bm.albedo_color
	return c.r >= WHITE and c.g >= WHITE and c.b >= WHITE


func _fail(msg: String) -> void:
	_fails += 1
	print("ART FAIL %s" % msg)
