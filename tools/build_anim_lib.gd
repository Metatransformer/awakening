extends SceneTree
## Merges every per-file Mixamo FBX animation into one AnimationLibrary.
##
## Every animation FBX in assets/animations/** carries a single clip named
## "mixamo_com" on the same 33-bone mixamorig skeleton as the hero, so no
## retargeting is needed — we just rename each clip to its filename and stack
## them into one library that AnimationTree can address as "ss_slash_01".
##
##   godot --path . --headless -s tools/build_anim_lib.gd
##
## Writes assets/animations/hero_anims.res

const SETS := {
	"ss": "res://assets/animations/sword_shield",
	"ex": "res://assets/animations/extra",
	"mg": "res://assets/animations/magic",
}
const OUT := "res://assets/animations/hero_anims.res"
## Clips that should loop when played. Everything else is one-shot.
const LOOPING := ["idle", "walk", "run", "strafe", "block_idle", "crouch_idle", "crouching"]


func _initialize() -> void:
	var lib := AnimationLibrary.new()
	var n := 0
	var failed: Array[String] = []

	for prefix in SETS:
		var dir_path: String = SETS[prefix]
		var dir := DirAccess.open(dir_path)
		if dir == null:
			push_warning("no such dir: %s" % dir_path)
			continue
		var files := dir.get_files()
		files.sort()
		for f in files:
			if not f.ends_with(".fbx"):
				continue
			var stem := f.get_basename()
			var anim := _extract(dir_path.path_join(f))
			if anim == null:
				failed.append(f)
				continue
			# Mixamo clips carry root motion in the hips; we drive position in
			# code, so the hips translation track would fight the controller.
			_strip_root_translation(anim)
			anim.loop_mode = (
				Animation.LOOP_LINEAR if _is_looping(stem) else Animation.LOOP_NONE
			)
			# "/" is reserved as the library/animation separator, so sets are
			# namespaced with an underscore: "ss_slash_01".
			lib.add_animation("%s_%s" % [prefix, stem], anim)
			n += 1

	var err := ResourceSaver.save(lib, OUT)
	print("ANIMS=%d SAVED=%s err=%d" % [n, OUT, err])
	if not failed.is_empty():
		print("FAILED: ", failed)
	quit(0 if err == OK else 1)


func _extract(path: String) -> Animation:
	if not ResourceLoader.exists(path):
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var root := ps.instantiate()
	var ap := _find_ap(root)
	var out: Animation = null
	if ap:
		for name in ap.get_animation_list():
			var a := ap.get_animation(name)
			if a and a.length > 0.05:
				out = a.duplicate(true)
				break
	root.queue_free()
	return out


## Remove the hips XZ translation so clips play in place; the CharacterBody3D
## owns horizontal position. Vertical hip motion is kept — it is what gives
## jumps and attack lunges their weight.
func _strip_root_translation(anim: Animation) -> void:
	for i in anim.get_track_count():
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		var p := str(anim.track_get_path(i))
		if not p.ends_with(":mixamorig_Hips"):
			continue
		for k in anim.track_get_key_count(i):
			var v: Vector3 = anim.track_get_key_value(i, k)
			anim.track_set_key_value(i, k, Vector3(0.0, v.y, 0.0))


func _is_looping(stem: String) -> bool:
	for tag in LOOPING:
		if stem.begins_with(tag):
			return true
	return false


func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_ap(c)
		if r:
			return r
	return null
