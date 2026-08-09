class_name MenuUtil
extends RefCounted
## Stateless helpers shared by the pause menu's screens: focus chaining, input
## labelling, and value formatting.
##
## Nothing here writes to Settings or Saves — the screens do that. This exists so
## focus wiring is done ONE way everywhere, because a menu with a hole in its
## focus graph strands a pad user on nothing.

## The pad decode tables used to live here, and a second copy of them lived in
## the HUD. Both are `Glyph` now (scripts/core/input_glyphs.gd) — the HUD needed
## the same answers this screen gives and the two had already drifted, which is
## how the HUD came to print `LMB` at a player holding a controller.

## Player-facing names for the actions Settings offers to rebind.
const ACTION_NAMES := {
	&"move_up": "Move Forward",
	&"move_down": "Move Back",
	&"move_left": "Move Left",
	&"move_right": "Move Right",
	# Lock-on is a TOGGLE, and on the pad it is the left trigger (OOT's Z) with
	# R3 kept as the thumb's shortcut. Pressed with nothing lockable it puts the
	# camera back behind you, which is the half of this button players actually
	# reach for.
	&"z_target": "Lock On / Recentre",
	# The sword is the two right shoulder buttons: the fast chain on one, the
	# heavy on the other. The heavy row has to name the hold and the item, because
	# the trigger is the same button for both and nothing on screen says so.
	&"attack": "Sword — fast",
	&"heavy": "Sword — heavy (hold to spin) / Use Item",
	&"shield": "Guard / Lock On (hold)",
	&"context": "Dodge / Sprint (hold)",
	&"interact": "Interact / Talk",
	&"use_item": "Use Item",
	&"jump": "Jump",
	# The three cycles. Named as cycles, because "Weapon ←" would read as a slot
	# and the whole point of the change that made these is that there are no
	# slots -- see the D-pad note in project.godot.
	&"weapon_prev": "Previous Weapon",
	&"weapon_next": "Next Weapon",
	&"item_next": "Next Item",
	&"loadout_swap": "Swap Loadout",
	&"first_person": "First Person",
	&"pause": "Pause",
	&"inventory": "Pouch",
	&"map": "Map",
}


# --- Focus ------------------------------------------------------------------

## Wire a column of controls into a closed vertical loop. `lock_horizontal`
## pins left/right to the control itself so a stray stick nudge cannot fling
## focus into another column.
static func chain(column: Array, lock_horizontal: bool = true) -> void:
	var n := column.size()
	if n == 0:
		return
	for i in n:
		var c: Control = column[i]
		if c == null:
			continue
		var up: Control = column[(i - 1 + n) % n]
		var down: Control = column[(i + 1) % n]
		c.focus_neighbor_top = c.get_path_to(up)
		c.focus_neighbor_bottom = c.get_path_to(down)
		c.focus_previous = c.get_path_to(up)
		c.focus_next = c.get_path_to(down)
		if lock_horizontal:
			c.focus_neighbor_left = ^"."
			c.focus_neighbor_right = ^"."


## Wire a row of controls left/right into a closed loop (the options tab bar).
static func chain_row(row: Array) -> void:
	var n := row.size()
	if n == 0:
		return
	for i in n:
		var c: Control = row[i]
		var left: Control = row[(i - 1 + n) % n]
		var right: Control = row[(i + 1) % n]
		c.focus_neighbor_left = c.get_path_to(left)
		c.focus_neighbor_right = c.get_path_to(right)


static func link_down(from: Control, to: Control) -> void:
	if from == null or to == null:
		return
	from.focus_neighbor_bottom = from.get_path_to(to)
	from.focus_next = from.get_path_to(to)
	to.focus_neighbor_top = to.get_path_to(from)
	to.focus_previous = to.get_path_to(from)


static func link_right(from: Control, to: Control) -> void:
	if from == null or to == null:
		return
	from.focus_neighbor_right = from.get_path_to(to)
	to.focus_neighbor_left = to.get_path_to(from)


## First control in `list` that can actually take focus. Disabled buttons are
## skipped — that is how "you cannot load an empty slot" stays true for a pad.
static func first_focusable(list: Array) -> Control:
	for c in list:
		var ctrl := c as Control
		if ctrl == null or not ctrl.is_visible_in_tree():
			continue
		if ctrl is BaseButton and (ctrl as BaseButton).disabled:
			continue
		if ctrl.focus_mode != Control.FOCUS_NONE:
			return ctrl
	return null


# --- Input labels -----------------------------------------------------------

static func action_title(action: StringName) -> String:
	return ACTION_NAMES.get(action, String(action).capitalize())


## Keyboard/mouse label. Settings owns this so the list always agrees with the
## InputMap it actually wrote.
static func key_label(action: StringName) -> String:
	return Settings.label_for(action)


## Gamepad label for an action. Settings.label_for() only reports keyboard and
## mouse, so the pad column is decoded read-only from the live InputMap.
static func pad_label(action: StringName) -> String:
	var e := Glyph.event_for(action, true)
	return Glyph.long(e) if e != null else "—"


## Human label for any single event — used for the conflict message, which has
## to name the key the player just pressed.
static func event_label(e: InputEvent) -> String:
	return Glyph.long(e)


## Which rebindable action already owns `event`, or &"" if none does.
## Settings.rebind() returns a bare false on a clash; this is how the UI turns
## that false into a sentence the player can act on.
static func conflicting_action(event: InputEvent, ignoring: StringName) -> StringName:
	for other in Settings.rebindable_actions():
		if other == ignoring:
			continue
		for e in InputMap.action_get_events(other):
			if e.is_match(event, true):
				return other
	return &""


# --- Formatting -------------------------------------------------------------

static func percent(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)


static func multiplier(v: float) -> String:
	return "%.2fx" % v


static func signed_degrees(v: float) -> String:
	return "%+d°" % roundi(v)


## "3 / 3" hearts, quarter-heart aware, the way the HUD counts them.
static func hearts_text(cur: float, maximum: float) -> String:
	return "%s / %s" % [_trim(cur), _trim(maximum)]


static func _trim(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return "%d" % roundi(v)
	return String.num(v, 2).rstrip("0").rstrip(".")
