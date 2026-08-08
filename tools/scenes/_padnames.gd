extends Node
## Prints the SEMANTIC name Godot gives every pad button index, and then the
## index each action is actually bound to AT RUNTIME.
##
## Both halves exist because both halves have lied here before.
##
##   * The index table: `project.godot` was once written in SDL/Xbox raw
##     numbering (attack=5, lock-on=9) on the belief that 5 was RB and 9 was R3.
##     In Godot's JoyButton enum 5 is the GUIDE button and 9 is LB, so the pad
##     had no attack button at all. Reading the enum out of the engine is the
##     only way to be sure which number a thumb reaches.
##   * The runtime bindings: `Settings` replays user://settings.cfg over the
##     InputMap at boot, so what the file says and what the player gets are
##     different questions. A stale rebind from a menu test had `attack` on the
##     N key with the mouse binding erased, twice.
##
##   godot --path . --headless res://tools/scenes/_padnames.tscn

## The highest index worth printing. JoyButton runs to MISC6 (25) in 4.7; the
## face/shoulder/stick/dpad buttons every layout decision turns on are under 16.
const MAX_BUTTON := 16


func _ready() -> void:
	print("--- JoyButton index -> name (from the engine) ---")
	for i in MAX_BUTTON:
		var e := InputEventJoypadButton.new()
		e.button_index = i as JoyButton
		print("  %2d  %s" % [i, e.as_text()])

	print("")
	print("--- action -> what is bound RIGHT NOW ---")
	for action in InputMap.get_actions():
		if String(action).begins_with("ui_"):
			continue
		var parts: Array[String] = []
		for e in InputMap.action_get_events(action):
			if e is InputEventJoypadButton:
				parts.append("pad%d" % (e as InputEventJoypadButton).button_index)
			elif e is InputEventJoypadMotion:
				var m := e as InputEventJoypadMotion
				parts.append("axis%d%s" % [m.axis, "+" if m.axis_value > 0.0 else "-"])
			elif e is InputEventKey:
				parts.append(OS.get_keycode_string((e as InputEventKey).physical_keycode))
			elif e is InputEventMouseButton:
				parts.append("Mouse%d" % (e as InputEventMouseButton).button_index)
		print("  %-14s %s" % [action, ", ".join(parts)])

	get_tree().quit(0)
