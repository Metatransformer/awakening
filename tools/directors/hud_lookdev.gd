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


## Exactly ONE ammo numeral was drawn on the hand row, and it was in `want`.
##
## `_draw_hands` notes each numeral as `ammo_<i>` under its own cell, so the keys
## the HUD published for the frame just captured are the number of numerals that
## reached the screen. That is the assertion #53's borrow has to pass and the one
## `hand_count`'s docstring predicted it would fail: give the bow the quiver's
## count unconditionally and bow + arrow prints six twice, once under the stave
## and once under the arrows.
##
## Deliberately NOT `ArmamentDb.hand_count_beside(&"bow", &"shield")`. That is a
## call on two string literals — true of the table whatever the hero is holding,
## and #52 closed on exactly that shape of assertion sitting under a label that
## read as a claim about the cell. `layout_rects()` is the drawn frame.
func _one_numeral(tag: String, want: StringName) -> int:
	var keys: Array = []
	for k: StringName in Hud.layout_rects().keys():
		if String(k).begins_with("ammo_"):
			keys.append(k)
	if keys.size() == 1 and keys[0] == want:
		print("  ok   HUDAMMO %s: one numeral, in %s" % [tag, want])
		return 0
	print("HUD FAIL %s: expected exactly one ammo numeral in %s, drew %s"
		% [tag, want, keys])
	return 1


