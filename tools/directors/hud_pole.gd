extends RefCounted
## The vitals pole, in every state it has, in both scenes that draw it.
##
## **This is the beat that would have caught the collision in HUD_PLAN §0** — the
## draught row drawn on top of the magic bar in the garrison and four pixels into
## the heat bar underground, which shipped twice and which `alchemy_loop.gd`
## passed straight through both times because none of its checks can see a
## rectangle.
##
## It has to run in BOTH scenes, and that is not a convenience: heat is
## dungeon-only, so the draught row takes a different slot in each, and the
## collision was a DIFFERENT collision in each. A director that only ran one of
## them would have caught one of the two.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/hud_pole.gd --out=/tmp/pole/x.png --warmup=60
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/hud_pole.gd --out=/tmp/pole/x.png --warmup=60
##
## The scene is not switched from in here on purpose. `Flow` owns
## `change_scene_to_file` (CLAUDE.md §6) and a director that drove a transition
## would be photographing the loading card's timing as much as the pole's layout.
## Two runs, one scene each, one prefix each.


const Layout := preload("res://tools/directors/_hud_layout.gd")

var _fails := 0


## Photograph, then assert on the rectangles that were just drawn. In that order,
## and it matters: the check reads `Hud.layout_rects()`, which the capture's own
## repaint is what fills.
func _shot(rig, path: String, tag: String) -> void:
	await rig.capture(path)
	_fails += Layout.check(tag)


