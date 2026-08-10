extends RefCounted
## The forge, end to end: a component on the floor becomes a longer chain.
##
## Point it at GARRISON. It descends on its own, because half the claims here are
## about what survives the trip and you cannot test that from one side of it.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/forge_loop.gd \
##     --out=/tmp/forge/x.png --warmup=60
##
## What it claims, in the order it proves them:
##
##   A  Components are in the catalogue and on the drop tables.
##   B  The pouch draws `Game.bag_slots` cells and marks the components.
##   C  The smith names a component cost and REFUSES when the bench is short.
##   CH Forging is a HOLD, it shows a gauge while you hold it, and a tap does
##      nothing -- the same contract the gate has, at the counter.
##   D  Buying a rung moves the number the gear actually reads -- the arc, the
##      draw, the reach, the edge, the plate -- not just a counter.
##   E  A component on the dungeon floor is picked up by WALKING OVER IT.
##   F  Extraction sorts components onto the bench and leaves the vendor the rest.
##   G  Death takes the bag, components included.
##   P  The armour is FOUR pieces on TWO paths, a piece commits for good, and
##      the four together land where the one `plate` ladder used to.
##
## D is the one that matters. Every other claim is bookkeeping; D is the claim
## that the money bought something the player can feel, and it is checked against
## `Game`'s own accessors rather than against `upgrades`, because a rung that
## incremented a counter and changed no behaviour is exactly the bug a "level"
## system produces.

var out := ""
var _fails := 0


func run(rig) -> void:
	out = rig.arg("out", "/tmp/forge/x.png").get_base_dir()
	_teach_the_smith()
	await rig.wait_frames(20)

	_catalogue()
	_plate_split()
	await _pouch(rig)
	await _smith(rig)
	await _descend(rig)
	await _sweep(rig)
	await _bank(rig)
	await _death(rig)
	await _save(rig)

	if _fails == 0:
		print("FORGE OK")
	else:
		print("FORGE FAIL -- %d check(s) failed" % _fails)


## The ladders are now RATIONED by two of the twelve relics: the smith knows
## rung 1 from the start, rung 2 after the Tally-Ledger and the rest after the
## Imperium Anvil-Plate (`RelicDb.forge_rungs_known()`, GDD §6.2 relics 1 and 2).
## Every D-beat below is written about a FULLY CLIMBED ladder -- "the finished
## chain is exactly the Longshot" is a claim about rung 3 -- and on a fresh save
## the ladder now stops at rung 1, so five checks failed on a forge that was
## working exactly as designed.
##
## Donated here, out loud, as a precondition. That the relics are what open the
## rungs is `relic_donate.gd`'s claim and is proved there; this director's
## subject is what the top of a ladder is worth once you can reach it.
func _teach_the_smith() -> void:
	for id: StringName in RelicDb.RUNG_RELICS:
		Game.set_flag(RelicDb.flag_donated(id))
	print("FORGE precondition: donated %s -- the ladders are rationed by them now"
		% [RelicDb.RUNG_RELICS])


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_fails += 1
		print("FORGE FAIL %s" % label)


# --- A. The catalogue -------------------------------------------------------

func _catalogue() -> void:
	# The FORGE's four, specifically. The alchemist's materials are the same kind
	# and share the same workbench (docs/METAGAME.md §6.6), so an unfiltered
	# `components()` has counted eight since the bottles landed -- and the claims
	# below are about the forge's table, not about how many benches exist.
	var parts := ItemDb.components(ItemDef.BENCH_FORGE)
	print("FORGE components=%s" % [parts])
	_ck("A0 four components exist", parts.size() == 4)
	for id in parts:
		var def := ItemDb.get_def(id)
		_ck("A1 %s is marked a component" % id, def != null and def.is_component())
	# A component nothing drops is a recipe nobody can fill. Both tables are
	# checked because they are tuned separately and the rare one is chest-only
	# on purpose -- if it ever leaks onto the enemy table, grinding room one
	# finishes every ladder.
	var on_enemy := 0
	for id in parts:
		if ItemDb.ENEMY_DROPS.has(id):
			on_enemy += 1
		_ck("A2 %s drops from chests" % id, ItemDb.CHEST_DROPS.has(id))
	_ck("A3 three of the four drop off bodies; the core does not",
		on_enemy == 3 and not ItemDb.ENEMY_DROPS.has(&"cold_iron_core"))


