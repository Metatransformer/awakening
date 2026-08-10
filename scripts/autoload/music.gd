extends Node
## Autoload `Music`. Picks what is playing and crossfades to it.
##
## The project shipped with 15 mastered tracks in `res://audio/music/` and
## nothing that ever called `play()` on any of them. The Music bus existed, the
## pause menu had a working Music slider, `Settings.music_volume` was persisted
## and restored -- all of it controlling silence. This is the missing half.
##
## What it keys off, and why it is a poll rather than a signal:
##
##  * **Garrison vs delve** comes from the current scene's path. Flow owns the
##    garrison<->dungeon change (docs/CONTRACT.md §7); rather than have Flow also
##    own music cues, this notices the scene it landed in. That way training,
##    playtest and proving_ground get music too, without Flow learning about
##    every scene anyone adds.
##  * **Combat** is polled off the enemies themselves: anything in the `enemy`
##    group that answers `is_engaged()`. Bus has no "combat started" signal, and
##    `target_acquired` is Z-lock, which is not the same thing -- you can be
##    swarmed without locking, and lock a corpse without a fight.
##  * **Boss** is the one thing that IS a signal, because Bus already has
##    `boss_engaged` / `boss_defeated` and they mean precisely this.
##
## It never touches AudioServer. Volume is the `Music` bus, which belongs to
## `Settings` (docs/CONTRACT.md §8) -- so the pause-menu slider drives this for
## free and nothing here has to know the slider exists.

enum Mood { SILENT, CALM, DELVE, FIGHT, BOSS }

## Every track in the project, sorted into the mood it belongs to. There is no
## garrison-specific track in the set, so the garrison gets `title_screen` -- it
## is the only cue in the library that is neither a dungeon ambience nor a
## fight.
const POOLS := {
	Mood.CALM: [
		"res://audio/music/title_screen.ogg",
	],
	Mood.DELVE: [
		"res://audio/music/dungeon_1.ogg",
		"res://audio/music/dungeon_2.ogg",
		"res://audio/music/dungeon_3.ogg",
	],
	Mood.FIGHT: [
		"res://audio/music/combat_1.ogg",
		"res://audio/music/combat_2.ogg",
		"res://audio/music/combat_3.ogg",
		"res://audio/music/combat_4.ogg",
		"res://audio/music/combat_5.ogg",
		"res://audio/music/combat_6.ogg",
		"res://audio/music/combat_7.ogg",
	],
	Mood.BOSS: [
		"res://audio/music/boss_1.ogg",
		"res://audio/music/boss_2.ogg",
		"res://audio/music/boss_3.ogg",
		"res://audio/music/boss_4.ogg",
	],
}

## Headroom. The tracks are mastered near full scale and the game's SFX are not;
## at 0 dB the music sits on top of the sword instead of under it. This is the
## mix, not the player's volume -- that is the Music bus.
const TRACK_DB := -8.0
## Far enough down to be inaudible without being -inf, which tweens badly.
const SILENT_DB := -60.0

const XFADE_IN := 1.6
const XFADE_OUT := 1.4
## Dropping into a fight should feel like a cut, not a dissolve.
const XFADE_FIGHT := 0.5

## How long after the last enemy disengages before the fight music lets go.
## Without this, one goblin losing line of sight for half a second whipsaws the
## whole soundtrack.
const FIGHT_LINGER := 4.0
## Cheap enough to run 4x a second, and no cue in the game needs finer timing.
const POLL := 0.25

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _active: AudioStreamPlayer
var _mood: Mood = Mood.SILENT
var _fade: Tween

## Tracks already played from the current pool, so a 7-track combat pool does not
## play combat_3 four times running. Cleared when the pool is exhausted.
var _drawn: Array[String] = []
var _boss := false
var _fight_until := 0.0
var _elapsed := 0.0


func _ready() -> void:
	# The music keeps playing while the pause menu is up. A soundtrack that cuts
	# out the moment you open Options makes the menu feel like a crash.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_a = _make_player("MusicA")
	_b = _make_player("MusicB")
	_active = _a

	Bus.boss_engaged.connect(func(_boss_node: Node3D) -> void: _set_boss(true))
	Bus.boss_defeated.connect(func() -> void: _set_boss(false))
	# Dying ends the run and the fight with it; without this the combat cue
	# rides through the death fade.
	Bus.player_died.connect(func() -> void:
		_boss = false
		_fight_until = 0.0)

	var t := Timer.new()
	t.name = "Poll"
	t.wait_time = POLL
	t.process_mode = Node.PROCESS_MODE_ALWAYS
	t.timeout.connect(_evaluate)
	add_child(t)
	t.start()