## Card #48. **A counter takes the screen, so the HUD stands down for it** — and
## the frame that carded this had the two-row control legend reading out below the
## Lanternkeeper's panel, naming RMB GUARD and D-PAD WEAPON while the counter had
## the input and none of them did anything. That legend is gone (card #121); the
## rule it carded is not, and the bars, the money rim and the extraction fee still
## sit in the strip a counter's scrim does not reach.
##
## Read off `Hud.layout_rects()` and not `Hud.visible`, which is the property the
## fix sets and would therefore agree with itself. The layout dictionary is filled
## by `_draw_hud` and cleared when the overlay stands down, so "empty" here means
## *the HUD published no rectangle for this frame* — the same instrument every
## other assertion in this file reads, pointed at the one state where it used to
## go stale rather than empty.
##
## **Both answers are known and both are demanded, in this order.** With the
## counter up the honest answer is nothing at all; four frames after it closes the
## honest answer is the full pole again, passing assertion 2. Only the second half
## can catch an instrument that has quietly stopped reporting, which is exactly
## how a check like this rots into a no-op.
##
## The POLE is what the second half asks for now. It used to ask for the LEGEND,
## which was the one element a director could force up on demand; with that
## deleted (card #121) `pole` is the element present in every garrison frame and
## absent from every stood-down one, so it is the honest witness.
func _counter_stands_the_hud_down(rig, out: String) -> int:
	var fails := 0
	var before: int = Hud.layout_rects().size()

	# Her own catalogue, so the board that appears is the one the carded frame
	# was of. Opened directly rather than walked to: `relic_donate.gd` owns
	# whether she can be reached, and this is a question about layering.
	var screen := TradeScreen.open(rig.scene(), TradeScreen.Mode.PROGRESSION,
		"THE FAR LANTERN", RelicDb, &"keeper", "Artifacts")
	await rig.wait_frames(12)
	await rig.capture(out.path_join("g_11_counter.png"))

	var during: Dictionary = Hud.layout_rects()
	if during.is_empty():
		print("  ok   POLESHOP counter up: the HUD published 0 rects (was %d)"
			% before)
	else:
		print("POLE FAIL the counter is up and the HUD still drew %d rect(s), "
			% during.size() + "including %s" % [during.keys().slice(0, 6)])
		fails += 1

	screen.close()
	# The layer is `queue_free`d, so the HUD's own `node_removed` deferral needs a
	# frame to land before the second half of the calibration is asked.
	await rig.wait_frames(8)
	await _shot(rig, out.path_join("g_12_counter_gone.png"), "g_12_counter_gone")
	if Hud.layout_rects().has(&"pole"):
		print("  ok   POLESHOP counter closed: the pole is back (%d rects)"
			% Hud.layout_rects().size())
	else:
		print("POLE FAIL the counter closed and the pole never came back — "
			+ "the frame above proves nothing about the counter")
		fails += 1
	return fails


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/pole/x.png").get_base_dir()
	await rig.wait_frames(30)

	var underground: bool = Run != null and Run.in_dungeon
	var tag := "d" if underground else "g"

	# 0 draughts: the state every run starts in and spends most of its life in.
	# Before decision 21 this frame drew NO draught row at all.
	await rig.wait_frames(6)
	await _shot(rig, out.path_join("%s_00_dry.png" % tag), "%s_00_dry" % tag)

	# 1 draught: one slot lit, one slot empty. The frame that proves the slots are
	# fixed by kind — the lit one must be the SECOND slot, because Emberblood is
	# second in `PotionDb.IDS` order and slots do not pack leftward any more.
	Game.start_draught(&"emberblood_draught", K.DRAUGHT_TIME)
	await rig.wait_frames(6)
	await _shot(rig, out.path_join("%s_01_ember.png" % tag), "%s_01_ember" % tag)

	# The other one alone, so the pair cannot both be passing by accident.
	Game.draughts.clear()
	Game.start_draught(&"ironhide_draught", K.DRAUGHT_TIME)
	await rig.wait_frames(6)
	await _shot(rig, out.path_join("%s_02_hide.png" % tag), "%s_02_hide" % tag)

	# The row full — all THREE slots, because the third one is the Ballast window
	# (#39) and it is not a draught. The row is the same width whatever is in it
	# (`Pal.DRAUGHT_RATIO` off the health bar), so the safe-margin claim is still
	# made against this frame; what three slots changes is the slot, from 73 px to
	# 47, and this is the frame that says whether a 47 px slot still reads as a
	# mark and four countable tiles.
	Game.start_draught(&"emberblood_draught", K.DRAUGHT_TIME)
	Game.start_draught(Game.BALLAST_ID, K.BALLAST_TIME)
	await rig.wait_frames(6)
	await _shot(rig, out.path_join("%s_03_both.png" % tag), "%s_03_both" % tag)

	# A draught nearly out: the tiles have to have gone out one at a time, and the
	# last one has to still be lit. `ceil` in `_draw_draughts` is what guarantees
	# the second half of that.
	#
	# Three different fills, one per slot, and Ballast's is SET rather than left
	# running: it is an 8 s window against a draught's 45, so a frame that let it
	# tick would photograph a different number of tiles on every machine.
	Game.draughts[&"emberblood_draught"] = K.DRAUGHT_TIME * 0.2
	Game.draughts[&"ironhide_draught"] = K.DRAUGHT_TIME * 0.6
	Game.draughts[Game.BALLAST_ID] = K.BALLAST_TIME * 0.4
	await rig.wait_frames(4)
	await _shot(rig, out.path_join("%s_04_expiring.png" % tag), "%s_04_expiring" % tag)

	# Magic spent. The bar's zero state is an empty track, and an empty track is
	# the thing that has to still read as an instrument.
	Game.magic = 0
	Bus.magic_changed.emit(Game.magic, Game.max_magic)
	await rig.wait_frames(4)
	await _shot(rig, out.path_join("%s_05_magic_spent.png" % tag), "%s_05_magic_spent" % tag)
	Game.fill_magic()

	# Low health: the pulse is VITAL <-> VOID now, and the frame this exists to
	# disprove is the one where it borrowed BONE from the stamina bar below it.
	Game.damage(Game.quarters - 2)
	await rig.wait_frames(4)
	await _shot(rig, out.path_join("%s_06_low.png" % tag), "%s_06_low" % tag)

	if underground:
		# Each heat tier, because heat's row sits between magic and the draughts
		# and nothing else photographs the pole at Blazing. Driven through
		# `Bus.enemy_died`, which is the signal `Heat` actually listens to —
		# poking `Heat.kills` would set the count without the tier, the window or
		# the announcement, and the frame would be of a state the game cannot
		# reach.
		var hero := rig.get_first_node_in_group(&"player") as Node3D
		var at: Vector3 = hero.global_position if hero != null else Vector3.ZERO
		for target in [3, 7, 13]:
			while Heat.kills < target:
				Bus.enemy_died.emit(hero, at)
			await rig.wait_frames(4)
			await _shot(rig, out.path_join("%s_07_heat_t%d.png" % [tag, Heat.tier]),
				"%s_heat_t%d" % [tag, Heat.tier])

	if not underground:
		# **The bottom strip is EMPTY, and that is the assertion.** The control
		# legend used to fade in and hold across it (decision 8); card #121
		# deleted it, and the three beats that photographed its fades went with
		# it. What replaced them is the null case — a settled garrison frame,
		# well past the ten seconds the window used to run for, on which no
		# `legend` rect may be published by anything. A removal nothing checks
		# is a removal that comes back.
		await rig.wait_frames(45)
		await _shot(rig, out.path_join("g_09_no_legend.png"), "g_09_no_legend")
		if Hud.layout_rects().has(&"legend"):
			print("POLE FAIL a `legend` rect is being published — card #121 "
				+ "removed the control legend and something has put it back")
			_fails += 1
		else:
			print("  ok   POLE no legend in the garrison strip (%d rects: %s)"
				% [Hud.layout_rects().size(), Hud.layout_rects().keys()])

		_fails += await _counter_stands_the_hud_down(rig, out)

	print("POLECHECK scene=%s draughts=%d magic=%d/%d q=%d layout_fails=%d" % [
		tag, Game.draughts.size(), Game.magic, Game.max_magic, Game.quarters, _fails])
	if _fails > 0:
		print("POLE FAIL %d layout assertion(s) — see HUDLAYOUT lines above" % _fails)
