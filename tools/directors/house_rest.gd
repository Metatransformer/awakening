extends RefCounted
## The hero's quarters — the billet, the cot and the footlocker, end to end.
##
## Six claims, and every one of them is a thing that would be invisible in a
## screenshot of a nice-looking room:
##
##   1. the billet is BUILT and it is where the garrison says it is — inside the
##      yard, clear of the relic ring, with two interactables in it that
##      `Prompt` can tell apart from four metres away;
##   2. the locker takes a stack out of the bag and gives it back, and both
##      directions go through `Run` — the bag's slot count and the heat premium
##      move with the goods instead of being left behind;
##   3. a full locker REFUSES, in words, instead of eating the stack;
##   4. **what is on the shelf survives `Run.enter()`**, which is the whole
##      reason the locker exists: the bag is cleared at the top of every run and
##      merchandise you did not sell used to die there with no event at all;
##   5. sleeping offers nightfall or morning; choosing morning plays the paused
##      clock and crossed civil cards, fully restores real health, grants
##      rank-based temporary overhealth, and WRITES A SLOT — and the slot reads
##      all of it back;
##   6. the lid is open while the screen is up and shut when it comes down.
##
## Then the pictures: the billet from the yard, the room from the doorway, the
## screen with both columns populated, and the personal bed with its prompt.
##
## This director writes to the real `user://saves` (sleeping is an autosave, and
## a director that mocked that out would be proving nothing). It takes the three
## slots' bytes at the start and puts them back at the end, exactly as
## `autosave.gd` does, so a run of it cannot cost anyone a save.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/house_rest.gd \
##     --out=/tmp/house/x.png --warmup=60

var _i := 0
var _fail := 0
var _backup: Dictionary = {}
var out := "/tmp/house"


func run(rig) -> void:
	out = rig.out_base().get_base_dir()
	_stash_saves()
	for i in Saves.SLOTS:
		Saves.erase(i)
	Saves.active_slot = -1

	var garrison := rig.scene() as Garrison
	if garrison == null:
		print("HOUSE FAIL the scene is not the garrison")
		return

	if not await _built(rig, garrison):
		_restore_saves()
		print("HOUSE FAILED (%d)" % maxi(_fail, 1))
		return
	await _locker(rig, garrison)
	await _survives_a_run(rig, garrison)
	await _sleep(rig, garrison)

	_restore_saves()
	print("HOUSE OK" if _fail == 0 else "HOUSE FAILED (%d)" % _fail)


# --- 1. It is built, and it is somewhere -------------------------------------