# --- P. The armour split ----------------------------------------------------
## docs/GDD.md §6.6, and the beat that would have caught the tuning trap the GDD
## warns about by name: four pieces each carrying `[0, 1, 2, 3]` is TWELVE
## quarter-hearts against a bestiary tuned for three, which would put every blow
## in the game on `Hero.hurt`'s one-quarter floor.
##
## Run on a scratch `upgrades` and put back afterwards, because every later beat
## in this file is written against the rungs it buys itself.
func _plate_split() -> void:
	var saved := Game.upgrades.duplicate()

	# The eight tracks the smith must actually stock. The ids in `ShopDb.LIMITS`
	# are spelled by hand (a const initialiser cannot loop), so this is the beat
	# that catches the typo -- a missing row reads as "the smith sells that one
	# forever" and nothing else in the build would notice.
	var missing: Array[StringName] = []
	for track: StringName in Game.PLATE_TRACKS:
		if not ShopDb.LIMITS.has(track) or not ShopDb.PARTS.has(track):
			missing.append(track)
	_ck("P0 every plate track is stocked and has a recipe (%s)" % [missing],
		missing.is_empty())
	_ck("P0b `plate` itself is gone from the board",
		not ShopDb.LIMITS.has(Game.FORGE_PLATE)
			and not ShopDb.PARTS.has(Game.FORGE_PLATE))

	# The two ceilings the GDD names. Not "about 4" -- the exact float, because
	# the tables were written to hit it and a later hand rounding them into
	# integers is the change this beat exists to fail on.
	Game.upgrades.clear()
	for piece: StringName in Game.PLATE_PIECES:
		Game.upgrades[Game.plate_track(piece, Game.PLATE_HEAVY)] = K.FORGE_MAX
	print("PLATE full-heavy soak=%.2f speed=%.4f" % [
		Game.armour_soak_exact(), Game.speed_mult()])
	_ck("P1 four heavy pieces soak 4 quarters",
		is_equal_approx(Game.armour_soak_exact(), 4.0))
	_ck("P2 and cost exactly 8% of the run (never K.RUN_SPEED itself)",
		is_equal_approx(snappedf(Game.speed_mult(), 0.0001), 0.92))

	Game.upgrades.clear()
	for piece: StringName in Game.PLATE_PIECES:
		Game.upgrades[Game.plate_track(piece, Game.PLATE_LIGHT)] = K.FORGE_MAX
	print("PLATE full-light soak=%.2f speed=%.4f" % [
		Game.armour_soak_exact(), Game.speed_mult()])
	_ck("P3 four light pieces soak 2 quarters",
		is_equal_approx(Game.armour_soak_exact(), 2.0))
	_ck("P4 and cost nothing at all", is_equal_approx(Game.speed_mult(), 1.0))

	# The commitment. One rung on one path shuts the other for that piece and
	# leaves the other three pieces free -- which is what makes "heavy chest,
	# light boots" a build rather than a bug.
	Game.upgrades.clear()
	Game.upgrades[Game.plate_track(&"chest", Game.PLATE_HEAVY)] = 1
	var light_chest := Game.plate_track(&"chest", Game.PLATE_LIGHT)
	_ck("P5 the chest's light path is closed", Game.path_closed(light_chest))
	_ck("P6 the smith will not sell it", ShopDb.cap_of(light_chest) == 0)
	_ck("P7 and says WHY (%s)" % ShopDb.refusal({"id": light_chest, "cost": 0}),
		ShopDb.refusal({"id": light_chest, "cost": 0}).contains("COMMITTED"))
	_ck("P8 the row is gone from the counter, not greyed",
		not ShopDb.stocked(light_chest))
	_ck("P9 the boots are still an open question",
		not Game.path_closed(Game.plate_track(&"boots", Game.PLATE_LIGHT))
			and ShopDb.cap_of(Game.plate_track(&"boots", Game.PLATE_LIGHT)) > 0)

	Game.upgrades = saved


# --- B. The pouch -----------------------------------------------------------

