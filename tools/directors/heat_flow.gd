extends RefCounted
## Proves the Heat slice, and photographs it.
##
## Six claims, each of which fails loudly rather than quietly:
##
##   1. a kill in the dungeon raises the chain, and refunds stamina
##   2. the tiers step at 2 / 5 / 9 kills and the multiplier climbs with them
##   3. loot swept while lit banks a premium, which lands in Run.bag_value()
##   4. ...and therefore raises Run.extract_cost() without any fee code knowing
##   5. a blow that LANDS breaks the chain; healing back does not restore it
##   6. the chain cools on its own when nothing dies
##
## Enemies are killed by draining their HealthComponent rather than by swinging.
## The sword is proven by p4_combat.gd; what is under test here is the economy
## hanging off `Bus.enemy_died`, and pathing synthetic input to nine bodies
## inside a 2.5 s window is a different project (see the note in mvp_loop.gd).
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/heat_flow.gd --out=/tmp/heat/x.png

var out := ""
var fails := 0


func run(rig) -> void:
	out = rig.arg("out", "/tmp/heat/x.png").get_base_dir()
	await rig.wait_frames(30)

	if not Run.in_dungeon:
		# The dungeon scene can be booted directly, which never calls Run.enter()
		# and so leaves the run cold, the bag stale and Heat refusing every kill.
		Run.enter(4242)
		await rig.wait_frames(10)

	await _cold(rig)
	await _climb(rig)
	await _sweep(rig)
	await _struck(rig)
	await _cool(rig)

	print("HEAT %s" % ("OK" if fails == 0 else "%d FAILURES" % fails))


# --- Beats ------------------------------------------------------------------

func _cold(rig) -> void:
	print("HEAT cold kills=%d tier=%d mult=%.2f bag=%d fee=%d" % [
		Heat.kills, Heat.tier, Heat.multiplier(), Run.bag_value(), Run.extract_cost()])
	_expect(Heat.tier == 0, "a fresh run starts cold")
	_expect(is_equal_approx(Heat.multiplier(), 1.0), "cold pays base value")
	await rig.capture(out.path_join("h_00_cold.png"))


## Kill up the ladder, photographing the bar at every tier. Stamina is spent to
## zero first so the refund has somewhere to land and is visible on the bar.
func _climb(rig) -> void:
	Game.stamina = 0.0
	Bus.stamina_changed.emit(Game.stamina, Game.max_stamina)
	await rig.wait_frames(4)

	var seen := {}
	for i in 9:
		if not _kill_one(rig):
			_fail("ran out of enemies at kill %d -- the floor spawned too few" % i)
			break
		await rig.wait_frames(3)
		print("HEAT kill %d -> kills=%d tier=%d mult=%.2f window=%.2f stamina=%.0f" % [
			i + 1, Heat.kills, Heat.tier, Heat.multiplier(), Heat.window01(),
			Game.stamina])
		if not seen.has(Heat.tier):
			seen[Heat.tier] = true
			await rig.capture(out.path_join("h_01_tier%d.png" % Heat.tier))

	_expect(Game.stamina > 0.0, "kills hand stamina back")
	_expect(Heat.tier == 3, "nine kills reaches Blazing (got tier %d)" % Heat.tier)
	_expect(Heat.multiplier() > 2.0, "Blazing pays over double")
	# The window has to be SHORTER at the top than at the bottom, or the meter is
	# a reward with no teeth -- that shrink is the entire tension of the system.
	_expect(K.HEAT_TIER_WINDOW[3] < K.HEAT_TIER_WINDOW[1],
		"the window shrinks as the chain climbs")
	await rig.capture(out.path_join("h_02_blazing.png"))


