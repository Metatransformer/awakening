class_name SuitSeater
extends RefCounted
## Puts one authored armour suit on any of the three bodies, and cuts the body back
## to a head so nothing shows through it.
##
## Ported from Valenfeld's `ArmorSeater.seat_skinned_mesh` / `_rebase_bind_to_body` /
## `_piece_canon_to_body_map`, and from the "simple suit mode" half of
## `HumanoidRig._equip_armor_simple_suit` (docs/designs/equipment-art-pipeline.md
## §"Simple suit mode" over there). The shape of it is Valenfeld's, and so is the
## reason it exists:
##
##   A SUIT IS A WHOLE BODY. `cloth/body_rigged.glb` is not a tabard to hang on a
##   torso -- it is the entire silhouette from collar to boot sole, gloves included,
##   and `head_rigged.glb` is the matching hood or helm. You do not dress the
##   character; you REPLACE the character with the suit and put their head back in
##   it. That is why the artist exported it in two halves.
##
## Which makes the whole per-slot fitting problem go away. There is no gap between a
## sleeve and a cuirass to close, because there is no seam: it is one mesh, and it
## was modelled dressed. Every artefact the constructed-garment attempt spent its
## rounds on -- the pass-through at the sternum, the wedge at the hip, the bare band
## at the deltoid -- is a seam problem, and this pipeline has no seams.
##
## **The one real problem is that a suit is authored against ONE figure.** Ours are
## three, 1.41 m to 1.82 m and shaped differently. `_fit_map` is the answer and it is
## the only clever thing in the file: fit a similarity (uniform scale + translation)
## between the suit's own rest skeleton and the wearer's, then rebase every Skin bind
## through it. The suit's vertices never move -- what changes is where each bone
## claims them from -- so the suit lands on the wearer's actual joints and deforms off
## the wearer's actual clips.
##
## Units are never named anywhere in here on purpose. The map is fitted between two
## rest poses in their OWN raw skeleton units, so whatever convention either side
## uses cancels into the scale factor. See `_fit_map`.

## Where the suits live. One directory per material, each holding the two halves.
const DIR := "res://assets/characters/suits/"
## The materials the pack ships, cheapest first. Cloth and leather are what a
## shopkeeper wears; mail and plate are here because the garrison sells them.
const SETS: Array[String] = ["cloth", "leather", "mail", "plate"]

## How far a role's colour is allowed to pull the suit it is painted on.
##
## Not all the way, and this is the difference between tinting a texture and tinting
## a flat colour. These atlases are already dark -- tooled black leather, a maroon
## robe, blued steel -- so a multiply by a role colour lands somewhere near black and
## takes the weave down with it. The first render of the seated suits had a
## pawnbroker who read as a silhouette. Softening the tint toward white before it
## multiplies keeps the role legible and leaves the material visible underneath,
## which is the whole reason for using authored art instead of a palette.
const TINT_PULL := 0.5

## Bones whose geometry survives the cut when a suit goes on.
##
## The face and the skull, and nothing else. `neck` is deliberately OUT: every head
## half in the pack is a hood or a coif that closes around the throat, so a neck left
## in is a neck poking through a collar -- and a neck left out is invisible, because
## the collar is what you see there instead.
##
## In practice only `Head` carries any geometry -- `head_end` and `headfront` are leaf
## markers with zero vertices weighted to them (measured, not assumed). They are
## listed anyway because a re-export that starts using them should not silently lose
## a jaw.
##
## **The whole skull survives, and that is a known limit.** Valenfeld cuts the
## CRANIUM -- the top-back of the skull, on an authored line from the forehead down to
## the base -- so a helm has nothing underneath it to punch through. There is no such
## line on this rig and no bone that draws one, so the cut is not available without
## authoring it. The visible consequence is exactly one: the leather suit's coif is a
## close cap and ends up entirely inside the skull, so a Stoneborn in leather reads
## bare-headed. The cloth hood and the plate helm are roomy enough to sit outside and
## both render correctly.
const HEAD_BONES := ["Head", "head_end", "headfront"]


