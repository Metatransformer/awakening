extends RefCounted
## Screenshot director: walks every Camera3D in the room and captures one frame
## from each, so the room can be judged from more than the one angle its author
## happened to like.
##
##   godot --path . -s tools/shoot.gd -- \
##       --scene=res://scenes/rooms/proving_ground.tscn \
##       --director=res://scripts/kit/proving_ground_tour.gd \
##       --out=/abs/dir/pg.png --size=1280x720
##
## Camera order is the scene order, and each frame is named after its camera node,
## so `pg_RefCam.png`, `pg_CamCorridor.png` and so on. Nothing here drives input —
## the room does not move. A piece that moves owes the critic a director that holds
## buttons (CONTRACT §9); this one only owes angles.

const SETTLE_FRAMES := 24


func run(rig) -> void:
	var root: Node = rig.scene()
	var cams: Array[Camera3D] = []
	_collect(root, cams)
	if cams.is_empty():
		push_error("proving_ground_tour: no Camera3D in %s" % root.name)
		return

	var base: String = rig.out_base()
	var stem: String = base.get_basename()
	var ext: String = base.get_extension()

	for cam in cams:
		cam.make_current()
		# Let the volumetric fog's temporal reprojection and the particle systems
		# converge on the new view before grabbing the frame — capture too early and
		# the fog is visibly still resolving from the previous camera.
		await rig.wait_frames(SETTLE_FRAMES)
		await rig.capture("%s_%s.%s" % [stem, cam.name, ext])


func _collect(n: Node, out: Array[Camera3D]) -> void:
	if n is Camera3D:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)
