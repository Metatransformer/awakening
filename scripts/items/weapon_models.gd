class_name WeaponModels
extends RefCounted
## Loads a weapon or item model, textured and scaled, ready to hang off a bone.
##
## Three problems this solves, all of which were measured rather than assumed
## (tools/_weapon_probe.gd prints the numbers):
##
##  1. The `weapons_hq` GLBs carry NO embedded images — every surface imports
##     with a bare material and renders flat grey. Their diffuse ships beside
##     them as `assets/weapons/textures/<id>_diff.jpg`. Binding it is not
##     optional polish; without it the sword is a grey wedge.
##  2. Scale varies wildly by source. The `weapons_hq` set is already native
##     1:1 metres (0.92 m swords, 0.61-0.94 m shields — exactly OOT one-hander
##     proportions against our 1.65 m hero). The imported alternates are not:
##     `kite_shield` is 1.39 m tall and the hookshot pistol is 1.00 m long.
##     Those get an explicit correction here so callers never guess.
##  3. GLB roots come in with their own node names, transforms and, for the
##     hookshot, a generated `tripo_node_...` identifier. Callers want a clean
##     Node3D at the origin whose local axes mean something.
##
## Grip convention, so every socket in the game agrees. Verified by render, not
## by reading the GLB — see tools/scenes/_weapon_lookdev.gd:
##   sword    — origin at the pommel, blade along +Y, flat of the blade in XY.
##   shield   — origin at the CENTRE of the shield, not its rim, so a socket
##              that places it at y=0 buries half of it. Front face points +Z.
##   hookshot — origin at the grip, barrel along +Z (the direction it fires).

const DIR_WEAPONS := "res://assets/weapons/"
const DIR_TEXTURES := "res://assets/weapons/textures/"
const DIR_ITEMS := "res://assets/items/"

## Models whose native size is not the size we want, and the factor that fixes
## it. Anything absent is already correct at 1.0 — that is the common case and
## deliberately requires no entry.
const SCALE_FIX := {
	"kite_shield": 0.52,      # 1.39 m tall -> 0.72 m, matching shield_noble
	"hookshot_pistol": 0.30,  # 1.00 m long -> 0.30 m, a pistol not a rifle
}

## Models that already carry embedded textures and must NOT be given a
## `_diff` bind (they have full PBR sets and overriding would flatten them).
const SELF_TEXTURED := ["kite_shield", "hookshot_pistol"]


## Build a model by id (the filename without extension), e.g. "sword_knightly".
## Returns null and pushes an error if the id does not resolve — a missing
## weapon should be loud, not an invisible hand.
static func make(id: String) -> Node3D:
	var path := _path_for(id)
	if path.is_empty():
		push_error("WeaponModels: no model for id '%s'" % id)
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("WeaponModels: '%s' failed to load" % path)
		return null

	var root := packed.instantiate() as Node3D
	root.name = id

	if not SELF_TEXTURED.has(id):
		var tex := _diffuse_for(id)
		if tex != null:
			_bind_albedo(root, tex)
		else:
			push_warning("WeaponModels: '%s' has no embedded texture and no %s_diff.jpg — it will render untextured." % [id, id])

	var s: float = SCALE_FIX.get(id, 1.0)
	if not is_equal_approx(s, 1.0):
		root.scale = Vector3.ONE * s
	return root


## Longest side of the assembled model, in metres. Lets a socket sanity-check
## what it was handed instead of trusting the id.
static func extent(model: Node3D) -> float:
	var acc := AABB()
	var first := true
	for mi in _meshes(model):
		var box: AABB = mi.transform * mi.mesh.get_aabb()
		if first:
			acc = box
			first = false
		else:
			acc = acc.merge(box)
	var sz := acc.size * model.scale
	return maxf(sz.x, maxf(sz.y, sz.z))


static func _path_for(id: String) -> String:
	for dir: String in [DIR_WEAPONS, DIR_ITEMS]:
		var p: String = dir + id + ".glb"
		if ResourceLoader.exists(p):
			return p
	return ""


static func _diffuse_for(id: String) -> Texture2D:
	for ext: String in [".jpg", ".png"]:
		var p: String = DIR_TEXTURES + id + "_diff" + ext
		if ResourceLoader.exists(p):
			return load(p) as Texture2D
	return null


## Give every surface its albedo map. The imported materials are shared
## resources owned by the .glb, so they are duplicated first — writing to them
## in place would repaint every other instance of the same model in the scene.
static func _bind_albedo(root: Node3D, tex: Texture2D) -> void:
	for mi in _meshes(root):
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i) as BaseMaterial3D
			var mat: StandardMaterial3D = (
				src.duplicate() as StandardMaterial3D if src is StandardMaterial3D
				else StandardMaterial3D.new()
			)
			mat.albedo_texture = tex
			mat.albedo_color = Color.WHITE
			# These are hand-painted diffuse maps with the metal already in the
			# pixels, so let the texture read rather than blowing it out with a
			# specular response the artist never accounted for.
			mat.metallic = 0.0
			mat.roughness = 0.55
			mi.set_surface_override_material(i, mat)


static func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out
