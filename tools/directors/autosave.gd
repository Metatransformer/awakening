extends RefCounted
## Autosaving — every scene transition commits the metagame, and says so.
##
## Four claims, and only the last one is a picture:
##
##   1. going down into the dungeon writes a slot, and CLAIMS that slot for
##      every autosave after it;
##   2. taking the stair to the next floor writes it again;
##   3. coming home writes it again — and every one of those saves points at
##      TOWN, never at the dungeon it was taken in. A slot holds `Game` and
##      nothing of `Run` (METAGAME §5: the run is what you are gambling), so a
##      save that pointed underground would reload into a generated floor with
##      no bag, no fee and no run behind it;
##   4. with all three slots full of saves a player made BY HAND, the autosave
##      declines and the HUD says nothing. An autosave that quietly overwrote
##      one of them would be deciding which of their saves mattered least.
##
## Then the notice itself, photographed as the world fades back in — which is
## the only moment it is visible, and the reason it holds for 2.2 s.
##
## This director writes to the real `user://saves`. It takes the three slots'
## bytes at the start and puts them back at the end, so a run of it cannot cost
## anyone a save.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/town.tscn \
##     --director=res://tools/directors/autosave.gd \
##     --out=/tmp/save/x.png --warmup=60

var _i := 0
var _fail := 0
var _backup: Dictionary = {}


func run(rig) -> void:
	_stash()

	for i in Saves.SLOTS:
		Saves.erase(i)
	Saves.active_slot = -1
	await rig.wait_seconds(0.3)

	# --- 1. In --------------------------------------------------------------
	Flow.enter_dungeon(4242)
	await _settle(rig)
	_check("going down wrote a slot", Saves.has_save(0))
	_check("...and claimed it (active_slot=%d)" % Saves.active_slot,
		Saves.active_slot == 0)
	_check("the run really started", Run.in_dungeon)
	_check("the notice is up on the frame the world comes back",
		float(Hud.get(&"_save_t")) >= 0.0)
	await _shot(rig, "entered")

	# The claim the format cannot make for itself.
	_check("the save points HOME, not at the floor it was taken on (%s)"
		% _scene_of(0), _scene_of(0) == Flow.TOWN)

	# --- 2. Down ------------------------------------------------------------
	# `played` is `Time.get_ticks_msec()` at the moment of writing, so it is the
	# one field that proves this is a SECOND write rather than the doorway's file
	# still sitting there. `stamp` is second-resolution and two transitions can
	# share one.
	var before := _played_of(0)
	Flow.descend()
	await _settle(rig)
	_check("descending wrote the same slot again", Saves.active_slot == 0)
	_check("...and it is a new write (%.1f -> %.1f)" % [before, _played_of(0)],
		_played_of(0) > before)
	_check("the notice came up again", float(Hud.get(&"_save_t")) >= 0.0)
	_check("...on floor %d" % Run.level, Run.level == 2)
	await _shot(rig, "descended")

	# --- 3. Home ------------------------------------------------------------
	# The real way out, not Flow.to_town(): extraction is the transition the
	# player has the most to lose across, and it runs through Run.extract ->
	# Bus.run_ended -> Flow, which is a longer path than the two above.
	before = _played_of(0)
	Game.add_gold(Run.extract_cost() + 50)   # he is not here to fail the toll
	_check("he can afford to leave (%d gold, %d fee)" % [Game.gold, Run.extract_cost()],
		Run.can_extract())
	_check("and he does", Run.extract())
	await _settle(rig)
	_check("...which wrote it a third time (%.1f -> %.1f)" % [before, _played_of(0)],
		_played_of(0) > before)
	_check("coming home wrote it again", Saves.active_slot == 0)
	_check("the run is over", not Run.in_dungeon)
	_check("and the notice came up in town too", float(Hud.get(&"_save_t")) >= 0.0)
	await _shot(rig, "home")

	# --- 4. Three saves made by hand are three saves left alone --------------
	await rig.wait_seconds(2.8)   # the notice must be GONE before we test silence
	_check("the notice cleared on its own", float(Hud.get(&"_save_t")) < 0.0)
	for i in Saves.SLOTS:
		Saves.save(i)
	Saves.active_slot = -1
	var wrote := Saves.autosave()
	await rig.wait_seconds(0.2)
	_check("with every slot spoken for, the autosave declines", not wrote)
	_check("...and says nothing about it", float(Hud.get(&"_save_t")) < 0.0)
	await _shot(rig, "declined")

	_restore()
	print("AUTOSAVE OK" if _fail == 0 else "AUTOSAVE FAILED (%d)" % _fail)


## Wait out the whole transition: the hold, the fade out, the scene swap, the
## fade in, and the autosave that lands at the end of it (game_flow.gd `_go`).
func _settle(rig) -> void:
	for i in 240:
		await rig.wait_seconds(0.05)
		if not Flow.busy:
			break
	await rig.wait_seconds(0.25)


# --- The slots ---------------------------------------------------------------

## The recorded scene, read off the raw file: `peek` does not report it (the
## slot cards have no use for it) and this director is the one caller that does.
func _scene_of(slot: int) -> String:
	var raw := _raw(slot)
	if raw == "":
		return ""
	var d: Variant = JSON.parse_string(raw)
	return String((d as Dictionary).get("scene", "")) if d is Dictionary else ""


func _played_of(slot: int) -> float:
	return float(Saves.peek(slot).get("played", -1.0))


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


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % what)
	else:
		_fail += 1
		print("AUTOSAVE FAIL %s" % what)


func _shot(rig, tag: String) -> void:
	await rig.capture("f_%02d_%s.png" % [_i, tag])
	_i += 1