## Seat one half of a suit on `dst`. Returns the meshes added, empty on failure.
##
## `tint` multiplies the authored albedo. It is how Valenfeld gets three NPC outfits
## out of one cloth suit, and it works here for the same reason: the texture carries
## the weave, the folds and the wear, so a multiply changes what the cloth is DYED
## without touching any of that. This is the difference between tinting a texture and
## the flat palette colour a procedural garment gets -- one is a dyed shirt, the
## other is a shape with a colour.
static func seat(dst: Skeleton3D, path: String, tag: String,
		tint: Color = Color.WHITE) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if dst == null or not ResourceLoader.exists(path):
		push_warning("suit_seater: no suit at %s" % path)
		return out
	var scene: PackedScene = load(path)
	if scene == null:
		return out
	var src_root := scene.instantiate()
	var src := _find_skel(src_root)
	if src == null:
		push_warning("suit_seater: %s has no Skeleton3D" % path)
		src_root.free()
		return out

	for mi in _skinned(src_root):
		var map := _fit_map(src, dst, mi.skin)
		var skin := Skin.new()
		var kept := 0
		for b in mi.skin.get_bind_count():
			var bone := _bind_name(mi.skin, b, dst)
			var di := dst.find_bone(bone)
			var si := src.find_bone(bone)
			if di < 0 or si < 0:
				# Godot's glTF importer uniquifies duplicate node names with a `_N`
				# suffix, so a bind can name a bone that no longer exists. `_bind_name`
				# already strips that; anything still missing would deform to the
				# origin, so bind it to itself and leave it where the artist put it.
				skin.add_named_bind(bone, mi.skin.get_bind_pose(b))
				continue
			skin.add_named_bind(bone, dst.get_bone_global_rest(di).affine_inverse()
				* map * src.get_bone_global_rest(si) * mi.skin.get_bind_pose(b))
			kept += 1
		if kept == 0:
			push_warning("suit_seater: %s shares no bones with this body" % path)
			continue

		var worn := MeshInstance3D.new()
		worn.name = "Suit_" + tag
		worn.mesh = mi.mesh
		worn.skin = skin
		# The authored materials come across untouched unless there is a tint to
		# apply, and then only as a per-instance override -- the mesh resource is
		# shared by every body wearing this suit, so writing to its surfaces would
		# dye the whole garrison the first shopkeeper's colour.
		if tint != Color.WHITE:
			for s in mi.mesh.get_surface_count():
				var src_mat := mi.mesh.surface_get_material(s)
				var m: BaseMaterial3D = src_mat.duplicate() if src_mat is BaseMaterial3D \
					else StandardMaterial3D.new()
				m.albedo_color = m.albedo_color * tint.lerp(Color.WHITE, 1.0 - TINT_PULL)
				worn.set_surface_override_material(s, m)
		dst.add_child(worn)
		worn.transform = Transform3D.IDENTITY
		worn.skeleton = ^".."
		out.append(worn)

	src_root.free()
	return out


## The similarity taking the suit's rest skeleton onto the wearer's.
##
## Ordinary Procrustes over the origins of every bone the two share, restricted to
## uniform scale plus translation -- no rotation, because both rigs rest in the same
## A-pose and a fitted rotation there is noise being dignified.
##
## Fitted in RAW skeleton units on both sides, which is what makes it unit-agnostic:
## the scale factor is a ratio of two spreads, so a rig authored in centimetres and a
## rig authored in metres produce the same answer with a factor of 100 sitting inside
## `s` where it belongs. Valenfeld's version threads each rig's root scale through to
## reach real-world space first; it does not need to, and not needing to is one less
## number that can be wrong.
##
## Uniform, not per-axis. A per-axis fit would match each body's proportions more
## closely and would also shear every rigid buckle, pauldron and boot cap on a plate
## suit into a parallelogram. The residual -- a suit slightly too lean on the
## Stoneborn, who is broader than his height says -- is what the per-set `fit` rows
## exist for in Valenfeld, and it is a tuning knob, not a correctness problem.
static func _fit_map(src: Skeleton3D, dst: Skeleton3D, skin: Skin) -> Transform3D:
	var a: Array[Vector3] = []
	var b: Array[Vector3] = []
	var seen := {}
	for i in skin.get_bind_count():
		var bone := _bind_name(skin, i, dst)
		if bone == "" or seen.has(bone):
			continue
		var si := src.find_bone(bone)
		var di := dst.find_bone(bone)
		if si < 0 or di < 0:
			continue
		seen[bone] = true
		a.append(src.get_bone_global_rest(si).origin)
		b.append(dst.get_bone_global_rest(di).origin)
	if a.size() < 2:
		return Transform3D.IDENTITY

	var ca := Vector3.ZERO
	var cb := Vector3.ZERO
	for p in a:
		ca += p
	for p in b:
		cb += p
	ca /= float(a.size())
	cb /= float(b.size())
	var sa := 0.0
	var sb := 0.0
	for i in a.size():
		sa += (a[i] - ca).length_squared()
		sb += (b[i] - cb).length_squared()
	var s := 1.0 if sa <= 1e-9 else sqrt(sb / sa)
	return Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), cb - ca * s)


