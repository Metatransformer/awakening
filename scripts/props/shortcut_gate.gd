class_name ShortcutGate
extends PuzzleGate
## The shortcut door, once it stopped being a check (`docs/PUZZLES.md` §5.1).
##
## `docs/PUZZLES.md` exists because **a door that opens because you own item X is
## a check, not a puzzle**, and the shortcut was the last of §5's three shapes
## still wearing one: a bare `LockedDoor` keyed on `FloorDb.shortcut_key`. This
## class is the door after the atoms went in front of it, and it is a
## `PuzzleGate` in every respect but one.
##
## ## The one respect: the flag is PERMANENT again
##
## `PuzzleGate.flag_id()` writes `atom_door_*`, which `PuzzleAtom.clear_run_flags()`
## wipes on `Run.enter()`. That is exactly right for the gate room -- §5.2's
## promise is that the gate room is a puzzle *every* run -- and it is exactly
## wrong here. §5.1's promise is the opposite one, and `run_state.gd` states it in
## so many words beside the call that does the wiping: *"those are permanent on
## purpose -- a shortcut you opened stays open across saves"*. GDD §5.3's
## *"on your fifth run you are at the Choir in ninety seconds"* is that sentence
## and nothing else. A shortcut re-locked by run two is not a shortcut; it is a
## puzzle you have to re-solve four times.
##
## So the flag goes back to `LockedDoor`'s `door_open_<destination>` -- restated
## rather than inherited, because GDScript's `super` reaches exactly one level and
## `PuzzleGate` is in between. The **atoms** in front of it still reset every run,
## which costs nothing: `PuzzleGate.watch()` refuses to adopt anything once the
## door is open, so a re-entered floor comes up with a lit eye standing beside a
## door that was never going to shut again.
##
## ## And one line that would otherwise lie
##
## `LockedDoor` connects `Bus.item_acquired` so a door can stop refusing the
## instant the boss drops the thing it wants -- correct for a check, and a lie for
## a puzzle. Floor 1's shortcut is marked with the bow, so killing the Warden
## while standing at it would have made it say `X TO OPEN` over an eye nobody has
## shot yet. That is GDD pillar 3's failure with the sign flipped: not a refusal
## that says nothing, but a promise the door cannot keep.

## The tag `LockedDoor` keys its permanent flag on. Restated here for the reason
## the class note gives; it is the one string in this file that has a twin, and
## the twin is `LockedDoor.flag_id`.
const PERMANENT := "door_open_%s"


## `LockedDoor`'s flag, not `PuzzleGate`'s. See the class note.
func flag_id() -> StringName:
	var tag := String(destination) if destination != &"" else String(name)
	return StringName(PERMANENT % tag)


## **A shortcut never goes back**, whatever its atoms are made of.
##
## `PuzzleGate.reversible()` reads the set: one non-latching atom and the door
## shuts again and stops persisting (card #116, and it is right for a plate).
## §5.1's promise is the exact opposite -- *"on your fifth run you are at the
## Choir in ninety seconds"* -- so this is the third respect in which this class
## differs from its parent, and it belongs beside the other two.
##
## It cannot fire today: `Dungeon._shortcut_pool` takes only atoms of tier
## **exactly N** for N >= 1, and both non-latching rows in the table (the plate
## and the lantern) are T0. That is a coincidence of two files agreeing, not a
## rule -- one T1 toggle added to `PuzzleAtoms.ATOMS` and the shortcut on floor 1
## starts closing behind the player, with the flag it wrote going with it. Stated
## here so the rule is in the file that owns the promise rather than in the pool
## that currently happens to keep it.
func reversible() -> bool:
	return false


## The mark warms, the sentence does not.
##
## Overrides `LockedDoor._on_item_acquired`, which announces `TO OPEN` on the
## frame the key item lands. Here the key item is only the **mark** -- §5.1's
## verb, off `PuzzleAtoms.TIER_ITEM` -- and owning the verb is not having
## performed it. `_refresh_prompt` re-reads `unlocked()`, which is the atoms, so
## the line the player gets is still the atom's own refusal.
func _on_item_acquired(id: StringName) -> void:
	if id != key_item or is_open():
		return
	_refresh_prompt()
	if Prompt.focus == self:
		Bus.prompt_changed.emit(prompt)