func _process(delta: float) -> void:
	_elapsed += delta


func _make_player(n: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = n
	p.bus = &"Music"
	p.volume_db = SILENT_DB
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	# Every music import in this project is `loop=false`, deliberately: there are
	# 3 dungeon and 7 combat tracks, so the pool rotates instead of one track
	# looping forever. That makes `finished` the cue to draw the next one --
	# without this connection the score plays once and the game goes quiet.
	p.finished.connect(func() -> void: _on_finished(p))
	add_child(p)
	return p


# --- What should be playing --------------------------------------------------

func _evaluate() -> void:
	var want := _desired_mood()
	if want != _mood:
		_go(want)


func _desired_mood() -> Mood:
	# Same rule the HUD uses: no hero in the tree means this is lookdev or a tool
	# scene, and those stay silent.
	var hero := get_tree().get_first_node_in_group(&"player")
	if hero == null:
		return Mood.SILENT

	if _boss:
		return Mood.BOSS

	if _enemies_engaged():
		_fight_until = _elapsed + FIGHT_LINGER
	if _elapsed < _fight_until:
		return Mood.FIGHT

	var scene := get_tree().current_scene
	var path := scene.scene_file_path if scene != null else ""
	return Mood.CALM if path.contains("garrison") else Mood.DELVE


func _enemies_engaged() -> bool:
	for e in get_tree().get_nodes_in_group(&"enemy"):
		# Asked, not inspected. This used to read `e.state` and compare it against
		# a hardcoded range of enum indices, which meant this file had an opinion
		# about the internals of a class it deliberately does not import. The
		# enemy owns what its own states mean; duck-typed so a future enemy that
		# answers the question differently just answers it.
		if not e.has_method(&"is_engaged"):
			continue
		if e.is_engaged():
			return true
	return false


func _set_boss(on: bool) -> void:
	_boss = on
	_evaluate()


# --- Playing it ---------------------------------------------------------------

func _go(mood: Mood) -> void:
	_mood = mood
	_drawn.clear()
	if mood == Mood.SILENT:
		_fade_out_active()
		return
	# A fight should land on the beat you got hit, not 1.6 seconds later.
	var dur := XFADE_FIGHT if mood == Mood.FIGHT or mood == Mood.BOSS else XFADE_IN
	_crossfade_to(_draw(mood), dur)


## Next track from the mood's pool, without repeating until the pool is used up.
func _draw(mood: Mood) -> String:
	var pool: Array = POOLS[mood]
	var left: Array[String] = []
	for p in pool:
		if not _drawn.has(p):
			left.append(p)
	if left.is_empty():
		_drawn.clear()
		left.assign(pool)
	var pick: String = left[randi() % left.size()]
	_drawn.append(pick)
	return pick


func _crossfade_to(path: String, dur: float) -> void:
	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("Music: could not load %s" % path)
		return

	var next := _b if _active == _a else _a
	var prev := _active

	next.stream = stream
	next.volume_db = SILENT_DB
	next.play()
	_active = next

	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.set_parallel(true)
	_fade.tween_property(next, "volume_db", TRACK_DB, dur)
	if prev.playing:
		_fade.tween_property(prev, "volume_db", SILENT_DB, minf(dur, XFADE_OUT))
		# Stop it once it is inaudible, or it burns a voice forever.
		_fade.chain().tween_callback(prev.stop)


func _fade_out_active() -> void:
	if not _active.playing:
		return
	if _fade != null and _fade.is_valid():
		_fade.kill()
	var p := _active
	_fade = create_tween()
	_fade.tween_property(p, "volume_db", SILENT_DB, XFADE_OUT)
	_fade.tween_callback(p.stop)


## A track ran out. Draw the next one from the same mood rather than letting the
## game fall silent.
func _on_finished(who: AudioStreamPlayer) -> void:
	if who != _active or _mood == Mood.SILENT:
		return
	_crossfade_to(_draw(_mood), XFADE_IN)


# --- For directors and debugging ----------------------------------------------

## The mood currently playing, as a name. Used by tools/directors/music_beats.gd.
func mood_name() -> String:
	return Mood.keys()[_mood]


## The track file currently playing, or "" when silent.
func current_track() -> String:
	if _active == null or not _active.playing or _active.stream == null:
		return ""
	return _active.stream.resource_path
