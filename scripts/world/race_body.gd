class_name RaceBody
extends Node3D
## A person from one of the Vale's peoples, standing where you left them.
##
## The garrison used to be staffed by tapered prisms with a lantern glued on.
## That was the right call while the loop was being built -- a nearly-good
## stand-in invites you to fix the model instead of the game -- but the loop
## works now, and three boxes are what the garrison looks like to somebody who
## has just walked out of a dungeon full of actual monsters.
##
## The bodies come from the Valenfeld pack (`assets/characters/races/`), which is
## where the races themselves come from: Stoneborn, Reshi and Vyr are peoples
## with lore attached, and each one keeps the counter its people would keep. See
## `Npc.COUNTERS` for which stands behind what, and why.
##
## **All of them are the same 24-bone rig.** That is the whole reason this file
## is short: one shared clip library (`_humanoid_anims.glb`) drives every body,
## so a fourth race is a row in `RACES` and nothing else.

## Where the bodies and the one shared clip set live.
const DIR := "res://assets/characters/races/"
const ANIMS := DIR + "_humanoid_anims.glb"
## Clothes. Same 24-bone rig as the bodies, which is the only reason `wear()`
## is eight lines instead of a character-assembly system.
const GARMENTS := "res://assets/characters/garments/"
## The pieces an outfit is made of, in the order they go on. There is no head
## piece: the pack's cloth hood sits badly on the Reshi's muzzle and the Vyr's
## crown, and a shopkeeper you cannot see the face of is a shopkeeper you have
## no reason to remember.
const OUTFIT: Array[String] = ["legs", "feet", "chest"]

## The peoples, and how tall each stands.
##
## `height` is METRES, measured to the crown, and it is the only scale input --
## the GLBs come out of the pack at assorted native sizes, so the body is fitted
## by measuring its own AABB (`_native_height`) rather than by a magic factor
## that goes stale the first time one is re-exported.
##
## The numbers are this repo's 1.72 m adult times each race's height multiplier
## from Valenfeld's own `races.json` appearance block (stoneborn 0.82, reshi
## 0.96, vyr 1.06). They are not decoration: the hero is 1.65 m (`K.HERO_H`), so
## the smith reads a clear head SHORT of you and the alchemist a clear head
## TALL, which is the fastest way to say "these are different peoples" without
## anybody saying it.
##
## No tint column, deliberately. Valenfeld tints one shared mesh per race; these
## GLBs each ship their own baked race texture, so tinting them again would only
## dirty a skin that is already the right colour.
##
## `static var`, not `const`: nothing here needs to be a constant expression,
## and a const Dictionary indexes as Variant, which the static typing then has
## to fight (CLAUDE.md §3).
static var RACES := {
	# Short, slab-built, and the best forges north of the river.
	"stoneborn": {"glb": "stoneborn_male_base.glb", "height": 1.41},
	# Tawny caravan blood: road-traders, fences, and the Driftmarket stalls.
	"reshi": {"glb": "reshi_male_base.glb", "height": 1.65},
	# A head over any settler, gold-skinned, born seeing the flaw in the drawing.
	"vyr": {"glb": "vyr_female_base.glb", "height": 1.82},
}

## The clips lifted out of the shared library, and nothing else.
##
## The pack ships about eighty -- every attack, roll and death a whole action
## game needs. A shopkeeper needs to stand there, so pulling the lot would mean
## retargeting eighty clips per body at load for the four we play.
##
## **The standing idle family only, and that is a constraint, not a shortlist.**
## Dropping the position tracks (see `_shared_lib`) is what lets one clip set fit
## three differently-sized bodies, but it also throws away the Hips track -- and
## any clip whose author moved the hips is now missing its ground contact. The
## action poses were rendered by `race_lookdev.gd` and `cast_buff` floats a good
## hand's width off the flagstones for exactly that reason. The four idles below
## keep the hips still, so they are the four that survive the trade. Anything
## with root motion needs the position track kept and re-scaled, which is a
## different feature than "the shopkeepers should not be boxes".
##
## They differ enough to tell apart at counter distance, and `Npc.LOOKS` gives
## each role its own, so the smith and the alchemist are not breathing in sync.
const CLIPS: Array[StringName] = [&"idle", &"idle3", &"idle4", &"idle9"]

