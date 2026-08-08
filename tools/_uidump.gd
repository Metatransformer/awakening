extends Node
## Does ui_accept / ui_cancel actually carry a joypad event in THIS project?
##
## The pause-menu critic claims they carry zero, which would make the menu
## keyboard-only for a pad player. Settle it by asking the live InputMap rather
## than by reading project.godot, which is silent about engine defaults: an
## action absent from that file is still supplied by the engine.
##
## Prints raw values, not OS.get_keycode_string() -- that returns "" for Enter,
## Space and the arrows in this build while working fine for Escape, which is
## exactly the kind of half-working readout that invents a bug.
func _ready() -> void:
	await get_tree().process_frame
	for a in [&"ui_accept", &"ui_cancel", &"ui_up", &"ui_down", &"ui_left", &"ui_right"]:
		var events := InputMap.action_get_events(a)
		var parts: Array[String] = []
		for e in events:
			if e is InputEventKey:
				parts.append("key(%d)" % (e as InputEventKey).physical_keycode)
			elif e is InputEventJoypadButton:
				parts.append("PAD(%d)" % (e as InputEventJoypadButton).button_index)
			elif e is InputEventJoypadMotion:
				parts.append("axis(%d,%+.0f)" % [
					(e as InputEventJoypadMotion).axis,
					(e as InputEventJoypadMotion).axis_value,
				])
			else:
				parts.append(e.get_class())
		var pads := parts.filter(func(s: String) -> bool: return s.begins_with("PAD") or s.begins_with("axis"))
		print("%-12s %d events  %-46s  pad=%s" % [
			a, events.size(), ", ".join(parts),
			"YES" if pads.size() > 0 else "NO",
		])
	get_tree().quit(0)
