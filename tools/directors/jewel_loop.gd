extends RefCounted
## The jewelcrafter, and the stat block she is read on.
##
## Point it at GARRISON. It never descends -- everything here is a garrison
## claim, and what a stone does underground is `forge_loop`'s ground already.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/jewel_loop.gd \
##     --out=/tmp/jewel/x.png --warmup=60
##
## What it claims, in the order it proves them:
##
##   A  Her two stones are in the catalogue, on her own bench, and drop.
##   B  She is a person standing in the yard, and TALK opens a counter.
##   C  A slot is bought twice -- a blank, then a path -- and the blank is the
##      only row until it is owned.
##   D  A path commits: one rung shuts the sibling for good.
##   E  Every rung moves the number the GAME reads, through the same accessor.
##   F  The ceiling belongs to the NUMBER, not to the faucet: a full Ward
##      bracelet on top of full heavy plate does not stack past `K.SOAK_MAX`,
##      and Swift never carries the hero past the measured `[oot]` run.
##   G  Her rungs are NOT rationed by `RelicDb.forge_rungs_known()`.
##   H  The equipment screen's stat block reads five numbers off `Game`, and
##      every one of them agrees with the accessor.
##
## F is the one that matters. Two faucets on one number is the arithmetic that
## made four plate pieces at `[0,1,2,3]` a twelve (docs/GDD.md §6.6), and it is
## the mistake that comes back the moment a ninth path is added.

var out := ""
var _fails := 0


