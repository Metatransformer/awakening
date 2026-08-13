extends RefCounted
## End-to-end proof for the real tree-cutting interaction.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison_outskirts.tscn \
##     --director=res://tools/directors/grove_cutting.gd \
##     --out=/tmp/grove-cutting/grove.png --warmup=60


func run(rig) -> void:
	var outskirts := rig.scene() as GarrisonOutskirts
	if not rig.check(outskirts != null, "scene is the garrison outskirts"):
		return
	Clock.running = false
	Clock.set_time(1, 10.0)
	Game.restore_garrison({})
	Run.reset()
	Game.set_flag(StoryDb.told_flag(&"elder", &"timber_duty"))
	Game.grant(ShopDb.WOODSMAN_AXE_ID)
	var axe_maximum := Game.tool_max_durability(ToolDb.WOODSMAN_AXE_ID)
	var wheel_before: Array[StringName] = Game.wheel.duplicate()

	await rig.wait_physics_frames(4)
	if not rig.check(outskirts.harvest_trees.size() == 10,
			"the authored grove has ten working trees"):
		return
	var hero := rig.root.get_tree().get_first_node_in_group(&"player") as Hero
	var tree: HarvestTree = outskirts.harvest_trees[0]
	if not rig.check(hero != null and tree != null, "hero and first tree are present"):
		return
	var heard_cues: Array[StringName] = []
	var cue_listener: Callable = func(id: StringName, _position: Vector3) -> void:
		heard_cues.append(id)
	Bus.request_sfx.connect(cue_listener)

	var cam := Camera3D.new()
	cam.fov = 48.0
	outskirts.add_child(cam)
	cam.global_position = tree.global_position + Vector3(7.0, 4.6, 7.5)
	cam.look_at(tree.global_position + Vector3.UP * 2.7, Vector3.UP)
	cam.make_current()
	hero.global_position = tree.global_position + Vector3(1.35, 0.12, 0.0)
	hero.velocity = Vector3.ZERO
	await rig.wait_physics_frames(5)
	rig.check(await rig.until(func() -> bool: return Prompt.focus == tree, 2.0),
		"walking to a grove tree gives the real CHOP TREE prompt focus")
	await rig.capture("grove_00_before.png")

	await rig.press(&"interact")
	var started: bool = await rig.until(
		func() -> bool: return hero.woodsman_chopping(), 2.0)
	rig.check(started, "holding interact starts the committed Woodsman's Axe chop")
	if started:
		rig.check(hero.combat.woodsman_axe != null and hero.combat.woodsman_axe.visible,
			"the utility axe replaces the combat loadout during the chop")
		cam.global_position = hero.global_position + Vector3(2.8, 1.8, -3.2)
		cam.look_at(hero.global_position + Vector3.UP * 1.15, Vector3.UP)
		await rig.wait_frames(2)
		await rig.capture("grove_01_chop.png")
		cam.global_position = tree.global_position + Vector3(7.0, 4.6, 7.5)
		cam.look_at(tree.global_position + Vector3.UP * 2.7, Vector3.UP)
	var harvested: bool = await rig.until(func() -> bool:
		return int(Run.bag.get(SupplyCargoDb.FIREWOOD_ID, 0)) == 1, 2.0)
	rig.release(&"interact")
	rig.check(harvested, "the axe impact awards exact Firewood cargo to the Run bag")
	rig.check(Game.tool_durability(ToolDb.WOODSMAN_AXE_ID) == axe_maximum - 1,
		"the successful tree impact spends exactly one Axe use")
	rig.check(heard_cues == [HarvestTree.SFX_AXE_HIT, HarvestTree.SFX_TREE_FALL],
		"the committed impact requests one axe hit and one tree-fall cue")
	rig.check(_positional_voice_playing(HarvestTree.SFX_AXE_HIT)
		and _positional_voice_playing(HarvestTree.SFX_TREE_FALL),
		"both supplied wood-cutting takes start through pooled positional SFX")
	await rig.wait_seconds(0.26)
	await rig.capture("grove_02_falling.png")
	await rig.wait_seconds(0.75)

	var stump := tree.get_node_or_null(^"Stump") as MeshInstance3D
	var pivot := tree.get_node_or_null(^"FallPivot") as Node3D
	var shape := tree.get_node_or_null(^"SolidTrunk/TrunkCollision") as CollisionShape3D
	rig.check(stump != null and stump.visible, "the harvested tree leaves a visible stump")
	rig.check(pivot != null and pivot.rotation.x < -1.45,
		"the selected tree falls to the ground away from the hero")
	rig.check(shape != null and shape.disabled, "the felled trunk no longer blocks movement")
	rig.check(not hero.woodsman_chopping() and not hero.combat.woodsman_axe.visible,
		"the utility axe is put away when the chop commitment ends")
	rig.check(Game.wheel == wheel_before and not Game.wheel.has(ShopDb.WOODSMAN_AXE_ID),
		"the Woodsman's Axe never enters the weapon wheel")
	await rig.capture("grove_03_stump.png")

	var second: HarvestTree = outskirts.harvest_trees[1]
	second.activate(hero)
	var before_refusal := Game.tool_durability(ToolDb.WOODSMAN_AXE_ID)
	await rig.wait_seconds(0.1)
	rig.check(not hero.woodsman_chopping()
		and int(Run.bag.get(SupplyCargoDb.FIREWOOD_ID, 0)) == 1,
		"a second tree refuses because today's chop is complete, not because cargo is held")
	rig.check(Game.tool_durability(ToolDb.WOODSMAN_AXE_ID) == before_refusal,
		"the same-day refusal spends no Axe use")
	Clock.set_time(2, 10.0)
	await rig.wait_physics_frames(3)
	rig.check(not stump.visible and tree.enabled
		and Game.can_chop_firewood(Clock.day, Clock.garrison_phase()),
		"the next day restores the grove and a fresh daily chop")
	if Bus.request_sfx.is_connected(cue_listener):
		Bus.request_sfx.disconnect(cue_listener)
	Clock.running = true
	print("GROVE CUTTING OK")


func _positional_voice_playing(cue: StringName) -> bool:
	var suffix := "/%s.wav" % String(cue)
	for voice: AudioStreamPlayer3D in Sfx._pool:
		if voice.playing and voice.stream != null \
				and voice.stream.resource_path.ends_with(suffix):
			return true
	return false
