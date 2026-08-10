class_name NpcBody
extends Node3D
## One of the five AUTHORED people in the garrison -- a body that arrived already
## dressed, and is not allowed anywhere near the clothing system.
##
## `RaceBody` builds a shopkeeper out of parts: a bare race base from the
## Valenfeld pack plus a suit seated onto its skeleton, tinted so three people in
## the same cloth are still three people. That is the right machine for a pack of
## interchangeable bases, and it is exactly the wrong machine for these five. The
## smith, the pawnbroker, the Lanternkeeper, the jewelcrafter and the alchemist
## were each modelled as a whole person, dressed, with their buckles and
## their beard painted into one atlas. There is no bare body underneath to seat a
## suit onto, no normalised UV layout for a garment to share, and no seam that a
## fitting pass could close. **Do not call anything in `SuitSeater` on these.**
##
## What they cost instead is a retarget, and that is the whole of this file. The
## pack's idle clips are authored on a 24-bone Mixamo-named rig in a T-pose;
## these are 41-bone Tripo rigs in an A-pose with different bone names, a
## different spine order and their own bone rolls. `_install_clips` maps one onto
## the other exactly (see the derivation there) so the garrison still breathes.
##
## `Npc.LOOKS` picks the body. The elder is still built by `RaceBody`, and that
## is not a transitional state waiting for a sixth model -- the two systems
## answer different questions and both are wanted. `RaceBody` is also what the
## dungeon and the monster roster run on, so it does not go anywhere.

const DIR := "res://assets/characters/npc/"
## The clip library, shared with `RaceBody`. Same four idles, same reason: these
## people stand at a counter, so a standing loop is the entire animation budget.
const ANIMS := "res://assets/characters/races/_humanoid_anims.glb"
const CLIPS: Array[StringName] = [&"idle", &"idle3", &"idle4", &"idle9"]

## Radians the imported art is turned away from the body it hangs on.
##
## ZERO, and **measured** (docs/CONTRACT.md §2.5, and this project has paid for
## guessing it four times). `tools/directors/npc_raw.gd` puts them all in front
## of a camera on +Z and they look back at it: the art is modelled facing +Z.
## `Npc` turns a shopkeeper with `_body.global_rotation.y = atan2(to.x, to.z)`,
## which sends +Z to the player, so art and holder already agree and the
## correction is nothing. Same number and same reasoning as `RaceBody.MODEL_YAW`
## -- and `enemy.gd` still needs `PI` for the same art, because it turns its
## bodies the other way.
const MODEL_YAW := 0.0

## Who each body is, and how tall they stand.
##
## `height` is METRES to the crown and it is the only scale input. They all import
## normalised into a unit box (Tripo does that, and `npc_raw.gd` measured it:
## every one is 0.998047 tall), so the fit is very nearly a straight multiply --
## but it is still measured per body in `_native_height`, because "they all
## happen to be 1.0 right now" is a fact about four files, not a contract.
##
## The numbers do the same work heights have always done here (`RaceBody.RACES`):
## the hero is 1.65 m, so the smith reads a clear head SHORT of you and the
## Lanternkeeper a little over. Read the garrison as a row and it steps --
## smith 1.44, jewelcrafter 1.63, elder 1.65, pawnbroker 1.72, keeper 1.74,
## alchemist 1.82 -- which is six people, not one body at six sizes.
##
## `static var`, not `const`: nothing here needs to be a constant expression, and
## a const Dictionary indexes as Variant (CLAUDE.md §3).
static var PEOPLE := {
	# The dwarf. Short and twice as wide as anyone else in the yard, which is the
	# silhouette the forge wants and the reason he keeps roughly the Stoneborn's
	# 1.41 he replaced rather than growing into the gap.
	"smith": {"fbx": "smith.fbx", "height": 1.44},
	"pawnbroker": {"fbx": "pawnbroker.fbx", "height": 1.72},
	# Hooded, and the tallest of the four. The Far Lantern is the strange counter
	# and she should read that way from across the flagstones.
	"lanternkeeper": {"fbx": "lanternkeeper.fbx", "height": 1.74},
	"jewelcrafter": {"fbx": "jewelcrafter.fbx", "height": 1.63},
	# The tallest person in the yard, and she keeps the 1.82 she had as a Vyr --
	# the height was doing work (she looks DOWN at you over the alembics) and the
	# model arriving is no reason to renegotiate it.
	"alchemist": {"fbx": "alchemist.fbx", "height": 1.82},
}

