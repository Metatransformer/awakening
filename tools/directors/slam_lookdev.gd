extends RefCounted
## The air-slam clip, frame by frame, at the seconds the code is about to claim
## things happen at.
##
## _clip_hips.gd says WHERE the hips are; it cannot say what the arms and the
## weapon are doing, and a slam is entirely about the weapon being overhead and
## then not. So this drives the hero's AnimationPlayer directly — the tree is
## switched off for the duration — and photographs a named list of times.
##
## `ax_melee_run_jump_attack` is 3.67 s of run-up, gather, leap, strike, land and
## then a man standing there. The offsets the hero uses (`slam_start_offset`,
## `slam_land_offset`) are read off THIS, not off the hips table:
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/slam_lookdev.gd --out=/tmp/slam/x.png
##   ffmpeg -y -i /tmp/slam/t%02d.png -filter_complex tile=6x2 /tmp/slam/sheet.png

const CLIP := &"ax_melee_run_jump_attack"
## Apex is 1.23 and touchdown is 1.83 on the hips track, so this brackets both
## ends of the descent tightly and then samples the recovery coarsely.
const TIMES: Array[float] = [
	1.10, 1.23, 1.30, 1.40, 1.50, 1.60,
	1.70, 1.80, 1.90, 2.10, 2.40, 2.75,
]


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/slam/x.png").get_base_dir()
	var hero: Node3D = rig.get_nodes_in_group(&"player")[0]
	hero.set(&"facing_yaw", 0.0)
	if Hud != null:
		Hud.visible = false

	var cam := hero.get_viewport().get_camera_3d()
	if cam != null:
		cam.set_physics_process(false)
	await rig.wait_seconds(0.6)

	# The tree owns the skeleton while it is active, so a direct play() is simply
	# overwritten every frame. Switch it off, pose by hand, switch it back.
	var tree: AnimationTree = hero.find_child("AnimTree", false, false)
	var player: AnimationPlayer = hero.find_child("AnimationPlayer", true, false)
	if tree == null or player == null:
		print("SLAMLD FAIL no AnimTree/AnimationPlayer on the hero")
		return
	tree.active = false
	player.play(CLIP)
	player.pause()

	for i in TIMES.size():
		var t: float = TIMES[i]
		player.seek(t, true)
		# The seek writes the pose on the mixer's own tick, not inside seek().
		await rig.physics_frame
		cam.global_position = hero.global_position + Vector3(2.1, 1.1, 2.6)
		cam.look_at(hero.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)
		await rig.capture(out.path_join("t%02d.png" % i))
		print("SLAMLD t%02d = %.2f s" % [i, t])

	tree.active = true
	print("SLAMLD done")
