extends RefCounted
## Focused proof for the three-second civil-day title ceremony.
##
## Run from the real garrison:
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/day_title_card.gd \
##     --out=/tmp/day-title/day_title.png --warmup=60

const NIGHT_CUE: StringName = &"nightfall_owl"
const DAWN_CUE: StringName = &"dawn_birds"
const CLOCK_CUE: StringName = &"clock_ticking"
const TIMING_TOLERANCE: float = 0.35
const QUEUE_TIMING_TOLERANCE: float = 0.55


func run(rig) -> void:
	var garrison := rig.scene() as Garrison
	if not rig.check(garrison != null, "scene is the real garrison"):
		return
	if not rig.check(not Flow.busy and not get_tree(rig).paused,
			"Flow and the real garrison are settled before the proof"):
		return

	var clock_before: Dictionary = Clock.snapshot()
	var rest_before: bool = Flow.deliberate_rest
	var blocked_before: bool = Prompt.blocked
	var paused_before: bool = get_tree(rig).paused
	var heard_cues: Array[StringName] = []
	var cue_listener: Callable = func(id: StringName) -> void:
		heard_cues.append(id)
	Bus.request_global_sfx.connect(cue_listener)

	# All crossings in this director are deliberate setup. This keeps the
	# existing natural-dawn trip out of a proof whose subject is the card itself.
	Flow.deliberate_rest = true
	Clock.running = true

	await _prove_night(rig, heard_cues)
	await _prove_dawn(rig, heard_cues)
	await _prove_crossed_queue(rig, heard_cues)
	await _prove_restore_is_silent(rig, heard_cues)

	if Bus.request_global_sfx.is_connected(cue_listener):
		Bus.request_global_sfx.disconnect(cue_listener)
	Flow.deliberate_rest = rest_before
	Prompt.blocked = blocked_before
	get_tree(rig).paused = paused_before
	Clock.restore(clock_before)
	print("DAY TITLE CARD OK")


func _prove_night(rig, heard_cues: Array[StringName]) -> void:
	Clock.restore({"day": 3, "hour": 19.99, "running": true})
	var started_usec := Time.get_ticks_usec()
	Clock.set_time(3, 20.0)
	await rig.wait_frames(2)
	var card := _active_card()
	if not rig.check(card != null, "20:00 raises a day title card"):
		return
	rig.check(card.title == "Night falls", "night card says Night falls")
	rig.check(card.day_line == "Day 3", "night card says Day 3")
	rig.check(card.cue == NIGHT_CUE, "night card exposes the owl cue")
	rig.check(get_tree(rig).paused and Prompt.blocked,
		"night card pauses the world and blocks gameplay input")
	rig.check(heard_cues == [CLOCK_CUE, NIGHT_CUE],
		"night requests quiet ticking beneath exactly one owl cue")
	rig.check(Sfx.last_global_cue == NIGHT_CUE,
		"Sfx centrally claims the owl cue")
	rig.check(_global_voice_playing(CLOCK_CUE),
		"the quiet clock bed plays on a pause-immune global SFX voice")
	rig.check(_global_voice_volume(CLOCK_CUE) <= -8.5,
		"the clock bed is mixed below the ceremony (%.1f dB)"
		% _global_voice_volume(CLOCK_CUE))
	rig.check(_global_voice_playing(NIGHT_CUE),
		"the owl plays on a pause-immune global SFX voice")
	rig.check(card.visual_mode == &"night", "night selects the crescent motif")
	var finishes := [0]
	card.finished.connect(func() -> void: finishes[0] += 1)
	await _prove_staging(rig, card, "night")
	await rig.capture("day_title_00_night.png")

	var cleared := await _wait_for_no_card(rig, DayTitleCard.PRESENTATION_SECONDS)
	var elapsed := float(Time.get_ticks_usec() - started_usec) / 1000000.0
	rig.check(cleared, "night card disappears")
	rig.check(absf(elapsed - DayTitleCard.PRESENTATION_SECONDS) <= TIMING_TOLERANCE,
		"night presentation lasts 3.0 seconds (%.3f)" % elapsed)
	rig.check(finishes[0] == 1, "night emits finished exactly once")
	rig.check(not get_tree(rig).paused and not Prompt.blocked,
		"night completion unpauses the world and restores gameplay input")
	var hud_line := String(Hud.get("_clock_text"))
	rig.check(hud_line.contains("DAY 3") and hud_line.contains("8:00pm"),
		"the compact HUD still reports Day 3 and 8:00pm (%s)" % hud_line)
	await rig.capture("day_title_01_hud_clock.png")


