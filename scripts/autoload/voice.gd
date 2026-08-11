extends Node
## Autoload `Voice`. The recorded lines, and the one mouth that says them.
##
## Fifteen lines exist and this is all of them (`docs/SCOPE.md` §1, Voiced lines
## **15** — the count is frozen the way every other count in that table is). A
## sixteenth is not a row here, it is an amendment.
##
## Three rules, and the first one is the whole design:
##
##  * **ONE PLAYER. One thing in the world is talking at any moment**, and
##    starting a line stops whatever was mid-sentence. That is not a resource
##    limit -- `Sfx` pools twelve voices because a room full of dying monsters
##    is genuinely twelve sounds at once -- it is the fiction: two people talking
##    over each other in a courtyard of five is a bug you cannot un-hear. It also
##    makes the interrupt free where it is *wanted*: closing a counter one beat
##    after opening it cuts the greeting off with the farewell, which is exactly
##    what walking away mid-sentence sounds like.
##  * **Not positional.** Every line in this table is said by somebody you are
##    standing directly in front of, having just pressed a button on them, or by
##    a narrator who is nowhere. `AudioStreamPlayer3D` would buy attenuation
##    nobody can perceive across two metres and cost a real failure -- the
##    alchemist's farewell is 3.6 s long and you are walking away from her while
##    it plays, so the one line in the game with a distance curve on it would be
##    the one line that fades out mid-word.
##  * **The file name is the WORDS.** `LINES` maps a cue to a file, and the file
##    is called what the actor said, so this table reads as a script and a line
##    can be found by remembering it rather than by opening five files. The cue
##    names (`hello`, `deal`, `farewell`) are the *slots*, and they are the same
##    slots for every speaker, which is why `Npc.activate` and `TradeScreen` each
##    have one call and no branch per counter.
##
## On the SFX bus, deliberately, rather than a `Voice` bus of its own. A fifth
## bus means a fifth slider, a fifth key in `Settings`, a fifth row in the
## options screen and a save-file field -- for fifteen lines that are already
## normalised to one loudness (`tools/import_voices.sh`). If the game ever grows
## a hundred of them, that is the moment, and it is a small change: this file
## names the bus in one place.

## Where the lines live. `audio/voice/<speaker>/<file>.ogg`.
##
## ogg and not the mp3 they were recorded as, for a reason that is audible on the
## shortest line: an mp3 stream begins with an encoder's padding frame, so a
## 0.8 s "hail" starts with ~30 ms of silence between the button and the voice.
## `tools/import_voices.sh` is the conversion, and it is also where the 20 dB
## loudness spread in the masters gets flattened.
const DIR := "res://audio/voice/%s/%s.ogg"

## Every recorded line in the game.
##
## speaker -> cue -> the takes for that cue. An Array even when there is one
## take, so `say` has no special case and a second take is a comma.
##
## The four counters share three cues and the elder shares two of them, which is
## the whole reason this is a table and not five scripts:
##
##   * `hello`    -- said when you address them, under the screen opening.
##   * `deal`     -- said when a transaction actually lands. Not on the press:
##     on the press that WORKED (`TradeScreen._commit`).
##   * `farewell` -- said when the screen comes down.
##
## **The alchemist has no `deal` take and that is not a gap to fill with somebody
## else's.** She was recorded with two lines; `say` returns 0.0 for a cue nobody
## has and nothing happens, which is the correct behaviour for a counter whose
## keeper does not comment on the sale. The Lanternkeeper has no lines at all,
## for the same reason -- she is silent until somebody records her.
##
## The elder's `hello` has two takes and `say` alternates rather than repeats
## (see `_last`): "hail" is 0.8 s and would be the most-heard line in the game.
const LINES := {
	&"narrator": {
		&"opening": ["opening"],
	},
	# The one person in the garrison who is not selling anything.
	&"elder": {
		# The report-for-duty line, said once, in the opening. See
		# `Garrison._open_the_game`.
		&"arrival": ["ive_been_expecting_you"],
		&"hello": ["hail", "how_go_your_explorations"],
	},
	&"smith": {
		&"hello": ["finest_wares_in_the_vale"],
		&"deal": ["thats_a_good_deal"],
		&"farewell": ["take_care"],
	},
	&"quartermaster": {
		&"hello": ["ive_just_the_deal_for_you"],
		&"deal": ["good_price"],
		&"farewell": ["come_back_with_more_treasures"],
	},
	&"alchemist": {
		&"hello": ["need_any_potions"],
		&"farewell": ["do_try_to_stay_alive_down_there"],
	},
	&"jewelcrafter": {
		&"hello": ["i_have_just_the_right_amulet_for_you"],
		&"deal": ["there_you_go"],
		&"farewell": ["youre_looking_quite_fashionable"],
	},
}

