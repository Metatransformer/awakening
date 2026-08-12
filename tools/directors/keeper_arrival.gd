extends RefCounted
## Two keepers unlocked in one descent: who is standing in the yard, and who
## gets introduced. Card #115.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/keeper_arrival.gd \
##     --fresh --out=/tmp/arrival/x.png --warmup=40
##
## **`--fresh` and nothing else.** The harness's default stamping is exactly
## wrong for this director in both directions — it puts all five keepers in the
## yard and marks every one of them already met — so this one declines the
## arrivals (`--fresh`) and erases the two `met_` flags it cares about by hand
## before its first observation. Everything below is judged on a yard built AFTER
## that, which `_rebuild` is for: the state a director inherits from `shoot.gd` is
## never the state under test here.
##
## The playtest it comes from (owner, 2026-08-12): one descent took the floor 1
## miniboss AND the floor 1 boss, so the smith and the alchemist unlocked in the
## same run. Both were standing in the yard on the way home and **only the smith
## was introduced** — the alchemist was a stranger at a new counter.
##
## What it claims, in the order it proves them:
##
##   A  **The root cause.** Two `Introduction.play` calls back to back open TWO
##      boxes. They did not: `finished` is emitted from `DialogueBox._exit_tree`,
##      which runs inside `Node.remove_child` on the current scene — the scene is
##      `blocked` for the length of that call, so the second scene's `add_child`
##      was refused, the second box never entered the tree, and the `await` on a
##      box that can never leave the tree hung forever. This beat is the
##      regression test for that and it is deliberately NOT routed through
##      `Garrison`: the defect is in the join between the box and the caller, and
##      it would bite any other caller the same way.
##   B  **First homecoming.** The smith walks in and is introduced. The alchemist
##      is unlocked, latched, and NOT in the yard — no body, no counter. One
##      introduction, not two.
##   C  **Second homecoming.** She is introduced now, and her counter is there.
##      The smith stays, and nobody is introduced twice.
##
## The frames are the point (CLAUDE.md §2). `k_02_apothecary_empty` and
## `k_04_apothecary_staffed` are one fixed camera on the alchemist's own counter,
## one homecoming apart: an empty bench in the first and Ysolt behind it in the
## second. See `_shoot_the_apothecary` for why it is not the arrival camera.

const GARRISON := "res://scenes/rooms/garrison.tscn"

var out := ""
var _rig = null


func run(rig) -> void:
	_rig = rig
	out = rig.arg("out", "/tmp/arrival/x.png").get_base_dir()

	if Game.flag(StoryDb.arrival_flag(&"jewelcrafter")):
		rig.fail("K0 run this one with --fresh (the harness has already opened "
			+ "the whole yard, and there is no arrival left to watch)")
		return

	await _a_back_to_back(rig)
	await _b_first_homecoming(rig)
	await _c_second_homecoming(rig)


# --- The scenario --------------------------------------------------------------

## The save the playtest was on: the mark and the first boss both came home, so
## two keepers have ARRIVED and neither has been introduced.
##
## `Game.flags.erase` and not a fresh `Game`: `--fresh` declines to stamp the
## arrivals but `shoot.gd` still marks everybody met (`_skip_the_introductions`),
## and that default is the one thing this director must not inherit.
func _stage_the_playtest() -> void:
	Game.set_flag(StoryDb.arrival_flag(&"smith"))
	Game.set_flag(StoryDb.arrival_flag(&"alchemist"))
	Game.flags.erase(StoryDb.intro_flag(&"smith"))
	Game.flags.erase(StoryDb.intro_flag(&"alchemist"))
	# Kessa is ungated and her scene belongs to the opening, which the harness
	# skips. Leaving her owed would put her first in ladder order and this
	# director would be watching the wrong arrival.
	Game.set_flag(StoryDb.intro_flag(&"quartermaster"))
	Game.set_flag(StoryDb.intro_flag(&"jewelcrafter"))


# --- A. Two scenes back to back -------------------------------------------------

