extends Node3D
## Foundation smoke test: does the hero mesh render, and does the merged
## AnimationLibrary actually bind and drive his skeleton?
@export var clip: String = "ss_idle_01"

func _ready() -> void:
	var hero: Node3D = (load("res://assets/characters/hero.fbx") as PackedScene).instantiate()
	hero.scale = Vector3.ONE * 1.65  # 1.0-unit model -> ~1.65 m adult Link
	add_child(hero)
	var ap: AnimationPlayer = hero.find_child("AnimationPlayer", true, false)
	var lib: AnimationLibrary = load("res://assets/animations/hero_anims.res")
	# The imported FBX ships a default "" library holding only the T-pose stub.
	# Evict it so our merged library owns the unprefixed namespace.
	if ap.has_animation_library(""):
		ap.remove_animation_library("")
	ap.add_animation_library("", lib)
	if ap.has_animation(clip):
		ap.play(clip)
		print("PLAYING ", clip, " len=", ap.get_animation(clip).length)
	else:
		printerr("missing clip ", clip, " have=", ap.get_animation_list().size())
