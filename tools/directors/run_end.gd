extends RefCounted
## Both ways a run can end, photographed, plus the walk back down afterwards.
##
## Four things this has to prove and one it has to prove twice:
##   1. dying raises RunEndScreen with the killer named and the haul crossed out;
##   2. extracting raises the SAME screen with the fee and the banked components;
##   3. BACK TO THE GARRISON actually goes to the garrison — and the button is
##      the only thing that does, so a screen that ignores it strands the run;
##   4. the garrison gate still opens afterwards, both times, which is the bug the
##      player reported ("A to descend doesn't work after I die").
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/run_end.gd --out=/tmp/rend/x.png

var out := ""
var _fails := 0
## The last prompt line the HUD was told to draw.
##
## A member and not a local in `_gate`, because the probe is a lambda: GDScript
## captures locals BY VALUE, so `said = text` inside one writes to the closure's
## own copy and the outer variable stays "" forever. It read as the game emitting
## nothing at all. Members go through `self`, which is captured by reference.
var _said := ""


func run(rig) -> void:
	out = rig.arg("out", "/tmp/rend/x.png").get_base_dir()
	await rig.wait_frames(30)

	await _death_leg(rig)
	await _extract_leg(rig)
	print("REND done fails=%d" % _fails)


# --- Leg one: killed underground --------------------------------------------

func _death_leg(rig) -> void:
	await _gate(rig, "first")
	if not Run.in_dungeon:
		_fail("could not get underground at all")
		return

	# A haul worth losing, one line of it a component so the sort order and the
	# rarity colours have something to do.
	Run.collect(&"iron_scrap", 6)
	Run.collect(&"deep_amber", 2)
	Run.collect(&"ghost_silk", 3)
	Run.collect(&"bone_shard", 11)
	# Two kills on the tally, done through the real door: Bus.enemy_died is what
	# Run counts, and faking the counter would prove nothing about the wiring.
	await _kill_two(rig)

	# Killed by a monster's own hitbox, so `Hit.source` carries a real name rather
	# than a string this director made up.
	var foe := _nearest_foe(rig)
	var hero = rig.get_nodes_in_group(&"player")[0]
	var hit := Hit.new()
	hit.amount = 99
	hit.from = hero.global_position + Vector3(0.0, 0.0, 2.0)
	hit.knockback = 5.0
	hit.source = &"ELITE WRAITH" if foe == null else _name_of(foe)
	hero.take_hit(hit)

	await rig.wait_frames(150)
	var screen := _screen(rig)
	print("REND death screen=%s paused=%s scene=%s kills=%d killer=%s" % [
		screen != null, rig.paused, rig.scene().name,
		int(Run.summary.get("kills", -1)), Run.summary.get("killer", &"")])
	if screen == null:
		_fail("no ending screen after a death")
		return
	if not rig.paused:
		_fail("the ending screen is up and the world is still running")
	if String(Run.summary.get("killer", &"")).is_empty():
		_fail("the ending screen cannot say what killed you")
	await rig.capture(out.path_join("e_00_died.png"))

	await _press_back(rig, "death")
	if rig.scene() is not Garrison:
		_fail("BACK TO THE GARRISON did not go to the garrison (scene=%s)" % rig.scene().name)
		return
	print("REND home paused=%s level=%d hp=%d/%d" % [
		rig.paused, Run.level, Game.health_points, Game.max_health_points])
	if rig.paused:
		_fail("the tree is still paused in the garrison")
	if Run.level != 1:
		_fail("garrison thinks we are on floor %d" % Run.level)
	await rig.capture(out.path_join("e_01_garrison.png"))


# --- Leg two: walked out with the bag ---------------------------------------

func _extract_leg(rig) -> void:
	await _gate(rig, "after death")
	if not Run.in_dungeon:
		_fail("the gate does not open after a death — the reported bug")
		return
	print("REND second descent ok, level=%d" % Run.level)

	Run.collect(&"deep_amber", 3)
	Run.collect(&"iron_scrap", 4)
	# A component, so the screen has a TO THE BENCH line to draw. Picked off the
	# database rather than named, so a renamed component cannot silently make this
	# beat test nothing.
	var comp := _some_component()
	if comp != &"":
		Run.collect(comp, 2)
	await _kill_two(rig)
	await rig.wait_frames(10)

	# Enough gold that the fee cannot refuse, and the fee is the line under test.
	Game.add_gold(Run.extract_cost() + 100)
	var fee := Run.extract_cost()
	if not Run.extract():
		_fail("extract() refused with the fee covered")
		return
	await rig.wait_frames(150)

	var screen := _screen(rig)
	print("REND extract screen=%s fee=%d(%d) banked=%d haul=%d" % [
		screen != null, int(Run.summary.get("fee", -1)), fee,
		(Run.summary.get("banked", {}) as Dictionary).size(),
		int(Run.summary.get("value", 0))])
	if screen == null:
		_fail("no ending screen after an extraction")
		return
	if int(Run.summary.get("fee", 0)) <= 0:
		_fail("the extraction screen does not know what the toll was")
	if comp != &"" and (Run.summary.get("banked", {}) as Dictionary).is_empty():
		_fail("a component was carried out and the screen banked nothing")
	if comp != &"" and not (Run.summary.get("contents", {}) as Dictionary).has(comp):
		_fail("the component is missing from the haul — snapshot taken too late")
	await rig.capture(out.path_join("e_02_extracted.png"))

	await _press_back(rig, "extract")
	if rig.scene() is not Garrison:
		_fail("BACK TO THE GARRISON did not go to the garrison after an extraction")
		return
	await rig.capture(out.path_join("e_03_garrison_again.png"))

	# And down one more time, because the gate is the thing that broke.
	await _gate(rig, "after extract")
	if not Run.in_dungeon:
		_fail("the gate does not open after an extraction")
	print("REND third descent in_dungeon=%s" % Run.in_dungeon)