func _pouch(rig) -> void:
	# A bag with one of everything in it, so the grid has a component cell, an
	# ingredient cell and empty cells all on screen at once.
	Run.in_dungeon = false
	Run.collect(&"whetstone_grit", 6)
	Run.collect(&"tension_coil", 4)
	Run.collect(&"deep_amber", 2)
	Run.collect(&"bone_shard", 9)
	await rig.wait_frames(6)

	Menu.open()
	await rig.wait_frames(6)
	# Straight to the screen rather than walking the root list: the root list is
	# critic_menu.gd's job and driving it here would only test the same buttons
	# twice.
	Menu._push({"screen": PauseMenu.Screen.POUCH})
	await rig.wait_frames(12)

	var pouch: MenuPouchPanel = Menu.get_node("Root/Screens/PouchScreen")
	_ck("B0 the pouch screen is showing", pouch.visible)
	# Counted off the shared `ItemGrid` rather than off a list of buttons the
	# panel used to keep: the grid IS the drawn cells now, so this reads what is
	# on screen instead of a parallel array that could agree with nothing.
	var drawn: int = pouch.grid().count()
	_ck("B1 it draws one cell per bag slot (%d of %d)" % [drawn, Game.bag_slots],
		drawn == Game.bag_slots)
	var filled := 0
	for id in pouch._cell_ids:
		if id != &"":
			filled += 1
	_ck("B2 filled cells match Run.slots_used() (%d of %d)" % [
		filled, Run.slots_used()], filled == Run.slots_used())
	_ck("B3 something is focused",
		Menu.get_viewport().gui_get_focus_owner() != null)
	# The frame has to fit on the screen, and nothing else here notices when it
	# does not. Six columns of 150 px built a 1400 px frame inside a 1280 px
	# viewport: every check above still passed while the detail column and the
	# Back button rendered off the right edge. A CenterContainer clips an
	# oversized child, it does not shrink it.
	var frame: Control = pouch.get_node("Center/Frame")
	var screen_size := Vector2(Menu.get_viewport().get_visible_rect().size)
	print("FORGE pouch frame=%.0fx%.0f viewport=%.0fx%.0f" % [
		frame.size.x, frame.size.y, screen_size.x, screen_size.y])
	_ck("B4 the pouch frame fits on the screen",
		frame.size.x <= screen_size.x and frame.size.y <= screen_size.y)
	await rig.capture(out.path_join("f_00_pouch.png"))

	Menu.close()
	await rig.wait_frames(10)


# --- C and D. The smith -----------------------------------------------------