func _built(rig, garrison: Garrison) -> bool:
	var h := garrison.house
	if h == null or h.bed == null or h.locker == null:
		print("HOUSE FAIL the garrison built no quarters")
		return false

	# Inside the curtain. The yard is `garrison.yard` across and the walls are
	# at half of it; a billet whose furniture had drifted outside would be
	# furniture in a field, and it would still photograph fine from the one
	# angle that missed the wall.
	var hx := garrison.yard.x * 0.5
	var hz := garrison.yard.y * 0.5
	for it in [h.bed, h.locker]:
		var p: Vector3 = it.global_position
		_check("%s is inside the walls (%.1f, %.1f)" % [it.prompt, p.x, p.z],
			absf(p.x) < hx and absf(p.z) < hz)

	# Clear of the relic ring. `Garrison._build_relic_props` is tuned so that at
	# least one lamp is in frame from anywhere in the yard, and the twelve are
	# evenly spaced for exactly that reason — a building that swallowed one
	# would break the claim quietly, in the one system whose whole job is to be
	# noticed.
	var nearest := 999.0
	for l in garrison.lights:
		for it in [h.bed, h.locker]:
			nearest = minf(nearest, K.plane(l.global_position - it.global_position).length())
	_check("the nearest relic lamp is %.1f m clear of the furniture" % nearest,
		nearest > 1.5)

	# The two look shots come off a camera of this director's own,
	# `garrison_look`'s way, and NOT off the game camera. The game rig is a
	# follow camera with lag and a wall-avoidance swing (game_camera.gd §1.5,
	# §1.6): teleport the hero into a corner and the boom is still pointing
	# wherever it was a second ago, so the first run of this beat photographed
	# the alchemist's stall and called it "the billet from the yard". A framing
	# claim needs a camera that is pointed on purpose. Everything AFTER this
	# beat goes back to the game rig, because the prompt and the screen are only
	# proved at the distance and angle the player actually reads them from.
	# Annotated rather than inferred: the parser cannot infer through this chain
	# and the file would not load at all (CLAUDE.md §3).
	var keep: Camera3D = rig.scene().get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	cam.fov = 55.0
	rig.scene().add_child(cam)
	cam.make_current()

	# From out in the yard, north-east of it: the angle a player walking down
	# from the gate arrives at. This is the frame that says whether the thing
	# reads as a building or as four boxes in a corner.
	cam.global_position = h.global_position + Vector3(7.2, 4.2, -7.6)
	cam.look_at(h.global_position + Vector3(0.0, 1.4, 0.0), Vector3.UP)
	await rig.wait_frames(4)
	await _shot(rig, "billet_from_yard")

	# And straight in through the open front, at eye height.
	cam.global_position = h.global_position + Vector3(0.6, 1.7, -6.0)
	cam.look_at(h.global_position + Vector3(-0.6, 1.0, 0.6), Vector3.UP)
	await rig.wait_frames(4)
	await _shot(rig, "doorway")

	cam.queue_free()
	if keep != null:
		keep.make_current()
	await rig.wait_frames(4)
	return true


# --- 2, 3, 6. The locker -----------------------------------------------------

