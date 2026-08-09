class_name Glyph
extends RefCounted
## What to print on screen for a button. One table, read by everything.
##
## There are three surfaces that name inputs to the player — the HUD's key caps
## and its town legend, the `(E) OPEN` prompt, and the options screen's bind list
## — and before this file they each decoded the InputMap themselves. Two of them
## only understood keyboards, which is how a pad player ended up looking at a
## HUD that said `LMB` while holding a controller.
##
## Everything here reads the **live InputMap**, never a remembered layout:
## `user://settings.cfg` is replayed over the map at boot and wins, so the
## shipped binding and the player's binding are different questions
## (docs/CONTRACT.md §4).
##
## Two lengths, because two places have different room:
##
##   * `long()` — "R-Stick", "D-Up", "LT". The options list, which has a column.
##   * `cap()` — four characters at most, drawn in PixelFont: "R3", "↑", "LT".
##     The HUD's key caps hang under 40 px cells and there is no room to be
##     polite about it.

## Godot's JoyButton indices, named the way a player would read them on an
## Xbox-layout pad. project.godot binds by index, so this is the decode table.
##
## NOTE: this is the JoyButton enum, NOT the SDL/Xbox raw numbering people quote
## from memory — 9 is LB and 8 is R3. See the long note in project.godot; a pass
## that renumbered the pad from memory left the game with no attack button.
const PAD_BUTTONS := {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Select",
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

## The four-character forms. The D-pad becomes arrows because the HUD draws the
## item buttons in the SHAPE of the D-pad — "D-Up" under a cell that is already
## the top of a cross is the label saying twice what the arrangement said once.
const PAD_CAPS := {
	JOY_BUTTON_BACK: "SEL",
	JOY_BUTTON_START: "STRT",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_DPAD_UP: "↑",
	JOY_BUTTON_DPAD_DOWN: "↓",
	JOY_BUTTON_DPAD_LEFT: "←",
	JOY_BUTTON_DPAD_RIGHT: "→",
}

const AXIS_CAPS := {
	JOY_AXIS_LEFT_X: "LS", JOY_AXIS_LEFT_Y: "LS",
	JOY_AXIS_RIGHT_X: "RS", JOY_AXIS_RIGHT_Y: "RS",
	JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT",
}


# --- The whole-action questions ---------------------------------------------

## The cap for `action` on the device the player is holding RIGHT NOW, or "" if
## that device has nothing bound to it. This is the one every in-world surface
## should call: `Settings.using_pad` is the only thing that decides, and it is
## decided in one place (see `Settings._input`).
static func cap(action: StringName) -> String:
	var e := event_for(action, Settings != null and Settings.using_pad)
	return cap_for(e) if e != null else ""


## The first event on `action` belonging to the pad (or to the keyboard and
## mouse). Returns null when that device has nothing on this action — which is a
## real answer, not a failure: `first_person` has no pad binding at all.
static func event_for(action: StringName, want_pad: bool) -> InputEvent:
	if action == &"" or not InputMap.has_action(action):
		return null
	for e in InputMap.action_get_events(action):
		if is_pad(e) == want_pad:
			return e
	return null


static func is_pad(e: InputEvent) -> bool:
	return e is InputEventJoypadButton or e is InputEventJoypadMotion


# --- Single events ----------------------------------------------------------

## Human label for any single event — used for the rebind conflict message,
## which has to name the key the player just pressed.
static func long(e: InputEvent) -> String:
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


## Four characters at most, upper case, for the HUD.
static func cap_for(e: InputEvent) -> String:
	if e is InputEventMouseButton:
		match (e as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "LMB"
			MOUSE_BUTTON_RIGHT: return "RMB"
			MOUSE_BUTTON_MIDDLE: return "MMB"
		return ""
	if e is InputEventKey:
		var k := e as InputEventKey
		# physical_keycode first: a binding stored physically prints nothing
		# through `keycode`, and a blank cap is worse than no cap at all.
		var code := k.physical_keycode if k.physical_keycode != 0 else k.keycode
		if code == 0:
			return ""
		var name := OS.get_keycode_string(code)
		match name:
			"Space": return "SPC"
			"Escape": return "ESC"
		return name if name.length() <= 4 else name.substr(0, 4)
	if e is InputEventJoypadButton:
		var b := (e as InputEventJoypadButton).button_index
		return PAD_CAPS.get(b, PAD_BUTTONS.get(b, "P%d" % b))
	if e is InputEventJoypadMotion:
		return AXIS_CAPS.get((e as InputEventJoypadMotion).axis, "AXIS")
	return ""
