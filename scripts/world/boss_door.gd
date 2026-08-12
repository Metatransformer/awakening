class_name BossDoor
extends LockedDoor
## The oversized gold-marked threshold into a floor boss's chamber. The Boss
## Key opens this door; killing the boss is a separate fact used by the arena and
## the rewards beyond it. Leaves, bars, collision, persistence and motion remain
## LockedDoor's single authored implementation.

const BOSS_OPENING_W := 5.4
const BOSS_OPENING_H := 4.6

@export var boss_id: StringName = &"cistern_warden"


## Public name for the arena's persistent kill state. This is deliberately not
## `flag_id()`: opening the chamber and defeating its occupant are two events.
static func dead_flag(id: StringName) -> StringName:
	return StringName("boss_dead_%s" % id)


func _ready() -> void:
	# Before LockedDoor builds: the row chooses the carved mark and these numbers
	# size both the inherited leaves and blocker.
	key_item = &"boss_key"
	opening_w = BOSS_OPENING_W
	opening_h = BOSS_OPENING_H
	if label.strip_edges().is_empty():
		label = "Boss Chamber"
	if destination == &"":
		destination = StringName("boss_chamber_f%d_%s" % [Run.level, boss_id])
	# Saves from the old boss-door contract carry only `boss_dead_<id>`. Promote
	# that completed state to the new independent door flag before the base class
	# restores its pose; a defeated chamber must never become sealed on upgrade.
	if Game.flag(dead_flag(boss_id)):
		Game.set_flag(flag_id())
	super()


func unlocked() -> bool:
	return Game.has_boss_key_for(Run.level)


func refusal_line() -> String:
	return "NEEDS THE BOSS KEY"


func _refresh_prompt() -> void:
	prompt = "OPEN THE BOSS DOOR" if unlocked() else refusal_line()


func _on_item_acquired(id: StringName) -> void:
	if id != key_item or is_open():
		return
	_refresh_prompt()
	_tint_sigil(1.0)
	if Prompt.focus == self:
		Bus.prompt_changed.emit("%s TO OPEN THE BOSS DOOR" % Glyph.cap(&"interact"))


func activate(by: Node3D) -> void:
	if is_open():
		return
	if not unlocked() or not Game.spend_boss_key():
		_refuse()
		return
	# Do not route back through LockedDoor.activate(): the ownership check would
	# correctly turn false after the spend. The spend and swing are one guarded
	# event, and `_open` latches before another activation can enter.
	activated.emit(by)
	_swing()
