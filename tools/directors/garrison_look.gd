extends RefCounted
## The garrison, and everyone in it, from the distances the player actually
## sees.
##
## A shopkeeper has to survive exactly two shots: the wide, where the yard has to
## read as three DIFFERENT shops at a glance, and standing-in-front-of, where the
## person behind the counter has to look like a person. Both are here, because
## the two fail in opposite directions -- a booth that reads beautifully up close
## can be an unreadable pile of brown boxes from across the yard.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/garrison_look.gd --out=/tmp/garrison/x.png

func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/tl/x.png").get_base_dir()
	var garrison: Garrison = rig.scene()
	# Long, on purpose. The bodies retarget a shared clip library at load and the
	# booths instance about twenty GLBs between them; a shot taken too early
	# catches bind-pose statues standing in an empty yard and looks like a bug in
	# something else entirely.
	await rig.wait_frames(40)

	var cam := Camera3D.new()
	cam.fov = 50.0
	garrison.add_child(cam)
	cam.make_current()

	# Wide first: the whole yard from above the arrival end, which is the frame
	# that answers "does this look like a garrison".
	#
	# Raised from (0, 9.5, 15) when the boundary became a 6 m curtain wall: at the
	# old height the south wall stood between this camera and the yard and filled
	# the bottom third of the shot with masonry. A proof camera that cannot see the
	# thing it is proving is worse than no shot, because it still says SHOT_OK.
	cam.fov = 62.0
	cam.global_position = Vector3(0.0, 15.0, 21.0)
	cam.look_at(Vector3(0.0, 1.0, -3.0), Vector3.UP)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("tl_00_yard.png"))

	# And the walk in, at eye height -- what you see stepping out of the gate.
	# The eye stays behind the arrival point so the elder waiting there is framed
	# at conversation distance instead of sharing the camera's position.
	cam.fov = 50.0
	cam.global_position = Vector3(0.0, 1.7, 12.8)
	cam.look_at(Vector3(-0.9, 1.2, 7.9), Vector3.UP)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("tl_01_arrive.png"))

	# The gatehouse, from where a player actually stands when they decide to go
	# down: eight metres out on the approach, at eye height.
	#
	# It has its own shot because it is the only piece of ARCHITECTURE in the
	# build, and the wide above cannot judge it -- from fifteen metres up the
	# passage is a black slot and the whole point of the thing is that the passage
	# has an inside. If this frame does not show cold light under the arch, the
	# gate has stopped signposting and nothing else here will notice.
	cam.fov = 55.0
	cam.global_position = garrison.gate.global_position + Vector3(0.0, 1.6, 8.5)
	cam.look_at(garrison.gate.global_position + Vector3(0.0, 3.4, 0.0), Vector3.UP)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("tl_02_gatehouse.png"))

	# And the plaza from over the south opening, which shows the yard's landmark
	# and the distinct rooms and service nooks around it.
	cam.fov = 62.0
	cam.global_position = garrison.plaza.global_position + Vector3(0.0, 7.0, 13.0)
	cam.look_at(garrison.plaza.global_position + Vector3(0.0, 1.6, 0.0), Vector3.UP)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("tl_03_plaza.png"))

	# Every counter from the customer's side of it. The eye is derived from the
	# keeper's own facing rather than hard-coded, so an NPC that is turned the
	# wrong way photographs as a back, not as a mysteriously empty frame.
	#
	# All FIVE people, not the three this list carried while there were three. The
	# keeper and the jewelcrafter were added to the yard without being added here,
	# so half the garrison had no proof shot at all -- which is how five authored
	# bodies could have landed with only two of them ever photographed at the
	# counter they stand behind. (The village elder was a sixth entry until he and
	# the Lanternkeeper became one man; `keeper` is him.)
	var subjects := [
		{"name": "vendor", "at": garrison.vendor, "back": 3.4, "high": 1.65},
		{"name": "smith", "at": garrison.smith, "back": 3.8, "high": 1.65},
		{"name": "alchemist", "at": garrison.alchemist, "back": 3.4, "high": 1.65},
		{"name": "keeper", "at": garrison.keeper, "back": 3.4, "high": 1.65},
		{"name": "jeweller", "at": garrison.jeweller, "back": 3.4, "high": 1.65},
		{"name": "gate", "at": garrison.gate, "back": 6.0, "high": 2.0},
	]
	for s in subjects:
		var node: Node3D = s["at"]
		# The keeper's own +Z is the customer's side (see `ShopBooth`), so stand
		# there and look back at them across their counter.
		var front: Vector3 = node.global_transform.basis * Vector3(0.0, 0.0, 1.0)
		cam.global_position = node.global_position \
			+ front * float(s["back"]) + Vector3(0.0, float(s["high"]), 0.0)
		cam.look_at(node.global_position + Vector3(0.0, 1.1, 0.0), Vector3.UP)
		await rig.wait_frames(3)
		await rig.capture(out.path_join("tl_10_%s.png" % s["name"]))

	# One three-quarter per shop as well. A booth is a little scene, and a
	# straight-on shot hides everything the keeper is standing in front of.
	for s in subjects:
		# The gate is masonry: no booth for a three-quarter to reveal.
		if String(s["name"]) == "gate":
			continue
		var node: Node3D = s["at"]
		var b := node.global_transform.basis
		var eye: Vector3 = b * Vector3(2.8, 0.0, 2.6)
		cam.global_position = node.global_position + eye + Vector3(0.0, 2.0, 0.0)
		cam.look_at(node.global_position + Vector3(0.0, 0.9, 0.0), Vector3.UP)
		await rig.wait_frames(3)
		await rig.capture(out.path_join("tl_20_%s_booth.png" % s["name"]))
	print("GARRISONLOOK done")
