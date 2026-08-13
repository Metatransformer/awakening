extends RefCounted
## Issue #199: actual door locks and floor-scoped key state on the minimap and
## full MAP screen.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/map_locks.gd \
##     --out=/tmp/map-locks/x.png --warmup=60

const SEED := 199044

var _fails := 0
var _out := ""


func run(rig) -> void:
	_out = rig.arg("out", "/tmp/map-locks/x.png").get_base_dir()
	if rig.scene().name != &"DungeonRun":
		_fail("wrong host scene; pass res://scenes/rooms/dungeon.tscn")
		return
	Game.reset()
	Run.enter(SEED)
	Run.level = 1
	var d := await _rebuild(rig)
	var hero := _hero(rig)
	if d == null or hero == null:
		_fail("dungeon or hero missing")
		return

	var ordinary := 0
	var boss := 0
	for tag: StringName in Atlas.locks:
		var record: Dictionary = Atlas.locks[tag]
		_ck("lock %s points at a real host room and wall" % tag,
			Atlas.rooms.has(record["cell"])
			and (record["wall"] as StringName) in [&"n", &"s", &"w", &"e"])
		if record["kind"] == Atlas.LOCK_BOSS:
			boss += 1
		else:
			ordinary += 1
		Atlas.see(record["cell"])
	_ck("Atlas publishes actual ordinary and boss locks", ordinary > 0 and boss == 1)
	_ck("the guaranteed small-key gate is one of those records",
		Atlas.locks.has(d.key_loop["tag"]))

	Game.set_small_keys_for_floor(1, 3)
	Game.add_boss_key()
	await rig.wait_frames(6)
	var hud_debug: Dictionary = Hud.map_debug()
	# The following minimap is deliberately clipped around the hero; seen locks
	# outside that window stay in Atlas but are not visible until the plan scrolls.
	_ck("minimap rendered the seen locks inside its clipped window",
		int(hud_debug.get(&"visible_lock_count", 0)) > 0
		and int(hud_debug.get(&"visible_lock_count", 0)) <= Atlas.locks.size())
	_ck("minimap debug names ordinary bone and boss gold glyphs",
		hud_debug.get(&"ordinary_lock_glyph") == &"bone_padlock"
		and hud_debug.get(&"boss_lock_glyph") == &"gold_padlock")
	_ck("HUD key strip shows 3 ordinary and 1 boss key",
		hud_debug.get(&"small_keys") == 3 and hud_debug.get(&"boss_key") == 1
		and bool(hud_debug.get(&"key_strip", false)))
	var layout: Dictionary = Hud.layout_rects()
	_ck("HUD publishes minimap key-strip geometry",
		layout.has(&"minimap_keys") and layout.has(&"minimap")
		and (layout[&"minimap"][&"rect"] as Rect2).encloses(
			layout[&"minimap_keys"][&"rect"] as Rect2))
	await rig.capture(_out.path_join("l_00_minimap_locks.png"))

	Menu.open_map()
	await rig.wait_frames(8)
	var map: MenuMapPanel = Menu.get_node("Root/Screens/MapScreen")
	_ck("MAP screen opened", Menu.is_open and map.visible)
	var full_debug := map.map_debug()
	_ck("full map rendered the same ordinary and boss locks",
		full_debug.get(&"lock_count") == hud_debug.get(&"lock_count")
		and int(full_debug.get(&"visible_lock_count", -1)) == Atlas.locks.size()
		and full_debug.get(&"ordinary_lock_glyph") == &"bone_padlock"
		and full_debug.get(&"boss_lock_glyph") == &"gold_padlock")
	_ck("full map key state matches the HUD",
		full_debug.get(&"small_keys") == 3 and full_debug.get(&"boss_key") == 1)
	var words := " ".join(_all_text(map))
	var band_labels: Array[String] = []
	for cell: Dictionary in map._band_cells():
		band_labels.append(String(cell.get("label", "")))
	_ck("dungeon StatBand is Floor / Rooms / Keys / Boss key",
		band_labels == ["Floor", "Rooms", "Keys", "Boss key"])
	_ck("legend names both lock glyphs",
		words.contains("Locked door") and words.contains("Boss-key door"))
	await rig.capture(_out.path_join("l_01_full_map_locks.png"))

	var before := Atlas.locks.size()
	var boss_door := d.anchor_node(&"boss_door") as BossDoor
	var boss_tag := StringName("boss_door_f%d" % Run.level)
	_ck("real closed Boss Door owns the gold Atlas record",
		boss_door != null and Atlas.locks.has(boss_tag)
		and Atlas.locks[boss_tag]["kind"] == Atlas.LOCK_BOSS)
	boss_door.activate(hero)
	await rig.wait_frames(5)
	_ck("real Boss Door opening removes exactly its lock record",
		boss_door.is_open() and Atlas.locks.size() == before - 1
		and not Atlas.locks.has(boss_tag))
	full_debug = map.map_debug()
	_ck("full map removes the opened icon immediately",
		int(full_debug.get(&"lock_count", -1)) == Atlas.locks.size()
		and int(full_debug.get(&"boss_lock_count", -1)) == 0)
	await rig.capture(_out.path_join("l_02_full_map_opened.png"))

	Menu.close()
	await rig.wait_frames(6)
	hud_debug = Hud.map_debug()
	_ck("minimap removes the same opened icon immediately",
		int(hud_debug.get(&"lock_count", -1)) == Atlas.locks.size()
		and int(hud_debug.get(&"boss_lock_count", -1)) == 0)
	_ck("Boss-key count repainted to zero on both surfaces",
		hud_debug.get(&"boss_key") == 0)
	await rig.capture(_out.path_join("l_03_minimap_opened.png"))

	print("MAP_LOCKS OK -- every check passed" if _fails == 0 \
		else "MAP_LOCKS FAILED (%d)" % _fails)


func _rebuild(rig) -> Node:
	var old: Node = rig.scene().get_node_or_null(^"Dungeon")
	if old != null:
		old.name = "DungeonOld"
		old.queue_free()
		await rig.wait_frames(2)
	var script := load("res://scripts/world/dungeon.gd") as GDScript
	var d: Node = script.new()
	d.name = "Dungeon"
	d.seed_override = SEED
	rig.scene().add_child(d)
	await rig.wait_frames(6)
	return d


func _hero(rig) -> Node3D:
	var players: Array = rig.get_nodes_in_group(&"player")
	return players[0] if not players.is_empty() else null


func _all_text(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	var label := root as Label
	if label != null and not label.text.strip_edges().is_empty():
		out.append(label.text)
	for child: Node in root.get_children():
		out.append_array(_all_text(child))
	return out


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("MAP_LOCKS ok %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_fails += 1
	print("MAP_LOCKS FAIL %s" % label)
