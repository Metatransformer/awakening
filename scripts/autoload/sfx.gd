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
## at it would put grass under the garrison's cobbles.

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
## real one. (`player_died` is voiced by `game_over` now; the row stays because
## it is still a true statement about what is on disk, and `sfx_moves` proves the
## expansion through it.)
## `attack_prepare` is the second sound to need this row for the second reason:
## it ships as `attack_prepare_1.ogg` with no sibling, so `Enemy`'s wind-up cue
## would have resolved to nothing, pushed one warning, cached the null and gone
## quiet for the rest of the run. A monster telegraph that is SILENTLY missing is
## the exact failure this table was written for.
const VARIANTS := {
	&"coin_trade": 3,
	&"coin_drop": 3,
	&"doom_stinger": 1,
	&"ui_move_selection": 1,
	&"attack_prepare": 1,
}

## The whole signal→sound table. Every entry is an event that already carries
## its own meaning; nothing here is a guess about what the designer wanted.
const CUES := {
	&"chest_opened": &"chest_open",
	&"door_opened": &"door_open",
	&"item_acquired": &"equip",
	&"loot_gained": &"pickup",
	&"items_sold": &"coin_trade",
	&"puzzle_solved": &"puzzle_complete",
	# The room is beaten. This is the beat a reward arrives ON, so it is
	# deliberately a short bright one rather than a fanfare -- the fanfare is the
	# chest landing a moment later (`reward_revealed` below), and two ceremonies
	# stacked on one frame read as a bug in the mix.
	&"room_cleared": &"arena_round_win",
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
	&"player_died": &"game_over",
	&"target_acquired": &"target_cycle",
	&"run_started": &"dungeon_enter",
	&"item_get_started": &"dungeon_complete",
	# The game saying "no". One refusal noise, shared by everything that refuses
	# -- `locked_door.gd` reaches for the same `craft_fail` by hand. There used to
	# be an `extract_refused` row beside this one; the rope cannot refuse any more
	# (the fee is capped at the purse), so the row went with the signal.
	&"bag_full": &"craft_fail",
}

## The arrival sounds, indexed by `RewardVfx` tier. A second table rather than two
## rows in `CUES`, because `CUES` is keyed on the SIGNAL and one signal cannot
## have two entries there -- `reward_revealed` carries the tier as an argument.
##
## The rule is the same one `CUES` keeps: **this is the only place either of
## these is chosen.** `RewardVfx` builds the flash and names no sound, so the two
## tiers can be re-voiced from here without touching a line of the effect.
##
## Both are placeholders picked from the 156 on disk and they are meant to be
## swapped. What they have to preserve is the CONTRAST -- tier 1 is a bright tick
## that says "there is something here", tier 2 is a held chord that says "that
## was the thing". `glint_bell` is what the puzzle chests have always used, so
## tier 1 is not a change to anything already shipped.
## Both tiers are the same take today, and that is on purpose rather than a gap
## waiting to be filled: `treasure_spawn` was authored for exactly this event --
## a chest falling out of nothing, landing, bouncing and glittering -- and there
## is one of it. The tiers already differ in the eye (a shaft of light, a second
## ring, twice the shake) and in how long they hold the screen, which is what
## "the level of the loot sets the level of the flash" asked for. When a bigger
## take exists, tier 2 is this line and nothing else moves.
const REWARD_CUES := {
	1: &"treasure_spawn",   ## MINOR -- a room's chest
	2: &"treasure_spawn",   ## MAJOR -- boss-grade
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
	Bus.perfect_dodge.connect(func(pos: Vector3) -> void:
		play_at(&"perfect_dodge", pos))

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
	Bus.room_cleared.connect(func(_id: StringName) -> void:
		_cue(&"room_cleared"))
	# At the chest and not at the hero, unlike everything above: a reward is a
	# place in the room. `Bus.reward_revealed` carries the position for this.
	Bus.reward_revealed.connect(func(tier: int, pos: Vector3) -> void:
		var id: StringName = REWARD_CUES.get(tier, REWARD_CUES[1])
		play_at(id, pos))
	Bus.player_died.connect(func() -> void: _cue(&"player_died"))
	Bus.target_acquired.connect(func(_t: Node3D) -> void:
		_cue(&"target_acquired"))
	Bus.run_started.connect(func(_s: int) -> void: _cue(&"run_started"))
	Bus.item_get_started.connect(func(_item_id: StringName, pos: Vector3) -> void:
		play_at(CUES[&"item_get_started"], pos))
	Bus.bag_full.connect(func() -> void: _cue(&"bag_full"))
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
	# Only the win is a sound. A run that ended badly already has `game_over`.
	#
	# The rope IS the way out (`scripts/items/escape_rope.gd` -- the extraction pad
	# is gone), so "the run ended and he extracted" and "the rope worked" are the
	# same instant, and `escape_rope` is what that instant sounds like. It replaces
	# `dungeon_complete`, which is a fanfare for arriving somewhere; the arriving
	# is the garrison, one scene change later, and it is not this signal.
	Bus.run_ended.connect(func(extracted: bool, _c: Dictionary, _v: int) -> void:
		if extracted:
			play_at(&"escape_rope", _hero_pos()))


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
		path = "res://audio/sfx/%s.wav" % name
	if not ResourceLoader.exists(path):
		push_warning("Sfx: no such sound res://audio/sfx/%s.[ogg|wav]" % name)
		_cache[name] = null
		return null
	var s := load(path) as AudioStream
	_cache[name] = s
	return s


func _hero_pos() -> Vector3:
	# `get_tree()` is NULL while the tree is shutting down, and an autoload outlives
	# the shutdown -- so a cue emitted by anything tearing itself down (a floor
	# being freed on the way to the next one, the game quitting) reached this line
	# and took the whole run out with `Cannot call method 'get_first_node_in_group'
	# on a null value`. Found by `room_reward`; the emitter that found it has been
	# fixed too (`RoomWatch._confirm`), but the crash was never that emitter's --
	# every one of the fourteen handlers above lands here.
	var tree := get_tree()
	if tree == null:
		return Vector3.ZERO
	var hero := tree.get_first_node_in_group(&"player")
	return (hero as Node3D).global_position if hero is Node3D else Vector3.ZERO