func _prove_dawn(rig, heard_cues: Array[StringName]) -> void:
	Clock.restore({"day": 4, "hour": 4.99, "running": true})
	var started_usec := Time.get_ticks_usec()
	Clock.set_time(4, 5.0, true)
	await rig.wait_frames(2)
	var card := _active_card()
	if not rig.check(card != null, "05:00 raises a day title card"):
		return
	rig.check(card.title == "The sun rises", "dawn card says The sun rises")
	rig.check(card.day_line == "Day 4", "dawn card says Day 4")
	rig.check(card.cue == DAWN_CUE, "dawn card exposes the bird cue")
	rig.check(get_tree(rig).paused and Prompt.blocked,
		"dawn card pauses the world and blocks gameplay input")
	rig.check(heard_cues.slice(-2) == [CLOCK_CUE, DAWN_CUE],
		"dawn requests quiet ticking beneath exactly one bird cue")
	rig.check(Sfx.last_global_cue == DAWN_CUE,
		"Sfx centrally claims the bird cue")
	rig.check(_global_voice_playing(DAWN_CUE),
		"the birds play on a pause-immune global SFX voice")
	rig.check(card.visual_mode == &"dawn", "dawn selects the sun motif")
	var finishes := [0]
	card.finished.connect(func() -> void: finishes[0] += 1)
	await _prove_staging(rig, card, "dawn")
	await rig.capture("day_title_02_dawn.png")
	rig.check(await _wait_for_no_card(rig, DayTitleCard.PRESENTATION_SECONDS),
		"dawn card disappears and completes")
	var elapsed := float(Time.get_ticks_usec() - started_usec) / 1000000.0
	rig.check(absf(elapsed - DayTitleCard.PRESENTATION_SECONDS) <= TIMING_TOLERANCE,
		"dawn presentation lasts 3.0 seconds (%.3f)" % elapsed)
	rig.check(finishes[0] == 1, "dawn emits finished exactly once")
	rig.check(not get_tree(rig).paused and not Prompt.blocked,
		"dawn completion unpauses the world and restores gameplay input")


