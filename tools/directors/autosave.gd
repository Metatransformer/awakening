extends RefCounted
## Autosaving — every scene transition commits the metagame, and says so.
##
## Four claims, and only the last one is a picture:
##
##   1. going down into the dungeon writes a slot, and CLAIMS that slot for
##      every autosave after it;
##   2. taking the stair to the next floor writes it again;
##   3. coming home writes it again — and every one of those saves points at
##      GARRISON, never at the dungeon it was taken in. A slot holds `Game` and
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
##     --scene=res://scenes/rooms/garrison.tscn \
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
		% _scene_of(0), _scene_of(0) == Flow.GARRISON)

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
	# The real way out, not Flow.to_garrison(): extraction is the transition the
	# player has the most to lose across, and it runs through Run.extract ->
	# Bus.run_ended -> Flow, which is a longer path than the two above.
	#
	# **`Run.extract()` does not go home by itself, and this beat believed it did
	# until 2026-08-09.** A run now ENDS on the floor it ended on, under
	# `RunEndScreen`, and BACK TO THE GARRISON is the press that travels
	# (scripts/ui/run_end/). `_on_run_ended` only raises the screen. So the old
	# beat measured the file a second after the rope, found the second beat's
	# write still sitting there, and reported `7.4 -> 7.4` — a red director that
	# was reading a real fact about a transition that had not started.
	#
	# `mvp_loop._return` was corrected for exactly this drift and left a note
	# about it; this one was not. Press the button the player presses.
	before = _played_of(0)
	Game.add_gold(Run.extract_cost() + 50)   # he is not here to fail the toll
	_check("he can afford to leave (%d gold, %d fee)" % [Game.gold, Run.extract_cost()],
		Run.can_extract())
	_check("and he does", Run.extract())
	await rig.wait_frames(150)
	_check("the run is over", not Run.in_dungeon)
	_check("...and the receipt is up, on the floor he left from", _run_end(rig) != null)
	await rig.wait_seconds(RunEndScreen.SETTLE + 0.2)
	await rig.hold_seconds([&"ui_accept"], 0.2)
	await _settle(rig)
	_check("...and BACK TO THE GARRISON reached the garrison (%s)" % rig.scene().name,
		rig.scene() is Garrison)
	_check("...which wrote it a third time (%.1f -> %.1f)" % [before, _played_of(0)],
		_played_of(0) > before)
	_check("coming home wrote it again", Saves.active_slot == 0)
	_check("and the notice came up in the garrison too", float(Hud.get(&"_save_t")) >= 0.0)
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


## The receipt, if it is up. Same search `mvp_loop` does — a run-ended screen is
## parented under whatever scene the run ended on, so there is no fixed path.
func _run_end(rig) -> RunEndScreen:
	for n in _walk(rig.scene()):
		if n is RunEndScreen:
			return n
	return null


func _walk(root: Node) -> Array:
	var found := [root]
	for c in root.get_children():
		found.append_array(_walk(c))
	return found


## Wait out the whole transition: the hold, the fade out, the scene swap, the
## fade in, and the autosave that lands at the end of it (game_flow.gd `_go`).
##
## **Do not wait on `Flow.busy` for this, which is what this did until
## 2026-08-09.** It is wrong at both ends. It is cleared near the TOP of `_go`'s
## second half, before `change_scene_to_file` and a long way before the write, so
## a poll that breaks on `not busy` returns with the autosave still pending. And
## it starts false: extraction runs `Run.extract` -> `Bus.run_ended` -> `Flow`, so
## a poll begun the frame after `Run.extract()` sees `busy == false` on its very
## first tick and breaks out before the fade has even started. Beat 3 then read
## beat 2's file and reported `6.8 -> 6.8`.
##
## That it passed for months is the point: it was a race this director won by a
## few milliseconds, and it started losing the day the garrison grew a house to
## build in `_ready`. Wait on the thing that actually changes — the scene node —
## and then give the tail of `_go` a margin it does not have to win.
func _settle(rig) -> void:
	# Annotated: `rig` is untyped here, so `scene()` hands back a Variant and
	# `:=` cannot infer (CLAUDE.md §3).
	var was: Node = rig.scene()
	for i in 300:
		await rig.wait_seconds(0.05)
		if rig.scene() != was and not Flow.busy:
			break
	await rig.wait_seconds(0.8)


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