## How many LIT tiles the Ballast slot published on the frame just captured, and
## whether that is the reading the beat expected.
##
## `Hud._draw_draughts` notes each lit tile as `draught_ballast_lit_<t>` under its
## own slot, so these keys are the clock as it reached the SCREEN — not
## `Game.draught_left`, which is the thing the HUD is supposed to be drawing and
## would report a running window whether or not a single pixel of it was drawn.
## That distinction is the whole of #39: the window already worked and nothing
## said so.
##
## `want < 0` means "any number of tiles, but the slot exists" — used where the
## exact count is a race against the harness's frame rate rather than a claim.
func _ballast_tiles(tag: String, want: int) -> int:
	var layout: Dictionary = Hud.layout_rects()
	var slot := StringName("draught_%s" % Game.BALLAST_ID)
	var lit := 0
	for k: StringName in layout.keys():
		if String(k).begins_with("draught_%s_lit_" % Game.BALLAST_ID):
			lit += 1
	# The container must be there in EVERY frame, lit or not. "It is drawn when it
	# is empty" is `_draw_draughts`'s own rule and the reason a player has met this
	# instrument before the first time it matters — so a beat that only ever
	# checked the lit tiles would pass on a HUD that drew the row solely while the
	# window was up, which is the version that teaches nobody.
	if not layout.has(slot):
		print("HUD FAIL %s: no Ballast slot in the row at all (%d lit)" % [tag, lit])
		return 1
	if want >= 0 and lit != want:
		print("HUD FAIL %s: Ballast slot drew %d lit tile(s), expected %d (%.2f s left)"
			% [tag, lit, want, Game.draught_left(Game.BALLAST_ID)])
		return 1
	print("  ok   HUDBALLAST %s: slot drawn, %d/%d tiles lit, %.2f s left"
		% [tag, lit, Hud.DRAUGHT_TILES, Game.draught_left(Game.BALLAST_ID)])
	return 0


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/hd/x.png").get_base_dir()

	# **This director is judged by eye, so it has to be shot at 1:1.** It used to
	# resize the OS window itself, because `shoot.gd` opened a 6880x2756 window for
	# a 1280x720 canvas and Lanczos-downscaled the result -- a 5.4x supersample,
	# which flatters exactly what this HUD is made of: hairlines, 1 px rules, 10 px
	# type. `enemy_bars.gd` measured the cost: an 8-stroke bracket of one flat
	# palette colour survived the downscale as FIVE correct pixels (HUD_PLAN
	# §15.14).
	#
	# `shoot.gd._size_the_window` does it for every director now (#35), so the two
	# lines that used to be here are gone. This only reports what it got -- a
	# resize that stops taking must not be silent in a director whose whole output
	# is pixels.
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

	# 8b. THE QUIVER, in the hand that counts it — the other half of the numeral
	#     the two frames above prove, and the pair card #52 asked for.
	#
	#     #52 reported the numeral as never drawn, off `gate_eye_row.gd`'s
	#     `g_03`/`g_06`. Those frames had the BOW in the right hand and the
	#     default SHIELD in the left, and `ArmamentDb.hand_count` gave the bow no
	#     numeral (its own docstring: a bow cell carrying the quiver's count
	#     prints the same number twice on one row). The cell that counts arrows is
	#     `arrow`, which lives in LEFT_POOL and which nothing in that director
	#     ever equipped — so both frames were photographing a shield.
	#
	#     Two ids reach this numeral and they arrive by different routes:
	#     `burst` out of RIGHT_POOL, `arrow` out of LEFT_POOL behind
	#     `armament_owned`'s "arrow follows the bow". Photographing one of them
	#     is why the other could be reported missing for a whole card.
	Game.grant(&"bow")
	for _i in Game.RIGHT_POOL.size():
		if Game.armament(&"right") == &"bow":
			break
		Game.cycle_armament(&"right")
	for _i in Game.LEFT_POOL.size():
		if Game.armament(&"left") == &"arrow":
			break
		Game.cycle_armament(&"left")
	Game.arrows = 0
	Bus.ammo_changed.emit(&"arrows", 0)
	await rig.wait_frames(6)
	await _shot(rig, out.path_join("h_13_quiver_empty.png"), "h_13_quiver_empty")

	# Six, because that is what `GateUrn` holds and what #43's `g_06` had in the
	# quiver — the same number, so the two directors' frames can be read side by
	# side.
	Game.add_arrows(6)
	await rig.wait_frames(6)
	await _shot(rig, out.path_join("h_14_quiver_six.png"), "h_14_quiver_six")

	if Game.armament(&"left") != &"arrow" or Game.armament(&"right") != &"bow":
		print("HUD FAIL the bow and quiver never reached the hands (%s/%s) — "
			% [Game.armament(&"right"), Game.armament(&"left")]
			+ "the h_13/h_14 frames prove nothing")
		_fails += 1

	# **The negative case for #53's borrow, and it is asserted on this frame
	# rather than the next one.** With bow + arrow up, the arrow cell IS the
	# count and the bow must stay blank — one numeral on the row, in the LEFT
	# cell. That is the objection `ArmamentDb.hand_count`'s docstring raised
	# against giving the bow a numeral at all, and `hand_count_beside` only
	# survives it if this frame prints exactly once.
	_fails += _one_numeral("h_14_quiver_six", &"ammo_0")

	# 8c. THE SAME QUIVER, WITH THE SHIELD UP — card #53. This is the loadout a
	#     player actually fights in: you find the bow on the Cistern Warden,
	#     cycle right to it, and keep the guard. Nothing in the hero gates firing
	#     on the left hand, so the shield costs you no arrows — it used to cost
	#     you the only readout of how many you had left.
	#
	#     Option 1 of the three the card offered: the bow borrows the numeral
	#     when the arrow cell is not up. The frame above and this one are the
	#     pair that settle it — one number in the LEFT cell there, one number in
	#     the RIGHT cell here, never two.
	#
	#     Asked as `Game.armament(&"left")`, never as `hand_count(&"shield")`:
	#     #52 closed on a director that asserted a call on a **string literal**,
	#     which is true of the table whatever the hero is holding, under a label
	#     that read as a claim about the cell. The rect keys below are stronger
	#     still — they are what the HUD actually drew.
	for _i in Game.LEFT_POOL.size():
		if Game.armament(&"left") == &"shield":
			break
		Game.cycle_armament(&"left")
	await rig.wait_frames(6)
	await _shot(rig, out.path_join("h_15_bow_shield.png"), "h_15_bow_shield")

	if Game.armament(&"left") != &"shield" or Game.armament(&"right") != &"bow":
		print("HUD FAIL the shield never came back up beside the bow (%s/%s) — "
			% [Game.armament(&"right"), Game.armament(&"left")]
			+ "the h_15 frame proves nothing")
		_fails += 1
	_fails += _one_numeral("h_15_bow_shield", &"ammo_1")

	# The borrowed cell at ZERO, because the borrow reaches a path the arrow cell
	# never did. `_draw_item_glyph` dims a spent count two ways — 30% alpha on a
	# TEXTURE, `Pal.MOTH` at 30% on the two-letter fallback — and `arrow` and
	# `burst` are both letter cells (#54: `arrow` has no baked icon). The bow is
	# the first thing to dim an actual icon, and "I have the bow and nothing to
	# fire" is the sentence that has to survive it: the cell must not read as an
	# empty hand.
	Game.arrows = 0
	Bus.ammo_changed.emit(&"arrows", 0)
	await rig.wait_frames(6)
	await _shot(rig, out.path_join("h_16_bow_shield_spent.png"),
		"h_16_bow_shield_spent")
	_fails += _one_numeral("h_16_bow_shield_spent", &"ammo_1")
	# Back to six for the arc frames below, which photograph the whole HUD and
	# should not be photographing a spent one by accident.
	Game.add_arrows(6)

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

	# 10. THE BALLAST WINDOW — card #39, and it is three frames because the card
	#     asks for three and the third is the one that gets skipped.
	#
	#     Ballast soaks three quarters for eight seconds and is paid for with a bag
	#     stack; until now nothing on the HUD said it was running, so the player
	#     read a live ward off the health bar not moving — which only speaks after
	#     something has already hit you, and never says how long is left.
	#
	#     **Driven through `Game.start_draught`, which is the one call
	#     `HeroRanged._cast_ballast` makes to raise this window** (its other three
	#     lines are the burn and the charge). The cast itself is proven in
	#     `relic_donate.gd` K21–K25, on the real ring, in a scene with a bag to
	#     burn; reproducing it here would mean granting the working, faking the
	#     alchemist's reading, and burning the T3 bag three beats above out from
	#     under the frames that need it. This director's subject is the pixels.
	#
	#     The assertions read `Hud.layout_rects()`, never `Game.draught_left` —
	#     `draught_left` is the input the HUD is supposed to be drawing and would
	#     report a healthy window on a HUD that drew nothing at all, which is the
	#     exact state #39 was filed about and the shape of assertion #52 closed on.
	_fails += _ballast_tiles("h_12_arc_left (before any cast)", 0)
	await _shot(rig, out.path_join("h_17_ballast_off.png"), "h_17_ballast_off")
	_fails += _ballast_tiles("h_17_ballast_off", 0)

	Game.start_draught(Game.BALLAST_ID, K.BALLAST_TIME)
	await rig.wait_frames(2)
	await _shot(rig, out.path_join("h_18_ballast_full.png"), "h_18_ballast_full")
	_fails += _ballast_tiles("h_18_ballast_full", Hud.DRAUGHT_TILES)

	# The SAME window, most of the way through. Waited on the WINDOW rather than on
	# a frame count or a sleep: `wait_frames` is the harness's clock and this is the
	# game's, and the whole claim of this pair of frames is that the clock moved
	# between them. `lit = ceil(t01 * 4)`, so ANY remainder in (0, 2.0 s] is one
	# tile: waiting for 1.92 s left puts the reading a whole tick inside that band
	# at the top and the band runs to zero at the bottom, so neither a slow tick
	# nor a slow capture can turn this frame into a 2 or a 0.
	var moved: bool = await rig.until(func() -> bool:
		return Game.draught_left(Game.BALLAST_ID) < K.BALLAST_TIME * 0.24,
		K.BALLAST_TIME + 2.0)
	if not moved:
		print("HUD FAIL the Ballast window never drained — h_19 proves nothing")
		_fails += 1
	await _shot(rig, out.path_join("h_19_ballast_late.png"), "h_19_ballast_late")
	_fails += _ballast_tiles("h_19_ballast_late", 1)

	# And gone. `Game._tick_draughts` erases the id and emits `draught_changed`,
	# which wakes the HUD for one more paint — so an expired window is a repainted
	# empty container and not a stale one left on screen by a HUD that stopped
	# redrawing. Those two look identical in a screenshot and only one of them is
	# correct, which is why this waits on the erase and then repaints twice.
	var over: bool = await rig.until(func() -> bool:
		return Game.draught_left(Game.BALLAST_ID) <= 0.0, 6.0)
	if not over:
		print("HUD FAIL the Ballast window never expired — h_20 proves nothing")
		_fails += 1
	await rig.wait_frames(4)
	await _shot(rig, out.path_join("h_20_ballast_over.png"), "h_20_ballast_over")
	_fails += _ballast_tiles("h_20_ballast_over", 0)

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