## Drop loot at full heat, sweep it, and check the premium reaches the fee.
func _sweep(rig) -> void:
	var hero: Node3D = rig.scene().get_tree().get_first_node_in_group(&"player")
	if hero == null:
		_fail("no hero in the scene")
		return

	var before_value := Run.bag_value()
	var before_fee := Run.extract_cost()
	var mult := Heat.multiplier()

	# Six of one thing, so the arithmetic below is checkable by eye in the log.
	for i in 6:
		var a := float(i) / 6.0 * TAU
		LootMote.drop(rig.scene(), &"iron_scrap",
			hero.global_position + Vector3(sin(a), 0.0, cos(a)) * 2.0)
	await rig.wait_frames(20)
	print("HEAT motes dropped at x%.2f" % mult)
	await rig.capture(out.path_join("h_03_hot_motes.png"))

	# Do NOT walk him onto them: magnetism at Blazing reaches 4.5 m and these are
	# at 2.0 m, so standing still and having them come to him IS the test.
	await rig.wait_seconds(1.2)
	print("HEAT after_sweep bag=%d premium=%d fee=%d (was value=%d fee=%d)" % [
		Run.bag_value(), Run.premium, Run.extract_cost(), before_value, before_fee])
	_expect(Run.premium > 0, "sweeping hot loot banks a premium")
	_expect(Run.bag_value() == Run.base_value() + Run.premium,
		"the premium is inside bag_value()")
	_expect(Run.extract_cost() > before_fee,
		"a hot bag costs more to bank than a cold one")

	# The premium is UNDER the naive figure on purpose, and by how much is the
	# proof that motes cool: dropped at x2.20 and swept about a second later,
	# each one has already given some of its heat back to the floor. A premium
	# that matched the drop-time multiplier exactly would mean cooling is dead.
	var def := ItemDb.get_def(&"iron_scrap")
	var uncooled := int(round(Run.bag_count() * def.value * (mult - 1.0)))
	print("HEAT premium %d vs %d uncooled -- the gap IS the cooling" % [
		Run.premium, uncooled])
	_expect(Run.premium < uncooled, "loot cools on the floor before it is swept")
	await rig.capture(out.path_join("h_04_premium.png"))


## A blow that lands takes a tier. Healing afterwards must not hand it back --
## the chain is not a resource you can buy your way out of losing.
func _struck(rig) -> void:
	var before := Heat.tier
	Game.damage(2 * K.QUARTER)
	# Two frames, not six. Bus signals are synchronous, so the break has already
	# landed; the wait is only to let the HUD repaint, and every extra frame is
	# eating into the flash this beat exists to photograph.
	await rig.wait_frames(2)
	print("HEAT struck tier %d -> %d kills=%d" % [before, Heat.tier, Heat.kills])
	_expect(Heat.tier < before, "a landed blow drops a tier")
	# Caught INSIDE the 0.35 s break flash, so the frame carries the RUST bar.
	# Capturing after the heal below misses it, and a flash nobody photographed
	# is a flash nobody has checked renders.
	await rig.capture(out.path_join("h_05_broken.png"))

	# Asserted with <=, not ==. The window is draining the whole time this runs
	# and a capture costs real seconds, so a natural step-down between the two
	# reads is legal; what must never happen is the chain going back UP.
	var after_break := Heat.tier
	Game.heal(Game.max_quarters)
	await rig.wait_frames(6)
	_expect(Heat.tier <= after_break, "healing does not restore the chain")
	await rig.capture(out.path_join("h_05b_healed.png"))


## Stand still and let it die. Two full windows is enough to step down twice.
func _cool(rig) -> void:
	var before := Heat.tier
	await rig.wait_seconds(K.HEAT_TIER_WINDOW[1] * 2.0 + 0.5)
	print("HEAT cooled tier %d -> %d kills=%d" % [before, Heat.tier, Heat.kills])
	_expect(Heat.tier < before or Heat.kills == 0,
		"the chain cools when nothing dies")
	await rig.capture(out.path_join("h_06_cooled.png"))


# --- Helpers ----------------------------------------------------------------

## Drain the nearest living enemy's health so it dies through the normal path --
## HealthComponent.died -> _on_died -> Bus.enemy_died, which is the signal the
## whole system hangs off. Killing it with queue_free() would prove nothing.
func _kill_one(rig) -> bool:
	for n in rig.scene().get_tree().get_nodes_in_group(&"enemy"):
		var hp = n.get(&"health")
		if hp == null or hp.dead:
			continue
		hp.apply_hit(Hit.make(hp.quarters + 4, n.global_position, &"director", 0.0))
		return true
	return false


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fail(what)


func _fail(what: String) -> void:
	fails += 1
	print("HEAT FAIL %s" % what)