## Emitted when a line finishes on its own. NOT emitted when one is cut off by
## the next -- a caller that has to know a line ended should use the length
## `say` hands back, which is true whatever happens afterwards. `Garrison`'s
## opening does exactly that, and it is why a missing file there costs a short
## black screen rather than a permanent one.
signal line_finished

var _player: AudioStreamPlayer
var _cache: Dictionary = {}
## speaker+cue -> the index of the take used last, so a two-take cue alternates
## instead of rolling a coin and saying "hail" three times running.
var _last: Dictionary = {}


func _ready() -> void:
	# ALWAYS, because the two moments this file exists for both happen with the
	# tree stopped: the opening narration plays over a paused world behind Flow's
	# veil, and a counter's farewell can outlive a pause taken on top of the shop.
	# A paused AudioStreamPlayer stops dead mid-word.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_player = AudioStreamPlayer.new()
	_player.name = "Line"
	_player.bus = &"SFX"
	add_child(_player)
	_player.finished.connect(func() -> void: line_finished.emit())


## Say a line. Returns how long it will take, in seconds, or 0.0 if this speaker
## has no take for this cue -- which is a normal answer, not an error: the
## alchemist has nothing to say about a sale and the Lanternkeeper has nothing to
## say at all.
##
## The return value is the contract for anything that has to wait: it is known
## the moment the line starts, so a caller never has to await a signal that a
## missing file would never emit.
func say(speaker: StringName, cue: StringName) -> float:
	var takes: Array = _takes(speaker, cue)
	if takes.is_empty():
		return 0.0

	var key := "%s/%s" % [speaker, cue]
	var i := 0
	if takes.size() > 1:
		i = (int(_last.get(key, -1)) + 1) % takes.size()
	_last[key] = i

	var stream := _load(speaker, str(takes[i]))
	if stream == null:
		return 0.0
	# Whatever was talking is not any more. See the header: one mouth.
	_player.stop()
	_player.stream = stream
	_player.play()
	return stream.get_length()


## Stop whatever is being said. For a transition that is about to take the
## speaker's whole scene away.
func stop() -> void:
	_player.stop()


func speaking() -> bool:
	return _player.playing


## The file name of the line being said this instant, or "" for silence.
##
## For directors. There is no other way to check that a counter said the RIGHT
## thing -- `speaking()` alone would pass a build where every cue in the table
## resolved to the same take, which is exactly the shape a copy-paste error in
## `LINES` takes.
func line() -> String:
	if not _player.playing or _player.stream == null:
		return ""
	return _player.stream.resource_path.get_file().get_basename()


func _takes(speaker: StringName, cue: StringName) -> Array:
	var rows: Dictionary = LINES.get(speaker, {})
	return rows.get(cue, [])


func _load(speaker: StringName, file: String) -> AudioStream:
	var path := DIR % [speaker, file]
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		# Loud, because a missing line is a missing line -- there are fifteen of
		# them and every one is named in the table above.
		push_warning("Voice: no such line %s" % path)
		_cache[path] = null
		return null
	var s := load(path) as AudioStream
	_cache[path] = s
	return s
