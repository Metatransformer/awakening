extends RefCounted
## Walks the whole loop and photographs every screen of it: town, vendor panel,
## smith panel, dungeon room, a fight, and the extraction channel.
##
##   godot --path . -s tools/shoot.gd -- \
##       --scene=res://scenes/main.tscn --out=/tmp/tour/00.png \
##       --director=res://tools/directors/metagame_tour.gd --warmup=60


func run(rig) -> void:
	var main := rig.scene() as Main
	if main == null:
		push_error("metagame_tour: main scene is not a Main")
		return

	# The camera grabs the mouse on ready; a captured cursor in a screenshot run
	# just means the pointer warps around the desktop for no benefit.
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Seed the player mid-progression so the shop panels have something in them.
	Game.add_gold(900)
	Game.stash_add(LootDB.BONE_SHARD, 14)
	Game.stash_add(LootDB.GOBLIN_FANG, 9)
	Game.stash_add(LootDB.KOBOLD_ICHOR, 5)
	Game.stash_add(LootDB.ORC_PLATE, 3)
	Bus.stash_changed.emit()
	await rig.wait_frames(6)

	await rig.capture("01_town.png")

	# Look at the vendor's stall from across the courtyard.
	main.hero.global_position = Vector3(-4.5, 0.05, 3.0)
	await rig.wait_frames(30)
	await rig.capture("02_vendor_stall.png")

	main.hud.open_vendor()
	await rig.wait_frames(6)
	await rig.capture("03_vendor_panel.png")
	main.hud.close_panel()

	main.hero.global_position = Vector3(4.5, 0.05, 3.0)
	await rig.wait_frames(30)
	await rig.capture("04_forge.png")

	main.hud.open_smith()
	await rig.wait_frames(6)
	await rig.capture("05_smith_panel.png")
	main.hud.close_panel()

	main.hero.global_position = Vector3(0.0, 0.05, -9.0)
	await rig.wait_frames(30)
	await rig.capture("06_gate.png")

	# Down we go.
	main.enter_dungeon()
	await rig.wait_frames(40)
	await rig.capture("07_dungeon_entrance.png")

	var d := main.world as Dungeon
	var exits: Array = d.map.exits_of(d.map.entrance)
	if not exits.is_empty():
		d._on_exit_taken(exits[0])
		await rig.wait_frames(40)
		await rig.capture("08_dungeon_room.png")

		# Swing at whatever is nearest, so the shot has a blade in it.
		var target: Enemy = null
		for c in d.room.get_children():
			if c is Enemy:
				target = c
				break
		if target != null:
			# Stand off the enemy toward the middle of the room, so the boom has
			# somewhere to sit that is not inside a wall.
			var away := (Vector3.ZERO - target.global_position)
			away.y = 0.0
			main.hero.global_position = target.global_position + away.normalized() * 2.2
			Bus.camera_recenter.emit()
			await rig.wait_frames(45)
			await rig.tap(["attack"])
			await rig.wait_frames(12)
			await rig.capture("09_attack.png")

		# Kill the room so the loot and the open door are both visible.
		for c in d.room.get_children():
			if c is Enemy:
				(c as Enemy).health.apply_hit(Hit.make(99, main.hero.global_position))
		await rig.wait_frames(50)
		await rig.capture("10_cleared_and_loot.png")

	# The paid way out, mid-channel.
	Game.bag.add(LootDB.BONE_SHARD, 5)
	Game.bag.add(LootDB.GOBLIN_FANG, 3)
	# The channel is K.EXTRACT_CHANNEL seconds long and breaks the moment the key
	# comes up, so the hold has to outlast it — photograph it mid-channel, then
	# keep holding.
	Input.action_press("item_up")
	await rig.wait_frames(60)
	await rig.capture("11_extracting.png")
	await rig.wait_seconds(K.EXTRACT_CHANNEL + 0.5)
	Input.action_release("item_up")
	await rig.wait_frames(60)
	await rig.capture("12_back_in_town.png")
