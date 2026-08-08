extends Node
## Prints the two things a combat builder cannot guess: the exact animation
## names in the merged hero library, and the exact bone names on the rig that a
## weapon socket can attach to.
##
##   godot --path . --headless res://tools/scenes/_rig_facts.tscn

func _ready() -> void:
	var lib: AnimationLibrary = load("res://assets/animations/hero_anims.res")
	var names: Array[StringName] = lib.get_animation_list()
	print("=== hero_anims.res : %d clips ===" % names.size())
	for n in names:
		var a := lib.get_animation(n)
		print("  %-34s %5.2fs  loop=%s" % [n, a.length, a.loop_mode != Animation.LOOP_NONE])

	var rig: Node3D = (load("res://assets/characters/hero.fbx") as PackedScene).instantiate() as Node3D
	add_child(rig)
	var skel := rig.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		print("no Skeleton3D")
		get_tree().quit(1)
		return
	print("\n=== skeleton : %d bones ===" % skel.get_bone_count())
	for i in skel.get_bone_count():
		var bn := skel.get_bone_name(i)
		# Hands, forearms and the spine are the only sockets a weapon needs.
		if bn.containsn("hand") or bn.containsn("forearm") or bn.containsn("spine"):
			var rest := skel.get_bone_global_rest(i)
			print("  [%2d] %-28s rest %v" % [i, bn, rest.origin])
	get_tree().quit(0)