func run(rig) -> void:
	out = rig.arg("out", "/tmp/jewel/x.png").get_base_dir()
	await rig.wait_frames(20)

	_catalogue()
	await _counter(rig)
	_commit()
	_numbers()
	_ceilings()
	_rationing()
	await _stat_block(rig)

	if _fails == 0:
		print("JEWEL OK")
	else:
		print("JEWEL FAIL -- %d check(s) failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_fails += 1
		print("JEWEL FAIL %s" % label)


# --- A. Her stones ----------------------------------------------------------

func _catalogue() -> void:
	var stones := ItemDb.components(ItemDef.BENCH_JEWEL)
	print("JEWEL stones=%s" % [stones])
	_ck("A0 two stones exist", stones.size() == 2)
	for id in stones:
		var def := ItemDb.get_def(id)
		_ck("A1 %s is a component on HER bench" % id,
			def != null and def.is_component() and def.bench == ItemDef.BENCH_JEWEL)
		_ck("A2 %s drops from chests" % id, ItemDb.CHEST_DROPS.has(id))
	# The bench label is a SIGNPOST and it has to stay true: the pouch prints one
	# counter per material, so a stone another catalogue also ate would send the
	# player to the wrong end of the yard holding her price.
	var others: Array[StringName] = []
	others.append_array(ItemDb.components(ItemDef.BENCH_FORGE))
	others.append_array(ItemDb.components(ItemDef.BENCH_ALCHEMY))
	var overlap := false
	for id in stones:
		if others.has(id):
			overlap = true
	_ck("A3 no other counter eats a stone", not overlap)
	_ck("A4 the cut stone is chests-only, like the core and the dew",
		not ItemDb.ENEMY_DROPS.has(&"cut_gemstone")
			and ItemDb.ENEMY_DROPS.has(&"silver_wire"))
	var def := ItemDb.get_def(&"cut_gemstone")
	_ck("A5 the pouch sends it to her by name (%s)" % def.bench_name(),
		def.bench_name() == "THE JEWELCRAFTER")


# --- B and C. The counter ---------------------------------------------------

func _counter(rig) -> void:
	var garrison := rig.scene() as Garrison
	if garrison == null or garrison.jeweller == null:
		print("JEWEL FAIL there is no jewelcrafter in the yard")
		_fails += 1
		return
	print("JEWEL she stands at %.2v facing %.0f deg" % [
		garrison.jeweller.global_position, rad_to_deg(garrison.jeweller.rotation.y)])

	# Inside the arrival frame, which is the constraint the alchemist's placement
	# comment was written for after she ended up behind the camera. The arrival
	# spot is z ~ +4.8 looking north, so anything the player must see has to be
	# forward of it.
	_ck("B0 she is forward of the arrival spot, not behind it",
		garrison.jeweller.global_position.z < 4.0)
	# Two metres of clearance from the twelve relic lamp posts, so she is not
	# standing inside one.
	var nearest := 999.0
	for l in garrison.lights:
		nearest = minf(nearest,
			garrison.jeweller.global_position.distance_to(l.global_position))
	print("JEWEL nearest relic post = %.2f m" % nearest)
	_ck("B1 she is clear of the relic ring", nearest > 1.6)

	Game.gold = 40000
	for id in ItemDb.components(ItemDef.BENCH_JEWEL):
		Game.components[id] = 120

	_stand_at(rig, garrison.jeweller.global_position
		+ garrison.jeweller.global_transform.basis * Vector3(0.0, 0.0, 1.6))
	await rig.wait_frames(24)
	for _i in 90:
		if Prompt.focus == garrison.jeweller:
			break
		await rig.wait_frames(2)
	_ck("B2 TALK is on her, not on the wall", Prompt.focus == garrison.jeweller)
	await rig.tap(["interact"])
	# The bench is behind the Upgrades option now (`Npc.activate`, 2026-08-10).
	_ck("B2b she offers Upgrades", await rig.talk("Upgrades"))
	await rig.wait_frames(16)

	var screen := _screen(rig)
	if screen == null:
		print("JEWEL FAIL the jewelcrafter did not open")
		_fails += 1
		return
	_ck("B3 it is the SAME TradeScreen, pointed at her",
		screen.catalogue == JewelDb)
	_ck("B4 the footer speaks her word (SET)", JewelDb.craft_verb() == "SET")

	# --- C. A slot is bought twice --------------------------------------------
	_ck("C0 four rows on a fresh save, one blank per slot",
		screen._rows.size() == 4)
	var blank := _row(screen, JewelDb.blank_id(&"amulet"))
	_ck("C1 the amulet blank is one of them", not blank.is_empty())
	_ck("C2 a blank costs gold and no stones",
		(blank["line"]["parts"] as Dictionary).is_empty())
	_ck("C3 so it is a TAP, not a hold", not JewelDb.crafts(blank["line"]))
	_ck("C4 and it names the question it opens (%s)" % blank["line"]["detail"],
		String(blank["line"]["detail"]).to_upper().contains("VIGOR"))

	# `_point_at`, and not `screen._cursor = i` (CLAUDE.md §3, card #77). The
	# assignment is half a move: `_point_at` is the half that calls `grab_focus`,
	# which is DEFERRED, so the `focus_entered` it queues lands a frame later, runs
	# back through `_on_cell_looked`, and puts `_cursor` on whatever row the last
	# `_refresh` left the focus on. Card #74 was nine red checks of exactly that.
	#
	# Going through `_point_at` makes the round trip IDEMPOTENT -- it re-points at
	# the row that was asked for -- so a beat that waits a frame before acting is
	# safe rather than racing. That is why no wait is added here: the fix is the
	# call, not a sleep.
	screen._point_at(screen._rows.find(blank))
	screen._commit()
	await rig.wait_frames(20)
	_ck("C5 buying it opened the two paths", JewelDb.owns_blank(&"amulet"))
	_ck("C6 the blank row is gone and two took its place",
		screen._rows.size() == 5)
	await rig.capture(out.path_join("j_00_counter.png"))

	# Every blank, so the board is at its widest for the shot and the beats
	# below have all eight paths to work with.
	for slot: StringName in Game.JEWEL_SLOTS:
		Game.upgrades[JewelDb.blank_id(slot)] = 1
	screen._refresh()
	await rig.wait_frames(8)
	print("JEWEL widest board = %d rows" % screen._rows.size())
	_ck("C7 eight rows once every slot is open", screen._rows.size() == 8)
	await rig.capture(out.path_join("j_01_paths.png"))

	# The rung IS a hold, because it eats a stone at rung 3 and the whole reason
	# `Catalogue.crafts` exists is to put the gauge on the commits that cannot be
	# given back.
	var edge := _row(screen, Game.jewel_track(&"ring1", &"edge"))
	_ck("C8 a rung is a HOLD", not edge.is_empty()
		and JewelDb.crafts(edge["line"]))

	screen.close()
	await rig.wait_frames(12)


# --- D. Commitment ----------------------------------------------------------

func _commit() -> void:
	Game.upgrades.clear()
	for slot: StringName in Game.JEWEL_SLOTS:
		Game.upgrades[JewelDb.blank_id(slot)] = 1
	var edge := Game.jewel_track(&"ring1", &"edge")
	var swift := Game.jewel_track(&"ring1", &"swift")
	Game.upgrades[edge] = 1

	_ck("D0 one Edge rung shuts Swift on that ring", Game.path_closed(swift))
	_ck("D1 she will not sell it", JewelDb.cap_of(swift) == 0)
	_ck("D2 and says why (%s)" % JewelDb.refusal({"id": swift, "cost": 0}),
		JewelDb.refusal({"id": swift, "cost": 0}).contains("CUT"))
	# The SECOND ring is a separate question, which is the whole reason there are
	# two of them: two Edge rings and one of each are different builds.
	_ck("D3 the second ring is still open",
		not Game.path_closed(Game.jewel_track(&"ring2", &"swift")))
	var ids: Array[StringName] = []
	for line in JewelDb.lines():
		ids.append(line["id"])
	_ck("D4 the shut path is off the board entirely", not ids.has(swift))


# --- E. The rungs move the game's own numbers -------------------------------

func _numbers() -> void:
	Game.reset()
	for slot: StringName in Game.JEWEL_SLOTS:
		Game.upgrades[JewelDb.blank_id(slot)] = 1

	var before := {
		"edge": Game.sword_bonus(),
		"soak": Game.armour_soak_exact(),
		"speed": Game.speed_mult(),
		"hearts": Game.heart_containers(),
		"stamina": Game.max_stamina,
		"regen": Game.stamina_regen(),
	}
	print("JEWEL base %s" % [before])

	Game.gold = 40000
	for id in ItemDb.components(ItemDef.BENCH_JEWEL):
		Game.components[id] = 400

	# Bought through `buy()`, not by writing `upgrades` -- the till is the thing
	# under test as much as the number is, and Vigor and Focus are the two paths
	# that APPLY something at the counter rather than being read back later.
	for slot: StringName in Game.JEWEL_SLOTS:
		var path: StringName = JewelDb.PATHS[slot][0]
		for _r in K.JEWEL_MAX:
			var track := Game.jewel_track(slot, path)
			var line := _line_for(track)
			if line.is_empty():
				break
			JewelDb.buy(line)
	print("JEWEL full-A edge=+%d soak=%.2f hearts=%d stamina=%.0f" % [
		Game.sword_bonus(), Game.armour_soak_exact(),
		Game.heart_containers(), Game.max_stamina])

	_ck("E0 four Vigor rungs are two whole heart containers",
		Game.heart_containers() == int(before["hearts"]) + 2)
	# BOTH rings on Edge -- eight rungs at a quarter of a quarter each. This is
	# the build the ring pair exists to allow, and it is worth as much as two
	# thirds of the sword's own ladder, which is why the gold ramp is steeper.
	_ck("E1 two full Edge rings are +2 quarters a swing",
		Game.sword_bonus() == int(before["edge"]) + 2)
	_ck("E2 a Ward bracelet soaks half a quarter a rung",
		is_equal_approx(Game.armour_soak_exact(), float(before["soak"]) + 2.0))

	# The B paths, on a clean slate.
	Game.reset()
	for slot: StringName in Game.JEWEL_SLOTS:
		Game.upgrades[JewelDb.blank_id(slot)] = 1
	Game.gold = 40000
	for id in ItemDb.components(ItemDef.BENCH_JEWEL):
		Game.components[id] = 400
	for slot: StringName in Game.JEWEL_SLOTS:
		var path: StringName = JewelDb.PATHS[slot][1]
		for _r in K.JEWEL_MAX:
			var line := _line_for(Game.jewel_track(slot, path))
			if line.is_empty():
				break
			JewelDb.buy(line)
	print("JEWEL full-B speed=%.4f regen=%.2f stamina=%.0f" % [
		Game.speed_mult(), Game.stamina_regen(), Game.max_stamina])
	_ck("E3 four Focus rungs are +60 stamina",
		is_equal_approx(Game.max_stamina, float(before["stamina"]) + 60.0))
	# 8%, which is exactly what four heavy pieces cost. Two Swift rings are the
	# price of undoing a full heavy suit, and that symmetry is the trade GDD §6.6
	# calls the loop's one genuinely hard standing question.
	_ck("E4 eight Swift rungs buy back what full heavy plate costs",
		Game.speed_mult_raw() > 1.08)
	_ck("E5 a Wind bracelet regenerates 40% faster",
		is_equal_approx(Game.stamina_regen(), float(before["regen"]) * 1.4))


# --- F. The ceiling belongs to the number -----------------------------------

func _ceilings() -> void:
	# Every faucet on soak, wide open: four heavy pieces (4.0) plus a full Ward
	# bracelet (2.0). Six, against a bestiary tuned for three.
	Game.reset()
	for piece: StringName in Game.PLATE_PIECES:
		Game.upgrades[Game.plate_track(piece, Game.PLATE_HEAVY)] = K.FORGE_MAX
	Game.upgrades[JewelDb.blank_id(&"bracelet")] = 1
	Game.upgrades[Game.jewel_track(&"bracelet", &"ward")] = K.JEWEL_MAX
	print("JEWEL both soak faucets open = %.2f (cap %.2f)" % [
		Game.armour_soak_exact(), K.SOAK_MAX])
	_ck("F0 soak stops at the NUMBER's cap, not at each faucet's",
		is_equal_approx(Game.armour_soak_exact(), K.SOAK_MAX))
	# A whole heart off every blow is the ceiling, and it is survivable ONLY
	# because `Hero.hurt` floors the result at one quarter. Asserted against that
	# arithmetic rather than against the cap, because the cap moving is a tuning
	# decision and the floor going missing is a bug.
	_ck("F1 and a hit still lands for something",
		maxi(K.QUARTER, K.HEART - Game.armour_soak()) >= K.QUARTER)

	# Speed from the other side: heavy plate takes 8%, two Swift rings give more
	# than that back, and the hero still runs at exactly the measured [oot] pace
	# and not a step faster (pillar 1).
	Game.reset()
	for slot: StringName in [&"ring1", &"ring2"]:
		Game.upgrades[JewelDb.blank_id(slot)] = 1
		Game.upgrades[Game.jewel_track(slot, &"swift")] = K.JEWEL_MAX
	print("JEWEL swift-only raw=%.4f clamped=%.4f" % [
		Game.speed_mult_raw(), Game.speed_mult()])
	_ck("F2 jewelery never outruns [oot]", is_equal_approx(Game.speed_mult(), 1.0))
	_ck("F3 but the raw product knows it had headroom",
		Game.speed_mult_raw() > 1.0)

	# And damage, the third shared number.
	Game.reset()
	Game.upgrades[Game.FORGE_EDGE] = K.FORGE_MAX
	for slot: StringName in [&"ring1", &"ring2"]:
		Game.upgrades[JewelDb.blank_id(slot)] = 1
		Game.upgrades[Game.jewel_track(slot, &"edge")] = K.JEWEL_MAX
	print("JEWEL both edge faucets open = +%d (cap %d)" % [
		Game.sword_bonus(), K.EDGE_MAX])
	_ck("F4 damage stops at K.EDGE_MAX", Game.sword_bonus() == K.EDGE_MAX)


# --- G. Her gate is the stones, not the smith's relics -----------------------

func _rationing() -> void:
	Game.reset()
	Game.upgrades[JewelDb.blank_id(&"amulet")] = 1
	print("JEWEL smith knows %d rungs; she offers %d" % [
		RelicDb.forge_rungs_known(),
		JewelDb.cap_of(Game.jewel_track(&"amulet", &"vigor"))])
	_ck("G0 the smith is rationed on a fresh save",
		RelicDb.forge_rungs_known() < K.FORGE_MAX)
	_ck("G1 she is not -- all four rungs, no relic donated",
		JewelDb.cap_of(Game.jewel_track(&"amulet", &"vigor")) == K.JEWEL_MAX)


# --- H. The stat block ------------------------------------------------------

func _stat_block(rig) -> void:
	# A hero mid-build rather than an empty or a finished one: two committed
	# armour pieces on opposite paths, one Edge ring, one Vigor amulet. That is
	# the state where a panel that recomputed instead of reading would be wrong,
	# because soak is fractional and speed is not 100%.
	Game.reset()
	Game.upgrades[Game.plate_track(&"chest", Game.PLATE_HEAVY)] = 2
	Game.upgrades[Game.plate_track(&"boots", Game.PLATE_LIGHT)] = 3
	Game.upgrades[Game.FORGE_EDGE] = 1
	Game.upgrades[JewelDb.blank_id(&"ring1")] = 1
	Game.upgrades[Game.jewel_track(&"ring1", &"edge")] = 2
	Game.upgrades[JewelDb.blank_id(&"amulet")] = 1
	Game.upgrades[Game.jewel_track(&"amulet", &"vigor")] = 2
	Game.resync_maxima(true)
	await rig.wait_frames(4)

	Menu.open()
	await rig.wait_frames(6)
	Menu._push({"screen": PauseMenu.Screen.EQUIP})
	await rig.wait_frames(14)

	var equip: MenuEquipPanel = Menu.get_node("Root/Screens/EquipScreen")
	_ck("H0 the equipment screen is showing", equip.visible)
	_ck("H1 five stats, and there is no sixth",
		MenuEquipPanel.STATS.size() == 5)

	var shown := {}
	for id: StringName in MenuEquipPanel.STATS:
		shown[id] = equip._stat_values[id].text
	print("JEWEL stat block %s" % [shown])

	# Read against the accessors, not against a recomputation -- the panel's one
	# rule is that it never does the arithmetic itself, and this is the beat that
	# would catch it starting to.
	_ck("H2 damage matches Game.sword_bonus()",
		String(shown[&"damage"]).contains("+%d" % Game.sword_bonus()))
	_ck("H3 speed matches Game.speed_mult()",
		String(shown[&"speed"]).begins_with("%.1f" % (Game.speed_mult() * 100.0)))
	_ck("H4 health matches Game.heart_containers()",
		String(shown[&"health"]).begins_with("%d" % Game.heart_containers()))
	_ck("H5 stamina matches Game.max_stamina",
		String(shown[&"stamina"]).begins_with("%d" % int(round(Game.max_stamina))))
	_ck("H6 soak matches Game.armour_soak() AND shows the fraction (%s)"
		% shown[&"soak"],
		String(shown[&"soak"]).contains("-%d" % Game.armour_soak())
			and String(shown[&"soak"]).contains("%.1f" % Game.armour_soak_exact()))

	var frame: Control = equip.get_node("Center/Frame")
	var screen_size := Vector2(Menu.get_viewport().get_visible_rect().size)
	print("JEWEL equip frame=%.0fx%.0f viewport=%.0fx%.0f" % [
		frame.size.x, frame.size.y, screen_size.x, screen_size.y])
	_ck("H7 the frame still fits on the screen with the block on it",
		frame.size.x <= screen_size.x and frame.size.y <= screen_size.y)
	await rig.capture(out.path_join("j_02_stats.png"))

	Menu.close()
	await rig.wait_frames(10)


# --- helpers ----------------------------------------------------------------

## The live catalogue row for `track`, or `{}` if she is not offering it.
func _line_for(track: StringName) -> Dictionary:
	for line in JewelDb.lines():
		if line["id"] == track:
			return line
	return {}


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
