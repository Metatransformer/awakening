extends RefCounted
## Rendered proof for the compact map/compass/day column in all real layouts.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --boot-here \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/hud_instruments.gd \
##     --out=/tmp/instruments/garrison.png --size=1280x720 --warmup=60
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --boot-here \
##     --scene=res://scenes/rooms/garrison_outskirts.tscn \
##     --director=res://tools/directors/hud_instruments.gd \
##     --out=/tmp/instruments/outskirts.png --size=1280x720 --warmup=60
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/hud_instruments.gd \
##     --out=/tmp/instruments/dungeon.png --size=1280x720 --warmup=60

const Layout := preload("res://tools/directors/_hud_layout.gd")


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/instruments/x.png").get_base_dir()
	await rig.wait_frames(20)
	var instrument := Hud.get_node_or_null("CivilInstruments") as CivilInstruments
	if not rig.check(instrument != null, "Hud owns one CivilInstruments control"):
		return
	var underground: bool = Run != null and Run.in_dungeon
	var mode := "dungeon" if underground else "surface"
	var output_mode := _output_mode(underground)
	rig.check(instrument.layout_mode() == StringName(mode),
		"instrument selected the %s layout" % mode)
	await _capture_layout(rig, instrument, out, output_mode, underground)
	await _prove_map(rig, out, output_mode)
	await _prove_headings(rig, instrument, out, output_mode)
	await _prove_forward_clock_jump(rig, instrument, out, output_mode)
	print("HUD INSTRUMENTS OK -- %s" % output_mode)


func _capture_layout(rig, instrument: CivilInstruments, out: String,
		mode: String, underground: bool) -> void:
	await rig.capture(out.path_join("%s_00_layout.png" % mode))
	var layout_failures := Layout.check("%s_instruments" % mode)
	rig.check(layout_failures == 0, "%s HUD layout has no collisions" % mode)
	var layout: Dictionary = Hud.layout_rects()
	rig.check(layout.has(&"civil_instruments"),
		"HUD publishes the civil instrument rectangle")
	var rect := instrument.instrument_rect()
	var viewport_size := Hud.get_viewport().get_visible_rect().size
	if rig.check(layout.has(&"minimap"), "%s layout includes the minimap" % mode):
		var map_entry: Dictionary = layout[&"minimap"]
		var map_rect: Rect2 = map_entry[&"rect"]
		rig.check(is_equal_approx(Pal.MINIMAP_SIZE, 126.0),
			"shared minimap contract stays at the compact 126 px size")
		rig.check(absf(map_rect.size.x - Pal.px(Pal.MINIMAP_SIZE,
			viewport_size.y)) <= 1.0,
			"minimap frame uses the compact shared size")
		var gap := rect.position.y - map_rect.end.y
		var expected_gap := Pal.px(CivilInstruments.MAP_GAP, viewport_size.y)
		rig.check(absf(gap - expected_gap) <= 1.0,
			"compact civil stack sits below the minimap (%.1f px gap)" % gap)
		rig.check(absf(rect.size.x - map_rect.size.x) <= 1.0,
			"map, compass and day track share one width")
		rig.check(absf(rect.end.x - map_rect.end.x) <= 1.0,
			"map, compass and day track share one right edge")
		rig.check(absf(rect.size.y - Pal.px(CivilInstruments.HEIGHT,
			viewport_size.y)) <= 1.0,
			"civil instrument is the compact two-band height")


func _prove_map(rig, out: String, mode: String) -> void:
	if not rig.check(Atlas.has_map(), "%s has one active Atlas map" % mode):
		return
	var kind := Atlas.map_kind()
	var provider_id := Atlas.map_provider_id()
	var debug: Dictionary = Hud.map_debug()
	rig.check(not debug.is_empty(), "%s active plan reached MapDraw through HUD" % mode)
	rig.check(StringName(debug.get(&"kind", &"")) == kind,
		"HUD reports the active %s kind" % kind)
	rig.check(int(debug.get(&"provider_id", 0)) == provider_id,
		"HUD reports the active %s provider" % mode)
	rig.check(bool(debug.get(&"player_centered", false)),
		"%s minimap follows the centred player" % mode)
	if kind == Atlas.KIND_SURFACE:
		rig.check(not Atlas.surface_plan().is_empty(),
			"%s Atlas surface plan is non-empty" % mode)
		rig.check(int(debug.get(&"path_count", 0)) > 0,
			"%s rendered real authored paths" % mode)
		rig.check(int(debug.get(&"landmark_count", 0)) > 0,
			"%s rendered real authored landmarks" % mode)
	else:
		rig.check(not Atlas.rooms.is_empty(), "%s Atlas dungeon plan is non-empty" % mode)

	Menu.open_map()
	await rig.wait_seconds(0.4)
	var map := Menu.get_node("Root/Screens/MapScreen") as MenuMapPanel
	rig.check(Menu.is_open and map.visible, "%s opens the pause MAP" % mode)
	await rig.capture(out.path_join("%s_01_map.png" % mode))
	var menu_debug := map.map_debug()
	rig.check(not menu_debug.is_empty(), "%s pause MAP rendered a non-empty plan" % mode)
	rig.check(Atlas.has_map() and Atlas.map_kind() == kind
		and Atlas.map_provider_id() == provider_id,
		"%s pause MAP keeps the same active authority and kind" % mode)
	rig.check(StringName(menu_debug.get(&"kind", &"")) == kind
		and int(menu_debug.get(&"provider_id", 0)) == provider_id,
		"%s pause MAP reports that authority through MapDraw" % mode)
	var screen_text := " ".join(_all_text(map)).to_lower()
	if kind == Atlas.KIND_SURFACE:
		rig.check(not screen_text.contains("nothing down here to chart"),
			"%s MAP no longer claims the surface is uncharted" % mode)
		rig.check(screen_text.contains(Atlas.map_title().to_lower()),
			"%s MAP names the active surface" % mode)
	Menu.close()
	await rig.wait_frames(4)
	rig.check(not Menu.is_open and not Menu.get_tree().paused,
		"%s closes MAP and leaves pause state clean" % mode)


