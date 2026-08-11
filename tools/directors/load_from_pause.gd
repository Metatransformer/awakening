extends RefCounted
## **Loading a save from the pause menu actually moves the player.**
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/load_from_pause.gd \
##     --out=/tmp/loadpause/x.png --warmup=90
##
## The bug this exists to keep dead: `MenuSavesPanel` restored the slot and
## emitted `load_requested(slot, dest)`, `PauseMenu` re-emitted it, and **nothing
## in the game was connected to it** — only `scripts/ui/menu/_menu_test.gd`, which
## prints. So Load Game restored `Game` and left the hero standing exactly where
## he was. The numbers loaded; the world did not. It is the worst shape a bug can
## take, because the HUD agrees with the save and only the floor under your feet
## disagrees.
##
## What it claims, in the order it proves them:
##
##   A  The hero can be walked off the garrison's spawn, so "he went back where
##      the save was written" is a claim distinguishable from "the room put him
##      at its default spawn". Every position check below rests on this.
##   B  Escape → Load Game → slot 1, all by key press, lands him back at the
##      SAVED position and restores `Game` with it — and the menu is gone and the
##      world is running when it does.
##   C  It survives being done TWICE. `_go` autosaves at the end of every
##      transition, off the hero's live position; place him after that and the
##      slot silently learns the room's default spawn instead, so the save works
##      once and then forgets where it was written.
##   D  Loading with a RUN in flight abandons the run. A slot holds `Game` and
##      nothing of `Run` (docs/METAGAME.md §5), so arriving home with
##      `Run.in_dungeon` still true means a bag from a run that no longer exists,
##      sitting in front of a vendor who will buy it.
##
## Beat D deliberately makes **no claim about where the hero lands**, and that is
## not laziness — see the note on `_dungeon_load`.
##
## This director writes to the real `user://saves`. It takes the three slots'
## bytes at the start and puts them back at the end, so a run of it cannot cost
## anyone a save. (`shoot.gd` sandboxes `settings.cfg` and nothing else.)

const KEY_ESC := 4194305   ## physical_keycode for Escape, as bound to `pause`.
const KEY_E := 69          ## `interact` in the world, CONFIRM in every menu.
const KEY_DOWN := 4194322

## How many rows down the root list to hunt for one by name before giving up.
## The list is a closed focus loop, so never landing on it is a real failure.
const ROW_LIMIT := 10
## How close to the recorded position counts as "back where the save was".
## Generous on purpose: `_place_hero` assigns `global_position` exactly, but the
## hero is a CharacterBody3D that gets a physics tick or two before anything is
## measured, and settling onto the courtyard is allowed to cost him a few
## centimetres of Y. A regression here is metres, not millimetres.
const NEAR := 0.5

var _i := 0
var _fails := 0
var _backup: Dictionary = {}


func run(rig) -> void:
	_deafen_the_pad()
	_stash()
	for i in Saves.SLOTS:
		Saves.erase(i)
	Saves.active_slot = -1
	await rig.wait_seconds(0.3)

	# Annotated, not inferred: `_walk_and_save` hands back a Variant (a Dictionary
	# or null), and `:=` against one is a parse ERROR in this project, not a
	# warning — CLAUDE.md §3, arriving from the same direction it always does.
	var saved_at: Variant = await _walk_and_save(rig)
	if saved_at != null:
		await _load_from_menu(rig, saved_at)
		await _dungeon_load(rig, saved_at)

	_restore()
	print("LOADPAUSE OK" if _fails == 0 else "LOADPAUSE FAILED (%d)" % _fails)


# --- A. Somewhere that is not the spawn --------------------------------------

