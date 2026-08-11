extends RefCounted
## The garrison fills up as you dig.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/roster.gd \
##     --fresh --out=/tmp/roster/x.png --warmup=40
##
## **`--fresh` is required** and the director says so if it is missing. Every
## other garrison director wants all five counters open and `tools/shoot.gd`
## stamps the arrival flags to give them that; this one is about the flags, so it
## is the one run that declines them.
##
## What it claims:
##
##   A  A new save's yard is Aldric, Kessa and the way down. The smith, the
##      alchemist and the jewelcrafter are not standing in it -- not greyed out,
##      not refusing to trade, NOT THERE.
##   B  Bring up the maker's mark off the floor 1 miniboss and the smith is in
##      the yard next time you walk into it, with his booth and his lamp.
##   C  Kill the first BOSS and the alchemist follows him. Two different kinds of
##      key on one ladder, which is card #91's whole shape: the smith is behind an
##      OBJECT you carried home and the other two are behind a body count.
##   D  And they stay. The gate latches to a flag, so a keeper who arrived cannot
##      un-arrive.
##
## The frames are the point (CLAUDE.md §2): `r_01_before` and `r_02_after` are the
## arrival camera on the same yard -- the smith's corner is bare grass in one and a
## forge with a dwarf behind it in the other.

const GARRISON := "res://scenes/rooms/garrison.tscn"

var out := ""
var _fails := 0


func run(rig) -> void:
	out = rig.arg("out", "/tmp/roster/x.png").get_base_dir()

	if not Game.flag(&"reported_for_duty") or Game.flag(StoryDb.arrival_flag(&"smith")):
		# The second half is the real test: `--fresh` is what leaves the smith's
		# flag unset. Said out loud rather than worked around, because a run of
		# this director without it would pass every check for the wrong reason.
		print("ROSTER FAIL run this one with --fresh (the smith is already here)")
		_fails += 1

	await _before(rig)
	await _after(rig)

	if _fails == 0:
		print("ROSTER OK")
	else:
		print("ROSTER FAIL -- %d check(s) failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_fails += 1
		print("ROSTER FAIL %s" % label)


# --- A. The empty yard ---------------------------------------------------------

func _before(rig) -> void:
	var g: Garrison = rig.scene()
	if g == null:
		_ck("A0 there is a garrison", false)
		return
	print("ROSTER bosses=%d gold_earned=%d" % [StoryDb.bosses_felled(), Game.gold_earned])
	_ck("A0 Aldric is here from the first frame", g.keeper != null)
	_ck("A1 and so is the quartermaster", g.vendor != null)
	_ck("A2 the smith is not", g.smith == null)
	_ck("A3 nor the alchemist", g.alchemist == null)
	_ck("A4 nor the jewelcrafter", g.jeweller == null)
	_ck("A5 the way down is open anyway", g.gate != null)

	await rig.capture(out.path_join("r_01_before.png"))


# --- B. The mark comes home -----------------------------------------------------

## **An object and not a kill count**, which is what changed on card #91. The
## sluice keeper -- the floor 1 miniboss -- drops `makers_mark`
## (`BossDb.MINIBOSSES`), the mark goes to Valenfeld, and Brannoc comes back on
## the next cart. Granted by hand here for the reason the boss flag below is: this
## director is about the garrison and not about the fight, and one that had to
## survive a miniboss to photograph a shopkeeper is a director nobody runs.
func _after(rig) -> void:
	Game.grant(StoryDb.SMITH_TOKEN)
	_ck("B0 the mark is in the pack", Game.has(StoryDb.SMITH_TOKEN))
	_ck("B1 which admits the smith and nobody else",
		StoryDb.unlocked(&"smith") and not StoryDb.unlocked(&"alchemist")
			and not StoryDb.unlocked(&"jewelcrafter"))
	# Still zero. The point of the amendment is that the smith arrives WITHOUT a
	# boss being dead, so a save can reach the forge on its first descent.
	_ck("B1b and no boss has been felled (%d)" % StoryDb.bosses_felled(),
		StoryDb.bosses_felled() == 0)

	var g: Garrison = await _rebuild(rig)
	if g == null:
		_ck("B2 the yard came back", false)
		return
	_ck("B2 and he is standing in it", g.smith != null)
	_ck("B3 with his counter in front of him",
		g.smith != null and _has_booth(g.smith))
	_ck("B4 the other two are still on the road",
		g.alchemist == null and g.jeweller == null)

	await rig.capture(out.path_join("r_02_after.png"))
	await _boss(rig)


# --- C. One boss later ----------------------------------------------------------

## The flag a killed boss leaves behind (`BossDoor.dead_flag`).
func _boss(rig) -> void:
	Game.set_flag(&"boss_dead_cistern_warden")
	_ck("C0 one boss counts as one", StoryDb.bosses_felled() == 1)
	_ck("C1 which admits the alchemist and not the jewelcrafter",
		StoryDb.unlocked(&"alchemist") and not StoryDb.unlocked(&"jewelcrafter"))

	var g: Garrison = await _rebuild(rig)
	if g == null:
		_ck("C2 the yard came back again", false)
		return
	_ck("C2 and Ysolt is standing in it", g.alchemist != null)
	_ck("C3 with the smith still beside him", g.smith != null)
	_ck("C4 and the setting bench still empty", g.jeweller == null)

	await rig.capture(out.path_join("r_03_alchemist.png"))

	# D. The latch. `unlocked` stamps a flag the first time the metric is met, so
	# an arrival cannot be undone by anything that touches the metric afterwards
	# -- including losing the object the gate was keyed to, which is the case the
	# smith's rung newly has and the other two do not.
	Game.flags.erase(&"boss_dead_cistern_warden")
	Game.items.erase(StoryDb.SMITH_TOKEN)
	_ck("D0 the count went back down", StoryDb.bosses_felled() == 0)
	_ck("D1 and the mark is gone from the pack", not Game.has(StoryDb.SMITH_TOKEN))
	_ck("D2 the smith is here regardless", StoryDb.unlocked(&"smith"))
	_ck("D3 and so is the alchemist", StoryDb.unlocked(&"alchemist"))


# --- helpers -------------------------------------------------------------------

## Tear the yard down and build it again, which is what walking back in from a
## run does (`Flow` re-instances the scene). Deferred `add_child` in a retry loop
## for CLAUDE.md §3's reason: resuming inside the tree's process loop finds `root`
## locked and answers "Parent node is busy setting up children".
func _rebuild(rig) -> Garrison:
	var old: Node = rig.scene()
	var parent: Node = old.get_parent()
	old.queue_free()
	await rig.wait_frames(2)

	var packed := load(GARRISON) as PackedScene
	if packed == null:
		return null
	var fresh := packed.instantiate()
	for _attempt in 240:
		if fresh.is_inside_tree():
			break
		parent.add_child.call_deferred(fresh)
		await rig.wait_frames(1)
	if not fresh.is_inside_tree():
		return null
	# `rig` IS the SceneTree (`shoot.gd extends SceneTree`), so this one assignment
	# is both the rig's `scene()` and the tree's own `current_scene` -- which is
	# where `DialogueBox` parents itself. One property, not two.
	rig.current_scene = fresh
	await rig.wait_frames(40)
	return fresh as Garrison


func _has_booth(who: Node) -> bool:
	for c in who.get_children():
		if c is ShopBooth:
			return true
	return false
