extends RefCounted
## Fires every signal in Sfx.CUES and checks a voice actually started.
##
## The failure this is built to catch is a silent one: a cue table entry naming
## a file that is not there. `Sfx._load` push_warnings and returns null, the
## game carries on, and the sound is simply missing forever -- which is exactly
## how 147 of this project's 156 sounds came to be unused without anyone
## noticing. So this asserts on `playing`, not on the absence of an error.
##
## Run:
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/sfx_cues.gd \
##     --out=/tmp/sfx/x.png --warmup=90

var _fails := 0


func run(rig) -> void:
	# THE BOOT KIT IS GONE (game_state.gd STARTER_KIT is empty now, docs/SCOPE.md
	# M1): the bow, the hookshot and the thirty arrows used to be handed over in
	# `Game._ready()`, and this director was written on top of that. It exercises
	# the gear rather than the earning of it, so it hands itself the same three
	# things the boot used to -- the alternative is a director that fails for a
	# reason that has nothing to do with what it claims.
	Game.grant(&"bow")
	Game.grant(&"hookshot")
	if Game.arrows < 30:
		Game.add_arrows(30 - Game.arrows)

	Settings.set_volume(&"SFX", 0.9)

	# Every id the table can ever ask for must resolve to a real file. This is
	# the cheap half of the check and it covers all of them at once.
	var ids: Array = Sfx.CUES.values()
	ids.append(&"escape_rope")  # emitted directly by the run_ended handler
	# The reward tiers live in their own table because `reward_revealed` carries
	# the tier as an argument and `CUES` is keyed on the signal. They are cues all
	# the same, and a tier pointing at a missing file fails exactly as silently.
	ids.append_array(Sfx.REWARD_CUES.values())
	# Reached only through bare `Bus.request_sfx` emitters, so they are in no table
	# and nothing else here would notice them going missing.
	ids.append(&"power_up")               # SoundingStone._on_taken -- the Echo
	ids.append(&"key_found")               # Dungeon._wake_key
	ids.append(&"door_refused")            # locked and barred door refusal UI
	ids.append(&"upgrade_stat_selected")   # progression catalogue selection
	ids.append(&"upgrade_stat_unlocked")   # successful progression purchase
	for id in ids:
		var s: AudioStream = Sfx._load(id)
		_ck("file exists for cue %s" % id, s != null)

	# The expensive half: prove the wiring, not just the files. Emitting on Bus
	# is what the game does, so that is what gets tested -- calling Sfx.play()
	# here would pass even if no signal were connected.
	await _fires(rig, "chest_opened",
		func() -> void: Bus.chest_opened.emit(&"c1", &"gold"))
	await _fires(rig, "door_opened",
		func() -> void: Bus.door_opened.emit(&"d1"))
	await _fires(rig, "item_acquired",
		func() -> void: Bus.item_acquired.emit(&"bow"))
	await _fires(rig, "loot_gained",
		func() -> void: Bus.loot_gained.emit(&"ore", 1))
	await _fires(rig, "items_sold",
		func() -> void: Bus.items_sold.emit({}, 40))
	await _fires(rig, "puzzle_solved",
		func() -> void: Bus.puzzle_solved.emit(&"p1"))
	await _fires(rig, "room_cleared",
		func() -> void: Bus.room_cleared.emit(&"Room_0_0"))
	# Both tiers, because they are two rows in `REWARD_CUES` and a lookup that
	# fell through to the tier-1 default would still pass a one-tier test.
	# The puzzle beat above uses the same take as MINOR on purpose. Wait past its
	# anti-stack gap so this beat tests the reveal independently instead of proving
	# that two copies correctly collapse into one.
	await rig.wait_seconds(float(Sfx.MIN_GAP[&"puzzle_reward"]) + 0.1)
	await _fires(rig, "reward_revealed (MINOR)",
		func() -> void: Bus.reward_revealed.emit(RewardVfx.MINOR, Vector3(1, 0, 1)))
	await _fires(rig, "reward_revealed (MAJOR)",
		func() -> void: Bus.reward_revealed.emit(RewardVfx.MAJOR, Vector3(1, 0, 1)))
	await _fires(rig, "target_acquired",
		func() -> void: Bus.target_acquired.emit(null))
	await _fires(rig, "player_died", func() -> void: Bus.player_died.emit())
	# `extract_refused` was tested here until 2026-08-09. The signal is gone: the
	# fee is capped at the purse, so the rope has nothing left to refuse.
	await _fires(rig, "bag_full", func() -> void: Bus.bag_full.emit())
	await _fires(rig, "enemy_died",
		func() -> void: Bus.enemy_died.emit(null, Vector3(2, 0, 2)))
	await _fires(rig, "run_started", func() -> void: Bus.run_started.emit(1))
	await _fires(rig, "run_ended (extracted)",
		func() -> void: Bus.run_ended.emit(true, {}, 100))
	await _fires(rig, "request_sfx (the declared interface)",
		func() -> void: Bus.request_sfx.emit(&"level_up", Vector3.ZERO))

	if _fails == 0:
		print("SFX OK — all checks passed")
	else:
		print("SFX FAIL — %d check(s) failed" % _fails)


## Emit, then look for a voice that started. Voices are round-robin, so this
## checks the pool as a whole rather than guessing which one was claimed.
func _fires(rig, label: String, emit: Callable) -> void:
	_silence()
	await rig.wait_frames(2)
	emit.call()
	await rig.wait_frames(4)
	_ck("%s started a voice" % label, _any_playing())


func _silence() -> void:
	for v in Sfx._pool:
		v.stop()


func _any_playing() -> bool:
	for v in Sfx._pool:
		if v.playing:
			return true
	return false


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_fails += 1
		print("SFX FAIL %s" % label)