func _locker(rig, garrison: Garrison) -> void:
	var h := garrison.house
	# Arrive as though a run had just paid out: the bag survives `extract()`
	# intact, which is the state the player is actually in when they walk in here.
	Run.in_dungeon = false
	Run.bag.clear()
	Game.stash.clear()
	Run.collect(&"deep_amber", 4)
	Run.collect(&"ghost_silk", 3)
	Run.collect(&"bone_shard", 9)
	await rig.wait_frames(6)
	var carried_before := Run.slots_used()

	if not await _approach(rig, h.locker, h.locker.global_position + Vector3(-1.2, 0.0, 0.0)):
		return
	_check("the cot did not steal the button from four metres away",
		Prompt.focus == h.locker)
	await _shot(rig, "locker_prompt")

	await rig.tap(["interact"])
	var opened: bool = await rig.until(func() -> bool: return _screen(rig) != null)
	if not opened:
		print("HOUSE FAIL the locker took the press and no screen came up")
		_fail += 1
		return
	var screen := _screen(rig)
	await rig.wait_frames(12)
	_check("the lid is open while the screen is up",
		absf(float(h.locker._lid.rotation.x) - Footlocker.LID_OPEN) < 0.4)
	await _shot(rig, "screen_open")

	# --- stow one, then the rest of the stack -------------------------------
	# `_point_at`, NOT `screen._cursor = i`. CLAUDE.md §3: the assignment holds for
	# exactly one frame, because `_point_at` is the other half of a move and it is
	# the half that calls `grab_focus`, which is DEFERRED -- the `focus_entered`
	# lands a frame later and puts `_cursor` back on whatever row the last
	# `_refresh` left the focus on. Card #77 counts seven directors still doing it.
	# Here it made the beat below unreadable: the hold acted on a drifted row, and
	# so did the screen's own bug (StashScreen._input), and the two were
	# indistinguishable until this line stopped adding a third mover of its own.
	screen._point_at(_row_of(screen, &"deep_amber"))
	await rig.wait_frames(2)
	var before: int = Run.bag.get(&"deep_amber", 0)
	await rig.tap(["ui_left"])
	await rig.wait_frames(8)
	_check("one amber left the bag (%d -> %d)" % [before, Run.bag.get(&"deep_amber", 0)],
		int(Run.bag.get(&"deep_amber", 0)) == before - 1)
	_check("...and it is on the shelf (%d)" % Game.stash_count(&"deep_amber"),
		Game.stash_count(&"deep_amber") == 1)

	await rig.hold_seconds(["ui_left"], 0.8)
	await rig.wait_frames(8)
	_check("holding stowed the rest of the stack (bag has %d, shelf has %d)"
		% [Run.bag.get(&"deep_amber", 0), Game.stash_count(&"deep_amber")],
		not Run.bag.has(&"deep_amber") and Game.stash_count(&"deep_amber") == before)
	_check("the bag got a slot back (%d -> %d)" % [carried_before, Run.slots_used()],
		Run.slots_used() < carried_before)
	await _shot(rig, "stowed")

	# --- and back again ------------------------------------------------------
	screen._point_at(_row_of(screen, &"deep_amber"))
	await rig.wait_frames(2)
	await rig.hold_seconds(["ui_right"], 0.8)
	await rig.wait_frames(8)
	_check("retrieving put all %d back in the bag" % before,
		int(Run.bag.get(&"deep_amber", 0)) == before and Game.stash_count(&"deep_amber") == 0)

	# --- 3. A full locker says so -------------------------------------------
	# Filled by hand rather than by carrying 24 stacks in: what is under test is
	# the refusal, and the shortest honest way to a full shelf is to fill it.
	# A full stack at a time, round and round the catalogue. One pass is not
	# enough: there are fewer non-relic kinds in `ItemDb` than there are slots in
	# the locker, so a single lap tops out five slots short of the cap and the
	# refusal never fires (the run that found this reported 19/24).
	var n := 0
	while not Game.stash_full() and n < 200:
		for id: StringName in ItemDb.all():
			if Game.stash_full():
				break
			if RelicDb.is_relic(id):
				continue
			var def := ItemDb.get_def(id)
			if def == null:
				continue
			Game.stash_add(id, def.stack)
			n += 1
	_check("the shelf filled to its cap (%d/%d slots off %d stacks)"
		% [Game.stash_slots_used(), K.STASH_SLOTS, n], Game.stash_full())

	screen._refresh()
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
	screen._point_at(_row_of(screen, &"ghost_silk"))
	var silk: int = Run.bag.get(&"ghost_silk", 0)
	await rig.tap(["ui_left"])
	await rig.wait_frames(8)
	# The claim is not "it did nothing" — it is that it did nothing AND SAID SO.
	# A transfer screen that silently swallows a press is the same bug as a bag
	# that silently eats a stack, one room higher up.
	_check("a full locker refused the silk (%d still carried)"
		% Run.bag.get(&"ghost_silk", 0), int(Run.bag.get(&"ghost_silk", 0)) == silk)
	_check("...and said why (\"%s\")" % screen._refuse_why,
		screen._refuse >= 0.0 and screen._refuse_why.contains("FULL"))
	await _shot(rig, "locker_full")

	# --- 6. The lid follows the screen --------------------------------------
	await rig.tap(["ui_cancel"])
	var closed: bool = await rig.until(func() -> bool: return _screen(rig) == null)
	_check("the screen closed on cancel", closed)
	await rig.wait_frames(24)
	_check("...and the lid shut behind it (%.2f rad)" % h.locker._lid.rotation.x,
		absf(float(h.locker._lid.rotation.x)) < 0.2)


# --- 4. The reason the locker exists -----------------------------------------

## The bag is cleared at the top of every run (`Run.enter`), so anything you did
## not sell was destroyed with no event, no notice and no receipt. That is the
## right rule for the dungeon and a silent one in the garrison. This is the beat
## that says the shelf is not the bag.
func _survives_a_run(rig, _garrison: Garrison) -> void:
	Game.stash.clear()
	Run.bag.clear()
	Run.in_dungeon = false
	Run.collect(&"deep_amber", 3)
	Game.stash_add(&"void_pearl", 2)
	await rig.wait_frames(4)

	Run.enter(4242)
	await rig.wait_frames(4)
	_check("the run cleared the bag, as it always has", Run.bag.is_empty())
	_check("and the two pearls are still on the shelf (%d)"
		% Game.stash_count(&"void_pearl"), Game.stash_count(&"void_pearl") == 2)

	# Put the world back the way the player left it — the next beat sleeps, and
	# `Bed` refuses mid-run on purpose (see its `activate`).
	Run.in_dungeon = false
	Run.level = 1


