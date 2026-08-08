extends Node3D
## Ground truth for the model yaw offset.
##
## Spawns four copies of the hero rig at yaw offsets 0/90/180/270, all playing
## the same locomotion clip, viewed from +Z looking toward -Z. Whichever copy
## shows us its BACK is facing -Z, which is what a Node3D's forward is — that
## offset is the correct `model_yaw_offset` for the hero.
##
## Each copy is labelled by a coloured post in front of where it SHOULD be
## looking, so "which way is he facing" is answerable from the image alone.
@export var clip: String = "ss_idle_01"

const OFFSETS := [0, 90, 180, 270]


func _ready() -> void:
	for i in OFFSETS.size():
		var deg: int = OFFSETS[i]
		var x := (float(i) - 1.5) * 2.6

		var pivot := Node3D.new()
		pivot.position = Vector3(x, 0, 0)
		add_child(pivot)

		var model := Node3D.new()
		model.rotation.y = deg_to_rad(float(deg))
		model.scale = Vector3.ONE * K.HERO_SCALE
		pivot.add_child(model)

		var rig: Node3D = (load("res://assets/characters/hero.fbx") as PackedScene).instantiate()
		model.add_child(rig)

		var ap: AnimationPlayer = rig.find_child("AnimationPlayer", true, false)
		if ap.has_animation_library(""):
			ap.remove_animation_library("")
		ap.add_animation_library("", load("res://assets/animations/hero_anims.res"))
		if ap.has_animation(clip):
			ap.play(clip)
			ap.seek(ap.get_animation(clip).length * 0.35, true)

		# A marker one metre along the pivot's -Z: where this copy OUGHT to look.
		var post := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.06
		cyl.bottom_radius = 0.06
		cyl.height = 1.4
		post.mesh = cyl
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.1, 0.9, 0.3)
		m.emission_enabled = true
		m.emission = Color(0.1, 0.9, 0.3)
		m.emission_energy_multiplier = 0.6
		post.material_override = m
		post.position = Vector3(x, 0.7, -1.5)
		add_child(post)

		var label := Label3D.new()
		label.text = "%d°" % deg
		label.font_size = 96
		label.position = Vector3(x, 2.4, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)

	var hint := Label3D.new()
	hint.text = "green post = -Z (a Node3D's forward).  The copy showing its BACK is correct."
	hint.font_size = 48
	hint.position = Vector3(0, 3.3, 0)
	hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(hint)