func _smith(rig) -> void:
	# THE COUNTER IS FIFTEEN LINES ONLY IF YOU OWN THE BOW AND THE HOOKSHOT AND
	# HAVE COMMITTED NO ARMOUR PIECE.
	# `ShopDb.GATED_BY` hides the `string` and `chain` ladders and the arrow line
	# until the weapon they sharpen is owned (docs/SCOPE.md M1), and
	# `Game.STARTER_KIT` is empty now -- so a cold boot stands at this counter
	# and sees TWELVE rows, not fifteen. From the other end, each of the four
	# armour pieces drops its losing path the moment it commits (GDD §6.6), so a
	# finished hero sees eleven. The count asserted below is the widest the board
	# ever gets, which is also the one the panel has to be able to draw.
	#
	# This director is the FORGE, and the ladder it drives by name below is the
	# chain. Granting the two weapons is the setup that makes the subject
	# reachable; it is not the thing under test. The gate itself -- that the rows
	# really are absent before you own the weapon, and really do appear after --
	# is tools/directors/gate_locks.gd's B and D beats, which is where M1 put it.
	Game.grant(&"bow")
	Game.grant(&"hookshot")

	var garrison := rig.scene() as Garrison
	_stand_at(rig, garrison.smith.global_position + Vector3(0.0, 0.0, 1.6))
	await rig.wait_frames(20)
	await rig.tap(["interact"])
	await rig.wait_frames(16)

	var screen := _screen(rig)
	if screen == null:
		print("FORGE FAIL the smith did not open")
		return
	_ck("C0 the smith lists fifteen lines (7 + the armour's 4x2)",
		screen._rows.size() == 15)
	# Fifteen rows against a panel that fits about thirteen. The window is the
	# only reason the boots are reachable at all, and a list that silently ran
	# off the bottom would look exactly like a list that was complete.
	_ck("C0b the panel windows rather than overflowing",
		screen._rows.size() > 8)

	# --- C. Refusal, with the right reason ------------------------------------
	# Rich, and holding nothing. The chain is the track the owner named by its
	# number, so it is the one driven here.
	Game.gold = 40000
	Game.components.clear()
	screen._refresh()
	var chain := _row(screen, &"chain")
	_ck("C1 the chain line exists", not chain.is_empty())
	if chain.is_empty():
		return
	_ck("C2 it names a component cost", not (chain["parts"] as Dictionary).is_empty())
	_ck("C3 gold alone cannot buy it", not ShopDb.can_buy(chain["line"]))
	_ck("C4 the refusal names the component, not the money (%s)"
		% ShopDb.refusal(chain["line"]),
		ShopDb.refusal(chain["line"]).contains("COIL"))
	screen._cursor = screen._rows.find(chain)
	screen._commit()
	await rig.wait_frames(20)
	_ck("C5 the press changed nothing", Game.forge_level(Game.FORGE_CHAIN) == 0)
	await rig.capture(out.path_join("f_01_short.png"))

	# --- D. Buy every rung of every ladder, and watch the gear move -----------
	var before := {
		"edge": Game.sword_bonus(),
		"plate": Game.armour_soak(),
		"guard": Game.guard_arc(),
		"string": Game.bow_draw_time(),
		"chain": Game.hook_reach(),
	}
	print("FORGE base edge=+%d plate=-%d guard=%.0f draw=%.2f reach=%.2f" % [
		before["edge"], before["plate"], before["guard"],
		before["string"], before["chain"]])

	# Stock the bench past the total of every recipe on the board. 40 of each was
	# NOT enough and the shortfall read as "the chain ladder stops at rung two":
	# coil is wanted by both the bow and the chain, 43 between them, so the last
	# rung silently refused. A director whose own stock is a hidden variable will
	# blame the game for the director's arithmetic.
	for id in ItemDb.components():
		Game.add_component(id, 120)
	screen._refresh()
	await rig.wait_frames(8)
	await rig.capture(out.path_join("f_02_forge.png"))

	await _forge_is_a_hold(rig, screen)

	# The top rung the smith can currently reach, which is NOT `K.FORGE_MAX`.
	# `ShopDb.cap_of` clamps a ladder by `RelicDb.forge_rungs_known()` -- 1 until
	# the Tally-Ledger of Fair Weights is donated, 2 until the Imperium
	# Anvil-Plate -- so on a cold boot every ladder legitimately stops at rung
	# one, and this check asserted 3 and called the game broken.
	#
	# It went unnoticed because it was UNREACHABLE: garrison.gd has not parsed
	# since c1e53a8, so this whole beat was skipped and the run reported green
	# on a ladder it never climbed. Asserting the taught ceiling instead of the
	# absolute one still catches the failure this check exists for -- a ladder
	# that stops short of what the smith knows -- and it will follow the ceiling
	# up on its own as the relics land, with no edit here.
	for track in Game.FORGE_TRACKS:
		var top: int = ShopDb.cap_of(track)
		for _rung in K.FORGE_MAX:
			var line := ShopDb.lines().filter(
				func(l: Dictionary) -> bool: return l["id"] == track)
			if line.is_empty() or not ShopDb.buy(line[0]):
				break
		_ck("D0 %s reached the top rung the smith knows (%d of %d, ceiling %d)" % [
			track, Game.forge_level(track), K.FORGE_MAX, top],
			Game.forge_level(track) == top)
	print("FORGE rungs taught=%d of %d (relics donated: %d)"
		% [RelicDb.forge_rungs_known(), K.FORGE_MAX, RelicDb.donated_count()])

	print("FORGE full edge=+%d plate=-%d guard=%.0f draw=%.2f reach=%.2f" % [
		Game.sword_bonus(), Game.armour_soak(), Game.guard_arc(),
		Game.bow_draw_time(), Game.hook_reach()])
	_ck("D1 the blade bites deeper", Game.sword_bonus() > before["edge"])
	_ck("D2 the armour soaks more", Game.armour_soak() > before["plate"])
	_ck("D3 the guard arc widened", Game.guard_arc() > before["guard"])
	_ck("D4 the bow draws faster", Game.bow_draw_time() < before["string"])
	_ck("D5 the chain got longer (%.2f m -> %.2f m)" % [
		before["chain"], Game.hook_reach()], Game.hook_reach() > before["chain"])
	# The top of the chain ladder IS [oot]'s Longshot. If this drifts, the table
	# stopped meaning what its comment says it means.
	#
	# Read off the TABLE, not off `Game.hook_reach()`. The relic gate above holds
	# the ladder at rung one on a cold boot, so the reach the shop can actually
	# produce here is 11.89 m -- and this check has never been about the shop. It
	# is about `K.CHAIN_REACH`'s last entry still being the Longshot, which is a
	# claim about the constants file and is just as true at rung one.
	_ck("D6 the top of the chain table is exactly the Longshot",
		is_equal_approx(K.CHAIN_REACH[K.FORGE_MAX], K.HOOK_LONGSHOT_RANGE))
	# A finished ladder must be refused, or gold buys a fourth rung off the end
	# of the array and the game crashes indexing K.
	var done := _row(screen, &"chain")
	if not done.is_empty():
		_ck("D7 a finished ladder is refused", not ShopDb.can_buy(done["line"]))

	screen._refresh()
	await rig.wait_frames(8)
	await rig.capture(out.path_join("f_03_forged.png"))

	# Close it and WAIT FOR IT TO BE GONE. The trade screen holds `Prompt.block`
	# for its whole life, so a screen still shutting means `Prompt.focus` is null
	# at the gate, the hold goes nowhere, and every beat after it reports a
	# failure it did not cause. mvp_loop.gd learned this the expensive way and
	# left a comment about it; a fixed frame count is the wrong instrument.
	await rig.tap(["ui_cancel"])
	for _i in 60:
		if _screen(rig) == null:
			break
		await rig.wait_frames(2)
	_ck("D8 the smith's screen closed", _screen(rig) == null)
	await rig.wait_frames(10)

	# The hero standing in the garrison was built before any of that. Prove the
	# SPAWNED gear reads the ladder, not just the accessor -- hero_combat
	# applies the arc in _ready, so only a fresh hero has it, and that is
	# exactly why the descent below is part of this director rather than a
	# separate one.
	var hero: Node = rig.get_nodes_in_group(&"player")[0]
	print("FORGE garrison hero block_cone=%.0f (built before the forge)"
		% hero.combat.block_cone)