# --- 5. The cot ---------------------------------------------------------------

func _sleep(rig, garrison: Garrison) -> void:
	var h := garrison.house
	# Sleep always restores real health now; Elder rank two adds exactly two
	# temporary quarters. One real quarter is low enough that the old rank-two
	# ordinary heal could not have reached the maximum, so this distinguishes the
	# new contract from the one it replaced.
	Game.upgrades[&"elder_bed"] = 2
	Game.upgrades.erase(&"elder_reveille")
	Game.set_temporary_overhealth(0)
	Game.quarters = K.QUARTER
	Bus.player_health_changed.emit(Game.quarters, Game.max_quarters)
	await rig.wait_frames(4)
	var hurt := Game.quarters
	_check("he is at one quarter before he lies down (%d/%d)"
		% [hurt, Game.max_quarters], hurt == K.QUARTER)

	if not await _approach(rig, h.bed, h.bed.global_position + Vector3(1.2, 0.0, 0.0)):
		return
	_check("the locker did not steal the button", Prompt.focus == h.bed)
	_check("the prompt says it is a hold", h.bed.hold_time > 0.0)
	await _shot(rig, "cot_prompt")

	# Held for well over `Bed.SLEEP_HOLD`, and then released: `Prompt` disarms on
	# activate and re-arms on the button coming up, so a director that never let
	# go would leave the button down inside the dialogue.
	await rig.hold_seconds(["interact"], 0.9)
	_check("the bed offered morning and accepted it through real dialogue presses",
		await rig.talk("Sleep until morning"))
	var went: bool = await rig.until(func() -> bool: return Flow.busy, 2.0)
	_check("the paused sleep-clock ceremony began", went)
	# A daytime morning sleep plays the 2.4-second clock, then crosses nightfall
	# and dawn. Flow presents both civil cards in order before returning control.
	var back: bool = await rig.until(func() -> bool:
		return not Flow.busy and not rig.paused and not Prompt.blocked, 18.0)
	_check("...and the sleep clock plus crossed civil cards gave control back", back)
	await rig.wait_frames(30)

	_check("sleep fully restored real health (%d -> %d/%d)"
		% [hurt, Game.quarters, Game.max_quarters],
		Game.quarters == Game.max_quarters)
	_check("the rank-two bunk granted two temporary quarters (%d)"
		% Game.temporary_overhealth,
		Game.temporary_overhealth == 2 * K.QUARTER)
	_check("the rest wrote a slot (%d)" % Saves.active_slot, Saves.has_save(0))
	var rest_slot := Saves.active_slot
	var minutes_after_open := (Clock.hour - Clock.effective_service_open_hour()) * 60.0
	_check("the rest gives control back as services open (%.2f)" % Clock.hour,
		minutes_after_open >= 0.0 and minutes_after_open < 2.0
		and Clock.services_available())
	_check("the world is running again", not rig.paused)
	await _shot(rig, "woke_gold_cap_2q")

	Game.damage(K.QUARTER)
	await rig.wait_frames(2)
	_check("one damage quarter reduced temporary overhealth from two to one (%d)"
		% Game.temporary_overhealth,
		Game.temporary_overhealth == K.QUARTER)
	_check("the first damage quarter left real health full (%d/%d)"
		% [Game.quarters, Game.max_quarters],
		Game.quarters == Game.max_quarters)
	await _shot(rig, "damage_gold_cap_1q")

	# Two one-quarter blows, not one two-quarter blow: mercy never softens a
	# one-quarter hit, so this proof is independent of the player's preference.
	Game.damage(K.QUARTER)
	Game.damage(K.QUARTER)
	_check("two more damage quarters consumed the last temporary quarter (%d)"
		% Game.temporary_overhealth, Game.temporary_overhealth == 0)
	_check("only the one-quarter remainder reduced real health (%d/%d)"
		% [Game.quarters, Game.max_quarters],
		Game.quarters == Game.max_quarters - K.QUARTER)

	# The autosave predates the damage probes. Loading it proves the rest wrote
	# both kinds of health and the locker's contents, not merely live memory.
	Game.stash.clear()
	Saves.load_slot(rest_slot)
	_check("full real health came back off the disk (%d/%d)"
		% [Game.quarters, Game.max_quarters],
		Game.quarters == Game.max_quarters)
	_check("the saved two-quarter temporary overhealth came back off the disk (%d)"
		% Game.temporary_overhealth,
		Game.temporary_overhealth == 2 * K.QUARTER)
	_check("the shelf came back off the disk (%d pearls)"
		% Game.stash_count(&"void_pearl"), Game.stash_count(&"void_pearl") == 2)


