extends RefCounted
## Daily-state proof: staffed counters by day, occupied bunks at night, and the
## Elder isolated in his own room.

func run(rig) -> void:
	var garrison := rig.scene() as Garrison
	if garrison == null:
		rig.fail("scene is not Garrison")
		return
	# Schedule state is the subject here; civil title presentation has its own
	# focused director and would obscure the night poses this one photographs.
	Clock.running = false
	await rig.wait_frames(45)
	var staff: Array[Npc] = [garrison.vendor, garrison.smith, garrison.alchemist,
		garrison.keeper, garrison.jeweller]
	Clock.set_time(1, 12.0)
	await rig.wait_frames(8)
	for npc: Npc in staff:
		if npc != null and (not npc.enabled
				or npc.current_activity() != Npc.ACTIVITY_WORKING
				or not npc.current_services_open()):
			rig.fail("%s is not working at noon" % npc.name)

	var cam := Camera3D.new()
	cam.fov = 58.0
	garrison.add_child(cam)
	cam.make_current()
	var out: String = rig.out_base().get_base_dir()
	cam.global_position = Vector3(9.2, 1.75, 1.0)
	cam.look_at(Vector3(15.3, 1.1, 1.0), Vector3.UP)
	await rig.capture(out.path_join("life_00_day_services.png"))

	Clock.set_time(1, 23.25)
	await rig.wait_frames(40)
	for npc: Npc in staff:
		if npc != null and (npc.enabled
				or npc.current_activity() != Npc.ACTIVITY_SLEEP
				or npc.current_services_open()):
			rig.fail("%s did not retire at bedtime" % npc.name)
		if npc != null:
			var face_up: Vector3 = npc.global_basis.z.normalized()
			if face_up.dot(Vector3.UP) < 0.99:
				rig.fail("%s does not lie face-up" % npc.name)
			var head_at: Vector3 = npc.global_position \
				+ npc.global_basis.y.normalized() * npc.head_y()
			var local_head_at: Vector3 = garrison.compound.to_local(head_at)
			if npc == garrison.keeper:
				if local_head_at.z > -15.45 or local_head_at.z < -15.95:
					rig.fail("%s's head missed the elder bed head (z=%.2f)"
						% [npc.name, local_head_at.z])
			elif local_head_at.x < -20.35 or local_head_at.x > -19.90:
				rig.fail("%s's head missed the barracks pillow (x=%.2f)"
					% [npc.name, local_head_at.x])
	cam.global_position = Vector3(-12.8, 2.7, 13.6)
	cam.look_at(Vector3(-19.2, 0.9, 2.0), Vector3.UP)
	await rig.capture(out.path_join("life_01_barracks_night.png"))
	cam.global_transform = garrison.compound.global_transform \
		* garrison.compound.port(&"elder_room_camera")
	await rig.capture(out.path_join("life_02_elder_room_night.png"))

	Game.upgrades.erase(&"elder_reveille")
	Clock.set_time(2, WorldClock.DAWN_HOUR)
	Clock.settle_wake_after_dawn()
	if not is_equal_approx(Clock.hour, WorldClock.SERVICE_OPEN_HOUR) \
			or not Clock.services_available():
		rig.fail("base wake did not settle at 07:00 with services open")

	Game.upgrades[&"elder_reveille"] = 1
	Clock.set_time(3, WorldClock.DAWN_HOUR)
	# This is the exact post-title natural-dawn path. Settlement is synchronous,
	# so the check lands before its deferred fade can replace the harness scene.
	Flow._return_at_dawn()
	if not is_equal_approx(Clock.hour, WorldClock.REVEILLE_OPEN_HOUR) \
			or not Clock.services_available():
		rig.fail("Early Reveille wake did not settle at 06:00 with services open")
	if Game.stash_capacity() != 24:
		rig.fail("base locker capacity drifted")
	Game.upgrades[&"elder_locker"] = 2
	if Game.stash_capacity() != 36:
		rig.fail("two locker ranks did not produce 36 slots")
	print("GARRISON LIFE OK")
