extends Node
## Autoload `Sfx`. Implements `Bus.request_sfx`, and plays the one-shots that
## the game's own signals already describe.
##
## `res://audio/sfx/` holds 156 sounds. Nine of them were wired -- the sword,
## the shield, and the five the pause menu owns -- and `Bus.request_sfx` had
## been declared in event_bus.gd with **no emitter and no listener** since it was
## written. This is that listener, plus the signal→sound table for the events
## that already say exactly what happened.
##
## Two rules this keeps:
##
##  * **One sound per event, chosen here.** The alternative -- every prop
##    loading its own AudioStream -- is how the chest ends up louder than the
##    boss. Anything that wants a noise emits `Bus.request_sfx(&"id", pos)` and
##    does not own an AudioStreamPlayer.
##  * **Pooled, never per-shot instanced.** A dungeon floor of dying monsters
##    would otherwise allocate a player per corpse.
##
## Deliberately NOT here: footsteps. `footstep_*` and the 14 material folders
## under audio/sfx/footsteps/ need a step event off the hero's animation and a
## read of what is underfoot; that is a system, not a table entry, and guessing
## at it would put grass under the town's cobbles.

## How many positional voices can overlap. Past this the oldest is recycled --
## a swarm dying at once should thin out, not blow the mixer up.
const VOICES := 12

## Sounds that ship as numbered variants -- `coin_trade` is on disk as
## `coin_trade_1..3`, never as `coin_trade.ogg`. Picking at random keeps a
## repeated event from turning into a machine gun.
##
## A count of 1 still belongs here: `doom_stinger` ships as `doom_stinger_1.ogg`
## with no sibling, so the bare name resolves to nothing. That is precisely how
## the death sting was missing on the first pass -- the file list had been
## grouped with its numeric suffix stripped, and the stripped name read like the
## real one.
const VARIANTS := {
	&"coin_trade": 3,
	&"coin_drop": 3,
	&"doom_stinger": 1,
	&"ui_move_selection": 1,
}

## The whole signal→sound table. Every entry is an event that already carries
## its own meaning; nothing here is a guess about what the designer wanted.
const CUES := {
	&"chest_opened": &"chest_open",
	&"door_opened": &"door_open",
	&"item_acquired": &"equip",
	&"loot_gained": &"pickup",
	&"items_sold": &"coin_trade",
	&"puzzle_solved": &"level_chime",
	# The sound a landed blow makes. It was missing, so the only combat noise in
	# the game was a monster DYING -- you could hit a wraith five times in
	# silence and then hear the sixth. Emitted with a real world position by
	# whatever got hit, so a blow lands where it landed.
	&"hit_landed": &"hit_flesh",
	&"enemy_died": &"hit_flesh",
	# A blow that was STOPPED, which has to read differently from one that
	# landed and from one that missed -- it is the shield's whole reward.
	# `HeroCombat.on_blocked` used to build its own AudioStreamPlayer3D per
	# block; it emits and nothing else now.
	&"shield_blocked": &"shield_block",
	&"player_died": &"doom_stinger",
	&"target_acquired": &"target_cycle",
	&"run_started": &"dungeon_enter",
	# Both of these are the game saying "no". Sharing one sound is the point:
	# the player should learn a single refusal noise, not two.
	&"bag_full": &"craft_fail",
	&"extract_refused": &"craft_fail",
}

