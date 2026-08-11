extends RefCounted
## Every surface in the game that is going to render as a white slab -- in the
## two shipped scenes AND on the bodies that only exist once the game is running.
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
## ## The second failure: a surface that is white before any light touches it
##
## Same picture, different cause, and the scene walk above could never have found
## it because it is not imported art. A code-built attachment with
## `emission_enabled` and a pale albedo adds its own emission to its own albedo
## and clips every channel to 1.0 on its own -- the room's lighting is then
## decoration on top of a surface that was already at maximum. `Enemy._sack` was
## `Pal.BONE` (0.847, 0.816, 0.722) at an emission multiplier of 0.25, which is
## 1.06 and 1.02 in red and green: a hard-edged white wedge on the goblin's
## chest, measured off `m_10_swung.png` at (255, 255, 240). `LootMote` was the
## same bug at 0.9. Both read on screen as untextured missing art.
##
## So the body pass also flags `albedo * (1 + emission_energy) >= 1.0` on any
## channel. That is deliberately a check on the MATERIAL alone and not on the
## render: it says "this surface is over-driven before the scene is even
## consulted", which is a fact about the code and true in every room.
##
## ## What it flags, and what it deliberately does not
##
## The fallback-white check runs on surfaces whose mesh came out of an imported
## file (`.glb`/`.gltf`/`.fbx`) only. A `BoxMesh` built in code with a flat colour
## is this project's house style (STYLEGUIDE §7.10 asks for procedural polygons),
## and the garrison is full of deliberately untextured props -- the relic lamps'
## near-black heads, the smithy's authored `smithy_iron`, the statue's cold
## `Statue.STONE`. None of those is white, because somebody chose their colour.
## Godot's fallback is the one colour nobody chooses, so WHITE + no texture +
## came-from-a-file is the signature, and it has no false positives here.
##
## The over-driven check runs on the spawned bodies only, and skips unshaded
## materials and anything that is not blending MIX. Both exemptions are load
## bearing: `Npc`'s lantern is `SHADING_MODE_UNSHADED` at an emission of 1.8 and
## renders as gold, because an unshaded material outputs its albedo and ignores
## emission entirely -- and the game's flashes and VFX are supposed to be bright.
## Restricting it to bodies is what keeps it quiet: there is no VFX inside a
## goblin, so everything it can see is a surface that has to hold a colour.
##
## ## Running it
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/art_audit.gd --out=/tmp/art/x.png
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/art_audit.gd --out=/tmp/art/x.png
##
## Either scene audits the whole cast: the bodies are spawned by this director,
## not found, so the roster it covers is `Enemy.DEFS` and `Npc.Role` rather than
## whatever the run happened to place.

## How close to `Color.WHITE` an albedo has to be to be the importer's and not a
## person's. Godot's fallback is exactly 1.0; nothing authored in this project
## sits above 0.9 on all three channels (`Pal.BONE` is 0.93, 0.91, 0.85 -- and it
## is never used as an untextured albedo on imported geometry).
const WHITE := 0.97

## Where the spawned cast stands: far under the floor of either scene, so nothing
## it does can walk into the frame this director also captures.
const STAGE := Vector3(0.0, -80.0, 0.0)

var _fails: int = 0


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/art/x.png").get_base_dir()
	# Long enough for the garrison's booths and the dungeon's rooms to be built
	# and for `Flow` to have let go of the frame.
	await rig.wait_seconds(2.5)

	var seen: Dictionary = {}
	_walk(rig.scene().get_tree().root, seen, "")

	# The half a scene walk cannot see. An enemy and a shopkeeper are assembled in
	# code at spawn -- neither is in `garrison.tscn` or `dungeon.tscn` -- so the
	# whole population that carries characters and their attachments was invisible
	# to this director until it started building one of each itself.
	var stage := Node3D.new()
	stage.position = STAGE
	rig.scene().add_child(stage)
	await _cast(rig, stage, seen)

	var keys: Array = seen.keys()
	keys.sort()
	for k in keys:
		_fail("%s x%d" % [k, seen[k]])

	stage.queue_free()
	await rig.wait_frames(2)
	await rig.capture(out.path_join("art_00.png"))
	if _fails == 0:
		print("ART OK")


