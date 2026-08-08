extends RefCounted
## The HUD in the states that matter, not the state it happens to boot in.
##
## An empty HUD always looks fine. The states that catch design problems are the
## ones with a full bag, a hurt player, a live lock-on and an unaffordable
## extraction fee -- so this director manufactures each of them and photographs
## the result. docs/STYLEGUIDE.md §5 is what these are checked against.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/hud_lookdev.gd --out=/tmp/hd/x.png


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/hd/x.png").get_base_dir()
	await rig.wait_frames(30)

	# 1. Fresh: full health, empty bag, in the dungeon.
	Run.enter(1234)
	await rig.wait_frames(6)
	await rig.capture(out.path_join("h_00_fresh.png"))

	# 2. A few commons in. Below tier 1, so the number is still BONE.
	Run.collect(&"bone_shard", 6)
	Run.collect(&"rot_moss", 4)
	await rig.wait_frames(20)
	await rig.capture(out.path_join("h_01_early.png"))

	# 3. Hurt. Two hearts of damage, so the ghost cells are live.
	Game.damage(2 * K.HEART)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("h_02_ghost.png"))
	await rig.wait_frames(30)
	await rig.capture(out.path_join("h_03_ghost_drained.png"))

	# 4. Rich. Past T2, so the rim halos and the number is GOLD.
	Run.collect(&"iron_scrap", 8)
	Run.collect(&"ghost_silk", 6)
	Run.collect(&"ember_gland", 5)
	Run.collect(&"deep_amber", 4)
	Run.collect(&"void_pearl", 3)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("h_04_toast.png"))
	await rig.wait_frames(40)
	await rig.capture(out.path_join("h_05_rich.png"))

	# 5. The fee is now well past the 30 gold a new player starts with, so the
	#    cost renders in RUST. This is the "you cannot afford to leave" state,
	#    which is the whole point of the mechanic and must read instantly.
	await rig.capture(out.path_join("h_06_unaffordable.png"))

	# 6. Standing in an extraction node, holding the button.
	Hud.set_extract_available(true)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("h_07_sweep.png"))
	Hud.set_extract_hold(0.65)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("h_08_holding.png"))
	Hud.set_extract_hold(0.0)

	# 7. Near death: cells pulse, empties go VOID.
	Game.damage(Game.quarters - 2)
	await rig.wait_frames(50)
	await rig.capture(out.path_join("h_09_low.png"))

	# 8. Rich enough for T3, so the number breathes.
	Game.add_gold(5000)
	Run.collect(&"kings_signet", 2)
	await rig.wait_frames(50)
	await rig.capture(out.path_join("h_10_t3.png"))

	print("HUDCHECK bag=%d value=%d slots=%d/%d fee=%d gold=%d" % [
		Run.bag_count(), Run.bag_value(), Run.slots_used(), Game.bag_slots,
		Run.extract_cost(), Game.gold])