func _output_mode(underground: bool) -> String:
	if underground:
		return "dungeon"
	var provider: Node = Atlas.map_provider()
	if provider is GarrisonOutskirts:
		return "outskirts"
	return "garrison"


func _prove_headings(rig, instrument: CivilInstruments, out: String,
		mode: String) -> void:
	var hero := rig.get_first_node_in_group(&"player") as Node3D
	if not rig.check(hero != null, "heading proof has a player"):
		return
	var original := hero.global_transform
	var original_facing := float(hero.get(&"facing_yaw"))
	var cases: Array[Dictionary] = [
		{&"label": "N", &"bearing": 0.0, &"direction": Vector3(0.0, 0.0, -1.0)},
		{&"label": "E", &"bearing": 90.0, &"direction": Vector3(1.0, 0.0, 0.0)},
		{&"label": "S", &"bearing": 180.0, &"direction": Vector3(0.0, 0.0, 1.0)},
		{&"label": "W", &"bearing": 270.0, &"direction": Vector3(-1.0, 0.0, 0.0)},
	]
	for entry: Dictionary in cases:
		var direction: Vector3 = entry[&"direction"]
		# The controller owns facing_yaw and rewrites the body from it every tick.
		# Drive both halves of that contract so this proof tests a stable body pose,
		# not a transform that the next physics frame immediately corrects.
		var heading_yaw := atan2(direction.x, direction.z)
		hero.set(&"facing_yaw", heading_yaw)
		hero.global_rotation.y = heading_yaw + PI
		await rig.wait_frames(4)
		var label := String(entry[&"label"])
		var bearing := float(entry[&"bearing"])
		rig.check(instrument.cardinal_label() == label,
			"player -basis.z points %s and the compass says %s" % [label, label])
		rig.check(absf(angle_difference(deg_to_rad(instrument.bearing_degrees()),
			deg_to_rad(bearing))) < deg_to_rad(1.0),
			"%s heading reads %.0f degrees" % [label, bearing])
		await rig.capture(out.path_join("%s_10_heading_%s.png" % [mode, label.to_lower()]))
	hero.set(&"facing_yaw", original_facing)
	hero.global_transform = original


func _prove_forward_clock_jump(rig, instrument: CivilInstruments, out: String,
		mode: String) -> void:
	var before := Clock.snapshot()
	Clock.restore({"day": 3, "hour": 9.0, "running": false})
	var settled: bool = await rig.until(func() -> bool:
		return absf(instrument.displayed_absolute_minutes()
			- instrument.target_absolute_minutes()) < 0.05, 2.5)
	rig.check(settled, "clock fixture settles at Day 3, 9:00am")
	await rig.capture(out.path_join("%s_20_clock_before.png" % mode))
	var start := instrument.displayed_absolute_minutes()
	Clock.set_time(3, 17.5)
	var target := instrument.target_absolute_minutes()
	rig.check(target > start + 400.0, "forward jump supplies a large later target")
	await rig.wait_frames(5)
	var middle := instrument.displayed_absolute_minutes()
	rig.check(middle > start and middle < target,
		"clock visibly eases between forward-jump targets")
	await rig.capture(out.path_join("%s_21_clock_moving.png" % mode))
	var arrived: bool = await rig.until(func() -> bool:
		return absf(instrument.displayed_absolute_minutes() - target) < 0.05, 2.5)
	rig.check(arrived, "clock reaches the forward-jump target")
	await rig.capture(out.path_join("%s_22_clock_arrived.png" % mode))

	# Absolute minutes make this a forward one-minute move even though the marker
	# wraps from the right end of the track to its left end at midnight.
	Clock.restore({"day": 4, "hour": 23.983333, "running": false})
	await rig.until(func() -> bool:
		return absf(instrument.displayed_absolute_minutes()
			- instrument.target_absolute_minutes()) < 0.05, 2.5)
	var midnight_start := instrument.displayed_absolute_minutes()
	Clock.set_time(5, 0.0)
	await rig.wait_frames(3)
	rig.check(instrument.displayed_absolute_minutes() > midnight_start,
		"midnight wrap continues forward in absolute civil time")
	Clock.restore(before)


func _all_text(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	var label := root as Label
	if label != null and not label.text.strip_edges().is_empty():
		out.append(label.text)
	for child in root.get_children():
		out.append_array(_all_text(child))
	return out
