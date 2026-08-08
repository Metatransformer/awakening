extends RefCounted
## Critic-owned director. Drives the dungeon look from cameras I choose, not the
## ones the builder framed. Enumerates every Camera3D authored in the room, then
## adds my own probes: an eye-height shot at the hero spawn, a shot in the corner
## furthest from any torch (does "unlit" actually mean black?), and a slow orbit.

func run(rig) -> void:
	var scn: Node = rig.scene()
	var cams: Array[Camera3D] = []
	_collect(scn, cams)
	print("CRITIC_CAMS ", cams.size())
	var i := 0
	for c in cams:
		print("CAM %d %s pos=%s rotdeg=%s fov=%.1f" % [i, c.name, str(c.global_position), str(c.global_rotation_degrees), c.fov])
		c.make_current()
		await rig.wait_frames(6)
		await rig.capture("/tmp/look_%02d_%s.png" % [i, c.name])
		i += 1

	# My own probes.
	var probe := Camera3D.new()
	scn.add_child(probe)
	probe.fov = 60.0

	var shots := [
		# name, position, look_at target
		["eye_spawn", Vector3(0, 1.35, 6.0), Vector3(0, 1.35, -6.0)],
		["far_corner", Vector3(-9.0, 1.35, -9.0), Vector3(9.0, 1.2, 9.0)],
		["up_at_ceiling", Vector3(0, 1.35, 0.0), Vector3(0.01, 6.0, -4.0)],
		["floor_close", Vector3(0, 0.9, 2.0), Vector3(0, 0.0, -1.0)],
		["wall_flat", Vector3(0, 1.6, -4.0), Vector3(0, 1.6, -12.0)],
	]
	for s in shots:
		probe.global_position = s[1]
		probe.look_at(s[2], Vector3.UP)
		probe.make_current()
		await rig.wait_frames(6)
		await rig.capture("/tmp/look_%02d_%s.png" % [i, s[0]])
		print("PROBE %s at %s" % [s[0], str(s[1])])
		i += 1

	# Orbit around the room centre at hero eye height, to see how the pools of
	# light distribute all the way round.
	for k in 8:
		var a := TAU * float(k) / 8.0
		probe.global_position = Vector3(sin(a) * 7.0, 1.35, cos(a) * 7.0)
		probe.look_at(Vector3(0, 1.2, 0), Vector3.UP)
		probe.make_current()
		await rig.wait_frames(4)
		await rig.capture("/tmp/look_%02d_orbit%d.png" % [i, k])
		i += 1


func _collect(n: Node, out: Array[Camera3D]) -> void:
	if n is Camera3D:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)