## The retarget map: **this rig's bone -> `[the clip library's bone, the bone to
## measure this one's direction against]`**.
##
## Written out rather than guessed from the names, because the names lie in two
## places and both would have produced a person folded in half:
##
##   * The library's spine runs `Hips -> Spine02 -> Spine01 -> Spine`, LOWEST
##     first, so its `Spine` is the CHEST -- the bone the shoulders hang off. This
##     rig's spine runs `Hip -> Waist -> Spine01 -> Spine02`, HIGHEST last, so its
##     `Spine02` is the chest. Matching `Spine01` to `Spine01` is the one pairing
##     here that is right by accident; matching `Spine02` to `Spine02` would have
##     tied the chest to the belly.
##   * `Pelvis`, `Root` and the eighteen `*Twist*` bones have no opposite number
##     and are deliberately absent. **An unmapped bone is not a hole.** It keeps
##     its rest pose relative to its parent, which means it rigidly inherits
##     whatever its nearest mapped ancestor is doing -- a forearm twist follows
##     the forearm, `Pelvis` follows `Hip`, and that is exactly what those bones
##     are for.
##
## The map is chain-preserving, and `_install_clips` is only exact because it is:
## for every bone here, its nearest mapped ancestor on THIS rig maps to the bone
## that is its opposite number's parent on that one. Adding a row that breaks
## that (mapping a hand without its forearm, say) silently bends the arm from the
## wrong joint. Check the chain before adding one.
##
## **The second column is the rest fix, and without it the retarget is wrong in a
## way that renders.** These bodies are A-posed with the elbows already bent; the
## library is a flat T-pose. A retarget that preserves the rotation a clip ADDS
## adds the idle's own bend on top of the bend that is already in the rest, and
## `npc_lookdev.gd` photographed the result: the smith and the Lanternkeeper
## stood with their forearms folded up under their chins while the other two,
## whose rests happen to be straighter, looked fine. Four bodies, one clip, four
## different wrong answers -- which is the signature of a rest-pose problem and
## not of a bad clip.
##
## So each bone names the bone AFTER it, and `_corrected_rests` turns
## "here to there" on this rig until it points where "here to there" points on
## the library rig. That is a direction, measured off both rest poses, so it
## carries no assumption about bone rolls or naming.
##
## `""` means **no fix: inherit the parent's**. It is on the three tips of every
## chain -- `Head`, the hands, the toes -- because a tip has nothing after it to
## aim at, and because the wrist and neck angles are a matter of each pack's taste
## rather than a pose difference. `Hip` aims at `Spine01` and not at `Waist`, its
## real child, because `Waist` sits at the same point to within 60 microns and a
## direction between coincident joints is noise.
static var BONES := {
	"Hip": ["Hips", "Spine01"],
	"Waist": ["Spine02", "Spine01"],
	"Spine01": ["Spine01", "Spine02"],
	"Spine02": ["Spine", "NeckTwist01"],
	"NeckTwist01": ["neck", "Head"],
	"Head": ["Head", ""],
	"L_Clavicle": ["LeftShoulder", "L_Upperarm"],
	"L_Upperarm": ["LeftArm", "L_Forearm"],
	"L_Forearm": ["LeftForeArm", "L_Hand"],
	"L_Hand": ["LeftHand", ""],
	"R_Clavicle": ["RightShoulder", "R_Upperarm"],
	"R_Upperarm": ["RightArm", "R_Forearm"],
	"R_Forearm": ["RightForeArm", "R_Hand"],
	"R_Hand": ["RightHand", ""],
	"L_Thigh": ["LeftUpLeg", "L_Calf"],
	"L_Calf": ["LeftLeg", "L_Foot"],
	"L_Foot": ["LeftFoot", "L_ToeBase"],
	"L_ToeBase": ["LeftToeBase", ""],
	"R_Thigh": ["RightUpLeg", "R_Calf"],
	"R_Calf": ["RightLeg", "R_Foot"],
	"R_Foot": ["RightFoot", "R_ToeBase"],
	"R_ToeBase": ["RightToeBase", ""],
}

## Metres, crown to floor, after fitting. Read by anything that has to put
## something at head height -- the name sign, the collision capsule.
var height: float = 1.7

var _rig: Node3D
var _skel: Skeleton3D
var _anim: AnimationPlayer
var _who: String = ""


## Build the body called `who`, or null if there is no such person.
##
## Static factory rather than `new()` + `setup()`, for `RaceBody.make`'s reason: a
## half-built rig that failed to find its art is a node you can still add to the
## tree and never notice is empty.
static func make(who: String) -> NpcBody:
	var body := NpcBody.new()
	if not body._setup(who):
		body.free()
		return null
	return body


