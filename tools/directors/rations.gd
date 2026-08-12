extends RefCounted
## **Food and drink, bought over the counter and eaten sitting down.** Card #98,
## `docs/METAGAME.md` §6.4.
##
## The item is not the heal. Hardtack gives back one heart over TWELVE SECONDS
## and Small Beer one spin's worth of magic over the same, and both of them are
## paid for by standing still for that long with nothing else happening -- so the
## thing this director has to prove is the twelve seconds, not the arithmetic.
## Every beat below is either "the meal ran" or "something took it away".
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/rations.gd \
##     --out=/tmp/rations/x.png --warmup=60
##
## What it claims, in the order it proves them:
##
##   A  **The null case**, first and deliberately first. Nothing is eating, so
##      `meal_progress()` is 0 and there is NO `meal_gauge` in the HUD's layout.
##      See below for why this beat is the one that makes the rest mean anything.
##   B  The counter. Both rations are in the quartermaster's Trade stock, they cost
##      gold and no materials, a purchase puts `K.RATION_BATCH` in the pack, and
##      a full pack refuses by naming the pack.
##   C  The wheel. A ration binds to a kit slot, the ring steps onto it, and
##      `selected_item()` is the biscuit.
##   D  The sit. One press of X and he is DOWN -- rooted, in the rest pose, with
##      the gauge on screen -- and it fills as the meal runs.
##   E  The ticks. A whole hardtack pays exactly `K.MEAL_HEAL` quarters, in
##      `RationDb.ticks()` steps, and a whole small beer pays `K.MEAL_MAGIC`
##      magic. The stack went down by one and only one.
##   F  The interruptions, which are the item. A step ends it, a blow ends it,
##      and NEITHER gives the ration back.
##   G  The refusals with a known answer: a full heart row will not let you eat
##      at all, and a full blue bar will not let you drink.
##
## ## The calibration, and which direction it runs (CLAUDE.md §2)
##
## The defect this instrument could plausibly invent is a **false positive** --
## reporting a meal that ran, a gauge that drew and a bar that moved, off a HUD
## key that is always present and a heal some other system paid for. So the
## control is a null case rather than an injected signal: beat A asserts the
## gauge is ABSENT before anything is eaten, and beat E brackets the heal with
## the hero's health read immediately before and after, on a scene with nothing
## in it that heals. A `meal_gauge` key that were merely always in the layout
## would fail A, and a heal that came from anywhere else would fail E's exact
## equality rather than its inequality -- `_ck` on `== MEAL_HEAL`, never on `> 0`.
##
## Beat G is the same control from the other end and it is the cheaper half: it
## points the whole chain (press X -> `begin_meal` -> sit) at a state whose answer
## is already known to be "nothing happens", and asserts nothing happened.

## Enough to buy several batches of both and still have a visibly different purse.
const PURSE := 900

## Which kit slot the biscuit goes in. 3 rather than 0 because 0 is the sword's
## in every other director and a ration landing there would be a binding the
## reader has to think about.
const SLOT := 3

var out := ""
var _fails := 0


