class_name RoomWatch
extends Node
## Knows which bodies a room was built with, and says when the last one is gone.
##
##     var watch := RoomWatch.attach(room_root, &"Room_2_-1")
##     for foe in foes:
##         watch.add(foe)
##     watch.cleared.connect(...)
##
## `Bus.room_cleared` has been declared in `event_bus.gd` since the bus was
## written and had **no emitter** -- so nothing in the game could react to a room
## being beaten, which is why a chest stood next to its guards from the moment
## the floor was generated. This is that emitter.
##
## **Counted, not scanned.** The alternative is a `_process` that asks the room
## for its live enemies every frame, and it is wrong twice: an enemy that chases
## the hero into the corridor stops being in the room without having been beaten,
## and the frame the last body's node is finally freed is ~3 s after it died
## (`Enemy._die` lets the death animation read, then sinks the corpse). The player
## beat the room on the killing blow; that is when the room is clear.
##
## **Three ways a body leaves and all of them count.**
##
##   `died_at`        the killing blow. The one that matters.
##   `escaped_with`   the Thief got away with the loot (`docs/BESTIARY.md` §3).
##                    Not a victory, and it still empties the room -- a reward
##                    that never landed because something ran off would be a
##                    room the player cannot finish and cannot see why.
##   `tree_exited`    the backstop, for a body removed by anything that is not
##                    either of the above. Without it a single unforeseen
##                    `queue_free` strands the room's chest for the whole run.
##
## Idempotent per body and fires `cleared` exactly once: all three can arrive for
## the same enemy (it dies, then its corpse leaves the tree three seconds later),
## and a room whose last two foes die in one frame must not clear twice.

## The last body is gone. Emitted with `Bus.room_cleared` on the same frame; this
## local one exists so a placer can hang a specific reward on a specific room
## without filtering a global signal by an id it has to keep in step.
signal cleared

## The room id put on the bus. `Dungeon` uses the room root's node name, which is
## what `Bus.room_entered` already carries -- the two signals must name a room
## the same way or a listener cannot pair them.
var room_id: StringName = &""

## Instance ids of the bodies still standing. Ids and not references, because a
## freed node cannot be compared and `is_instance_valid` on a whole array every
## time one dies is the scan this class exists to avoid.
var _live: Dictionary = {}
var _done: bool = false


## Build one and park it under `root`. A child of the room so it dies with the
## floor -- a watcher outliving its room would fire into a torn-down scene.
static func attach(root: Node, id: StringName) -> RoomWatch:
	var w := RoomWatch.new()
	w.name = &"RoomWatch"
	w.room_id = id
	root.add_child(w)
	return w


## Start watching one body. Safe to call with anything; a node that has none of
## the three signals is simply never counted, which is better than a watcher that
## can never clear.
func add(foe: Node) -> void:
	if foe == null or not is_instance_valid(foe):
		return
	var key := foe.get_instance_id()
	if _live.has(key):
		return
	_live[key] = true

	if foe.has_signal(&"died_at"):
		foe.connect(&"died_at", func(_where: Vector3) -> void: _gone(key))
	if foe.has_signal(&"escaped_with"):
		foe.connect(&"escaped_with",
			func(_loot: Dictionary, _where: Vector3) -> void: _gone(key))
	foe.tree_exited.connect(func() -> void: _gone(key))


## How many are left. For a director, and for a caller that wants to know whether
## there was ever anything to beat.
func live_count() -> int:
	return _live.size()


func is_clear() -> bool:
	return _done


func _gone(key: int) -> void:
	if _done or not _live.has(key):
		return
	_live.erase(key)
	if not _live.is_empty():
		return
	# **Confirmed a frame later, and that deferral is the whole defence against a
	# floor teardown.**
	#
	# Taking the stair down, dying, extracting or loading frees the `Dungeon`, and
	# every body in every unbeaten room on it emits `tree_exited` on the way out.
	# That empties `_live` for every watcher at once -- so without this, walking
	# down one flight fired `room_cleared` for six rooms the player never beat, and
	# every held chest on the dying floor tried to land into a tree that was
	# already gone. Measured, from `room_reward`'s first run: three SCRIPT ERRORs
	# out of `Sfx._hero_pos` and a `RewardVfx: no live parent` for each chest.
	#
	# A deferred call to a freed object is dropped by the engine, and a watcher on
	# a torn-down floor IS freed before the flush reaches it -- so the confirmation
	# simply never happens, which is the correct answer. A watcher whose room is
	# still standing is still there a frame later, and clears.
	_confirm.call_deferred()


func _confirm() -> void:
	if _done or not _live.is_empty():
		return
	# Belt as well as braces: `is_inside_tree()` is false for a watcher that was
	# removed rather than freed, and `get_tree()` is null while the tree itself is
	# shutting down. Neither is a room the player beat.
	if not is_inside_tree() or get_tree() == null:
		return
	_done = true
	cleared.emit()
	Bus.room_cleared.emit(room_id)
