extends RefCounted
## The HUD in the states that matter, not the state it happens to boot in.
##
## An empty HUD always looks fine. The states that catch design problems are the
## ones with a full bag, a hurt player, a live lock-on and a walk home that now
## costs everything -- so this director manufactures each of them and photographs
## the result. docs/STYLEGUIDE.md §5 is what these are checked against.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/hud_lookdev.gd --out=/tmp/hd/x.png


const Layout := preload("res://tools/directors/_hud_layout.gd")

var _fails := 0


## Photograph, then assert on the rectangles that were just drawn. This director
## is the one that fills the bag to eight stacks, so it is the only one that ever
## sees the slips at full height -- which is exactly the case HUD_PLAN §14.5
## claims resolves and does not.
func _shot(rig, path: String, tag: String) -> void:
	await rig.capture(path)
	_fails += Layout.check(tag)


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/hd/x.png").get_base_dir()
	await rig.wait_frames(30)

	# 1. Fresh: full health, empty bag, in the dungeon.
	Run.enter(1234)
	await rig.wait_frames(6)
	await _shot(rig, out.path_join("h_00_fresh.png"), "h_00_fresh")

	# 2. A few commons in. Below tier 1, so the number is still BONE.
	Run.collect(&"bone_shard", 6)
	Run.collect(&"rot_moss", 4)
	await rig.wait_frames(20)
	await _shot(rig, out.path_join("h_01_early.png"), "h_01_early")

	# 3. Hurt. Two hearts of damage, so the ghost cells are live.
	Game.damage(2 * K.HEART)
	await rig.wait_frames(4)
	await _shot(rig, out.path_join("h_02_ghost.png"), "h_02_ghost")
	await rig.wait_frames(30)
	await _shot(rig, out.path_join("h_03_ghost_drained.png"), "h_03_ghost_drained")

	# 4. Rich. Past T2, so the rim halos and the number is GOLD.
	Run.collect(&"iron_scrap", 8)
	Run.collect(&"ghost_silk", 6)
	Run.collect(&"ember_gland", 5)
	Run.collect(&"deep_amber", 4)
	Run.collect(&"void_pearl", 3)
	await rig.wait_frames(4)
	await _shot(rig, out.path_join("h_04_toast.png"), "h_04_toast")
	await rig.wait_frames(40)
	await _shot(rig, out.path_join("h_05_rich.png"), "h_05_rich")

	# 5. "Leaving now costs everything you have." There used to be a frame before
	#    this one for the fee rendering in RUST; the standing EXTRACT line is gone
	#    (`Hud._draw_extraction`), so the sweep IS the announcement now and a
	#    second capture of the same screen was photographing nothing.
	Hud.set_extract_dear(true)
	await rig.wait_frames(4)
	await _shot(rig, out.path_join("h_06_sweep.png"), "h_06_sweep")
	Hud.set_extract_hold(0.65)
	await rig.wait_frames(4)
	await _shot(rig, out.path_join("h_07_holding.png"), "h_07_holding")
	Hud.set_extract_hold(0.0)

	# 6. Near death: cells pulse, empties go VOID.
	Game.damage(Game.quarters - 2)
	await rig.wait_frames(50)
	await _shot(rig, out.path_join("h_08_low.png"), "h_08_low")

	# 7. Rich enough for T3, so the number breathes.
	Game.add_gold(5000)
	Run.collect(&"kings_signet", 2)
	await rig.wait_frames(50)
	await _shot(rig, out.path_join("h_09_t3.png"), "h_09_t3")

	print("HUDCHECK bag=%d value=%d slots=%d/%d fee=%d gold=%d" % [
		Run.bag_count(), Run.bag_value(), Run.slots_used(), Game.bag_slots,
		Run.extract_cost(), Game.gold])
	print("HUDCHECK layout_fails=%d" % _fails)
	if _fails > 0:
		print("HUD FAIL %d layout assertion(s) — see HUDLAYOUT lines above" % _fails)