## One of every monster and every shopkeeper, assembled and walked.
func _cast(rig, stage: Node3D, seen: Dictionary) -> void:
	var kinds: Array = Enemy.DEFS.keys()
	kinds.sort()
	var foes: Array[Enemy] = []
	var x := 0.0
	for kind in kinds:
		var e := Enemy.new()
		e.kind = kind
		e.position = Vector3(x, 0.0, 0.0)
		stage.add_child(e)
		foes.append(e)
		x += 3.0
	var people: Array[Npc] = []
	for role in Npc.Role.values():
		var n := Npc.new()
		n.role = role
		n.position = Vector3(x, 0.0, 0.0)
		stage.add_child(n)
		people.append(n)
		x += 4.0
	# Models load and rigs settle. 40 frames is generous; the models are already
	# in the resource cache by the time either scene has finished building.
	await rig.wait_frames(40)
	for e in foes:
		_walk(e, seen, "Enemy %s" % e.kind)
	for n in people:
		_walk(n, seen, "Npc %s" % _role_name(n.role))

	# The thief's sack exists only mid-GRAB, which no amount of waiting will
	# produce on a stage with nobody to rob. Reaching past `_` into the two
	# builders is the honest way to audit a surface that is real for about a
	# second: it is the same material either way, and a surface the player sees
	# for a second is exactly the kind that ships broken.
	# NO `await` anywhere in this loop, and that is the whole of why it works. An
	# empty sack on a body that is not mid-GRAB is swept up by `Enemy`'s own
	# `_physics_process` on the very next frame -- the first version of this waited
	# two frames to be safe and audited nothing at all, twice, while reporting OK.
	# Both builders are synchronous and the mesh is in the tree when they return.
	for e in foes:
		if not e.has_method("_build_sack"):
			continue
		e.call("_build_sack")
		_walk(e, seen, "Enemy %s empty sack" % e.kind)
		e.call("_fill_sack", &"void_pearl")
		_walk(e, seen, "Enemy %s full sack" % e.kind)
		e.call("_clear_sack")


func _role_name(role: int) -> String:
	for k in Npc.Role.keys():
		if int(Npc.Role[k]) == role:
			return str(k)
	return str(role)


## `label` names the body being audited, and is "" for the scene walk. It is what
## turns the over-driven check on, and it is also the whole of the message's
## usefulness: `@MeshInstance3D@1709` names nothing, "Enemy goblin empty sack"
## names the function to open.
func _walk(n: Node, seen: Dictionary, label: String) -> void:
	var mi := n as MeshInstance3D
	if mi != null and mi.mesh != null and mi.is_visible_in_tree():
		if label != "":
			_check_overdriven(mi, seen, label)
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
		_walk(c, seen, label)


## A surface that is already clipped before the room's lights are added.
func _check_overdriven(mi: MeshInstance3D, seen: Dictionary, label: String) -> void:
	var bm := mi.material_override as BaseMaterial3D
	if bm == null:
		bm = mi.get_surface_override_material(0) as BaseMaterial3D
	if bm == null:
		return
	if not bm.emission_enabled:
		return
	# An unshaded material outputs its albedo and never adds emission, so its
	# multiplier is not a brightness. `Npc`'s 1.8 lantern lives here.
	if bm.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return
	# ADD and friends are the game's flashes and hits. They are meant to blow out.
	if bm.blend_mode != BaseMaterial3D.BLEND_MODE_MIX:
		return
	# A textured surface's albedo_color is a tint, usually white, and multiplying
	# it by the emission says nothing about what lands on screen.
	if bm.albedo_texture != null:
		return
	var a := bm.albedo_color
	var e := 1.0 + bm.emission_energy_multiplier
	var hot := maxf(a.r, maxf(a.g, a.b)) * e
	if hot < 1.0:
		return
	var key := "%s is over-driven: albedo (%.2f, %.2f, %.2f) x (1 + %.2f emission) = %.2f -- white before any light reaches it" % [
		label, a.r, a.g, a.b, bm.emission_energy_multiplier, hot]
	seen[key] = int(seen.get(key, 0)) + 1


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
