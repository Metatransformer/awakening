extends RefCounted
## The garrison fills up as you dig.
##
##   godot --path . -s tools/shoot.gd -- \
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
##   B  Kill the first boss and the smith is in the yard next time you walk into
##      it, with his booth and his lamp and his own arrival line.
##   C  And he stays. The gate latches to a flag, so a keeper who arrived cannot
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
	_ck("A1 and so is the pawnbroker", g.vendor != null)
	_ck("A2 the smith is not", g.smith == null)
	_ck("A3 nor the alchemist", g.alchemist == null)
	_ck("A4 nor the jewelcrafter", g.jeweller == null)
	_ck("A5 the way down is open anyway", g.gate != null)

	await rig.capture(out.path_join("r_01_before.png"))


# --- B/C. One boss later -------------------------------------------------------

func _after(rig) -> void:
	# The flag a killed boss leaves behind (`BossDoor.dead_flag`). Set by hand
	# because this director is about the garrison and not about the fight -- and
	# because a director that had to survive `cistern_warden` to photograph a
	# shopkeeper would be a director nobody runs.
	Game.set_flag(&"boss_dead_cistern_warden")
	_ck("B0 one boss counts as one", StoryDb.bosses_felled() == 1)
	_ck("B1 which admits the smith and nobody else",
		StoryDb.unlocked(&"smith") and not StoryDb.unlocked(&"alchemist")
			and not StoryDb.unlocked(&"jewelcrafter"))

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

	# C. The latch. `unlocked` stamps a flag the first time the metric is met, so
	# an arrival cannot be undone by anything that touches the metric afterwards.
	Game.flags.erase(&"boss_dead_cistern_warden")
	_ck("C0 the count went back down", StoryDb.bosses_felled() == 0)
	_ck("C1 and the smith is here regardless", StoryDb.unlocked(&"smith"))


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