## Walk him off the spawn, save, then walk him off THAT. Returns the saved
## position, or null if he could not be moved at all (in which case every later
## beat would be measuring nothing and the director says so and stops).
func _walk_and_save(rig) -> Variant:
	var hero := _hero(rig)
	if hero == null:
		_ck("A0 there is a hero in the garrison", false)
		return null
	var spawn := hero.global_position

	var a := await _walk(rig, ["move_down", "move_right"], 1.1)
	_ck("A1 he walked off the spawn (%.2f m)" % spawn.distance_to(a),
		spawn.distance_to(a) > 1.0)
	if spawn.distance_to(a) <= 1.0:
		return null

	# A fingerprint on `Game`, so beat B can tell a restore from a coincidence.
	# Gold rather than a flag: it is on the pause menu's own band, so the
	# screenshots show it changing too.
	Game.add_gold(777)
	var purse := Game.gold
	_ck("A2 the slot wrote", Saves.save(0))
	_ck("A3 ...and claimed itself (active_slot=%d)" % Saves.active_slot,
		Saves.active_slot == 0)
	_ck("A4 the file records where he was standing (%.2f m out)"
		% a.distance_to(_pos_of(0)), a.distance_to(_pos_of(0)) < 0.01)
	await _shot(rig, "saved")

	# ...and now somewhere else entirely, so "he went back" has somewhere to go
	# back FROM. `Game` moves too — a load that restored the room and not the
	# purse would pass a position-only check.
	var b := await _walk(rig, ["move_up", "move_left"], 1.7)
	_ck("A5 he walked away from the save (%.2f m)" % a.distance_to(b),
		a.distance_to(b) > 1.5)
	Game.add_gold(500)
	_ck("A6 and the purse moved with him (%d -> %d)" % [purse, Game.gold],
		Game.gold != purse)
	await _shot(rig, "walked_away")

	return {"pos": a, "gold": purse}


# --- B + C. The press the player makes ---------------------------------------

func _load_from_menu(rig, saved: Dictionary) -> void:
	var want: Vector3 = saved["pos"]

	var ok := await _press_load(rig, "B")
	if not ok:
		return
	await _settle(rig)

	var hero := _hero(rig)
	_ck("B1 the load landed in a garrison (%s)"
		% (rig.scene().name if rig.scene() != null else "<null>"),
		rig.scene() is Garrison)
	_ck("B2 there is a hero in it", hero != null)
	if hero != null:
		_ck("B3 **and he is back where the save was written** (%.2f m out)"
			% want.distance_to(hero.global_position),
			want.distance_to(hero.global_position) < NEAR)
	_ck("B4 the purse came back with him (%d, wanted %d)"
		% [Game.gold, int(saved["gold"])], Game.gold == int(saved["gold"]))
	_ck("B5 the menu closed behind it", not Menu.is_open)
	_ck("B6 ...and the world is running", not rig.paused)
	await _shot(rig, "loaded")

	# --- C. Twice. -----------------------------------------------------------
	# `_go` ends every transition with `Saves.autosave()`, which reads the hero
	# out of the LIVE TREE. Place him after that instead of before and the slot
	# quietly learns the garrison's default spawn — beat B still passes, and the
	# save is destroyed. So the check is not "did it work", it is "did doing it
	# leave the slot able to do it again".
	_ck("C0 the slot still records the saved spot after a load (%.2f m out)"
		% want.distance_to(_pos_of(0)), want.distance_to(_pos_of(0)) < NEAR)

	var moved := await _walk(rig, ["move_up"], 1.4)
	_ck("C1 he walked away again (%.2f m)" % want.distance_to(moved),
		want.distance_to(moved) > 1.0)
	if not await _press_load(rig, "C"):
		return
	await _settle(rig)
	var again := _hero(rig)
	_ck("C2 a SECOND load still lands on the saved spot (%.2f m out)"
		% (want.distance_to(again.global_position) if again != null else -1.0),
		again != null and want.distance_to(again.global_position) < NEAR)
	await _shot(rig, "loaded_twice")


# --- D. A load ends the run --------------------------------------------------