## Play two introductions the way `Garrison` used to, and count the boxes.
##
## Fire-and-forget, exactly as the yard does it, because the whole failure lives
## in when the second `play` resumes: awaiting the pair from here would serialise
## them onto this coroutine and could not reproduce anything.
func _a_back_to_back(rig) -> void:
	_stage_the_playtest()
	var host: Node = rig.scene()
	if not rig.check(host != null, "A0 there is a garrison to talk in"):
		return

	_both(host)
	var boxes := await _turn_the_pages(rig, 2)
	rig.check(boxes >= 2,
		"A1 two introductions back to back open two boxes (%d opened)" % boxes)
	rig.check(Game.flag(StoryDb.intro_flag(&"smith"))
		and Game.flag(StoryDb.intro_flag(&"alchemist")),
		"A2 and both are marked met (smith=%s alchemist=%s)"
			% [Game.flag(StoryDb.intro_flag(&"smith")),
				Game.flag(StoryDb.intro_flag(&"alchemist"))])


func _both(host: Node) -> void:
	await Introduction.play(host, &"smith")
	await Introduction.play(host, &"alchemist")


## Press `interact` at whatever box is up until no more arrive, and answer how
## many DISTINCT boxes were seen.
##
## Counted on the null->box EDGE rather than by instance id, because an id is
## reused the moment the first box is freed and two scenes would read as one.
## And the button is only ever pressed at a box that is actually up: a stray
## `interact` in an empty yard lands on the Lanternkeeper, who stands inside his
## own trigger radius of the spawn, and opens a conversation this would then
## count.
func _turn_the_pages(rig, want: int, patience: int = 500) -> int:
	var boxes := 0
	var had := false
	var quiet := 0
	for _i in patience:
		var box: Node = rig.dialogue()
		if box != null:
			if not had:
				boxes += 1
			had = true
			quiet = 0
			await rig.tap(["interact"])
		else:
			had = false
			quiet += 1
			# Long enough to cover the beat `Introduction` leaves between two
			# scenes, and to notice that a second one is never coming.
			if boxes >= want and quiet > 120:
				break
		await rig.wait_frames(2)
	return boxes


# --- B and C. Two homecomings ---------------------------------------------------

func _b_first_homecoming(rig) -> void:
	_stage_the_playtest()
	var g: Garrison = await _rebuild(rig)
	if not rig.check(g != null, "B0 the yard came back"):
		return

	rig.check(g.smith != null, "B1 the smith is in the yard")
	rig.check(g.alchemist == null,
		"B2 and the alchemist, who arrived in the same run, is NOT")
	rig.check(g.vendor != null and g.keeper != null,
		"B3 the two who live here are still here")
	rig.check(StoryDb.unlocked(&"alchemist"),
		"B4 her arrival is still latched — she is on the road, not un-arrived")

	await _watch_the_arrival(rig, g, &"smith", "B", "k_01_smith_intro")

	rig.check(Game.flag(StoryDb.intro_flag(&"smith")),
		"B7 the smith has been met")
	rig.check(not Game.flag(StoryDb.intro_flag(&"alchemist")),
		"B8 and the alchemist has NOT — one introduction per homecoming")
	await _shoot_the_apothecary(rig, g, "k_02_apothecary_empty.png")


func _c_second_homecoming(rig) -> void:
	var g: Garrison = await _rebuild(rig)
	if not rig.check(g != null, "C0 the yard came back again"):
		return

	rig.check(g.alchemist != null, "C1 the alchemist is in the yard now")
	rig.check(g.alchemist != null and _has_booth(g.alchemist),
		"C2 with her counter in front of her")
	rig.check(g.smith != null, "C3 and the smith is still beside her")

	await _watch_the_arrival(rig, g, &"alchemist", "C", "k_03_alchemist_intro")

	rig.check(Game.flag(StoryDb.intro_flag(&"alchemist")),
		"C6 she has been met")
	rig.check(StoryDb.pending_introduction() == &"",
		"C7 and nobody is owed one now")
	await _shoot_the_apothecary(rig, g, "k_04_apothecary_staffed.png")