# --- Pieces -----------------------------------------------------------------

## Stand at the gate, check the prompt SAYS HOLD, and hold it.
func _gate(rig, tag: String) -> void:
	var garrison := rig.scene() as Garrison
	if garrison == null:
		_fail("not in the garrison for the %s descent (scene=%s)" % [tag, rig.scene().name])
		return
	_said = ""
	var probe := func(text: String) -> void:
		if not text.is_empty():
			_said = text
	Bus.prompt_changed.connect(probe)

	var hero = rig.get_nodes_in_group(&"player")[0]
	hero.global_position = garrison.gate.global_position + Vector3(0.0, 0.0, 1.8)
	for _i in 60:
		if Prompt.focus == garrison.gate:
			break
		await rig.wait_frames(2)
	Bus.prompt_changed.disconnect(probe)

	print("REND %s gate prompt=\"%s\"" % [tag, _said])
	if Prompt.focus != garrison.gate:
		_fail("nothing owns the interact button at the gate (%s)" % tag)
		return
	# The whole of the reported bug in one assertion: a 0.9 s hold whose prompt
	# does not say HOLD is a prompt that reads as broken to anyone who taps it.
	if _said.find("HOLD") == -1:
		_fail("the gate prompt does not say HOLD: \"%s\"" % _said)

	# A tap must NOT open it, which is what makes the word load-bearing.
	await rig.tap([&"interact"])
	await rig.wait_frames(20)
	if Run.in_dungeon:
		_fail("a TAP opened the gate — the hold is not being enforced")
		return

	await rig.hold_seconds([&"interact"], 1.4)
	await rig.wait_frames(180)


## Press the screen's one button and wait out the fade.
func _press_back(rig, tag: String) -> void:
	var screen := _screen(rig)
	if screen == null:
		return
	# Past the settle window first, or the press is correctly ignored.
	await rig.wait_seconds(RunEndScreen.SETTLE + 0.2)
	await rig.hold_seconds([&"ui_accept"], 0.2)
	await rig.wait_frames(240)
	print("REND %s back-to-garrison -> scene=%s ending=%s busy=%s" % [
		tag, rig.scene().name, Flow.ending, Flow.busy])
	if _screen(rig) != null:
		_fail("the ending screen survived the ride home (%s)" % tag)


## Two kills through the real damage path, so `Run.kills` is counting the signal
## the game emits and not a number this director wrote.
func _kill_two(rig) -> void:
	var before := Run.kills
	for _i in 2:
		var foe := _nearest_foe(rig)
		if foe == null:
			break
		foe.health.apply_hit(Hit.make(999, foe.global_position + Vector3.FORWARD))
		await rig.wait_frames(20)
	await rig.wait_frames(30)
	print("REND kills %d -> %d" % [before, Run.kills])
	if Run.kills <= before:
		_fail("killing monsters does not move the run tally")


func _name_of(foe: Node3D) -> StringName:
	var k := String(foe.get("kind"))
	return StringName(("ELITE " if bool(foe.get("elite")) else "") + k.to_upper())


func _nearest_foe(rig) -> Node3D:
	for f in rig.get_nodes_in_group(&"enemy"):
		if is_instance_valid(f) and not f.health.dead:
			return f
	return null


func _some_component() -> StringName:
	var ids := ItemDb.components()
	return ids[0] if not ids.is_empty() else &""


func _screen(rig) -> RunEndScreen:
	for n in _all(rig.scene()):
		if n is RunEndScreen:
			return n
	return null


func _all(root: Node) -> Array:
	var found := [root]
	for c in root.get_children():
		found.append_array(_all(c))
	return found


func _fail(msg: String) -> void:
	_fails += 1
	print("REND FAIL %s" % msg)
