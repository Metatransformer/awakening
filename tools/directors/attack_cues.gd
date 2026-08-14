extends RefCounted
## Do the attack sounds fire WHEN the config says, rather than always on the
## commit frame?
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/attack_cues.gd --out=/tmp/cues/x.png
##
## `Player.Audio` states every attack sound as a FRACTION of the swing it
## belongs to, and `HeroCombat._fire_due_cues` pays them out as the swing
## advances. Every shipped cue is 0.0 — the whoosh rings on the commit frame,
## exactly as it did when it was a bare `play()` — so nothing in the game
## exercises the delayed path, and a scheduler nobody has ever seen wait is a
## scheduler that has not been tested (CLAUDE.md §2). This points the instrument
## at an answer it already knows: a cue armed at 0.50 must be SILENT at 0.20 of
## the swing and RINGING after 0.60.
##
## It reads `AudioStreamPlayer3D.playing`, which is honest under
## `tools/quiet.sh` — the wrapper's `--audio-driver Dummy` opens no device but
## the server still tracks playback state.
##
## The null case is the first check: a swing thrown with the shipped config must
## put the whoosh out on the SAME frame it commits. Without it this director
## could pass while the scheduler quietly delayed everything.

## Hero.MoveState.ATTACK.
const STATE_ATTACK := 4
## Where the probe cue is armed, as a fraction of the swing, and the two moments
## it is sampled at. Both sit clear of the boundary so a frame of jitter cannot
## decide the answer.
const CUE_AT := 0.50
const SAMPLE_EARLY := 0.20
const SAMPLE_LATE := 0.75


func run(rig) -> void:
	var players: Array = rig.get_nodes_in_group(&"player")
	if players.is_empty():
		rig.fail("CUES no node in group `player`")
		return
	var hero: Node3D = players[0]
	var combat: Node = hero.get("combat")
	if combat == null:
		rig.fail("CUES the hero has no HeroCombat")
		return
	await rig.wait_frames(30)

	var swing_player: AudioStreamPlayer3D = combat.get("_swing_player")
	var yell_player: AudioStreamPlayer3D = combat.get("_yell_player")
	if swing_player == null or yell_player == null:
		rig.fail("CUES the combat node has no audio players")
		return

	var dur: float = combat.get("swing_time")

	# --- 1. The null case: the shipped cue is 0.0, so it rings immediately ----
	swing_player.stop()
	rig.tap(["attack"])
	await rig.wait_frames(2)
	rig.check(swing_player.playing,
		"a swing whose WHOOSH_AT is %.2f rings on the commit frame"
			% Player.Audio.Light.WHOOSH_AT[0])
	rig.check(int(hero.get("state")) == STATE_ATTACK,
		"and the hero is actually swinging")
	await rig.wait_seconds(dur + 0.4)

	# --- 2. The delayed case -------------------------------------------------
	# Armed straight after the press, on the swing that press started. `_commit`
	# clears the yell slot, so this has to land after it — which is exactly the
	# order the spin and the flurry use.
	yell_player.stop()
	rig.tap(["attack"])
	await rig.wait_frames(2)
	combat.call("_cue_sounds", CUE_AT, Vector2(1.0, 1.0))

	# Sampled off `_swing_t`, the clock the scheduler itself reads, and not off
	# a wall-clock wait: an earlier draft waited `dur * fraction` seconds and
	# failed on the late sample while the cue had in fact fired exactly on time.
	# A director that measures the thing through a second, drifting clock is
	# reporting on its own timer (CLAUDE.md §2).
	await _until(rig, combat, dur * SAMPLE_EARLY)
	rig.check(not yell_player.playing,
		"a cue armed at %.2f is still silent at %.2f of the swing"
			% [CUE_AT, SAMPLE_EARLY])
	rig.check(float(combat.get("_cue_yell")) >= 0.0, "and is still armed there")

	await _until(rig, combat, dur * SAMPLE_LATE)
	rig.check(float(combat.get("_cue_yell")) < 0.0,
		"the scheduler has fired it by %.2f of the swing" % SAMPLE_LATE)
	rig.check(yell_player.playing, "and the sound is ringing")
	print("CUES swing_time=%.2fs cue at %.2f -> %.3fs in" % [dur, CUE_AT, dur * CUE_AT])

	# --- 3. Nothing survives its own swing -----------------------------------
	# A cue that outlived the swing it belonged to would ring at the start of the
	# next attack, which is the failure mode the reset in `_advance_swing` exists
	# for. Arm one past the end and prove it never fires.
	await rig.wait_seconds(dur + 0.4)
	yell_player.stop()
	rig.tap(["attack"])
	await rig.wait_frames(2)
	combat.call("_cue_sounds", 1.6, Vector2(1.0, 1.0))
	await rig.wait_seconds(dur + 0.3)
	rig.check(not yell_player.playing,
		"a cue armed past the end of the swing is dropped, not carried over")

	print("CUES checks complete")


## Step frames until the running swing has been going for `t` seconds. Gives up
## after a second of frames so a swing that never started cannot hang the run.
func _until(rig, combat: Node, t: float) -> void:
	for _i in 240:
		if float(combat.get("_swing_t")) >= t:
			return
		await rig.wait_frames(1)
