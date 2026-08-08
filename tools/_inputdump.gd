extends Node
## Prints every action and the keyboard/mouse binding actually registered at
## runtime, so "the control does nothing" can be split into "the binding is
## wrong" and "nothing is listening".
func _ready() -> void:
	await get_tree().process_frame
	for a in InputMap.get_actions():
		if String(a).begins_with("ui_"):
			continue
		var parts: Array[String] = []
		for e in InputMap.action_get_events(a):
			if e is InputEventKey:
				parts.append(OS.get_keycode_string((e as InputEventKey).physical_keycode))
			elif e is InputEventMouseButton:
				parts.append("Mouse%d" % (e as InputEventMouseButton).button_index)
			elif e is InputEventJoypadButton:
				parts.append("Pad%d" % (e as InputEventJoypadButton).button_index)
			elif e is InputEventJoypadMotion:
				parts.append("Axis%d" % (e as InputEventJoypadMotion).axis)
		print("%-14s %s" % [a, ", ".join(parts)])
	get_tree().quit(0)