## The scene this visit owes: one box, the elder opening it, the camera on the
## person being named, and exactly one box for the whole visit.
func _watch_the_arrival(rig, g: Garrison, who: StringName, tag: String,
		frame: String) -> void:
	var opened: bool = await rig.until(
		func() -> bool: return rig.dialogue() != null, 8.0)
	if not rig.check(opened, "%s5a somebody is introduced" % tag):
		return
	var box: Node = rig.dialogue()
	rig.check(box.speaker_name() == DialogueDb.name_of(&"elder"),
		"%s5b the elder opens it (%s)" % [tag, box.speaker_name()])

	# Forward until the newcomer answers, then photograph the shot that is the
	# whole reason they have to be standing in the yard for their own scene.
	for _i in 8:
		if rig.dialogue() == null or box.speaker == who:
			break
		await rig.tap(["interact"])
		await rig.wait_frames(2)
	rig.check(box.speaker == who,
		"%s5c and %s answers him (%s)" % [tag, who, box.speaker])
	var cam := _convo(rig)
	if cam != null:
		await rig.until(func() -> bool: return cam.settled(), 3.0)
	rig.check(cam != null, "%s5d the conversation has the camera" % tag)
	await rig.capture(out.path_join("%s.png" % frame))

	var boxes := await _turn_the_pages(rig, 1)
	rig.check(boxes == 1,
		"%s6 exactly one introduction played this visit (%d)" % [tag, boxes])


# --- helpers -------------------------------------------------------------------

## Tear the yard down and build it again, which is what walking home from a run
## does (`Flow` re-instances the scene). Deferred `add_child` in a retry loop for
## CLAUDE.md §3's reason -- resuming inside the tree's process loop finds the
## parent locked. Lifted from `tools/directors/roster.gd`, which does the same
## thing for the same reason.
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
	# `rig` IS the SceneTree, so this is both `rig.scene()` and the tree's
	# `current_scene` -- which is where `DialogueBox` parents itself.
	rig.current_scene = fresh
	await rig.wait_frames(20)
	return fresh as Garrison


## The alchemist's station, from in front of it, on the same camera both visits.
##
## **The arrival camera cannot make this claim and it was tried first.** Since the
## compound generator landed, the keepers stand at named ports along the east
## range rather than on a ring around the plaza, so the shot a returning player
## gets from the gate is the statue and the parade ground — `k_02` and `k_04` were
## the same picture twice with a working change between them, which is exactly the
## kind of frame CLAUDE.md §2 calls proof of nothing. So this stands where a
## customer would stand at her counter: empty bench on the first homecoming,
## Ysolt behind it on the second.
##
## A camera of its own rather than a walk, because the two frames have to be
## IDENTICAL but for the person — a hero teleported twice arrives with whatever
## yaw the last beat left him, and the difference between the two pictures would
## then include the camera.
func _shoot_the_apothecary(rig, g: Garrison, name: String) -> void:
	var at: Transform3D = g.compound.global_transform \
		* g.compound.port(&"alchemist_day")
	# **`+basis.z` and not `-basis.z`.** A booth's +Z is the CUSTOMER's side
	# (`ShopBooth`), which is the one place in this project where the forward
	# convention of CLAUDE.md §4 is deliberately the other way round -- the keeper
	# has their back to the range and faces the parade. Taken the obvious way this
	# stood inside the alcove photographing the yard through a doorway, which is
	# how it was caught.
	var facing := at.basis.z.normalized()
	var cam := Camera3D.new()
	cam.name = &"ApothecaryProof"
	var prev := g.get_viewport().get_camera_3d()
	g.add_child(cam)
	cam.global_position = at.origin + facing * 4.5 + Vector3.UP * 2.2
	cam.look_at(at.origin + Vector3.UP * 1.1, Vector3.UP)
	cam.make_current()
	await rig.wait_frames(10)
	await rig.capture(out.path_join(name))
	if prev != null and is_instance_valid(prev):
		prev.make_current()
	cam.queue_free()
	await rig.wait_frames(2)


## The live `ConvoCamera`, or null -- off the viewport, so the claim is about the
## camera that is RENDERING and not one merely staged.
func _convo(rig) -> ConvoCamera:
	var scene: Node = rig.scene()
	if scene == null:
		return null
	var vp := scene.get_viewport()
	if vp == null:
		return null
	return vp.get_camera_3d() as ConvoCamera


func _has_booth(who: Node) -> bool:
	for c in who.get_children():
		if c is ShopBooth:
			return true
	return false
