extends RefCounted
## **The forgiveness pass** (docs/SCOPE.md MF). Four independent softenings of
## systems that were already built, and the one director that proves all four.
##
## Point it at GARRISON. Nothing here descends: the case is arithmetic on `Run`,
## the two undos are counters in the yard, the receipt is a screen that can be
## raised anywhere, and mercy is a number on `Game`. What the dungeon does with
## any of it is `mvp_loop`'s ground already.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/forgive_loop.gd \
##     --out=/tmp/forgive/x.png --warmup=60
##
## What it claims, in the order it proves them:
##
##   A  **The document case** (GDD §3.1). Three of the twelve slots come home.
##      Nine still die, a relic will not fit in it, and the heat premium is
##      split between the two halves rather than following the body.
##   B  The pouch DRAWS the case as the top of the bag, and A moves a stack
##      across the line in either direction.
##   C  **The receipt's second column.** A death shows what the floor kept,
##      crossed out, beside what the case brought home. An extraction still
##      shows one column.
##   D  **Reforge** (GDD §6.6). The plate goes back in the fire, the components
##      come back, the gold does not, and the piece is uncommitted.
##   E  **Recut.** One rung lower and the stones are gone. Four presses re-open
##      a slot, and Vigor's stored hearts come back down with it.
##   F  **Mercy** (GDD §7.1). Off until asked for, driven by deaths, capped well
##      short of invulnerable, and it never touches the world.
##
## The one that would fail silently is A's arithmetic. `slots_used()` is now the
## sum of two regions, and a stack split across the line costs a cell on each
## side; get that wrong and the bag holds items the pouch has no cell to draw --
## loot that exists in the totals and nowhere on the screen.

var out := ""
var _fails := 0