## Radians the imported art is turned away from the body it hangs on.
##
## MEASURED, not derived (docs/CONTRACT.md §2.5, and the fourth time this
## project has paid for guessing). It is ZERO, and the reason is worth writing
## down because the neighbouring file uses the opposite number:
##
##   * The pack's bodies are modelled looking down **+Z**.
##   * `npc.gd` turns a shopkeeper with `rotation.y = atan2(to.x, to.z)`, and a
##     yaw of θ sends **+Z** to (sin θ, 0, cos θ) -- so the body's +Z is what
##     ends up pointing at the player. That is heading convention (CLAUDE.md
##     §4), not the -basis.z forward convention.
##
## Art +Z and holder +Z agree, so the correction is nothing. `enemy.gd` needs
## `PI` for the same art because it turns its bodies the OTHER way
## (`rotation.y = heading + PI`); the offsets differ because the holders differ,
## not because the art does. The first cut of this file copied the PI across and
## the whole garrison stood with its back to the customer -- `race_lookdev.gd`
## is the render that caught it, and the render is the only thing that can.
const MODEL_YAW := 0.0

## Metres, crown to floor, after fitting. Read by anything that has to put
## something at head height -- the name sign, the lamp.
var height: float = 1.7

var _rig: Node3D
var _anim: AnimationPlayer
var _skel: Skeleton3D


## Build a body for `race`, or null if the pack has no such people.
##
## Static factory rather than `new()` + `setup()`: a half-built rig that failed
## to find its GLB is a node you can still add to the tree and never notice.
static func make(race: String) -> RaceBody:
	var body := RaceBody.new()
	if not body._setup(race):
		body.free()
		return null
	return body


## Dress the body in one fabric, tinted.
##
## The pack's cloth pieces are skinned to the SAME 24-bone rig as the bodies, so
## dressing somebody is not a fitting problem -- it is moving one mesh under
## this body's own `Skeleton3D` and letting the named skin bind resolve against
## it by bone name. The garment then deforms with every clip for free, which is
## the whole reason to do it this way rather than hanging static geometry off
## the chest and watching it stay behind when the body moves.
##
## `tint` multiplies the fabric's own texture rather than replacing it: a flat
## albedo would throw away the weave and give three shopkeepers in coloured
## plastic. The three tints are the robe colours the box placeholders already
## used, so the garrison's palette does not move just because the people did.
func wear(fabric: String, tint: Color) -> void:
	if _skel == null:
		return
	for piece in OUTFIT:
		var path := "%s%s_%s.glb" % [GARMENTS, piece, fabric]
		if not ResourceLoader.exists(path):
			push_warning("race_body: no %s in %s" % [piece, fabric])
			continue
		var inst := (load(path) as PackedScene).instantiate()
		var mi := _first_mesh(inst)
		if mi == null:
			push_warning("race_body: %s has no mesh" % path)
			inst.queue_free()
			continue
		mi.get_parent().remove_child(mi)
		# Its owner is still the garment GLB's root, which we are about to throw
		# away; leaving it set makes Godot warn about an inconsistent owner on
		# every piece of clothing in the garrison.
		mi.owner = null
		_skel.add_child(mi)
		# Identity, deliberately: the garment's vertices are authored in the same
		# space as the body's, so the skeleton it now hangs on is the only
		# transform it should be getting. Anything inherited from its own GLB's
		# Armature would apply the unit conversion a second time.
		mi.transform = Transform3D.IDENTITY
		mi.skeleton = ^".."
		for s in mi.get_surface_override_material_count():
			var m := mi.mesh.surface_get_material(s)
			if m == null:
				continue
			var dup := m.duplicate() as StandardMaterial3D
			if dup == null:
				continue
			dup.albedo_color = tint
			# The garrison is lit by torches and one cold moon; a specular
			# highlight on homespun reads as wet plastic (STYLEGUIDE §4).
			dup.roughness = 1.0
			dup.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			mi.set_surface_override_material(s, dup)
		inst.queue_free()


## Play a clip by name, looping. Unknown names are ignored rather than fatal:
## a role that asks for a clip this pack does not carry should stand there, not
## take the garrison down with it.
func play(clip: StringName) -> void:
	if _anim == null or not _anim.has_animation(clip):
		return
	_anim.play(clip)