# --- CH. Forging is a hold ---------------------------------------------------

## The counter's half of the rule in `HoldGauge`: a commit that eats MATERIALS
## wants the button held, it shows a gauge for the whole hold, and letting go
## early does nothing at all.
##
## Driven with real presses. Every other beat in this file reaches past the input
## layer and calls `screen._commit()` -- which is right, they are about the
## economy -- and that is exactly why this one must not: the thing under test IS
## the input path, and a director that reached past it would still pass with the
## hold deleted and the gauge never drawn.
## `screen` is untyped, like `rig`: annotating it `TradeScreen` made this call
## fail once with "argument 2 (previously freed) is not a subclass of the
## expected argument class" on a screen that was demonstrably alive and in the
## tree one line earlier. A director is not the place to spend an afternoon on a
## class-cache race.
func _forge_is_a_hold(rig, screen) -> void:
	var chain := _row(screen, &"chain")
	if chain.is_empty():
		_ck("CH0 there is a chain rung to hold", false)
		return
	screen._cursor = screen._rows.find(chain)
	screen._hold = 0.0
	await rig.wait_frames(4)

	# Annotated, not inferred: `screen` is untyped above, so everything read off
	# it is a Variant and `:=` cannot infer a float from one (CLAUDE.md §3).
	var need: float = screen._hold_time(screen._cursor)
	var before := Game.forge_level(Game.FORGE_CHAIN)
	_ck("CH0 the chain rung wants a hold (%.2f s)" % need, need > 0.0)
	# The other kind of line, and the reason `_hold_time` asks the catalogue
	# rather than the mode: arrows are gold-only, re-buyable, and a hold on them
	# would be the ceremony that teaches players to stop reading holds.
	var arrows := _row(screen, &"arrows")
	_ck("CH1 a gold-only line is still a tap",
		not arrows.is_empty()
		and is_zero_approx(screen._hold_time(screen._rows.find(arrows))))
	# The footer says the SMITH's word, not the UI's. It shipped as "CRAFT" for
	# one build because a static in `Catalogue` calling another static in
	# `Catalogue` never reaches `ShopDb` -- caught by looking at the frame, so it
	# is checked in text here where a glance cannot miss it.
	_ck("CH1b the footer speaks the smith's word (%s)" % screen._verb(),
		str(screen._verb()) == "FORGE")

	await rig.tap(["ui_accept"])
	await rig.wait_frames(10)
	_ck("CH2 a tap forges nothing", Game.forge_level(Game.FORGE_CHAIN) == before)

	# Sampled every frame and released on the FIRST reading. NOT read once after a
	# fixed wait: the gauge advances by `delta`, so N frames is N frames of
	# unknown duration (`shoot.hold_seconds` says this in as many words), and the
	# alchemist's twin of this beat duly read 0.00 on a slow run where the whole
	# hold had already elapsed and the commit had reset the bar.
	Input.action_press(&"ui_accept")
	var peak := 0.0
	for _i in 30:
		await rig.wait_frames(1)
		peak = maxf(peak, screen._hold)
		if peak > 0.0:
			break
	Input.action_release(&"ui_accept")
	await rig.wait_frames(6)
	print("FORGE craft hold peak=%.2f of %.2f s" % [peak, need])
	_ck("CH3 the gauge fills while the button is down (%.2f)" % peak, peak > 0.0)
	_ck("CH4 letting go snaps it back to zero (%.2f)" % screen._hold,
		is_zero_approx(screen._hold))
	_ck("CH5 and forged nothing", Game.forge_level(Game.FORGE_CHAIN) == before)

	# Held through, with the shutter open one frame in: the frame is the proof,
	# and no assertion about a float can see a bar that renders off its row.
	Input.action_press(&"ui_accept")
	await rig.wait_frames(1)
	await rig.capture(out.path_join("f_02b_hold.png"))
	# And from here in GAME SECONDS, not frames -- 45 frames is 0.75 s at 60 Hz
	# and 0.37 s at 120, and only one of those outlasts a 0.5 s hold.
	await rig.hold_seconds(["ui_accept"], 0.9)
	await rig.wait_frames(10)
	_ck("CH6 holding it through forges the rung (%d -> %d)" % [
		before, Game.forge_level(Game.FORGE_CHAIN)],
		Game.forge_level(Game.FORGE_CHAIN) == before + 1)