func run(rig) -> void:
	out = rig.arg("out", "/tmp/forgive/x.png").get_base_dir()
	await rig.wait_frames(20)

	await _case(rig)
	await _pouch(rig)
	await _receipt(rig)
	await _reforge(rig)
	await _recut(rig)
	await _mercy(rig)

	if _fails == 0:
		print("FORGIVE OK")
	else:
		print("FORGIVE FAIL -- %d check(s) failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_fails += 1
		print("FORGIVE FAIL %s" % label)


# --- A. The document case ---------------------------------------------------

func _case(rig) -> void:
	Game.reset()
	Run.enter(9001)

	_ck("A0 the case is three slots", Run.CASE_SLOTS == 3)
	_ck("A1 the hold is everything else (%d + %d = %d)" % [
		Run.CASE_SLOTS, Run.hold_slots(), Game.bag_slots],
		Run.CASE_SLOTS + Run.hold_slots() == Game.bag_slots)

	# Pickup packs the case FIRST. The forgiving default for the player who never
	# opens a menu, which is exactly the player §3.1 is about; the packing
	# DECISION is still there, it is just a repack rather than a chore.
	Run.collect(&"deep_amber", 1)
	_ck("A2 the first thing you pick up is packed", Run.in_case(&"deep_amber") == 1)

	# A relic does not fit, and that one line is what keeps the hardest question
	# in the design being asked: the most valuable thing in the run is the thing
	# the case cannot save.
	var relic := _a_relic()
	_ck("A3 there is a relic to try", relic != &"")
	if relic != &"":
		Run.collect(relic, 1)
		_ck("A4 a relic will not go in the case", Run.in_case(relic) == 0)
		_ck("A5 and it is still in the bag, in the hold",
			Run.in_hold(relic) == 1)
		_ck("A6 the refusal says why (%s)" % Run.case_refusal(relic),
			Run.case_refusal(relic).contains("documents"))

	# Fill the whole thing, then check the two regions add up to what the header
	# prints. This is the check that catches a stack straddling the line.
	Run.collect(&"bone_shard", 14)
	Run.collect(&"whetstone_grit", 5)
	Run.collect(&"tension_coil", 7)
	print("FORGIVE bag=%s cased=%s" % [Run.bag, Run.case_contents()])
	_ck("A7 the case never overflows its three (%d)" % Run.case_slots_used(),
		Run.case_slots_used() <= Run.CASE_SLOTS)
	_ck("A8 slots_used is the two regions summed (%d = %d + %d)" % [
		Run.slots_used(), Run.case_slots_used(), Run.hold_slots_used()],
		Run.slots_used() == Run.case_slots_used() + Run.hold_slots_used())
	_ck("A9 and never more than the bag holds",
		Run.slots_used() <= Game.bag_slots)

	# Unpack and repack one stack. The count in the bag must not move: the case
	# is a mark on what is already carried, not a second container.
	var before := int(Run.bag.get(&"deep_amber", 0))
	var moved := Run.unstow(&"deep_amber")
	_ck("A10 unpacking moves the stack out of the case", moved > 0
		and Run.in_case(&"deep_amber") == 0)
	_ck("A11 and does not change what is carried",
		int(Run.bag.get(&"deep_amber", 0)) == before)
	_ck("A12 packing it again puts it back",
		Run.stow(&"deep_amber") == moved and Run.in_case(&"deep_amber") == before)

	# --- The death itself ---
	var kept := Run.case_contents()
	var lost: Dictionary[StringName, int] = {}
	for id: StringName in Run.bag:
		if Run.in_hold(id) > 0:
			lost[id] = Run.in_hold(id)
	var bench_before := Game.component_count(&"whetstone_grit")
	var hot := Run.premium

	Run.die()
	await _settle(rig)
	print("FORGIVE after death bag=%s kept=%s" % [Run.bag, kept])
	for id: StringName in kept:
		if ItemDb.get_def(id) != null and ItemDb.get_def(id).is_component():
			continue
		_ck("A15 %s survived because it was packed" % id,
			int(Run.bag.get(id, 0)) == int(kept[id]))
	for id: StringName in lost:
		if kept.has(id):
			continue
		_ck("A16 %s died because it was not" % id, not Run.bag.has(id))
	# The ONE place a component survives a death, and it survives because the
	# player packed it.
	if kept.has(&"whetstone_grit"):
		_ck("A17 a packed component reached the bench",
			Game.component_count(&"whetstone_grit")
				== bench_before + int(kept[&"whetstone_grit"]))
	# Heat is earned per gold of loot and cannot outlive the loot, so the pot is
	# prorated rather than following the body wholesale.
	print("FORGIVE heat before=%d after=%d" % [hot, Run.premium])
	_ck("A18 the heat premium was split, not kept whole",
		Run.premium <= hot and Run.premium >= 0)

	var summary: Dictionary = Run.summary
	_ck("A19 the summary carries the kept column",
		summary.has("kept") and summary.has("kept_value"))
	_ck("A20 and it is exactly what the case held",
		(summary["kept"] as Dictionary).size() == kept.size())


func _a_relic() -> StringName:
	for id: StringName in ItemDb.all():
		if RelicDb.is_relic(id):
			return id
	return &""


# --- B. The pouch draws it --------------------------------------------------

func _pouch(rig) -> void:
	Game.reset()
	Run.enter(9002)
	Run.collect(&"deep_amber", 3)
	Run.collect(&"whetstone_grit", 6)
	Run.collect(&"bone_shard", 9)
	await rig.wait_frames(6)

	Menu.open()
	await rig.wait_frames(6)
	Menu._push({"screen": PauseMenu.Screen.POUCH})
	await rig.wait_frames(14)

	var pouch: MenuPouchPanel = Menu.get_node("Root/Screens/PouchScreen")
	_ck("B0 the pouch is showing", pouch.visible)
	_ck("B1 the case has its own three cells",
		pouch._case_grid.count() == Run.CASE_SLOTS)
	_ck("B2 the hold has the rest (%d)" % pouch.grid().count(),
		pouch.grid().count() == Run.hold_slots())
	_ck("B3 and together they are the bag",
		pouch._case_grid.count() + pouch.grid().count() == Game.bag_slots)
	# The frame still fits. Six columns of 150 px once built a 1400 px frame
	# inside a 1280 px viewport and every check above still passed; the case adds
	# a row, so this is the beat that catches it going over the bottom.
	var frame: Control = pouch.get_node("Center/Frame")
	var screen_size := Vector2(Menu.get_viewport().get_visible_rect().size)
	print("FORGIVE pouch frame=%.0fx%.0f viewport=%.0fx%.0f" % [
		frame.size.x, frame.size.y, screen_size.x, screen_size.y])
	_ck("B4 the frame fits on the screen",
		frame.size.x <= screen_size.x and frame.size.y <= screen_size.y)
	_ck("B5 the cursor opens on the case, which is the answer to 'what if I die'",
		Menu.get_viewport().gui_get_focus_owner() == pouch._case_grid.cell_at(0))
	await rig.capture(out.path_join("fg_00_case.png"))

	# A on a cased cell takes it out; A on a carried cell puts it back. Driven
	# through the panel's own handlers rather than through `Run`, because what is
	# under test here is the VERB and not the arithmetic A proved.
	var packed: StringName = pouch._case_ids[0]
	_ck("B6 there is something in the case to unpack", packed != &"")
	pouch._on_case_activated(0)
	await rig.wait_frames(6)
	_ck("B7 A unpacked it", Run.in_case(packed) == 0)
	var at := pouch._cell_ids.find(packed)
	_ck("B8 and it is drawn in the hold now", at >= 0)
	if at >= 0:
		pouch._on_hold_activated(at)
		await rig.wait_frames(6)
		_ck("B9 A packed it again", Run.in_case(packed) > 0)
	await rig.capture(out.path_join("fg_01_packed.png"))

	Menu.close()
	await rig.wait_frames(10)


# --- C. The receipt's second column -----------------------------------------

func _receipt(rig) -> void:
	Game.reset()
	Run.enter(9003)
	# Six kinds, because the case holds three and the beat is about the OTHER
	# column: a bag that fits entirely in the case dies with nothing on the floor,
	# and the receipt would honestly draw one grid.
	Run.collect(&"deep_amber", 2)
	Run.collect(&"bone_shard", 12)
	Run.collect(&"tension_coil", 4)
	Run.collect(&"whetstone_grit", 5)
	Run.collect(&"silver_wire", 3)
	Run.collect(&"void_pearl", 2)
	var kept := Run.case_contents()
	Run.die()
	# Copied before `_settle`, because the ride home it stands down is also what
	# would clear `Run.summary` out from under the screen this beat is about.
	var summary := Run.summary.duplicate(true)
	await _settle(rig)

	var screen := RunEndScreen.open(rig.scene(), summary)
	await rig.wait_frames(14)
	_ck("C0 the death receipt is up", screen.died())
	var grids := _grids(screen)
	print("FORGIVE receipt grids=%d kept=%s" % [grids.size(), kept])
	_ck("C1 a death draws TWO columns", grids.size() == 2)
	_ck("C2 one of them is struck through", _strikes(screen) == 1)
	_ck("C3 the kept column is the case",
		screen._kept.size() == _priced(kept).size())
	_ck("C4 and the receipt prints what it was worth",
		int(Run.summary.get("kept_value", -1)) >= 0)
	await rig.capture(out.path_join("fg_02_receipt_death.png"))
	screen.get_parent().queue_free()
	await rig.wait_frames(6)

	# An extraction brings the whole bag home, so a split there would be the
	# screen inventing a distinction the ending did not make.
	Run.enter(9004)
	Run.collect(&"deep_amber", 2)
	Run.collect(&"bone_shard", 6)
	Run.extract()
	var out_summary := Run.summary.duplicate(true)
	await _settle(rig)
	var out_screen := RunEndScreen.open(rig.scene(), out_summary)
	await rig.wait_frames(14)
	_ck("C5 an extraction is not a death", not out_screen.died())
	_ck("C6 and it still draws ONE column", _grids(out_screen).size() == 1)
	_ck("C7 with no cross on it", _strikes(out_screen) == 0)
	await rig.capture(out.path_join("fg_03_receipt_out.png"))
	out_screen.get_parent().queue_free()
	await rig.wait_frames(6)


## The item stacks in `counts` that the receipt would actually draw -- an id with
## no `ItemDef` is skipped by `_stacks_of` and must be skipped here too.
func _priced(counts: Dictionary) -> Dictionary:
	var out_counts := {}
	for id: StringName in counts:
		if ItemDb.get_def(id) != null:
			out_counts[id] = counts[id]
	return out_counts


func _grids(root: Node) -> Array:
	var found: Array = []
	for n in _all(root):
		if n is ItemGrid:
			found.append(n)
	return found


func _strikes(root: Node) -> int:
	var n := 0
	for c in _all(root):
		if c is RunEndScreen.Strike:
			n += 1
	return n


# --- D. Reforge -------------------------------------------------------------

func _reforge(rig) -> void:
	Game.reset()
	Game.gold = 40000
	for id in ItemDb.components(ItemDef.BENCH_FORGE):
		Game.components[id] = 200
	# The ladders are rationed by two relics -- the smith knows rung 1 until the
	# Tally-Ledger and rung 2 until the Imperium Anvil-Plate. A reforge is about
	# a FULLY climbed piece, so the ceiling has to be open before the beat starts.
	# That the relics are what open it is `relic_donate.gd`'s claim, not this one.
	for id: StringName in RelicDb.RUNG_RELICS:
		Game.set_flag(RelicDb.flag_donated(id))

	var fresh := _reforge_lines()
	_ck("D0 a fresh save is offered no reforge at all", fresh.is_empty())

	# Three rungs of heavy chest, bought at the counter so the components are
	# genuinely spent and the refund has something to give back.
	var track := Game.plate_track(&"chest", Game.PLATE_HEAVY)
	var spent := {}
	for i in K.FORGE_MAX:
		var line := _line(track)
		for pid: StringName in line.get("parts", {}):
			spent[pid] = int(spent.get(pid, 0)) + int(line["parts"][pid])
		_ck("D1.%d rung %d bought" % [i, i + 1], ShopDb.buy(line))
	_ck("D2 the chest is at the top of heavy",
		Game.forge_level(track) == K.FORGE_MAX)
	_ck("D3 light is closed for that piece",
		Game.path_closed(Game.plate_track(&"chest", Game.PLATE_LIGHT)))

	var row := _reforge_lines()
	print("FORGIVE reforge rows=%d" % row.size())
	_ck("D4 exactly one piece can be reforged", row.size() == 1)
	var line := row[0]
	_ck("D5 it costs no gold -- the price was the grind", int(line["cost"]) == 0)
	_ck("D6 and it is a HOLD, not a tap", ShopDb.crafts(line))
	_ck("D7 the footer says REFORGE, not FORGE", String(line["verb"]) == "REFORGE")
	_ck("D8 the row names what comes back (%s)" % line["detail"],
		String(line["detail"]).contains("returns"))

	var gold_before := Game.gold
	var bench_before := {}
	for pid: StringName in spent:
		bench_before[pid] = Game.component_count(pid)

	_ck("D9 the reforge takes", ShopDb.buy(line))
	_ck("D10 the piece is back at rung 0", Game.forge_level(track) == 0)
	_ck("D11 and the key is gone, not zeroed", not Game.upgrades.has(track))
	_ck("D12 the opposite path is open again",
		not Game.path_closed(Game.plate_track(&"chest", Game.PLATE_LIGHT)))
	_ck("D13 the gold did NOT come back", Game.gold == gold_before)
	for pid: StringName in spent:
		_ck("D14 every %s came back (%d)" % [pid, int(spent[pid])],
			Game.component_count(pid) == int(bench_before[pid]) + int(spent[pid]))
	_ck("D15 and the row is gone with nothing left to undo",
		_reforge_lines().is_empty())

	# The counter, drawn, with the row on it. Rebuilt from a committed piece
	# because the beat above just took the only one apart.
	Game.upgrades[Game.plate_track(&"legs", Game.PLATE_LIGHT)] = 2
	var garrison := rig.scene() as Garrison
	await _shoot_counter(rig, garrison.smith,
		garrison.smith.global_position + Vector3(0.0, 0.0, 1.6),
		"fg_04_reforge.png")


func _reforge_lines() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for line in ShopDb.lines():
		if String(line["id"]).begins_with(ShopDb.REFORGE):
			found.append(line)
	return found


func _line(id: StringName) -> Dictionary:
	for line in ShopDb.lines():
		if line["id"] == id:
			return line
	return {}


# --- E. Recut ---------------------------------------------------------------

func _recut(rig) -> void:
	Game.reset()
	Game.gold = 40000
	for id in ItemDb.components(ItemDef.BENCH_JEWEL):
		Game.components[id] = 200

	_ck("E0 a fresh save is offered no recut", _recut_lines().is_empty())

	Game.upgrades[JewelDb.blank_id(&"amulet")] = 1
	var track := Game.jewel_track(&"amulet", &"vigor")
	var stones := {}
	for i in K.JEWEL_MAX:
		var buy := _jline(track)
		for pid: StringName in buy.get("parts", {}):
			stones[pid] = int(stones.get(pid, 0)) + int(buy["parts"][pid])
		_ck("E1.%d rung %d set" % [i, i + 1], JewelDb.buy(buy))
	var hearts := Game.heart_containers()
	_ck("E2 four Vigor rungs is two hearts",
		hearts == K.START_HEARTS + K.JEWEL_MAX / 2)
	_ck("E3 focus is closed", Game.path_closed(
		Game.jewel_track(&"amulet", &"focus")))

	var rows := _recut_lines()
	_ck("E4 exactly one slot can be recut", rows.size() == 1)
	var line := rows[0]
	_ck("E5 it costs no gold", int(line["cost"]) == 0)
	_ck("E6 and it is a HOLD", JewelDb.crafts(line))
	_ck("E7 the row says the stones are lost (%s)" % line["detail"],
		String(line["detail"]).contains("lost"))

	var bench := Game.component_count(&"cut_gemstone")
	_ck("E8 the recut takes", JewelDb.buy(line))
	_ck("E9 one rung lower, not zero",
		Game.jewel_level(track) == K.JEWEL_MAX - 1)
	# Metal is conserved and stone is not. This is the whole asymmetry between
	# the two counters, and it is the line that keeps her the harder commitment.
	_ck("E10 the stone did NOT come back",
		Game.component_count(&"cut_gemstone") == bench)
	_ck("E11 and the hearts came down with it",
		Game.heart_containers() < hearts)
	_ck("E12 focus is still closed at rung 3",
		Game.path_closed(Game.jewel_track(&"amulet", &"focus")))

	# All the way down. Four presses and four gemstones, which is the price the
	# design intends for changing your mind at HER counter.
	for _i in K.JEWEL_MAX:
		var again := _recut_lines()
		if again.is_empty():
			break
		JewelDb.buy(again[0])
	_ck("E13 four presses take it to nothing", Game.jewel_level(track) == 0)
	_ck("E14 the key is gone, not zeroed", not Game.upgrades.has(track))
	_ck("E15 and the slot is a real choice again", not Game.path_closed(
		Game.jewel_track(&"amulet", &"focus")))
	_ck("E16 the hearts are back where they started",
		Game.heart_containers() == K.START_HEARTS)

	Game.upgrades[Game.jewel_track(&"ring1", &"edge")] = 2
	Game.upgrades[JewelDb.blank_id(&"ring1")] = 1
	var garrison := rig.scene() as Garrison
	await _shoot_counter(rig, garrison.jeweller,
		garrison.jeweller.global_position
			+ garrison.jeweller.global_transform.basis * Vector3(0.0, 0.0, 1.6),
		"fg_05_recut.png")


func _recut_lines() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for line in JewelDb.lines():
		if String(line["id"]).begins_with(JewelDb.RECUT):
			found.append(line)
	return found


func _jline(id: StringName) -> Dictionary:
	for line in JewelDb.lines():
		if line["id"] == id:
			return line
	return {}


# --- F. Mercy ---------------------------------------------------------------

func _mercy(rig) -> void:
	Game.reset()
	var was := Settings.mercy
	Settings.mercy = false
	_ck("F0 nobody is softened until they ask", Game.mercy_rate() == 0.0)

	Settings.mercy = true
	Game.deaths = 0
	var base := Game.mercy_rate()
	print("FORGIVE mercy base=%.3f" % base)
	_ck("F1 it starts small", is_equal_approx(base, K.MERCY_BASE) and base < 0.1)

	Game.deaths = 4
	_ck("F2 it climbs with deaths", Game.mercy_rate() > base)
	Game.deaths = 999
	print("FORGIVE mercy capped=%.3f" % Game.mercy_rate())
	_ck("F3 and caps well short of invulnerable",
		is_equal_approx(Game.mercy_rate(), K.MERCY_MAX) and K.MERCY_MAX <= 0.5)

	# A blow is never zeroed. `Hero` keeps the same floor for armour, and for the
	# same reason: a hit that can be reduced to nothing stops being a reason to
	# move.
	Game.deaths = 999
	Game.max_quarters = 999
	Game.quarters = 999
	Game._mercy_carry = 10.0
	Game.damage(K.QUARTER)
	_ck("F4 a one-quarter blow still lands", Game.quarters == 998)

	# Over a fight, exactly the advertised fraction. The carry is what makes an
	# integer resistance honest -- rounded per hit, 30% of a two-quarter blow is
	# nought every single time.
	Game.quarters = 999
	Game._mercy_carry = 0.0
	var blows := 40
	var each := 4
	for _i in blows:
		Game.damage(each)
	var taken := 999 - Game.quarters
	var want := int(round(float(blows * each) * (1.0 - K.MERCY_MAX)))
	print("FORGIVE mercy took %d of %d, expected about %d" % [
		taken, blows * each, want])
	_ck("F5 over a fight it forgives what it advertises",
		absi(taken - want) <= 2)

	# It does not touch the world. §7 is intact: the bands, the spawns and the
	# telegraphs are the same numbers with mercy on as with it off, because this
	# is not level-scaling by another name.
	var world_on := [Prog.health_mult(3), Prog.windup_scale(3),
		Prog.pack(3), Prog.elite_chance(3)]
	Settings.mercy = false
	var world_off := [Prog.health_mult(3), Prog.windup_scale(3),
		Prog.pack(3), Prog.elite_chance(3)]
	_ck("F6 the Cut is exactly as dangerous either way", world_on == world_off)

	# The switch is a PREFERENCE and lives in settings.cfg; the dial it turns is
	# save state. Neither belongs in the other, which is §7.1's "it lives in
	# options and not in the fiction" written as two files.
	Settings.mercy = true
	Game.deaths = 7
	Saves.save(4)
	Game.reset()
	_ck("F7 a new game has died no times", Game.deaths == 0)
	Saves.load_slot(4)
	_ck("F8 deaths survive the save file", Game.deaths == 7)

	# Shot with the dial ON, so the caption in the frame is the live rate and not
	# the offer. Set on the autoload rather than through the row, which would call
	# `Settings.save_settings()` and leave a director's preference in the player's
	# settings.cfg; `was` goes back at the end of the beat.
	Settings.mercy = true
	Game.reset()
	Menu.open()
	await rig.wait_frames(6)
	Menu._push({"screen": PauseMenu.Screen.OPTIONS})
	await rig.wait_frames(14)
	var opts: MenuOptionsPanel = Menu.get_node("Root/Screens/OptionsScreen")
	opts.open_tab(MenuOptionsPanel.Tab.GAME)
	await rig.wait_frames(10)
	_ck("F9 the row is on the GAME tab, named plainly", _finds(opts, "Mercy"))
	_ck("F10 and the caption prints the live number, not a euphemism",
		opts._mercy_caption().contains("%"))
	print("FORGIVE mercy caption: %s" % opts._mercy_caption())

	# Focus the row before the shot. Mercy is deliberately the LAST heading on the
	# GAME tab and the tab is taller than the frame, so a picture of the top of the
	# page would show Camera and Combat and prove nothing about the toggle this
	# beat exists for. `_scroll.follow_focus` does the scrolling.
	var mercy_row: Control = opts._content.get_node_or_null("row_mercy")
	_ck("F11 the row takes focus, which is how a pad reaches it", mercy_row != null)
	if mercy_row != null:
		mercy_row.grab_focus()
	# Then all the way down. `follow_focus` stops as soon as the ROW is on screen,
	# which leaves the caption -- the part that prints the live rate, and the whole
	# reason F10 exists -- hanging off the bottom edge. The page ends here, so the
	# bottom of the scroll is the honest frame.
	opts._scroll.scroll_vertical = int(opts._scroll.get_v_scroll_bar().max_value)
	await rig.wait_frames(14)
	print("FORGIVE mercy focus=%s scroll=%d" % [
		str(mercy_row != null and mercy_row.has_focus()),
		opts._scroll.scroll_vertical])
	await rig.capture(out.path_join("fg_06_mercy.png"))
	Menu.close()
	Settings.mercy = was
	await rig.wait_frames(10)


func _finds(root: Node, text: String) -> bool:
	for n in _all(root):
		if n is Label and (n as Label).text.contains(text):
			return true
		if n is Button and (n as Button).text.contains(text):
			return true
		if n.name.to_lower().contains(text.to_lower()):
			return true
	return false


# --- Shared -----------------------------------------------------------------

## Put the world back after a simulated run ending.
##
## `Run.die()` and `Run.extract()` are the rules under test, but they also trip
## `Flow`: it holds for a beat, PAUSES the tree, blocks `Prompt` and raises its
## own ending screen for the ride home. A director that ends a run and then walks
## up to a counter is walking through a stopped world with the prompts switched
## off -- which is exactly how D's smith beat failed while E's jeweller, one
## screen later, passed: the interact that was meant for the smith dismissed the
## leftover ending screen instead, and THAT is what unpaused everything.
##
## The wait is longer than `Flow.HOLD * 1.4` on purpose. The pause lands after
## that timer, so clearing up before it fires puts the world back and then lets
## Flow stop it again a moment later.
func _settle(rig) -> void:
	await rig.wait_seconds(1.2)
	Flow.ending = false
	for n in _all(rig.scene()):
		if n is RunEndScreen:
			n.get_parent().queue_free()
	rig.paused = false
	Prompt.blocked = false
	await rig.wait_frames(8)


## Open a counter and photograph it. The rows are what the beats above have
## already checked; this is the frame, which is the only thing that can tell you
## the undo row landed somewhere a player can reach.
func _shoot_counter(rig, who: Node3D, stand: Vector3, name: String) -> void:
	if who == null:
		return
	_stand_at(rig, stand)
	await rig.wait_frames(24)
	for _i in 90:
		if Prompt.focus == who:
			break
		await rig.wait_frames(2)
	await rig.tap(["interact"])
	# Through the conversation the press now opens (`Npc.activate`, 2026-08-10).
	var service := "Smithing" if name == "fg_04_reforge.png" else "Upgrades"
	await rig.talk(service)
	await rig.wait_frames(18)
	var screen := _screen(rig)
	if screen == null:
		_ck("the counter opened for %s" % name, false)
		return
	print("FORGIVE %s rows=%d" % [name, screen._rows.size()])
	# Point at the undo row before the shot. It is deliberately LAST on the board
	# (see `ShopDb._reforge_row`) and the board is taller than the frame, so a
	# picture of the top of the counter would prove nothing about the row this
	# director exists for.
	for i in screen._rows.size():
		var row: Dictionary = screen._rows[i]
		if row.get("kind") != &"buy":
			continue
		var id := String(row["line"]["id"])
		if id.begins_with(ShopDb.REFORGE) or id.begins_with(JewelDb.RECUT):
			screen._point_at(i)
			_ck("the undo row is reachable with the cursor (%s)"
				% row["line"]["label"], true)
			break
	await rig.wait_frames(12)
	await rig.capture(out.path_join(name))
	await rig.tap(["ui_cancel"])
	await rig.wait_frames(12)


func _screen(rig) -> TradeScreen:
	for n in _all(rig.scene()):
		if n is TradeScreen:
			return n
	return null


func _all(root: Node) -> Array:
	var found := [root]
	for c in root.get_children():
		found.append_array(_all(c))
	return found


func _stand_at(rig, where: Vector3) -> void:
	var players: Array = rig.get_nodes_in_group(&"player")
	if players.is_empty():
		return
	var hero: Node3D = players[0]
	hero.global_position = where
