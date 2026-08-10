extends RefCounted
## The doll stage, on its own, before any screen depends on it.
##
## It exists for one question CLAUDE.md §4 says you are not allowed to answer by
## reasoning: WHICH WAY IS THE HERO FACING. The rig is aimed by `-basis.z` in the
## world and the art faces `+Z`, so a menu camera parked on `+Z` gets the front
## of him with no correction — but that sentence has been wrong three times in
## this project's history, so it is photographed instead of argued.
##
## Also proves the fit: three stages of different aspect, one figure, no crop.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/doll_lookdev.gd --out=/tmp/doll/x.png

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const DollStageScript := preload("res://scripts/ui/kit/doll_stage.gd")


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/doll/x.png").get_base_dir()
	await rig.wait_frames(20)

	UITheme.prewarm()

	var layer := CanvasLayer.new()
	layer.layer = 120
	rig.root.add_child(layer)
	layer.add_child(UITheme.modal_scrim(func() -> void: pass))

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 60
	panel.offset_top = 40
	panel.offset_right = -60
	panel.offset_bottom = -40
	UITheme.style_panel(panel, UITheme.FRAME_FACE_SOLID)
	layer.add_child(panel)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)

	# The pouch card's box, the equipment column's box, and a deliberately wrong
	# one. A fit that only works at the aspect it was tuned at is not a fit.
	var stages: Array[DollStage] = []
	for box: Vector2 in [Vector2(150, 190), Vector2(260, 420), Vector2(420, 200)]:
		var cell := VBoxContainer.new()
		cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_theme_constant_override("separation", 6)
		row.add_child(cell)
		var stage := DollStageScript.new()
		stage.custom_minimum_size = box
		cell.add_child(stage)
		var cap := Label.new()
		cap.text = "%d x %d" % [int(box.x), int(box.y)]
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.apply_text_style(cap, UITheme.TYPE_CAPTION)
		cell.add_child(cap)
		stages.append(stage)

	await rig.wait_frames(2)
	for stage in stages:
		stage.mount(DollStageScript.hero_rig())

	# Long enough for the deferred frame, the FBX's first animation tick, and the
	# viewport's own first render.
	await rig.wait_frames(30)
	await rig.capture(out.path_join("d_00_front.png"))

	# Three quarters, so a doll that happens to look right head-on because it is
	# symmetric is still caught.
	for stage in stages:
		stage.set_yaw(deg_to_rad(90.0))
	await rig.wait_frames(10)
	await rig.capture(out.path_join("d_01_turned.png"))

	print("DOLL LOOKDEV OK -> %s" % out)