func _setup(race: String) -> bool:
	var row: Dictionary = RACES.get(race, {})
	if row.is_empty():
		push_error("race_body: no such people as '%s' (have %s)" % [race, RACES.keys()])
		return false

	var path: String = DIR + str(row["glb"])
	if not ResourceLoader.exists(path):
		push_error("race_body: no body at %s" % path)
		return false

	_rig = (load(path) as PackedScene).instantiate() as Node3D
	_rig.rotation.y = MODEL_YAW
	add_child(_rig)

	_skel = _rig.find_child("Skeleton3D", true, false) as Skeleton3D
	_anim = _rig.find_child("AnimationPlayer", true, false) as AnimationPlayer

	height = float(row["height"])
	var native := _native_height(_rig, _skel)
	if native > 0.001:
		_rig.scale = Vector3.ONE * (height / native)

	_install_clips()
	return true


# --- The shared clip library ------------------------------------------------
#
# Loaded and cooked ONCE for the whole game, then re-based per body. Both caches
# are static because the cooking is the expensive half and the result does not
# depend on who asked.

static var _lib: AnimationLibrary = null
static var _src_rest: Dictionary = {}


## Every wanted clip, ROTATION ONLY, keyed by name.
##
## The position and scale tracks are dropped on the way in, and that is the
## load-bearing line in this file. The pack baked absolute bone positions at the
## 1.8 m human rig it was authored on; played on a 1.41 m Stoneborn those keys
## do not scale him, they RESIZE him -- the body snaps back to human proportions
## the moment the clip starts, and the careful height fitting above evaporates
## on frame one. Rotations carry no length, so one clip set fits every body and
## each keeps its own size.
static func _shared_lib() -> AnimationLibrary:
	if _lib != null:
		return _lib
	_lib = AnimationLibrary.new()
	var packed := load(ANIMS) as PackedScene
	if packed == null:
		push_error("race_body: shared clips missing at %s -- bodies will stand in bind pose" % ANIMS)
		return _lib

	var inst := packed.instantiate()
	var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var sk := inst.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk != null:
		for i in sk.get_bone_count():
			_src_rest[sk.get_bone_name(i)] = sk.get_bone_rest(i).basis.get_rotation_quaternion()
	if ap != null:
		for clip in CLIPS:
			if not ap.has_animation(clip):
				push_warning("race_body: shared clips have no '%s'" % clip)
				continue
			var a: Animation = ap.get_animation(clip).duplicate(true)
			for t in range(a.get_track_count() - 1, -1, -1):
				var tt := a.track_get_type(t)
				if tt == Animation.TYPE_POSITION_3D or tt == Animation.TYPE_SCALE_3D:
					a.remove_track(t)
			# Everything here is a standing loop for somebody minding a shop;
			# the GLB import leaves loop_mode NONE, which would leave each of
			# them frozen on their last frame a second after the garrison loads.
			a.loop_mode = Animation.LOOP_LINEAR
			_lib.add_animation(clip, a)
	else:
		push_error("race_body: no AnimationPlayer in %s" % ANIMS)
	inst.queue_free()
	return _lib