# --- E and F. Underground ---------------------------------------------------

func _descend(rig) -> void:
	var garrison := rig.scene() as Garrison
	_stand_at(rig, garrison.gate.global_position + Vector3(0.0, 0.0, 1.8))
	# Wait for THE GATE to own the button, not for "something" to. The teleport
	# out of the smith's trigger takes a physics frame or two to register as an
	# exit, and until it does `Prompt.focus` is still the smith -- non-null, so a
	# "focus != null" wait breaks instantly and the 0.9 s hold that follows
	# re-opens the shop instead of opening the gate. That is exactly how this
	# beat failed here, and the whole run then reported an economy bug it did not
	# have. `Prompt.focus != null` is not the state you need; the gate is.
	for _i in 90:
		if Prompt.focus == garrison.gate:
			break
		await rig.wait_frames(2)
	print("FORGE gate focus=%s blocked=%s" % [
		Prompt.focus.prompt if Prompt.focus != null else "<none>", Prompt.blocked])
	_ck("E0a the gate owns the interact button", Prompt.focus == garrison.gate)
	# The gate wants a 0.9 s hold. A tap must not open it -- that is the whole
	# point of the hold, and it is one press to prove.
	await rig.tap(["interact"])
	await rig.wait_frames(20)
	_ck("E0b a tap does not open the gate", not Run.in_dungeon)

	# Hold until the descent registers, rather than for a fixed 1.3 s and a shrug.
	# `rig.hold_seconds` was what this used and it left `Prompt._hold` at 0.00
	# with `_armed` false -- the button never reached Prompt at all.
	#
	# This beat is also what found the bug that made every director on this
	# machine flaky: a GAMEPAD on the desk. Sticks resting just outside the
	# deadzone reported `move_up` / `move_right` held, the hero walked out of the
	# gate's radius mid-hold, `Prompt` dropped focus, and the run reported five
	# economy failures for a gate it had never reached. `shoot.gd` now strips
	# joypad bindings for the life of a capture run.
	#
	# The re-plant stays: the hero has physics, and losing focus zeroes `_hold`
	# with nothing printed, so the bar restarts and the beat lies about why.
	Input.action_press(&"interact")

	# The gate's own glow is the diegetic half of this and the HUD's gauge is the
	# legible half; the bug being guarded against is a hold that ships with
	# neither. `Hud` mirrors `Bus.hold_changed`, so reading it is reading what
	# got drawn, and the shutter opens on the first frame it is non-zero.
	#
	# Sampled per frame and kept as a PEAK. Read once after twenty frames it
	# failed two runs in three on a loaded machine -- twenty frames is 0.9 s if
	# the frames are 45 ms, the descent had already happened, and the gauge it
	# went looking for had correctly gone back to zero along with the garrison.
	var peak := 0.0
	var required := false
	var shot := false
	for _i in 40:
		await rig.wait_frames(1)
		peak = maxf(peak, Hud._hold01)
		required = required or Hud._hold_required
		if not shot and peak > 0.0:
			shot = true
			await rig.capture(out.path_join("f_03_gate_hold.png"))
		if Run.in_dungeon:
			break
	print("FORGE gate gauge peak=%.2f required=%s" % [peak, required])
	_ck("E0c the HUD knows the gate is a hold", required)
	_ck("E0d the gauge filled while he held it (%.2f)" % peak, peak > 0.0)

	for _i in 12:
		await rig.wait_frames(8)
		if Run.in_dungeon:
			break
		if Prompt.focus != garrison.gate:
			_stand_at(rig, garrison.gate.global_position + Vector3(0.0, 0.0, 1.8))
	Input.action_release(&"interact")
	print("FORGE post_hold in_dungeon=%s busy=%s scene=%s" % [
		Run.in_dungeon, Flow.busy, rig.scene().name])
	await rig.wait_frames(140)
	_ck("E0 he went down", Run.in_dungeon)

	var hero: Node = rig.get_nodes_in_group(&"player")[0]
	print("FORGE dungeon hero block_cone=%.0f" % hero.combat.block_cone)
	_ck("E1 the freshly spawned hero carries the forged guard arc",
		is_equal_approx(hero.combat.block_cone, Game.guard_arc()))


