extends RefCounted
## The way out, driven the way a player drives it: Select, then HOLD Y.
##
## Everything else that tests the rope tests half of it. `_equip_director` drives
## the POUCH row in `_menu_test.tscn`, where there is no hero and
## `Bus.escape_rope_used` is emitted into an empty room; `mvp_loop._extract`
## calls `rope.begin()` on the node directly and says in as many words that the
## menu path is somebody else's job. Nothing joined the two, so the chain the
## player actually performs — a button in a paused menu, a menu that closes
## itself, and a channel that starts in the world — had no proof at all.
##
## It runs in a REAL dungeon (`dungeon.tscn` calls `Run.enter()` on ready), not
## in the menu harness, for the reason `escape_in_game.gd` gives about its own
## twin: a menu proven only in the scene built to prove it is a menu the shipping
## game can be missing entirely.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/rope_hold.gd \
##     --out=/tmp/rope/r.png --size=1280x720 --warmup=60

## physical_keycode for I, as bound to `inventory`. Sent as a real InputEvent:
## `Input.action_press` (which `rig.tap` uses) sets action STATE and dispatches
## no event at all, and the menu opens off `_unhandled_input` (CLAUDE.md §3).
const KEY_I := 73

var out := ""
var _fails := 0
var _fired := false


func _on_used() -> void:
	_fired = true


func run(rig) -> void:
	out = rig.arg("out", "/tmp/rope/r.png").get_base_dir()
	await rig.wait_frames(30)

	# Annotated: `get_nodes_in_group` off an untyped `rig` returns Variant, and an
	# inferred `:=` on it is a PARSE error that takes the whole director down —
	# after which shoot.gd waits forever for a `run()` that was never loaded.
	var players: Array = rig.get_nodes_in_group(&"player")
	if players.is_empty():
		_fail("A0 there is no hero in this room")
		return
	var hero = players[0]
	var rope: EscapeRope = hero.rope
	_ck("A0 the room booted into a run", Run.in_dungeon)
	_ck("A1 the hero is carrying the way out", rope != null)
	if rope == null:
		return

	# Something in the bag, so the fee is a real number and not the floor.
	Run.collect(&"iron_scrap", 4)
	Game.add_gold(200)
	await rig.wait_frames(10)
	print("ROPE fee=%d purse=%d bag=%d" % [
		Run.extract_cost(), Game.gold, Run.bag_value()])

	# --- Select opens the pouch ----------------------------------------------
	await _key(rig, KEY_I, 20)
	_ck("B0 the pouch button opened the menu", Menu.is_open)
	var pouch: MenuPouchPanel = Menu.get_node("Root/Screens/PouchScreen")
	_ck("B1 and opened it ON the pouch", pouch.visible)
	await rig.capture(out.path_join("r_00_pouch.png"))

	# --- A tap of Y is not leaving -------------------------------------------
	Bus.escape_rope_used.connect(_on_used)
	await rig.hold_seconds(["ui_hold"], 0.08)
	await rig.wait_frames(10)
	_ck("C0 a tap of Y left nobody", not _fired and Menu.is_open and Run.in_dungeon)
	_ck("C1 and the gauge snapped back (%.2f)" % pouch._rope_hold,
		is_zero_approx(pouch._rope_hold))

	# --- Held through --------------------------------------------------------
	# In game seconds against a 0.9 s hold: a frame count is a duration of
	# unknown length (`shoot.hold_seconds`).
	Input.action_press(&"ui_hold")
	for _i in 120:
		await rig.wait_frames(1)
		if pouch._rope_hold >= MenuPouchPanel.ROPE_HOLD * 0.45:
			break
	await rig.capture(out.path_join("r_01_holding.png"))
	await rig.hold_seconds(["ui_hold"], MenuPouchPanel.ROPE_HOLD + 0.4)
	await rig.wait_frames(6)
	Bus.escape_rope_used.disconnect(_on_used)

	_ck("D0 holding Y used the rope", _fired)
	# The whole menu, not one screen off the stack: the channel happens in the
	# world and the player has to be able to watch it.
	_ck("D1 the menu closed whole for it", not Menu.is_open)
	_ck("D2 the tree is running again", not rig.paused)
	_ck("D3 the rope is channelling in the WORLD", rope.active())
	await rig.capture(out.path_join("r_02_channelling.png"))

	# --- And it finishes ------------------------------------------------------
	await rig.wait_seconds(EscapeRope.CHANNEL_TIME)
	await rig.wait_frames(40)
	_ck("E0 the channel finished the run", not Run.in_dungeon)
	await rig.capture(out.path_join("r_03_ended.png"))

	if _fails == 0:
		print("ROPE OK — Select, hold Y, and he leaves")
	else:
		print("ROPE FAIL %d check(s)" % _fails)


func _key(rig, code: int, settle: int = 12) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	await rig.wait_frames(2)
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	await rig.wait_frames(settle)


func _ck(what: String, ok: bool) -> void:
	if ok:
		print("PASS %s" % what)
	else:
		_fails += 1
		print("ROPE FAIL %s" % what)


func _fail(msg: String) -> void:
	_fails += 1
	print("ROPE FAIL %s" % msg)
