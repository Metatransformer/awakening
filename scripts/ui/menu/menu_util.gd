class_name MenuUtil
extends RefCounted
## Stateless helpers shared by the pause menu's screens: focus chaining, input
## labelling, and value formatting.
##
## Nothing here writes to Settings or Saves — the screens do that. This exists so
## focus wiring is done ONE way everywhere, because a menu with a hole in its
## focus graph strands a pad user on nothing.

## Godot's JoyButton indices, named the way a player would read them on an
## Xbox-layout pad. project.godot binds by index, so this is the decode table.
const PAD_BUTTONS := {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_GUIDE: "Guide",
	JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L-Stick",
	JOY_BUTTON_RIGHT_STICK: "R-Stick",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-Up",
	JOY_BUTTON_DPAD_DOWN: "D-Down",
	JOY_BUTTON_DPAD_LEFT: "D-Left",
	JOY_BUTTON_DPAD_RIGHT: "D-Right",
}

const PAD_AXES := {
	JOY_AXIS_LEFT_X: ["Stick L", "Stick R"],
	JOY_AXIS_LEFT_Y: ["Stick Up", "Stick Down"],
	JOY_AXIS_RIGHT_X: ["R-Stick L", "R-Stick R"],
	JOY_AXIS_RIGHT_Y: ["R-Stick Up", "R-Stick Down"],
	JOY_AXIS_TRIGGER_LEFT: ["LT", "LT"],
	JOY_AXIS_TRIGGER_RIGHT: ["RT", "RT"],
}

## Player-facing names for the actions Settings offers to rebind.
const ACTION_NAMES := {
	&"move_up": "Move Forward",
	&"move_down": "Move Back",
	&"move_left": "Move Left",
	&"move_right": "Move Right",
	# Lock-on is a TOGGLE on the right stick, not a held shoulder — a stick you
	# have to keep clicked in is not a control. The three item buttons are the
	# C-pad: whatever the player bound to them, bound in the Items screen.
	&"z_target": "Lock On (toggle)",
	&"attack": "Attack",
	&"heavy_attack": "Heavy Attack",
	&"shield": "Guard (hold)",
	&"context": "Roll / Backstep",
	&"interact": "Interact",
	&"item_left": "Item ←",
	&"item_up": "Item ↑",
	&"item_right": "Item →",
	&"item_down": "Swap Loadout",
	&"first_person": "First Person",
	&"pause": "Pause",
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
## mouse, so the pad column is decoded here, read-only, from the live InputMap.
static func pad_label(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "—"
	for e in InputMap.action_get_events(action):
		var text := event_label(e)
		if e is InputEventJoypadButton or e is InputEventJoypadMotion:
			return text
	return "—"


## Human label for any single event — used for the conflict message, which has
## to name the key the player just pressed.
static func event_label(e: InputEvent) -> String:
	if e is InputEventKey:
		var k := e as InputEventKey
		var code := k.physical_keycode if k.physical_keycode != 0 else k.keycode
		return OS.get_keycode_string(code)
	if e is InputEventMouseButton:
		match (e as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "Mouse L"
			MOUSE_BUTTON_RIGHT: return "Mouse R"
			MOUSE_BUTTON_MIDDLE: return "Mouse M"
			_: return "Mouse %d" % (e as InputEventMouseButton).button_index
	if e is InputEventJoypadButton:
		var b := (e as InputEventJoypadButton).button_index
		return PAD_BUTTONS.get(b, "Pad %d" % b)
	if e is InputEventJoypadMotion:
		var m := e as InputEventJoypadMotion
		var pair: Array = PAD_AXES.get(m.axis, [])
		if pair.is_empty():
			return "Axis %d" % m.axis
		return pair[0] if m.axis_value < 0.0 else pair[1]
	return "—"


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
