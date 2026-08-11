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

	# **Shoot at 1280x720 for real.** This is a LOOKDEV director -- every frame it
	# produces exists to be judged by eye -- and until now every one of them was a
	# 6880x2756 render Lanczos-downscaled to 720p by `shoot.gd`. A 5.4x supersample
	# flatters exactly what this HUD is made of: hairlines, 1 px rules, 10 px type.
	# `enemy_bars.gd` measured the cost — an 8-stroke bracket of one flat palette
	# colour survived the downscale as FIVE correct pixels (HUD_PLAN §15.14).
	#
	# `--size` alone will not do it: that sets the viewport inside a window
	# `project.godot` opens MAXIMIZED. The window itself has to be resized, which is
	# `perf_probe.gd`'s trick.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await rig.wait_frames(30)
	print("HUDCHECK render size=%s" % [DisplayServer.window_get_size()])

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
	#
	#    And, on the way there, the damage flicker — the rim goes GOLD for two
	#    frames at the instant you are hurt (decision 17, ranked by 33). Two
	#    FRAMES, so it cannot be photographed after a `wait_frames`: this capture
	#    deliberately has none in front of it, because `rig.capture` awaits
	#    exactly one `frame_post_draw`. The rim is COBALT here, so GOLD over it
	#    is unmistakable.
	#
	#    Writing this beat is what caught the flicker being unpaintable at all:
	#    it was a 0.034 s timer, `_process` adds a whole delta before the draw,
	#    and this harness runs well under 30 fps — so it expired every time,
	#    unseen. HUD_PLAN §15.11.
	Game.damage(Game.quarters - 2)
	await _shot(rig, out.path_join("h_08a_flicker.png"), "h_08a_flicker")
	await rig.wait_frames(50)
	await _shot(rig, out.path_join("h_08_low.png"), "h_08_low")

	# 7. Rich enough for T3, so the slips breathe.
	#
	# **This beat did not reach T3 and never had.** It was `Game.add_gold(5000)`
	# plus two signets: gold is the PURSE and `Pal.tier` reads the BAG, so the
	# frame this director exists to produce sat at 1130 — T2 — under a comment
	# saying T3, for the whole life of the file. Nothing caught it because the
	# tier was never asserted, only described — so it is asserted below, and this
	# beat now fails loudly rather than quietly photographing T2.
	#
	# The gold stays: T2 also lerps the fog toward GOLD, and a purse that can
	# actually pay the extraction fee is what the other beats want on screen.
	#
	# **And signets could not get there either.** They stack 2 to a slot at 90
	# each, so a whole 12-slot bag of nothing else is 1080 against a T3 of 3000.
	# The best slot in the game is Deep Amber (55 × 6 = 330), which puts the
	# STARTING bag's absolute ceiling at 3960 and a realistic mixed one nowhere
	# near it. So this beat also buys slots, which is what a player would have
	# done by the time this frame is true of them. See HUD_PLAN §15.10 — T3 being
	# this hard to reach is a finding about the thresholds, not a quirk here.
	#
	# 20 slots is also the only thing that ever checks decision 26's claim that
	# the slot-mark row is read from `Run` rather than hard-coded at twelve.
	Game.add_gold(5000)
	Game.bag_slots = 20
	Run.collect(&"deep_amber", 42)
	if Pal.tier(Run.bag_value()) < 3:
		push_error("HUDLOOKDEV h_09_t3: bag is %d, T3 is %d — this frame is not T3"
			% [Run.bag_value(), Pal.T3])
		_fails += 1
	await rig.wait_frames(50)
	await _shot(rig, out.path_join("h_09_t3.png"), "h_09_t3")

	# 7b. The SAME frame one second later. The breath is 0.5 Hz, so one second is
	#     half a period and this is the opposite phase — a single T3 capture can
	#     land anywhere on the sine and proves nothing about whether it moves.
	#     Diff the two slips and the animation is either there or it is not.
	await rig.wait_frames(60)
	await _shot(rig, out.path_join("h_09_t3_phase.png"), "h_09_t3_phase")

	# 7c. The floor card, announcing and settled (decision 18).
	#
	#     Nothing in this repo photographed this card in either state, which is how
	#     it kept a permanent BONE level line through every review: the announcement
	#     and the readout are the SAME two lines in two colours, so a director that
	#     shoots one of them cannot tell you the other one exists.
	#
	#     `Bus.floor_arrived` is the real trigger -- the frame the loading card
	#     lifts -- so this drives it rather than poking `_floor_t`, and the settle
	#     is walked by `Hud._process` on the game clock exactly as it is in play.
	#     FLOOR_HOLD is 2.4 s and FLOOR_SETTLE 0.9, so 200 frames is comfortably
	#     past the end of the ramp at any rate this harness runs at.
	Bus.floor_arrived.emit(Run.level)
	await rig.wait_frames(2)
	await _shot(rig, out.path_join("h_09a_floor_lit.png"), "h_09a_floor_lit")
	await rig.wait_frames(200)
	await _shot(rig, out.path_join("h_09b_floor_dim.png"), "h_09b_floor_dim")

	# 8. A WORKING in the right hand, with charges and without. HUD_PLAN §11 asks
	#    for these two frames by name and they are the proof of decisions 10-12:
	#    Burst is the one armament with no baked icon (`_iconbake.gd` bakes off
	#    real MODELS and he casts it from an empty hand), so its cell is the ONLY
	#    one that reaches the lettering fallback. Under the deleted `KIT_LABEL`
	#    that cell drew "BU" from the HUD's own copy of the table; it now draws it
	#    from `ArmamentDb.letter()`, and if those two had disagreed about the row
	#    the frame would say "?".
	#
	#    The numeral must draw BOTH times. At zero charges it dims rather than
	#    disappearing — "I have the working and no charges" is a different
	#    sentence from "I have no working", and a cell that goes blank at zero
	#    tells the second one.
	Game.grant(&"burst")
	Game.add_charges(3)
	for _i in Game.RIGHT_POOL.size():
		if Game.armament(&"right") == &"burst":
			break
		Game.cycle_armament(&"right")
	await rig.wait_frames(6)
	await _shot(rig, out.path_join("h_10_burst.png"), "h_10_burst")

	Game.charges = 0
	Bus.ammo_changed.emit(&"charges", 0)
	await rig.wait_frames(6)
	await _shot(rig, out.path_join("h_11_burst_spent.png"), "h_11_burst_spent")

	if Game.armament(&"right") != &"burst":
		print("HUD FAIL could not put a working in the right hand — "
			+ "the h_10/h_11 frames prove nothing")
		_fails += 1

	# 9. The damage arc, at the four cardinal bearings. It replaced `Feel`'s
	#    full-screen vignette (decision 13), and the ONLY thing it adds over that
	#    vignette is the direction — so a director that photographs one arc has
	#    checked nothing. Four frames, four quadrants, or the convention in
	#    `Hud._on_hero_struck` is unverified.
	#
	#    Driven through `Bus.hero_struck` with a world position built from the
	#    CAMERA's basis, which is the same transform the HUD inverts. Feeding it
	#    world axes instead would pass or fail on where the courtyard happens to
	#    be pointing.
	var hero3 := rig.get_first_node_in_group(&"player") as Node3D
	var cam := rig.root.get_camera_3d() as Camera3D
	if hero3 == null or cam == null:
		print("HUD FAIL no hero or no camera — the arc frames prove nothing")
		_fails += 1
	else:
		# local -Z is forward, so this is: in front, to the right, behind, to the
		# left. The arc must land top, right, bottom, left in that order.
		var dirs := {
			"front": Vector3(0.0, 0.0, -3.0),
			"right": Vector3(3.0, 0.0, 0.0),
			"behind": Vector3(0.0, 0.0, 3.0),
			"left": Vector3(-3.0, 0.0, 0.0),
		}
		for name: String in dirs:
			var world: Vector3 = (hero3.global_position
				+ cam.global_transform.basis * (dirs[name] as Vector3))
			Bus.hero_struck.emit(world)
			await _shot(rig, out.path_join("h_12_arc_%s.png" % name),
				"h_12_arc_%s" % name)

	# Assertion 4 (decision 32). Once, not per capture — it is a property of the
	# palette and of `Hud.rarity_weight`, not of any one frame. See the long note
	# in `_hud_layout.gd` for why it does not read pixels.
	_fails += Layout.check_contrast()

	print("HUDCHECK bag=%d value=%d slots=%d/%d fee=%d gold=%d" % [
		Run.bag_count(), Run.bag_value(), Run.slots_used(), Game.bag_slots,
		Run.extract_cost(), Game.gold])
	print("HUDCHECK layout_fails=%d" % _fails)
	if _fails > 0:
		print("HUD FAIL %d layout assertion(s) — see HUDLAYOUT lines above" % _fails)