var _pool: Array[AudioStreamPlayer3D] = []
var _next := 0
var _cache: Dictionary = {}


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer3D.new()
		p.name = "Voice%d" % i
		p.bus = &"SFX"
		# The hero is 1.65 m and rooms are small; the default 1 m unit size makes
		# a chest across the room inaudible (docs/CONTRACT.md §1, 1 unit = 1 m).
		p.unit_size = 6.0
		p.max_distance = 40.0
		add_child(p)
		_pool.append(p)

	Bus.request_sfx.connect(play_at)

	# --- the table, bound to the signals it names ----------------------------
	Bus.chest_opened.connect(func(_id: StringName, _c: StringName) -> void:
		_cue(&"chest_opened"))
	Bus.door_opened.connect(func(_id: StringName) -> void: _cue(&"door_opened"))
	Bus.item_acquired.connect(func(_id: StringName) -> void:
		_cue(&"item_acquired"))
	Bus.loot_gained.connect(func(_id: StringName, _n: int) -> void:
		_cue(&"loot_gained"))
	Bus.items_sold.connect(func(_sold: Dictionary, _paid: int) -> void:
		_cue(&"items_sold"))
	Bus.puzzle_solved.connect(func(_id: StringName) -> void:
		_cue(&"puzzle_solved"))
	Bus.player_died.connect(func() -> void: _cue(&"player_died"))
	Bus.target_acquired.connect(func(_t: Node3D) -> void:
		_cue(&"target_acquired"))
	Bus.run_started.connect(func(_s: int) -> void: _cue(&"run_started"))
	Bus.bag_full.connect(func() -> void: _cue(&"bag_full"))
	Bus.extract_refused.connect(func(_cost: int, _gold: int) -> void:
		_cue(&"extract_refused"))
	# These two carry a real world position, so they play where they happened
	# rather than on top of the player.
	Bus.hit_landed.connect(func(_t: Node3D, _n: int, pos: Vector3) -> void:
		play_at(CUES[&"hit_landed"], pos))
	Bus.enemy_died.connect(func(_e: Node3D, pos: Vector3) -> void:
		play_at(CUES[&"enemy_died"], pos))
	# `at` is the contact point on the shield, not the hero's feet, so a blow
	# caught on the boss's side of the guard rings from there.
	Bus.shield_blocked.connect(func(at: Vector3, _n: Vector3) -> void:
		play_at(CUES[&"shield_blocked"], at))
	# Only the win is a sound. A run that ended badly already has doom_stinger.
	Bus.run_ended.connect(func(extracted: bool, _c: Dictionary, _v: int) -> void:
		if extracted:
			play_at(&"dungeon_complete", _hero_pos()))


## Play `id` at a world position. This is `Bus.request_sfx`'s implementation --
## emit that rather than calling this directly, so nothing has to hold a
## reference to this autoload.
func play_at(id: StringName, position: Vector3) -> void:
	var stream := _load(id)
	if stream == null:
		return
	var v := _claim()
	v.stream = stream
	v.global_position = position
	v.play()


## Play `id` wherever the hero is -- for events that are about the player rather
## than about a place.
func play(id: StringName) -> void:
	play_at(id, _hero_pos())


func _cue(signal_name: StringName) -> void:
	var id: StringName = CUES[signal_name]
	play_at(id, _hero_pos())


## Round-robin rather than "find a free one": with 12 voices the oldest is
## always the right one to steal, and scanning for silence makes a burst of
## simultaneous hits drop sounds instead of overlapping them.
func _claim() -> AudioStreamPlayer3D:
	var v := _pool[_next]
	_next = (_next + 1) % _pool.size()
	return v


## Resolve `id` to a stream, expanding `foo` to a random `foo_N` when that sound
## ships as numbered variants.
func _load(id: StringName) -> AudioStream:
	var name := String(id)
	# `>= 1`, not `> 1`: a lone `_1` variant still has to be expanded.
	var count: int = int(VARIANTS.get(id, 0))
	if count >= 1:
		name = "%s_%d" % [name, 1 + (randi() % count)]

	if _cache.has(name):
		return _cache[name]

	var path := "res://audio/sfx/%s.ogg" % name
	if not ResourceLoader.exists(path):
		push_warning("Sfx: no such sound %s" % path)
		_cache[name] = null
		return null
	var s := load(path) as AudioStream
	_cache[name] = s
	return s


func _hero_pos() -> Vector3:
	var hero := get_tree().get_first_node_in_group(&"player")
	return (hero as Node3D).global_position if hero is Node3D else Vector3.ZERO