## Go down, pick something up, and load out of the pause menu.
##
## **No position claim in this beat, on purpose.** Entering the dungeon is a
## `Flow` transition, so it autosaves — into slot 0, which this director owns —
## and `Saves._save_scene` redirects that write HOME while `Saves.save` records
## the hero's live coordinates, which are the floor's. The recorded scene and the
## recorded position therefore disagree for any save taken underground, which is
## a fault in the FORMAT and not in the wiring this director is about. It is
## measured and printed below rather than asserted, so the number is on the log
## for whoever picks that up; beats B and C make the position claim, above
## ground, where the redirect never fires.
func _dungeon_load(rig, saved: Dictionary) -> void:
	Flow.enter_dungeon(4242)
	await _settle(rig)
	_ck("D0 the run started", Run.in_dungeon)
	Run.collect(&"bone_shard", 5)
	_ck("D1 ...and there is something in the bag (%d gold's worth)"
		% Run.bag_value(), not Run.bag.is_empty())
	await _shot(rig, "underground")

	if not await _press_load(rig, "D"):
		return
	await _settle(rig)

	_ck("D2 the load came home (%s)"
		% (rig.scene().name if rig.scene() != null else "<null>"),
		rig.scene() is Garrison)
	_ck("D3 **the run was abandoned**", not Run.in_dungeon)
	_ck("D4 ...and the bag went with it (%d line(s) left)" % Run.bag.size(),
		Run.bag.is_empty())
	_ck("D5 ...and the floor number went back to 1 (level=%d)" % Run.level,
		Run.level == 1)
	_ck("D6 the receipt screen did NOT come up — this run did not END, it was "
		+ "discarded", not Flow.ending)

	# Measured, not asserted. See the note above.
	var hero := _hero(rig)
	if hero != null:
		var want: Vector3 = saved["pos"]
		print("  note dungeon-written slot puts him %.2f m from the garrison save"
			% want.distance_to(hero.global_position))
	await _shot(rig, "home_again")


# --- Driving the menu the way a player does ----------------------------------

## Escape → walk to Load Game → confirm → confirm slot 1. Real InputEvents, not
## `Input.action_press`: the pause menu listens in `_unhandled_input`, and
## `action_press` sets action state without dispatching an event, so
## `_unhandled_input` never runs (CLAUDE.md §3).
func _press_load(rig, tag: String) -> bool:
	# Lettered rather than numbered, so these never collide with the numbered
	# claims of whichever beat called them -- this runs three times.
	await _key(rig, KEY_ESC, 16)
	_ck("%s· Escape opened the menu" % tag, Menu.is_open)
	if not Menu.is_open:
		print("  note %s" % _why(rig))
		return false
	if not await _focus_row(rig, "Load Game"):
		_ck("%s· could reach the 'Load Game' row" % tag, false)
		await _key(rig, KEY_ESC, 16)
		return false
	_ck("%s· could reach the 'Load Game' row" % tag, true)
	await _key(rig, KEY_E, 16)

	var saves: Control = Menu.get_node("Root/Screens/SavesScreen")
	_ck("%s· E opened the Load screen" % tag, saves.visible)
	if not saves.visible:
		await _key(rig, KEY_ESC, 16)
		return false
	# `_apply_top` calls `focus_first`, and in LOAD mode an empty row is
	# FOCUS_NONE — so focus is already on the only slot with a save in it.
	await _shot(rig, "load_screen")
	await _key(rig, KEY_E, 10)
	return true


## Walk the root list with the arrow keys until the focused control SAYS
## `label`. Through `UiKit.label_of` and not `Button.text`: a root row is a
## composed VerbRow whose own `text` is empty and whose label is a child Label.
func _focus_row(rig, label: String) -> bool:
	for i in ROW_LIMIT:
		# Annotated: `rig` is untyped, so `rig.root` is a Variant and `:=` cannot
		# infer (CLAUDE.md §3).
		var c: Control = rig.root.gui_get_focus_owner()
		if c != null and UiKit.label_of(c) == label:
			return true
		await _key(rig, KEY_DOWN, 6)
	return false


func _key(rig, code: int, settle: int = 8) -> void:
	var d := InputEventKey.new()
	d.keycode = code
	d.physical_keycode = code
	d.pressed = true
	Input.parse_input_event(d)
	await rig.wait_frames(2)
	var u := InputEventKey.new()
	u.keycode = code
	u.physical_keycode = code
	u.pressed = false
	Input.parse_input_event(u)
	await rig.wait_frames(settle)


# --- Helpers -----------------------------------------------------------------