func _sweep(rig) -> void:
	var hero: Node3D = rig.get_nodes_in_group(&"player")[0]
	Run.bag.clear()
	Run.premium = 0
	Bus.bag_changed.emit(Run.bag, 0)
	await rig.wait_frames(4)

	# Three components on the floor, a stride away, with no button anywhere near
	# them. Walking over a drop IS the pickup (LootMote answers overlap), and
	# this is the claim the owner asked for by name.
	var at := hero.global_position
	var drops: Array[LootMote] = []
	for i in 3:
		var id: StringName = [&"whetstone_grit", &"tension_coil", &"riveted_plate"][i]
		drops.append(LootMote.drop(rig.scene(), id,
			at + Vector3(0.9 * (float(i) - 1.0), 0.0, 1.4)))
	await rig.wait_frames(40)
	_ck("E2 three motes are on the floor", _motes(rig).size() >= 3)
	await rig.capture(out.path_join("f_04_motes.png"))

	var before := Run.bag_count()
	for m in drops:
		if is_instance_valid(m):
			_stand_at(rig, m.global_position)
			await rig.wait_frames(20)
	print("FORGE swept bag=%d value=%d" % [Run.bag_count(), Run.bag_value()])
	_ck("E3 walking over them picked them up, with no button pressed",
		Run.bag_count() >= before + 3)
	_ck("E4 they are in the bag by name",
		Run.bag.has(&"whetstone_grit") and Run.bag.has(&"tension_coil"))
	await rig.capture(out.path_join("f_05_swept.png"))


func _bank(rig) -> void:
	# Something for the vendor too, so the sort has two kinds to separate.
	Run.collect(&"void_pearl", 1)
	await rig.wait_frames(4)
	var stock_before := Game.component_count(&"whetstone_grit")
	var fee := Run.extract_cost()
	var value := Run.bag_value()
	print("FORGE pre_extract bag=%d fee=%d" % [value, fee])
	# The fee is charged on the WHOLE bag. A component that dodged the toll
	# would make carrying one strictly better than carrying a pearl, and the
	# slot decision would evaporate.
	_ck("F0 the fee is a quarter of the bag, components included",
		fee == maxi(Run.EXTRACT_MIN, int(round(value * Run.EXTRACT_RATE))))

	Game.gold = 5000
	_ck("F1 extraction succeeded", Run.extract())
	await rig.wait_frames(90)

	print("FORGE home bench=%s bag=%s" % [Game.components, Run.bag])
	_ck("F2 the components reached the bench",
		Game.component_count(&"whetstone_grit") > stock_before)
	var left_over := false
	for id: StringName in Run.bag:
		if ItemDb.is_component(id):
			left_over = true
	_ck("F3 no component is left in the vendor's bag", not left_over)
	_ck("F4 the merchandise stayed", Run.bag.has(&"void_pearl"))
	await rig.wait_frames(30)
	await rig.capture(out.path_join("f_06_home.png"))


# --- G. What death takes ----------------------------------------------------