## Play a clip by name, looping. Unknown names are ignored rather than fatal: a
## role that asks for a clip this library does not carry should stand there, not
## take the garrison down with it.
func play(clip: StringName) -> void:
	if _anim == null or not _anim.has_animation(clip):
		return
	_anim.play(clip)


## Hold one frame of a clip, forever. For a body that is not a person: the
## `Statue` on the plaza is this rig in stone.
##
## It has to be a POSE and not the rest pose, which is the whole reason this
## exists. These rigs import in an A-pose with the arms out and the hands open;
## a statue left in it does not read as a carved figure, it reads as a character
## whose animation failed to load -- which is a bug this project has shipped
## before and would not be able to tell apart at a glance.
##
## `seek` with `update = true` applies the pose on the spot rather than at the
## next process tick, so a caller can freeze in `_ready` and a screenshot taken
## on the very next frame is already correct.
func hold(clip: StringName, at: float) -> void:
	if _anim == null or not _anim.has_animation(clip):
		return
	_anim.play(clip)
	_anim.seek(at, true)
	_anim.pause()


func _setup(who: String) -> bool:
	var row: Dictionary = PEOPLE.get(who, {})
	if row.is_empty():
		push_error("npc_body: nobody called '%s' (have %s)" % [who, PEOPLE.keys()])
		return false
	_who = who

	var path: String = DIR + str(row["fbx"])
	if not ResourceLoader.exists(path):
		push_error("npc_body: no body at %s" % path)
		return false

	_rig = (load(path) as PackedScene).instantiate() as Node3D
	_rig.rotation.y = MODEL_YAW
	add_child(_rig)

	_skel = _rig.find_child("Skeleton3D", true, false) as Skeleton3D
	_anim = _rig.find_child("AnimationPlayer", true, false) as AnimationPlayer

	height = float(row["height"])
	var native := _native_height(_rig)
	if native > 0.001:
		_rig.scale = Vector3.ONE * (height / native)

	_install_clips()
	return true


## Crown height of the art as it ships, in `rig`'s own space.
##
## **Measure the MESH here, and note that `RaceBody` says the exact opposite.**
## Both are right, because the two packs are built differently and the reason is
## worth keeping:
##
##   * The Valenfeld bodies keep their bones in centimetres and their vertices in
##     metres, with a 0.01 on the Armature that cancels against the skin's bind
##     matrices. A mesh measurement there reproduces the same cancellation the
##     fitting code can get wrong, so it must go through the bones.
##   * These are one flat metre-scale rig with no conversion node anywhere --
##     `_npc_facts.gd` prints the crown identically in skeleton space and in rig
##     space -- so the mesh bounds are simply the truth.
##
## And the bones cannot be used here even if you wanted to: this rig's topmost
## bone is `Head`, sitting around y 0.845 with no `head_end` above it, while the
## skull draws up to 0.998. Fitting to the bones would make every one of them
## roughly 18% too tall, consistently, in a way that looks deliberate.
static func _native_height(rig: Node3D) -> float:
	var top := 0.0
	for c in _all(rig):
		var mi := c as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		# Mesh space -> rig space. `rig`'s own transform is left out: the fit being
		# computed here is what that transform is about to become.
		var to_rig := Transform3D.IDENTITY
		var n: Node3D = mi
		while n != null and n != rig:
			to_rig = n.transform * to_rig
			n = n.get_parent() as Node3D
		var box: AABB = to_rig * mi.mesh.get_aabb()
		top = maxf(top, box.position.y + box.size.y)
	return top


# --- The shared clip library ------------------------------------------------
#
# Loaded and read ONCE for the whole game. Static because the reading is the
# expensive half and the result does not depend on who asked.
#
# Deliberately its own cache rather than a call into `RaceBody._shared_lib`: that
# one keeps LOCAL rest rotations, which is all its own re-base needs, and the
# retarget below needs GLOBAL rests and the parent of every bone. One extra
# instantiate at first garrison load, freed on the spot, in exchange for the two
# files not reaching into each other.

## `{"clips": {name: Animation}, "rest": {bone: Quaternion}, "up": {bone:
## Quaternion}, "at": {bone: Vector3}}` -- per source bone, its global rest
## rotation, its PARENT's (identity at the root), and where it sits in the rest
## pose. The positions are only ever used as directions between two bones, so the
## library's centimetres never have to be reconciled with this rig's metres.
static var _src: Dictionary = {}