## Put the shared clips on THIS body, re-pointed and re-based.
##
## Two corrections, and skipping either one is a silent wrong-looking person
## rather than an error:
##
##  * **Re-point.** The clips were exported against the library GLB's node tree,
##    where the skeleton sits at some path of its own. This body's skeleton is
##    somewhere else, and a track aimed at a node that is not there drives
##    nothing at all -- you get a bind-pose statue and no complaint from Godot.
##
##  * **Re-base.** Same bone names and same hierarchy, but every body in the
##    pack was auto-rigged in its OWN rest pose. A key is an absolute local
##    rotation, so replaying the human's keys on the Stoneborn's rest puts him
##    in the human's shape -- shoulders hunched, arms splayed. Per bone,
##    `key' = (this_rest * source_rest⁻¹) · key` keeps the rotation the clip ADDS
##    beyond rest and throws away the rest it assumed.
func _install_clips() -> void:
	if _anim == null or _skel == null:
		push_error("race_body: body has no %s" % ("Skeleton3D" if _skel == null else "AnimationPlayer"))
		return
	var lib := _shared_lib()
	var anim_root := _anim.get_node_or_null(_anim.root_node) as Node
	if anim_root == null:
		push_error("race_body: AnimationPlayer root missing -- cannot bind clips")
		return
	var skel_path := String(anim_root.get_path_to(_skel))

	# The GLB ships its own one-clip stub library under the same empty name, and
	# Godot refuses a second: "Can't add animation library twice with name: ''".
	if _anim.has_animation_library(&""):
		_anim.remove_animation_library(&"")
	var dst := AnimationLibrary.new()
	for clip in lib.get_animation_list():
		var a: Animation = lib.get_animation(clip).duplicate(true)
		for t in a.get_track_count():
			var bone := String(a.track_get_path(t).get_concatenated_subnames())
			a.track_set_path(t, NodePath(skel_path + ":" + bone))
			if a.track_get_type(t) != Animation.TYPE_ROTATION_3D:
				continue
			var bi := _skel.find_bone(bone)
			if bi < 0 or not _src_rest.has(bone):
				continue
			var tgt: Quaternion = _skel.get_bone_rest(bi).basis.get_rotation_quaternion()
			var corr: Quaternion = tgt * (_src_rest[bone] as Quaternion).inverse()
			if corr.is_equal_approx(Quaternion.IDENTITY):
				continue
			for k in a.track_get_key_count(t):
				a.track_set_key_value(t, k, corr * (a.track_get_key_value(t, k) as Quaternion))
		dst.add_animation(clip, a)
	_anim.add_animation_library(&"", dst)


## Crown height of the art as it ships, in `rig`'s own space.
##
## **Measure the BONES, never the mesh AABB.** That sentence cost a render loop,
## and it is not obvious, so here is the whole trap:
##
## The pack authors its skeletons in centimetres -- `head_end` sits at rest
## y ≈ 180.8 -- and converts to metres with a 0.01 scale on the `Armature` node
## above the skeleton. The MESH, meanwhile, ships with its vertices already in
## METRES (`mesh.get_aabb()` is 1.81 tall), and the skin's bind matrices carry
## the ×100 that maps it into bone space. So the two conversions cancel exactly
## at render time and the body draws 1.81 m tall -- correct, and by a route that
## no single node's transform describes.
##
## Which means a mesh-AABB measurement is wrong in a way that LOOKS right:
##
##   accumulate the 0.01 down to the mesh × the mesh's 1.81 m AABB = 0.018
##
## a "native height" of 1.8 cm, so the fit multiplied the rig by 78, and the
## garrison rendered as three hundred-metre giants standing outside the frame.
## The check that was supposed to catch it computed the crown the SAME wrong
## way, multiplied 0.78 by 1.81, printed a perfect "1.41 m", and confirmed the
## bug. Two errors, one cancellation, one very convincing number.
## `MeshInstance3D`'s `get_aabb()` is no help either -- for these bodies it
## returns the raw mesh bounds unchanged, skin and all.
##
## The bones do not lie: they are what the vertices are ultimately hung on, the
## whole pack shares the one 24-bone rig, and the rest pose is the T-pose every
## body ships in. So take the tallest bone rest and carry it up to `rig` space
## through whatever transforms sit in between.
static func _native_height(rig: Node3D, skel: Skeleton3D) -> float:
	if skel == null:
		return 0.0
	var top := 0.0
	for i in skel.get_bone_count():
		top = maxf(top, skel.get_bone_global_rest(i).origin.y)
	# Skeleton space -> rig space. `rig`'s own transform is deliberately left
	# out: the fit being computed here is what that transform is about to become.
	var to_rig := Transform3D.IDENTITY
	var n: Node3D = skel
	while n != null and n != rig:
		to_rig = n.transform * to_rig
		n = n.get_parent() as Node3D
	return (to_rig * Vector3(0.0, top, 0.0)).y


## The first MeshInstance3D anywhere under `n`. The cloth GLBs carry exactly one.
static func _first_mesh(n: Node) -> MeshInstance3D:
	var mi := n as MeshInstance3D
	if mi != null and mi.mesh != null:
		return mi
	for c in n.get_children():
		var found := _first_mesh(c)
		if found != null:
			return found
	return null