# --- Plumbing -----------------------------------------------------------------

func _screen(rig) -> StashScreen:
	for n in _all(rig.scene()):
		if n is StashScreen:
			return n
	return null


func _all(node: Node) -> Array:
	var found: Array = [node]
	for c in node.get_children():
		found.append_array(_all(c))
	return found


func _row_of(screen: StashScreen, id: StringName) -> int:
	for i in screen._rows.size():
		if screen._rows[i]["id"] == id:
			return i
	return 0


## `mvp_loop._approach`, and its whole lesson with it: standing next to an
## Interactable is not the same event as being NOTICED by one. The trigger is an
## Area3D and it reports about two PHYSICS ticks after a teleport, which is three
## rendered frames on one machine and twenty on another.
func _approach(rig, it: Interactable, at: Vector3) -> bool:
	_stand_at(rig, at, it.global_position)
	# Swing the boom round behind him. `_stand_at` teleports the BODY; the
	# follow camera is still aimed wherever it was and takes a second or two of
	# lag to catch up, so a prompt shot taken straight after the teleport is a
	# photograph of the wrong corner of the yard with the right text on it.
	Bus.camera_recenter.emit()
	var seen: bool = await rig.until(func() -> bool: return Prompt.focus == it)
	if not seen:
		print(("HOUSE FAIL %s never took the interact button (focus=%s,"
			+ " inside=%s, blocked=%s)") % [it.prompt,
			Prompt.focus.prompt if Prompt.focus != null else "<none>",
			it.player_inside, Prompt.blocked])
		_fail += 1
		return false
	await rig.wait_physics_frames(2)
	return true


func _stand_at(rig, at: Vector3, look_at = null) -> void:
	var hero: Hero = rig.scene().get_tree().get_first_node_in_group(&"player")
	if hero == null:
		return
	hero.global_position = Vector3(at.x, 0.05, at.z)
	if look_at != null:
		var to := K.flat(look_at - hero.global_position)
		if to != Vector3.ZERO:
			hero.facing_yaw = atan2(to.x, to.z)
			hero.rotation.y = hero.facing_yaw + PI


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % what)
	else:
		_fail += 1
		print("HOUSE FAIL %s" % what)


func _shot(rig, tag: String) -> void:
	await rig.capture(out.path_join("h_%02d_%s.png" % [_i, tag]))
	_i += 1


# --- The three slots, borrowed and put back ----------------------------------
# Lifted from `autosave.gd`, deliberately duplicated rather than shared: a
# helper in `tools/` that both directors imported would be a third file to keep
# correct, and this is twelve lines that must never be wrong.

func _stash_saves() -> void:
	for i in Saves.SLOTS:
		_backup[i] = _raw(i)


func _restore_saves() -> void:
	for i in Saves.SLOTS:
		var raw: String = _backup.get(i, "")
		if raw == "":
			Saves.erase(i)
			continue
		var f := FileAccess.open(Saves.slot_path(i), FileAccess.WRITE)
		if f != null:
			f.store_string(raw)
			f.close()
	Saves.active_slot = -1


func _raw(slot: int) -> String:
	var f := FileAccess.open(Saves.slot_path(slot), FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t
