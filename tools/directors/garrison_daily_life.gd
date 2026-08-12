extends RefCounted
## Daily-state proof: staffed counters by day, occupied bunks at night, and the
## Elder isolated in his own room.

func run(rig) -> void:
	var garrison := rig.scene() as Garrison
	if garrison == null:
		rig.fail("scene is not Garrison")
		return
	await rig.wait_frames(45)
	var staff: Array[Npc] = [garrison.vendor, garrison.smith, garrison.alchemist,
		garrison.keeper, garrison.jeweller]
	Clock.set_time(1, 12.0)
	await rig.wait_frames(8)
	for npc: Npc in staff:
		if npc != null and (not npc.enabled or npc._off_duty):
			rig.fail("%s is not working at noon" % npc.name)

	var cam := Camera3D.new()
	cam.fov = 58.0
	garrison.add_child(cam)
	cam.make_current()
	var out: String = rig.out_base().get_base_dir()
	cam.global_position = Vector3(9.2, 1.75, 1.0)
	cam.look_at(Vector3(15.3, 1.1, 1.0), Vector3.UP)
	await rig.capture(out.path_join("life_00_day_services.png"))

	Clock.set_time(1, 22.0)
	await rig.wait_frames(40)
	for npc: Npc in staff:
		if npc != null and (npc.enabled or not npc._off_duty):
			rig.fail("%s still trades at night" % npc.name)
	cam.global_position = Vector3(-12.8, 2.7, 13.6)
	cam.look_at(Vector3(-19.2, 0.9, 2.0), Vector3.UP)
	await rig.capture(out.path_join("life_01_barracks_night.png"))
	cam.global_transform = garrison.compound.global_transform \
		* garrison.compound.port(&"elder_room_camera")
	await rig.capture(out.path_join("life_02_elder_room_night.png"))

	Game.upgrades[&"elder_reveille"] = 1
	Clock.set_time(2, 6.25)
	await rig.wait_frames(10)
	if not Clock.services_available():
		rig.fail("Early Reveille did not open services at 06:15")
	if Game.stash_capacity() != 24:
		rig.fail("base locker capacity drifted")
	Game.upgrades[&"elder_locker"] = 2
	if Game.stash_capacity() != 36:
		rig.fail("two locker ranks did not produce 36 slots")
	print("GARRISON LIFE OK")