func run(rig) -> void:
	out = rig.arg("out", "/tmp/rations/x.png").get_base_dir()
	await rig.wait_frames(20)

	await _null_case(rig)
	await _counter(rig)
	await _wheel(rig)
	await _sit(rig)
	await _ticks(rig)
	await _interrupt(rig)
	await _refusals(rig)

	if _fails == 0:
		print("RATIONS OK bought, bound, eaten sitting down, and interrupted")
	else:
		print("RATIONS FAIL -- %d check(s) failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_fails += 1
		print("RATIONS FAIL %s" % label)


# --- A. The null case ---------------------------------------------------------

## **The control, and it runs before anything else has happened.**
##
## Every check below reads `Game.eating()` or looks for `meal_gauge` in the HUD's
## layout, and both of those are worth exactly nothing if they are true all the
## time. This is the frame where the honest answer is *nothing*, and this is the
## beat that says nothing is what it got. `frame_repro.gd`'s 0-of-921,600 is the
## same instrument pointed the same way (CLAUDE.md §2).
func _null_case(rig) -> void:
	Game.gold = PURSE
	_ck("A0 nobody is eating at boot", not Game.eating())
	_ck("A1 and the progress of no meal is zero (%.2f)" % Game.meal_progress(),
		is_zero_approx(Game.meal_progress()))
	_ck("A2 the pack starts empty (%s)" % [Game.rations],
		Game.rations.is_empty())
	# The layout is rebuilt every frame `_draw_hud` runs, so this is a question
	# about the frame just drawn and not about a dictionary somebody cleared.
	await rig.wait_frames(6)
	var keys: Dictionary = Hud.layout_rects()
	_ck("A3 the HUD drew no meal gauge (%d rects, none of them the gauge)"
		% keys.size(),
		keys.size() > 0 and not keys.has(&"meal_gauge"))
	await rig.capture(out.path_join("r_00_null.png"))


# --- B. Over the counter ------------------------------------------------------

func _counter(rig) -> void:
	var garrison := rig.scene() as Garrison
	if garrison == null or garrison.vendor == null:
		_ck("B0 the quartermaster is in the garrison", false)
		return
	_ck("B0 the quartermaster is in the garrison", true)
	_stand_at(rig, garrison.vendor.global_position + Vector3(0.0, 0.0, 1.6),
		garrison.vendor.global_position)
	var focused := await _wait_until(rig,
		func() -> bool: return Prompt.focus == garrison.vendor, 120)
	_ck("B1 she owns the interact button", focused)
	await rig.tap(["interact"])
	_ck("B2 she offers Trade", await rig.talk("Trade"))
	await rig.wait_frames(16)

	var screen := _screen(rig)
	if screen == null:
		_ck("B3 her counter opened", false)
		return
	_ck("B3 her counter opened", true)
	_ck("B4 it is the two-sided Trade service",
		screen.mode == TradeScreen.Mode.TRADE and screen.catalogue == SupplyDb
			and screen._stock_grid != null and screen._bag_grid != null)

	for id: StringName in RationDb.IDS:
		_ck("B4a %s belongs to the Trade stock subset" % id,
			SupplyDb.STOCK_IDS.has(id))

	for id: StringName in RationDb.IDS:
		var row := _row(screen, id)
		if row.is_empty():
			_ck("B5 %s is on the board" % id, false)
			continue
		_ck("B5 %s is on the board (%s)" % [id, row["line"]["label"]], true)
		_ck("B6 %s costs gold and NOT materials -- she issues, she does not brew"
			% id,
			int(row["line"]["cost"]) > 0
				and (row["line"].get("parts", {}) as Dictionary).is_empty())
		# The blurb has to say the twelve seconds. That sentence IS the item -- a
		# row reading "+1 heart" would be describing a cheaper Heart Draught, which
		# is the one thing this must not read as (`RationDb.effect_of`).
		_ck("B7 %s says what it costs in TIME (%s)" % [id, row["line"]["blurb"]],
			String(row["line"]["blurb"]).contains("%ds" % int(K.MEAL_TIME)))

	# Bought the way a player buys it, on the biscuit.
	var aimed := await _aim(rig, screen, &"hardtack")
	_ck("B8 the cursor is on the food row (%s)" % screen.cursor_label(), aimed)
	var gold_before := Game.gold
	await rig.capture(out.path_join("r_01_counter.png"))
	await rig.tap(["ui_accept"])
	await rig.wait_frames(12)
	_ck("B9 a purchase put a batch in the pack (%d)" % Game.ration_count(&"hardtack"),
		Game.ration_count(&"hardtack") == K.RATION_BATCH)
	_ck("B10 and it cost the counter's price (%d -> %d)" % [gold_before, Game.gold],
		Game.gold == gold_before - int(SupplyDb.RATION_GOLD[&"hardtack"]))

	# Drink too, so the ring below has two stops on it and E has something to
	# pour into the blue bar.
	Game.add_rations(&"small_beer", K.RATION_BATCH)

	# And the ceiling. `add_rations` clamps, so a full pack is a REFUSAL and not a
	# purchase that quietly evaporates -- the same shape the quiver keeps.
	Game.add_rations(&"hardtack", K.RATION_STACK)
	screen._refresh()
	var full := _row(screen, &"hardtack")
	_ck("B11 a full pack refuses (%d/%d)"
		% [Game.ration_count(&"hardtack"), K.RATION_STACK],
		not full.is_empty() and not SupplyDb.can_buy(full["line"]))
	_ck("B12 and the refusal names the pack, not the money (%s)"
		% SupplyDb.refusal(full["line"]),
		SupplyDb.refusal(full["line"]).contains("PACK"))
	await _aim(rig, screen, &"hardtack")
	await rig.wait_frames(6)
	await rig.capture(out.path_join("r_02_full.png"))

	await rig.tap(["ui_cancel"])
	var gone := await _wait_until(rig, func() -> bool: return _screen(rig) == null, 90)
	_ck("B13 her screen closed", gone)
	await rig.wait_frames(10)


# --- C. On the wheel ----------------------------------------------------------

func _wheel(rig) -> void:
	_ck("C0 a carried ration is bindable", Game.wheel_bindable(&"hardtack"))
	# And one you have none of is not. The pair is the check: "bindable" that
	# answers yes to everything is not a gate.
	_ck("C1 and one you are not carrying is not",
		not Game.wheel_bindable(&"mourning_dew"))
	_ck("C2 it binds to a kit slot", Game.wheel_bind(SLOT, &"hardtack"))
	_ck("C3 and the slot holds it (%s)" % Game.wheel_at(SLOT),
		Game.wheel_at(SLOT) == &"hardtack")
	_ck("C4 the slot is ready to fire", Game.wheel_ready(SLOT))
	# The RING, which is the thing D-pad down walks and the thing the HUD cell
	# counts. Bottles first and then rations, so the biscuit is past the glass.
	var ring := Game.carry_ids()
	print("RATIONS ring=%s" % [ring])
	_ck("C5 the ring carries the rations (%s)" % [ring],
		ring.has(&"hardtack") and ring.has(&"small_beer"))
	_ck("C6 selecting the slot puts it under the item cell",
		Game.wheel_select(SLOT) and Game.selected_item() == &"hardtack")
	_ck("C7 and `selected_ration` agrees with `selected_item` (%s / %s)"
		% [Game.selected_ration(), Game.selected_item()],
		Game.selected_ration() == &"hardtack")
	# A bottle is NOT a ration and the two accessors have to disagree about one.
	_ck("C8 while `selected_potion` says nothing -- a biscuit is not in glass",
		Game.selected_potion() == &"")
	await rig.wait_frames(8)
	await rig.capture(out.path_join("r_03_selected.png"))


# --- D. He sits down ----------------------------------------------------------

func _sit(rig) -> void:
	var hero := _hero(rig)
	if hero == null:
		_ck("D0 there is a hero to feed", false)
		return
	# Hurt first, or `begin_meal` refuses a full heart row and every check below
	# fails for the right reason at the wrong time. Half a row, so the whole
	# ration fits inside the headroom and E can assert an exact total.
	Game.quarters = maxi(1, Game.max_quarters / 2)
	Bus.player_health_changed.emit(Game.quarters, Game.max_quarters)
	var where := hero.global_position

	# **The button, not the function.** `Game.begin_meal` is what X reaches; a
	# director that called it directly would prove the meal and nothing about
	# whether a player can start one.
	await rig.tap(["use_item"])
	var started := await _wait_until(rig, func() -> bool: return Game.eating(), 60)
	_ck("D0 one press of X starts the meal", started)
	if not started:
		return
	_ck("D1 and it is the biscuit that is being eaten (%s)" % Game.meal_id,
		Game.meal_id == &"hardtack")

	await rig.wait_frames(30)
	# ROOTED. The blend is eased over `rest_fade`, so this is sampled after it has
	# had time to arrive rather than on the frame the meal began.
	var rest := float(hero._tree.get("parameters/Rest/blend_amount"))
	_ck("D2 he is in the rest pose (blend %.2f)" % rest, rest > 0.5)
	_ck("D3 and he has not moved (%.3f m)"
		% hero.global_position.distance_to(where),
		hero.global_position.distance_to(where) < 0.05)

	# The gauge -- on screen, and filling. Read off `Hud.layout_rects()`, which is
	# what the HUD actually drew, rather than off `Game.meal_left`, which is what
	# it was told. Those two came apart once already (#52, on an arrow counter
	# that was drawn and reported missing).
	var keys: Dictionary = Hud.layout_rects()
	var drawn: bool = keys.has(&"meal_gauge")
	_ck("D4 the HUD drew the meal gauge", drawn)
	if drawn:
		var e: Dictionary = keys[&"meal_gauge"]
		var r: Rect2 = e[&"rect"]
		_ck("D5 it is inside the item cell (parent=%s)" % e[&"parent"],
			e[&"parent"] == &"item_cell")
		_ck("D6 and it has pixels (%.1f x %.1f)" % [r.size.x, r.size.y],
			r.size.x > 1.0 and r.size.y > 0.0)
	await rig.capture(out.path_join("r_04_seated.png"))

	var early := Game.meal_progress()
	await rig.wait_seconds(K.MEAL_TICK)
	var later := Game.meal_progress()
	_ck("D7 the meal runs down (%.2f -> %.2f)" % [early, later], later > early)
	await rig.capture(out.path_join("r_05_halfway.png"))

	# Left alone to finish, so E can weigh the whole thing.
	await _wait_until(rig, func() -> bool: return not Game.eating(), 900)
	_ck("D8 and it ends on its own", not Game.eating())
	await rig.wait_frames(30)
	var stood := float(hero._tree.get("parameters/Rest/blend_amount"))
	_ck("D9 he stands back up (blend %.2f)" % stood, stood < 0.5)
	_ck("D10 and the gauge went with it",
		not Hud.layout_rects().has(&"meal_gauge"))
	await rig.capture(out.path_join("r_06_stood.png"))


# --- E. What a whole ration pays ---------------------------------------------

## Exact totals, never "went up". `> 0` would pass against a heal that came from
## anywhere -- and the garrison is a room with a bed, a fountain and an elder in
## it. `== K.MEAL_HEAL` is the only assertion that can tell those apart.
func _ticks(rig) -> void:
	_ck("E0 a whole ration is %d ticks" % RationDb.ticks(),
		RationDb.ticks() == int(round(K.MEAL_TIME / K.MEAL_TICK)))
	_ck("E1 and the ticks add up to the ration (%d x %d = %d)"
		% [RationDb.ticks(), RationDb.per_tick(&"hardtack"), K.MEAL_HEAL],
		RationDb.ticks() * RationDb.per_tick(&"hardtack") == K.MEAL_HEAL)
	_ck("E2 the same for the drink (%d x %d = %d)"
		% [RationDb.ticks(), RationDb.per_tick(&"small_beer"), K.MEAL_MAGIC],
		RationDb.ticks() * RationDb.per_tick(&"small_beer") == K.MEAL_MAGIC)

	# FOOD, weighed end to end. Bracketed immediately either side of one meal.
	Game.quarters = maxi(1, Game.max_quarters / 2)
	var health_before := Game.quarters
	var stack_before := Game.ration_count(&"hardtack")
	_ck("E3 a meal begins", Game.begin_meal(&"hardtack"))
	_ck("E4 and the biscuit leaves the pack on the FIRST frame (%d -> %d)"
		% [stack_before, Game.ration_count(&"hardtack")],
		Game.ration_count(&"hardtack") == stack_before - 1)
	await _wait_until(rig, func() -> bool: return not Game.eating(), 900)
	_ck("E5 the whole biscuit paid exactly %d quarters (%d -> %d)"
		% [K.MEAL_HEAL, health_before, Game.quarters],
		Game.quarters == health_before + K.MEAL_HEAL)

	# DRINK. The blue bar is the one nothing else in the game refills outside a
	# run boundary (`Game.fill_magic`), which makes it the cleaner of the two
	# brackets: there is no fountain for this one.
	Game.magic = maxi(0, Game.max_magic - K.MEAL_MAGIC)
	Bus.magic_changed.emit(Game.magic, Game.max_magic)
	var magic_before := Game.magic
	_ck("E6 a drink begins", Game.begin_meal(&"small_beer"))
	await rig.wait_frames(20)
	await rig.capture(out.path_join("r_07_drinking.png"))
	await _wait_until(rig, func() -> bool: return not Game.eating(), 900)
	_ck("E7 the whole cup paid exactly %d magic (%d -> %d)"
		% [K.MEAL_MAGIC, magic_before, Game.magic],
		Game.magic == magic_before + K.MEAL_MAGIC)
	# Which is one spin, and that equality is the entire reason the drink exists
	# at this size (`K.MEAL_MAGIC`, and the owner directive on `K.MAGIC_SPIN`).
	_ck("E8 and that is exactly one spin (%d)" % K.MAGIC_SPIN,
		K.MEAL_MAGIC == K.MAGIC_SPIN)


# --- F. The interruptions -----------------------------------------------------

## **This is the item.** Everything above is a heal on a delay; what makes a
## ration a stopgap rather than a cheap Heart Draught is that anything at all
## takes it away from you, and that you have already paid for it when it does.
func _interrupt(rig) -> void:
	var hero := _hero(rig)
	if hero == null:
		return

	# A STEP. Held long enough to clear the stick deadzone for a frame or two and
	# no longer -- the claim is that walking ends it, not that walking a metre does.
	Game.quarters = maxi(1, Game.max_quarters / 2)
	var stack_before := Game.ration_count(&"hardtack")
	_ck("F0 a meal begins", Game.begin_meal(&"hardtack"))
	await rig.wait_seconds(K.MEAL_TICK + 0.4)
	var paid := Game.quarters
	_ck("F1 it has paid at least one tick by %.0fs (%d)"
		% [K.MEAL_TICK, paid], paid > Game.max_quarters / 2)
	await rig.hold_seconds(["move_left"], 0.35)
	_ck("F2 a step ends it", not Game.eating())
	_ck("F3 and the biscuit is NOT given back (%d -> %d)"
		% [stack_before, Game.ration_count(&"hardtack")],
		Game.ration_count(&"hardtack") == stack_before - 1)
	_ck("F4 while the ticks it already paid are kept (%d)" % Game.quarters,
		Game.quarters == paid)
	await rig.wait_frames(20)
	var up := float(hero._tree.get("parameters/Rest/blend_amount"))
	_ck("F5 and he is on his feet again (blend %.2f)" % up, up < 0.5)

	# A BLOW. `Hero.take_hit` cancels at the very top, before it decides whether
	# the blow even lands, so this holds however the hit resolves.
	Game.quarters = maxi(2, Game.max_quarters / 2)
	stack_before = Game.ration_count(&"hardtack")
	_ck("F6 another meal begins", Game.begin_meal(&"hardtack"))
	await rig.wait_frames(20)
	_ck("F7 he is seated for it", Game.eating())
	var hit := Hit.new()
	hit.amount = K.QUARTER
	hit.from = hero.global_position + Vector3(0.0, 0.0, 2.0)
	hero.take_hit(hit)
	_ck("F8 a blow ends it", not Game.eating())
	_ck("F9 and that biscuit is gone too (%d -> %d)"
		% [stack_before, Game.ration_count(&"hardtack")],
		Game.ration_count(&"hardtack") == stack_before - 1)
	await rig.wait_frames(20)
	await rig.capture(out.path_join("r_08_interrupted.png"))


# --- G. The refusals with a known answer --------------------------------------

## The second half of the calibration. Every beat above asked the chain to do
## something and watched it happen; this asks it to do something whose answer is
## already *nothing* and watches nothing happen.
func _refusals(rig) -> void:
	Game.quarters = Game.max_quarters
	Bus.player_health_changed.emit(Game.quarters, Game.max_quarters)
	var stack := Game.ration_count(&"hardtack")
	_ck("G0 a full heart row refuses the biscuit", not Game.begin_meal(&"hardtack"))
	_ck("G1 and refusing costs nothing (%d)" % Game.ration_count(&"hardtack"),
		Game.ration_count(&"hardtack") == stack)
	_ck("G2 nobody sat down", not Game.eating())

	Game.fill_magic()
	var cups := Game.ration_count(&"small_beer")
	_ck("G3 a full blue bar refuses the drink", not Game.begin_meal(&"small_beer"))
	_ck("G4 and that costs nothing either (%d)" % Game.ration_count(&"small_beer"),
		Game.ration_count(&"small_beer") == cups)

	# The PRESS, not just the function -- the whole chain pointed at the known
	# answer. X on a full heart row must be a silent no-op and not a hero who sits
	# down for twelve seconds and gets up again having eaten a biscuit.
	Game.wheel_select(SLOT)
	await rig.tap(["use_item"])
	await rig.wait_frames(20)
	_ck("G5 and pressing X at full health does nothing at all",
		not Game.eating() and Game.ration_count(&"hardtack") == stack)
	_ck("G6 with no gauge on the HUD to say otherwise",
		not Hud.layout_rects().has(&"meal_gauge"))

	# An empty stack is the other end of the same question.
	Game.rations.erase(&"hardtack")
	Bus.rations_changed.emit(Game.rations)
	Game.quarters = maxi(1, Game.max_quarters / 2)
	_ck("G7 an empty stack refuses too", not Game.begin_meal(&"hardtack"))
	await rig.wait_frames(6)
	await rig.capture(out.path_join("r_09_refused.png"))


# --- Helpers ------------------------------------------------------------------

## Put the cursor on `id`'s row and prove it stayed there. See `charge_buy._aim`
## for the long version -- assigning `screen._cursor` is CLAUDE.md §3's trap and
## it has cost this repo three cards (#40, #74, #77). `_point_at` is the fix and
## checking the aim afterwards is the half that turns a drifted cursor into a
## failing beat instead of a mislabelled photograph.
func _aim(rig, screen, id: StringName) -> bool:
	var row := _row(screen, id)
	if row.is_empty():
		return false
	screen._point_at(screen._rows.find(row))
	await rig.wait_frames(8)
	var at := _row(screen, id)
	return not at.is_empty() and screen._cursor == screen._rows.find(at)


func _row(screen, id: StringName) -> Dictionary:
	for r in screen._rows:
		if r.get("kind") == &"buy" and r["line"]["id"] == id:
			return r
	return {}


func _screen(rig) -> TradeScreen:
	for n in _all(rig.scene()):
		if n is TradeScreen:
			return n as TradeScreen
	return null


func _hero(rig) -> Node3D:
	var players: Array = rig.get_nodes_in_group(&"player")
	return players[0] if not players.is_empty() else null


func _all(root: Node) -> Array:
	var found := [root]
	for c in root.get_children():
		found.append_array(_all(c))
	return found


## Poll rather than wait a fixed number of frames: the harness runs at whatever
## speed the machine allows, so every fixed wait is a wait of unknown duration.
func _wait_until(rig, cond: Callable, frames: int) -> bool:
	for _i in frames:
		if cond.call():
			return true
		await rig.wait_frames(1)
	return cond.call()


## Teleport. Pathing a hero across the garrison with synthetic input is its own
## project and the thing under test is the counter and the meal.
func _stand_at(rig, where: Vector3, look_at: Variant = null) -> void:
	var hero := _hero(rig)
	if hero == null:
		return
	hero.global_position = where
	if look_at != null:
		var to: Vector3 = K.flat((look_at as Vector3) - where)
		if to != Vector3.ZERO:
			hero.facing_yaw = atan2(to.x, to.z)
			hero.rotation.y = hero.facing_yaw + PI