## Strip the joypad bindings `PauseMenu` put BACK, and say how many.
##
## `shoot.gd` deafens the gamepad in `_initialize` for the reason CLAUDE.md §3
## gives — a stick resting outside its deadzone drives the hero and fails
## directors in beats that look like game races. But `_initialize` is *before*
## the autoloads' `_ready`, and `PauseMenu._ensure_pad_ui_actions` runs in its
## own `_ready` and puts five of them straight back: JOY_BUTTON_A/X on
## `ui_accept`, **JOY_BUTTON_B on `ui_cancel`**, and the shoulders on the tab
## actions. They are live for the rest of the run.
##
## For this director that is not cosmetic. `ui_cancel` is `back()`, and at the
## root of the menu `back()` is `close()` — so a pad B firing anywhere in the
## second between Escape and the slot press closes the menu the beat just
## opened, and every check after it reports a wiring failure that is really a
## controller on somebody's desk. It cost the second run of this file exactly
## that, and the tell was in the screenshot: the HUD had flipped to pad key-caps
## (`Settings._input` → `Bus.input_device_changed`) in a run driven entirely by
## synthesised KEYS.
##
## Deliberately fixed here and not in `shoot.gd`. `critic_menu.gd` drives this
## same menu with synthesised pad events and NEEDS those five bindings alive, so
## a second blanket strip in the harness would break it. The harness cannot tell
## the two intentions apart; the director that wants silence asks for it.
func _deafen_the_pad() -> void:
	var n := 0
	for action in InputMap.get_actions():
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadMotion or ev is InputEventJoypadButton:
				InputMap.action_erase_event(action, ev)
				n += 1
	print("  note stripped %d joypad binding(s) PauseMenu._ready put back" % n)


## What the world looked like when a menu press did not land. Printed rather than
## checked: it is a note for whoever reads a failing log, not a claim.
func _why(rig) -> String:
	return ("busy=%s ending=%s screen_up=%s pads=%s using_pad=%s paused=%s"
		% [Flow.busy, Flow.ending, Prompt.screen_up,
			Input.get_connected_joypads(), Settings.using_pad, rig.paused])


func _hero(rig) -> Node3D:
	return rig.get_first_node_in_group(&"player") as Node3D


## Hold `actions` for `seconds` of game time and hand back where he ended up.
## `hold_seconds` and not a frame count: walking is measured on the game clock
## and a frame count is a distance that depends on the panel (shoot.gd's note).
func _walk(rig, actions: Array, seconds: float) -> Vector3:
	await rig.hold_seconds(actions, seconds)
	await rig.wait_physics_frames(4)
	var hero := _hero(rig)
	return hero.global_position if hero != null else Vector3.ZERO


## Wait out the whole transition: the fade out, the scene swap, the fade in, and
## the autosave at the end of it (game_flow.gd `_go`).
##
## **Do not wait on `Flow.busy`** — autosave.gd's note explains why at length: it
## is cleared before `change_scene_to_file` and a long way before the write, and
## it reads false on the first tick of a transition that has not started yet.
## Wait on the thing that actually changes, then give the tail a margin.
func _settle(rig) -> void:
	# Annotated: `rig` is untyped here, so `scene()` hands back a Variant and
	# `:=` cannot infer (CLAUDE.md §3).
	var was: Node = rig.scene()
	for i in 300:
		await rig.wait_seconds(0.05)
		if rig.scene() != was and not Flow.busy:
			break
	await rig.wait_seconds(0.9)


## The recorded position, read off the raw file: `peek` does not report it (the
## slot cards have no use for it) and this director is one of two callers that do.
func _pos_of(slot: int) -> Vector3:
	var raw := _raw(slot)
	if raw == "":
		return Vector3.INF
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return Vector3.INF
	var p: Array = (parsed as Dictionary).get("pos", [])
	if p.size() < 3:
		return Vector3.INF
	return Vector3(p[0], p[1], p[2])


func _raw(slot: int) -> String:
	var f := FileAccess.open(Saves.slot_path(slot), FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t


func _stash() -> void:
	for i in Saves.SLOTS:
		_backup[i] = _raw(i)


func _restore() -> void:
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


func _ck(what: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % what)
	else:
		_fails += 1
		print("LOADPAUSE FAIL %s" % what)


func _shot(rig, tag: String) -> void:
	await rig.capture("lp_%02d_%s.png" % [_i, tag])
	_i += 1
