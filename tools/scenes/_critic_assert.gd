extends Node

func _ready() -> void:
	var idx := AudioServer.get_bus_index(&"Music")
	# 1. slider-to-zero must MUTE, not sit at -60 dB.
	Settings.set_volume(&"Music", 0.0)
	print("MUTE_AT_ZERO %s (db=%.1f)" % [AudioServer.is_bus_mute(idx),
		AudioServer.get_bus_volume_db(idx)])
	# 2. a mid value must reach the real bus.
	Settings.set_volume(&"Music", 0.25)
	print("BUS_FOLLOWS mute=%s db=%.2f expected=%.2f"
		% [AudioServer.is_bus_mute(idx), AudioServer.get_bus_volume_db(idx),
		   linear_to_db(0.25)])
	# 3. it persisted to disk.
	var cfg := ConfigFile.new()
	print("PERSIST load=%d value=%s path=%s"
		% [cfg.load(Settings.path), cfg.get_value("audio", "music", "MISSING"),
		   ProjectSettings.globalize_path(Settings.path)])
	# 4. loading an empty slot returns nothing.
	Saves.erase(2)
	print("EMPTY_SLOT_LOAD peek_empty=%s load_slot_returns=%s"
		% [Saves.peek(2).get("empty", null), Saves.load_slot(2)])
	get_tree().quit()