func _death(rig) -> void:
	# Simulated rather than fought: `Run.die()` is the rule under test, and
	# arranging a real death underground is p4_combat.gd's job.
	Run.enter(4242)
	Run.collect(&"cold_iron_core", 1)
	Run.collect(&"tension_coil", 3)
	var bench := Game.component_count(&"cold_iron_core")
	_ck("G0 a core is in the bag", Run.bag.has(&"cold_iron_core"))
	Run.die()
	# Wait out the WHOLE ride home, not a fixed 20 frames. `Run.die()` starts a
	# Flow transition, and game_flow.gd `_go` autosaves at the very END of it --
	# after the fade in. Twenty frames returns while that is still in flight, so
	# the autosave lands somewhere inside H below: `Saves.save(2)` has already
	# made 2 the active slot by then, and if the stray write arrives after
	# `Game.reset()` it overwrites the slot with the wiped state and H1/H2/H4
	# fail for a reason that has nothing to do with the save format. Roughly one
	# run in two, and it moves whenever anything upstream changes frame timing.
	# Same shape as autosave.gd's `_settle`, and for the same reason.
	for _i in 240:
		await rig.wait_seconds(0.05)
		if not Flow.busy:
			break
	await rig.wait_seconds(0.25)
	_ck("G1 death took the bag", Run.bag.is_empty())
	_ck("G2 death did NOT touch the bench",
		Game.component_count(&"cold_iron_core") == bench)
	print("FORGE after_death bench_cores=%d bag=%d" % [
		Game.component_count(&"cold_iron_core"), Run.bag_count()])


# --- H. The trip through the save file --------------------------------------

## Everything above is worthless if a rung does not survive quitting the game,
## and this is the one part of it that fails SILENTLY. `JSON.parse` hands back
## `String` keys, so a `components`/`upgrades` dictionary rebuilt without
## `StringName(k)` loads without an error and reads back empty: `forge_level(
## &"edge")` misses, every ladder is at rung 0, and the save file looks fine.
func _save(rig) -> void:
	var rungs := {}
	for track in Game.FORGE_TRACKS:
		rungs[track] = Game.forge_level(track)
	var bench := Game.components.duplicate()
	var slots := Game.bag_slots

	Saves.save(2)
	await rig.wait_frames(10)
	# Wipe it properly rather than clearing a field or two. A reset that left the
	# dictionaries in place would pass this whether the loader worked or not.
	Game.reset()
	await rig.wait_frames(10)
	_ck("H0 the reset really cleared the bench", Game.components.is_empty())

	Saves.load_slot(2)
	await rig.wait_frames(10)
	print("FORGE reloaded rungs=%s bench=%s slots=%d" % [
		rungs, Game.components, Game.bag_slots])
	var kept := true
	for track: StringName in rungs:
		if Game.forge_level(track) != int(rungs[track]):
			kept = false
	_ck("H1 every forged rung came back", kept)
	var stocked := true
	for id: StringName in bench:
		if Game.component_count(id) != int(bench[id]):
			stocked = false
	_ck("H2 the workbench came back, keyed by StringName", stocked)
	_ck("H3 the bag size came back", Game.bag_slots == slots)
	# And the gear still reads it, which is the thing the player would notice.
	_ck("H4 the reloaded chain is still the Longshot",
		is_equal_approx(Game.hook_reach(), K.CHAIN_REACH[rungs[&"chain"]]))
	Saves.erase(2)


# --- Helpers ----------------------------------------------------------------

func _row(screen, id: StringName) -> Dictionary:
	for r in screen._rows:
		if r.get("kind") == &"buy" and r["line"]["id"] == id:
			return r
	return {}


func _screen(rig) -> TradeScreen:
	for n in _all(rig.scene()):
		if n is TradeScreen:
			return n
	return null


func _motes(rig) -> Array:
	var found := []
	for n in _all(rig.scene()):
		if n is LootMote:
			found.append(n)
	return found


func _all(root: Node) -> Array:
	var found := [root]
	for c in root.get_children():
		found.append_array(_all(c))
	return found


## Teleport. Pathing a hero across a procedural dungeon with synthetic input is
## its own project, and the thing under test here is the economy. `facing_yaw`
## as well as `rotation.y`, because the hero turns toward his own heading every
## frame and setting only the node would be undone before the next capture --
## see docs/CONTRACT.md §2.5, facing is measured, not derived.
func _stand_at(rig, where: Vector3, look_at: Variant = null) -> void:
	var players: Array = rig.get_nodes_in_group(&"player")
	if players.is_empty():
		return
	var hero: Node3D = players[0]
	hero.global_position = where
	if look_at != null:
		var to: Vector3 = K.flat((look_at as Vector3) - where)
		if to != Vector3.ZERO:
			hero.facing_yaw = atan2(to.x, to.z)
			hero.rotation.y = hero.facing_yaw + PI