static func _source() -> Dictionary:
	if not _src.is_empty():
		return _src
	_src = {"clips": {}, "rest": {}, "up": {}, "at": {}}
	var packed := load(ANIMS) as PackedScene
	if packed == null:
		push_error("npc_body: shared clips missing at %s -- bodies will stand in bind pose" % ANIMS)
		return _src

	var inst := packed.instantiate()
	var sk := inst.find_child("Skeleton3D", true, false) as Skeleton3D
	var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if sk != null:
		for i in sk.get_bone_count():
			var name := sk.get_bone_name(i)
			var p := sk.get_bone_parent(i)
			var rest := sk.get_bone_global_rest(i)
			_src["rest"][name] = rest.basis.get_rotation_quaternion()
			_src["at"][name] = rest.origin
			_src["up"][name] = (sk.get_bone_global_rest(p).basis.get_rotation_quaternion()
				if p >= 0 else Quaternion.IDENTITY)
	if ap != null:
		for clip in CLIPS:
			if not ap.has_animation(clip):
				push_warning("npc_body: shared clips have no '%s'" % clip)
				continue
			_src["clips"][clip] = ap.get_animation(clip)
	else:
		push_error("npc_body: no AnimationPlayer in %s" % ANIMS)
	inst.queue_free()
	return _src


## This rig's rest pose, turned into the pose the clips were authored against.
##
## Returns every bone's corrected GLOBAL rest rotation, by name. Nothing is
## written back to the `Skeleton3D` -- an unanimated body still stands in the
## A-pose it shipped in, which is what you want when you are looking at the raw
## art. This is the rest the KEYS are computed against.
##
## The rule, per bone:
##
##   * A bone with a tip in `BONES` gets turned, in world space, by the shortest
##     rotation that takes "me to my tip" on this rig onto "me to my tip" on the
##     library rig. Shortest, so it introduces no roll of its own and the body's
##     own bone rolls survive -- setting the rest outright to the library's would
##     have been one line shorter and would have corkscrewed every upper arm 90°,
##     because the two packs disagree about which way a bone's X points.
##   * Everything else -- the tips themselves, and all eighteen twist bones and
##     `Pelvis` and `Root` -- keeps its rest relative to its parent, so it rides
##     along with whatever correction landed above it.
##
## Recursive with a memo rather than a loop over bone indices: Godot's importers
## do usually emit parents before children, but "usually" is not a thing to build
## a rest pose on, and a parent read before it was corrected is a limb that is
## subtly wrong in one body out of four.
func _corrected_rests() -> Dictionary:
	var src := _source()
	var out := {}
	for i in _skel.get_bone_count():
		_correct(i, src, out)
	return out


func _correct(i: int, src: Dictionary, out: Dictionary) -> Quaternion:
	var bone := _skel.get_bone_name(i)
	if out.has(bone):
		return out[bone]
	var rest := _skel.get_bone_global_rest(i)
	var p := _skel.get_bone_parent(i)
	var row: Array = BONES.get(bone, [])
	var tip := str(row[1]) if row.size() > 1 else ""

	var q: Quaternion
	if tip != "" and _skel.find_bone(tip) >= 0 and BONES.has(tip):
		var here: Vector3 = rest.origin
		var there: Vector3 = _skel.get_bone_global_rest(_skel.find_bone(tip)).origin
		var s_here: Vector3 = src["at"].get(str(row[0]), Vector3.ZERO)
		var s_there: Vector3 = src["at"].get(str(BONES[tip][0]), Vector3.ZERO)
		var mine := (there - here).normalized()
		var theirs := (s_there - s_here).normalized()
		# A degenerate pair means two coincident joints and no direction to read;
		# leave the bone alone rather than turning it by a rounding error.
		if mine.length_squared() < 0.5 or theirs.length_squared() < 0.5:
			q = rest.basis.get_rotation_quaternion()
		else:
			q = Quaternion(mine, theirs) * rest.basis.get_rotation_quaternion()
	elif p >= 0:
		q = _correct(p, src, out) * _skel.get_bone_rest(i).basis.get_rotation_quaternion()
	else:
		q = rest.basis.get_rotation_quaternion()
	out[bone] = q
	return q