func _prove_crossed_queue(rig, heard_cues: Array[StringName]) -> void:
	Clock.restore({"day": 7, "hour": 19.5, "running": true})
	var cue_start := heard_cues.size()
	var started_usec := Time.get_ticks_usec()
	Clock.set_time(8, 5.0, true)

	var seen: Array[String] = []
	var modes: Array[StringName] = []
	var last_card_id: int = 0
	var max_overlap: int = 0
	var fully_staged: Dictionary = {}
	var exiting: Dictionary = {}
	var finishes := [0]
	var deadline := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline:
		var cards: Array[Node] = Flow.find_children("DayTitleCard", "", true, false)
		max_overlap = maxi(max_overlap, cards.size())
		var card := _active_card()
		if card != null and card.get_instance_id() != last_card_id:
			seen.append(card.title)
			last_card_id = card.get_instance_id()
			modes.append(card.visual_mode)
			card.finished.connect(func() -> void: finishes[0] += 1)
		if card != null:
			var id := card.get_instance_id()
			if card.reveal_progress > 0.98 and card.motif_progress > 0.98 \
					and card.title_progress > 0.98 and card.rule_progress > 0.98 \
					and card.day_progress > 0.98:
				fully_staged[id] = true
			if card.exit_progress > 0.05:
				exiting[id] = true
		if seen.size() == 2 and card == null and not get_tree(rig).paused:
			break
		await get_tree(rig).process_frame

	var elapsed := float(Time.get_ticks_usec() - started_usec) / 1000000.0
	rig.check(seen == ["Night falls", "The sun rises"],
		"a jump crossing both boundaries presents night then dawn")
	rig.check(modes == [&"night", &"dawn"],
		"the queued cards use crescent then sun variants")
	rig.check(max_overlap == 1, "crossed boundary cards never overlap")
	rig.check(fully_staged.size() == 2,
		"both queued cards complete their reveal and text staging")
	rig.check(exiting.size() == 2, "both queued cards reach their eased exit")
	rig.check(finishes[0] == 2, "the queued cards each emit finished exactly once")
	rig.check(absf(elapsed - DayTitleCard.PRESENTATION_SECONDS * 2.0) \
			<= QUEUE_TIMING_TOLERANCE,
		"the crossed jump plays two complete three-second cards (%.3f)" % elapsed)
	rig.check(heard_cues.size() == cue_start + 4
		and heard_cues.slice(cue_start) \
			== [CLOCK_CUE, NIGHT_CUE, CLOCK_CUE, DAWN_CUE],
		"the crossed jump requests one quiet clock under owl then birds")


func _prove_restore_is_silent(rig, heard_cues: Array[StringName]) -> void:
	var cue_count := heard_cues.size()
	Clock.restore({"day": 12, "hour": 20.5, "running": true})
	await rig.wait_frames(12)
	rig.check(_active_card() == null and heard_cues.size() == cue_count,
		"Clock.restore does not replay a civil title card or cue")


func _prove_staging(rig, card: DayTitleCard, variant: String) -> void:
	await _wait_wall_seconds(rig, 0.20)
	rig.check(card.reveal_progress > 0.15 and card.reveal_progress < 0.99,
		"%s shaped field is visibly revealing" % variant)
	rig.check(card.motif_progress > 0.0 and card.motif_progress < 0.99,
		"%s horizon motif is moving during the reveal" % variant)
	rig.check(card.title_progress < 0.15 and card.day_progress < 0.05,
		"%s title and day wait for the motif" % variant)
	await _wait_wall_seconds(rig, 0.85)
	rig.check(card.reveal_progress > 0.98 and card.motif_progress > 0.98,
		"%s field and horizon motif settle legibly" % variant)
	rig.check(card.title_progress > 0.98 and card.rule_progress > 0.98 \
			and card.day_progress > 0.98,
		"%s title, rule, and day finish their staged entrance" % variant)
	rig.check(card.exit_progress < 0.05,
		"%s picture holds before its eased exit" % variant)


func _active_card() -> DayTitleCard:
	return Flow.find_child("DayTitleCard", true, false) as DayTitleCard


func _global_voice_playing(cue: StringName) -> bool:
	var suffix := "/%s.wav" % String(cue)
	for voice: AudioStreamPlayer in Sfx._global_pool:
		if voice.playing and voice.stream != null \
				and voice.stream.resource_path.ends_with(suffix):
			return true
	return false


func _global_voice_volume(cue: StringName) -> float:
	var suffix := "/%s.wav" % String(cue)
	for voice: AudioStreamPlayer in Sfx._global_pool:
		if voice.playing and voice.stream != null \
				and voice.stream.resource_path.ends_with(suffix):
			return voice.volume_db
	return 0.0


func _wait_for_no_card(rig, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0) + 750
	while Time.get_ticks_msec() < deadline:
		if _active_card() == null:
			return true
		await get_tree(rig).process_frame
	return false


func _wait_wall_seconds(rig, seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree(rig).process_frame


func get_tree(rig) -> SceneTree:
	return rig.root.get_tree()