## Cut a body mesh down to the head, and hand back the original so it can be put
## back when the suit comes off.
##
## A triangle survives if EVERY corner of it belongs to the head (dominant weight,
## `HEAD_BONES`), which is the conservative direction: a triangle spanning the jaw
## and the neck is dropped, so the cut edge sits a millimetre high rather than
## leaving a ring of throat outside the collar.
##
## Vertices are kept whole and only the index list is filtered. Rebuilding the vertex
## arrays would mean re-indexing the bone and weight arrays alongside them, and an
## orphaned vertex costs nothing but the four bytes it already occupied.
static func cut_to_head(mi: MeshInstance3D) -> ArrayMesh:
	if mi == null or mi.mesh == null:
		return null
	var head := ArrayMesh.new()
	for s in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(s)
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		if bones.is_empty() or idx.is_empty():
			continue
		var per := bones.size() / (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var on_head := {}
		var keep := PackedInt32Array()
		for t in idx.size() / 3:
			var ok := true
			for c in 3:
				var v := idx[t * 3 + c]
				if not on_head.has(v):
					var best := -1
					var bw := -1.0
					for j in per:
						if weights[v * per + j] > bw:
							bw = weights[v * per + j]
							best = bones[v * per + j]
					on_head[v] = best
				if not _is_head(mi, on_head[v]):
					ok = false
					break
			if ok:
				keep.append(idx[t * 3]); keep.append(idx[t * 3 + 1]); keep.append(idx[t * 3 + 2])
		if keep.is_empty():
			continue
		arr[Mesh.ARRAY_INDEX] = keep
		head.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		head.surface_set_material(head.get_surface_count() - 1, mi.mesh.surface_get_material(s))
	return head if head.get_surface_count() > 0 else null


## Is bind slot `b` of this mesh's skin one of the head bones? Resolved through the
## SKIN rather than the skeleton, because a vertex's `ARRAY_BONES` entry indexes the
## skin's bind list, not the skeleton's bone list, and the two agree only by accident.
static func _is_head(mi: MeshInstance3D, b: int) -> bool:
	if mi.skin == null or b < 0 or b >= mi.skin.get_bind_count():
		return false
	return String(mi.skin.get_bind_name(b)) in HEAD_BONES


## A bind's bone name, with the glTF importer's `_N` uniquifying suffix taken back
## off when the stripped name is a real bone and the suffixed one is not. Valenfeld
## fixes this at the same seam and for the same reason: a bind that names no bone is
## not an error anywhere, it is a region of the mesh that silently stops deforming.
static func _bind_name(skin: Skin, b: int, dst: Skeleton3D) -> String:
	var n := String(skin.get_bind_name(b))
	if n == "" or dst == null or dst.find_bone(n) >= 0:
		return n
	var us := n.rfind("_")
	if us > 0 and us < n.length() - 1 and n.substr(us + 1).is_valid_int() \
			and dst.find_bone(n.substr(0, us)) >= 0:
		return n.substr(0, us)
	return n


static func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _find_skel(c)
		if s != null:
			return s
	return null


static func _skinned(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var mi := n as MeshInstance3D
	if mi != null and mi.mesh != null and mi.skin != null:
		out.append(mi)
	for c in n.get_children():
		out.append_array(_skinned(c))
	return out