## Put the shared idles on THIS body, retargeted.
##
## The two rigs share nothing: 24 bones against 41, Mixamo names against Tripo
## names, a T-pose rest against an A-pose rest, and bone rolls that agree
## nowhere. `RaceBody` gets away with a one-line re-base (`this_rest *
## source_rest⁻¹` on the front of every key) because every body in ITS pack was
## auto-rigged from the same template and the correction is small. Used here it
## produces a person with their forearms folded up under their chin, because that
## formula quietly assumes the two rigs' local bone axes agree.
##
## The exact version. Write `R(b)` for a bone's GLOBAL rest rotation and `p` for
## its parent. A clip key is a LOCAL rotation `L(b)`, and what the retarget has to
## preserve is not the local key -- it is the rotation the pose puts on the bone
## RELATIVE TO ITS PARENT in world terms, which is the same quantity on both rigs:
##
##     X = R_src(p) · L_src · R_src(b)⁻¹
##
## Substituting that back on this side gives the key to write:
##
##     L_dst = R_dst(p)⁻¹ · R_src(p) · L_src · R_src(b)⁻¹ · R_dst(b)
##
## which is five multiplies per key and no sampling, no baking and no error. Note
## `R_dst(p)` is THIS rig's real parent -- often an unmapped bone like `Pelvis` --
## while `R_src(p)` is the opposite number's parent on the library rig. Those two
## are allowed to be different bones precisely because `BONES` is chain-preserving
## (see the note there); if it stops being, this stops being exact.
##
## **`R_dst` here is `_corrected_rests()`, never the skeleton's own.** Preserving
## the rotation a clip ADDS is only the right thing to preserve when both rigs
## start from the same pose, and these do not. See `_corrected_rests`.
##
## Two more things that are silent failures rather than errors if skipped:
##
##  * **Re-point.** The clips were exported against the library's node tree. A
##    track aimed at a node that is not in THIS tree drives nothing at all -- you
##    get a bind-pose statue and no complaint from Godot.
##  * **Loop.** The GLB import leaves `loop_mode` NONE, which freezes every
##    shopkeeper on their last frame a second after the garrison loads.
func _install_clips() -> void:
	if _anim == null or _skel == null:
		push_error("npc_body: %s has no %s" % [
			_who, "Skeleton3D" if _skel == null else "AnimationPlayer"])
		return
	var src := _source()
	var anim_root := _anim.get_node_or_null(_anim.root_node) as Node
	if anim_root == null:
		push_error("npc_body: AnimationPlayer root missing -- cannot bind clips")
		return
	var skel_path := String(anim_root.get_path_to(_skel))

	# This rig's corrected global rests, and each bone's PARENT's, by name.
	var dst_rest := _corrected_rests()
	var dst_up := {}
	for i in _skel.get_bone_count():
		var p := _skel.get_bone_parent(i)
		dst_up[_skel.get_bone_name(i)] = (dst_rest[_skel.get_bone_name(p)]
			if p >= 0 else Quaternion.IDENTITY)

	# Which source bone drives which track, keyed the way a track path reads.
	var from := {}
	for dst_bone in BONES:
		from[str((BONES[dst_bone] as Array)[0])] = dst_bone

	# The FBX ships its own one-clip stub library under the empty name, and Godot
	# refuses a second: "Can't add animation library twice with name: ''".
	if _anim.has_animation_library(&""):
		_anim.remove_animation_library(&"")

	var lib := AnimationLibrary.new()
	for clip in src["clips"]:
		var a: Animation = (src["clips"][clip] as Animation).duplicate(true)
		for t in range(a.get_track_count() - 1, -1, -1):
			var src_bone := String(a.track_get_path(t).get_concatenated_subnames())
			# Rotation only. A position key is an absolute bone offset measured on
			# the library's 1.8 m skeleton; replayed here it would not scale these
			# bodies, it would RESIZE them, and the height fitting above would
			# evaporate on frame one. Scale tracks go for the same reason.
			if a.track_get_type(t) != Animation.TYPE_ROTATION_3D or not from.has(src_bone):
				a.remove_track(t)
				continue
			var dst_bone: String = from[src_bone]
			a.track_set_path(t, NodePath(skel_path + ":" + dst_bone))
			var head: Quaternion = (dst_up[dst_bone] as Quaternion).inverse() * (src["up"][src_bone] as Quaternion)
			var tail: Quaternion = (src["rest"][src_bone] as Quaternion).inverse() * (dst_rest[dst_bone] as Quaternion)
			for k in a.track_get_key_count(t):
				a.track_set_key_value(t, k, head * (a.track_get_key_value(t, k) as Quaternion) * tail)
		a.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation(clip, a)
	_anim.add_animation_library(&"", lib)


static func _all(n: Node) -> Array[Node]:
	var out: Array[Node] = [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out
