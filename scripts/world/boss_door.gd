class_name BossDoor
extends LockedDoor
## The way down, and the thing standing in front of it.
##
## `docs/GDD.md` §5.1: **the boss door replaces the stair.** It sits on the far
## wall of the deepest room, where `scripts/world/stairs.gd` sits today, and
## behind it is floor N+1. So the floor's deepest room is still where the best
## chest and the commitment are, and the walk to it is still the longest one.
##
## **A killed boss stays dead.** One world flag, `boss_dead_<id>`, and it is the
## ONLY state either half of the fight keeps: this door reads it to decide
## whether it is sealed, and `BossArena` reads it (through this node) to decide
## whether to build a boss at all. A re-entered floor therefore has an open door
## and an empty arena from one fact, rather than from two that can disagree.
##
## **It is a `LockedDoor` with a different gate, and nothing else.** The leaves,
## the strapwork, the bars, the sigil, the swing, the restore-from-flag pose and
## the "an open door stays open" rule are all inherited unchanged -- what this
## subclass replaces is `unlocked()`, which asks a boss instead of an inventory,
## and the two lines of text that go with it. That is the whole file, and if it
## ever needs more than that the base class was the wrong parent.
##
## Two things it deliberately does NOT do:
##
##  * **It never calls `Flow`.** The base class's header is emphatic about this
##    and a stair-replacement is exactly where the temptation lives. The door
##    hands `destination` back on `opened` and the placer decides what that
##    means (`CLAUDE.md` §6 -- `Flow` is the only thing that changes scenes).
##  * **It never watches the boss.** `BossArena` owns the fight and calls
##    `unseal()` when it ends. A door that connected to `Bus.boss_defeated`
##    itself would open for a boss on some other floor the moment the signal
##    fired, and would be a second thing deciding when the fight is over.
##
## ## Why the refusal is overridden the way it is
##
## `LockedDoor.refusal_for()` is a STATIC, and overriding a static would do
## nothing: a bare static call written inside the base class binds to the base's
## copy at parse time and the subclass's version is never reached (`CLAUDE.md`
## §3 -- the smith's counter shipped a wrong string for a build because of this).
## So the two INSTANCE methods that produce the line are what get replaced here,
## and `on_focus` is left alone because it goes through `_say_refusal` as a
## Callable, which does dispatch.

## Which boss holds this door. A key into `BossDb.BOSSES`.
@export var boss_id: StringName = &"cistern_warden"


## The one flag. Public and static so `BossArena` can ask what it is called
## without having a door in hand, and so a director can set it to prove the
## re-entry case.
static func dead_flag(id: StringName) -> StringName:
	return StringName("boss_dead_%s" % id)


func _ready() -> void:
	# No item opens this, so no item id: `sigil_of(&"")` falls through to
	# `SIGIL_DEFAULT`, a plain keyhole in the game's off-white. That is the right
	# mark as well as the free one -- the bow's MOSS and the hookshot's CYAN each
	# mean "you need a thing", and this door does not want a thing.
	key_item = &""
	if label.strip_edges().is_empty():
		label = "The Way Down"
	if destination == &"":
		destination = StringName("descend_%s" % boss_id)
	super()
	# A boss killed on an earlier run leaves its door hanging open (GDD §5.1),
	# whether or not anybody walked through it that time. `LockedDoor._ready` has
	# already posed it open if `flag_id()` was set -- and `flag_id()` IS the kill
	# flag here -- so this is only a belt for the case where the base class's
	# check and this one drift apart. It costs a branch and it is the difference
	# between "the fight is over" and "the fight is over AND you opened the door",
	# which is a distinction no player should ever be asked to care about.
	if Game.flag(flag_id()) and not is_open():
		_pose_open()


# --- The gate -----------------------------------------------------------------

## Not `Game.has(key_item)`. This door is opened by a corpse.
func unlocked() -> bool:
	return Game.flag(flag_id())


## The kill flag, reused as the door's own one-way flag. Deliberately ONE flag
## and not two: `LockedDoor._swing` writes `flag_id()` and `LockedDoor._ready`
## reads it, so making them the same fact as "the boss is dead" is what makes a
## re-entered floor consistent for free.
## Called BARE and not as `BossDoor.dead_flag(...)`. Both would be correct here
## -- the trap in `CLAUDE.md` §3 is a bare static call written inside a BASE
## class, which binds to the base's copy and never reaches an override, and
## `dead_flag` is declared in this file with nothing below it. The bare form is
## the one that also survives a cold global class cache, which is the state this
## file is in on the run that first loads it.
func flag_id() -> StringName:
	return dead_flag(boss_id)


## The fight is over. Called by `BossArena` on the boss's death -- and it sets
## the flag BEFORE swinging, so a player who walks away without going through
## still comes back to an open door.
func unseal() -> void:
	Game.set_flag(flag_id())
	_refresh_prompt()
	if is_open():
		return
	_swing()


# --- What it says -------------------------------------------------------------

## Names the thing, exactly as the base class names the item. GDD pillar 3: a
## refusal that says "LOCKED" tells the player only that they wasted a walk;
## "THE CISTERN WARDEN STILL LIVES" tells them what the door is for, that there
## is something to kill, and where they are going next.
func _seal_line() -> String:
	var row := BossDb.get_boss(boss_id)
	if row.is_empty():
		return "SEALED"
	return "%s STILL LIVES" % String(row["title"])


func _refresh_prompt() -> void:
	prompt = "DESCEND" if unlocked() else _seal_line()


func _say_refusal() -> void:
	if Prompt.focus != self or is_open() or unlocked():
		return
	Bus.prompt_changed.emit(_seal_line())
