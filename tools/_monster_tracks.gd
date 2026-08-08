extends Node
## Which skeleton is monster_library.res actually authored against?
##
## The monster GLBs come in TWO bone-naming families — "Hips/LeftUpLeg/..." and
## "Hips/Spine02/Spine01/neck/..." — so a shared library can only fit one of
## them. Binding it to the other silently produces a motionless T-pose, which
## reads as "the animation did not play" and sends you debugging the wrong
## thing. Print the library's track paths and compare.

func _ready() -> void:
	var lib := load("res://assets/animations/monster_library.res") as AnimationLibrary
	var anim := lib.get_animation(&"idle")
	print("=== monster_library 'idle' : %d tracks ===" % anim.get_track_count())
	for i in mini(anim.get_track_count(), 12):
		print("  ", anim.track_get_path(i))

	for id in ["skeleton", "goblin"]:
		var root := (load("res://assets/monsters/%s.glb" % id) as PackedScene).instantiate() as Node3D
		add_child(root)
		var skel := root.find_child("Skeleton3D", true, false) as Skeleton3D
		var names: Array = []
		for i in skel.get_bone_count():
			names.append(skel.get_bone_name(i))
		print("\n[%s] path=%s" % [id, root.get_path_to(skel)])
		print("   bones: ", names)
		var ap := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
		for clip in ap.get_animation_list():
			var a := ap.get_animation(clip)
			print("   clip '%s' %.2fs tracks=%d first=%s" % [
				clip, a.length, a.get_track_count(),
				a.track_get_path(0) if a.get_track_count() > 0 else "-"])
		root.queue_free()
	get_tree().quit(0)
