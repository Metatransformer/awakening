extends RefCounted
## Live-input integration proof for the developer console and its puzzle lab.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/dev_console.gd \
##     --out=/tmp/dev_console/x.png --warmup=60

const GARRISON_SCENE := "res://scenes/rooms/garrison.tscn"
const DUNGEON_SCENE := "res://scenes/rooms/dungeon.tscn"
const DEV_PUZZLE_SCENE := "res://scenes/rooms/dev_puzzle.tscn"

var _rig: Variant
var _out_dir: String = ""


func run(rig) -> void:
	_rig = rig
	_out_dir = rig.arg("out", "/tmp/dev_console/x.png").get_base_dir()

	if not await _prove_open_and_restore():
		return
	if not await _open_console():
		return
	if not await _submit_console_command("/puzzles"):
		return
	var status: String = DevConsole._status.text
	for fixture: Dictionary in DevPuzzleCatalogue.all():
		var fixture_id: String = String(fixture["id"])
		if not rig.check(status.contains(fixture_id),
				"/puzzles status lists %s" % fixture_id):
			return
	await rig.capture(_out_dir.path_join("01_console_puzzles.png"))

	if not rig.check(not Game.dev_god_mode,
			"god mode begins off before the live /god command"):
		return
	if not await _submit_console_command("/god"):
		return
	if not rig.check(Game.dev_god_mode, "/god turns god mode on"):
		return
	if not await _submit_console_command("/grant bow"):
		return
	if not rig.check(Game.has(&"bow"), "/grant bow grants the bow"):
		return

	var heart_before: int = int(Game.upgrades.get(&"heart", 0))
	if not await _submit_console_command("/upgrade heart"):
		return
	if not rig.check(int(Game.upgrades.get(&"heart", 0)) == heart_before + 1,
			"/upgrade heart advances exactly one rung"):
		return
	if not _prove_god_mode():
		return

	var eye_room: DevPuzzleRoom = await _open_fixture(&"eye_sequence")
	if eye_room == null or not await _prove_eye_fixture(eye_room):
		return
	await rig.capture(_out_dir.path_join("02_eye_sequence.png"))

	var eyes: Array[PuzzleAtom] = _atoms_with_id(
		eye_room.fixture_root(), PuzzleAtoms.EYE_SWITCH)
	var first_eye: PuzzleAtom = _atom_at_index(eyes, 0)
	if not rig.check(first_eye != null,
			"eye_sequence exposes its index-zero eye for the reset proof"):
		return
	first_eye.solve()
	var first_flag: StringName = first_eye.flag_id()
	if not rig.check(first_eye.is_solved() and Game.flag(first_flag),
			"solving the first eye latches both its state and atom flag"):
		return

	eye_room = await _open_fixture(&"eye_sequence")
	if eye_room == null:
		return
	eyes = _atoms_with_id(eye_room.fixture_root(), PuzzleAtoms.EYE_SWITCH)
	if not rig.check(eyes.size() == 3 and _all_unsolved(eyes),
			"re-entering eye_sequence rebuilds all three eyes unsolved"):
		return
	if not rig.check(not Game.flag(first_flag),
			"re-entering eye_sequence removes the first eye's old atom flag"):
		return

	var room: DevPuzzleRoom = await _open_fixture(&"lantern_coupling")
	if room == null or not _prove_lantern_fixture(room):
		return
	await rig.capture(_out_dir.path_join("03_lantern_coupling.png"))

	room = await _open_fixture(&"pillar_chain")
	if room == null or not _prove_pillar_fixture(room):
		return
	await rig.capture(_out_dir.path_join("04_pillar_chain.png"))

	room = await _open_fixture(&"plate_nest")
	if room == null or not _prove_plate_fixture(room):
		return
	await rig.capture(_out_dir.path_join("05_plate_nest.png"))

	for atom_id: StringName in PuzzleAtoms.all():
		room = await _open_fixture(atom_id)
		if room == null or not _prove_stock_fixture(room, atom_id):
			return
		await rig.capture(_out_dir.path_join("stock_%s.png" % String(atom_id)))

	for destination: String in ["dungeon", "dungeon2", "dungeon3"]:
		var expected_floor: int = 1 if destination == "dungeon" \
			else int(destination.trim_prefix("dungeon"))
		if not await _open_console():
			return
		if not await _submit_console_command("/tp %s" % destination):
			return
		if not await _wait_for_scene(DUNGEON_SCENE,
				"the normal dungeon after /tp %s" % destination):
			return
		if not rig.check(Run.in_dungeon and Run.level == expected_floor,
				"/tp %s starts a live run on floor %d" % [destination, expected_floor]):
			return
		if destination == "dungeon":
			var shards_before: int = int(Run.bag.get(&"bone_shard", 0))
			if not await _open_console():
				return
			if not await _submit_console_command("/grant bone_shard"):
				return
			if not rig.check(int(Run.bag.get(&"bone_shard", 0)) == shards_before + 1,
					"/grant accepts a validated run-bag item id"):
				return
			await _send_key(KEY_QUOTELEFT)

	if not await _open_console():
		return
	if not await _submit_console_command("/tp town"):
		return
	if not await _wait_for_scene(GARRISON_SCENE, "the garrison after /tp town"):
		return
	if not rig.check(not Run.in_dungeon,
			"/tp town returns to the garrison outside a dungeon run"):
		return

	print("DEV CONSOLE OK -- live commands, fixture resets, and dev travel verified")


func _prove_open_and_restore() -> bool:
	if not _rig.check(DevConsole._root != null and DevConsole._status != null
			and DevConsole._input_box != null,
			"DevConsole built its live root, status label, and TextEdit"):
		return false

	# Give the console a concrete focus owner to restore. It lives on the
	# director's runtime only and stays off-screen.
	var prior_focus := Button.new()
	prior_focus.name = "DevConsolePriorFocus"
	prior_focus.position = Vector2(-100.0, -100.0)
	prior_focus.custom_minimum_size = Vector2.ONE
	prior_focus.focus_mode = Control.FOCUS_ALL
	DevConsole.add_child(prior_focus)
	prior_focus.grab_focus()
	await _rig.wait_frames(2)
	if not _rig.check(DevConsole.get_viewport().gui_get_focus_owner() == prior_focus,
			"director setup establishes a concrete prior focused Control"):
		return false

	var paused_before: bool = _rig.paused
	var mouse_before: Input.MouseMode = Input.get_mouse_mode()
	if not await _open_console():
		return false
	if not _rig.check(DevConsole._root.visible,
			"a real unshifted backtick makes the console visible"):
		return false
	if not _rig.check(_rig.paused, "opening the console pauses the tree"):
		return false
	if not _rig.check(DevConsole.get_viewport().gui_get_focus_owner()
			== DevConsole._input_box,
			"opening the console focuses its TextEdit"):
		return false
	if not _rig.check(Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE,
			"opening the console makes the mouse visible"):
		return false

	await _send_key(KEY_QUOTELEFT)
	if not _rig.check(not DevConsole._root.visible,
			"a second real backtick closes the console"):
		return false
	if not _rig.check(_rig.paused == paused_before,
			"closing restores the exact prior paused state"):
		return false
	if not _rig.check(Input.get_mouse_mode() == mouse_before,
			"closing restores the exact prior mouse mode"):
		return false
	if not _rig.check(DevConsole.get_viewport().gui_get_focus_owner() == prior_focus,
			"closing restores the exact prior focused Control"):
		return false
	return true


func _open_console() -> bool:
	if DevConsole._root == null or DevConsole._input_box == null:
		_rig.fail("DevConsole UI is unavailable")
		return false
	if DevConsole._root.visible:
		_rig.fail("DevConsole was unexpectedly already open")
		return false
	await _send_key(KEY_QUOTELEFT)
	if not _rig.check(DevConsole._root.visible and _rig.paused,
			"real backtick opens and pauses the live DevConsole"):
		return false
	if not _rig.check(DevConsole.get_viewport().gui_get_focus_owner()
			== DevConsole._input_box,
			"the reopened console focuses its live TextEdit"):
		return false
	return true


func _submit_console_command(command: String) -> bool:
	if not DevConsole._root.visible or not _rig.paused:
		_rig.fail("cannot submit %s: the live console is not open and paused" % command)
		return false
	var input_box: TextEdit = DevConsole._input_box
	input_box.text = command + " "
	input_box.set_caret_line(input_box.get_line_count() - 1)
	input_box.set_caret_column(input_box.get_line(
		input_box.get_line_count() - 1).length())
	# The console deliberately accepts an autocomplete row on Enter when there is
	# no space. The trailing space above hides completion before this real key.
	await _rig.wait_frames(2)
	await _send_key(KEY_ENTER)
	return true


func _send_key(code: int) -> void:
	var down := InputEventKey.new()
	down.keycode = code as Key
	down.physical_keycode = code as Key
	down.pressed = true
	down.echo = false
	down.shift_pressed = false
	down.alt_pressed = false
	down.ctrl_pressed = false
	down.meta_pressed = false
	Input.parse_input_event(down)
	await _rig.wait_frames(2)
	var up := InputEventKey.new()
	up.keycode = code as Key
	up.physical_keycode = code as Key
	up.pressed = false
	up.shift_pressed = false
	up.alt_pressed = false
	up.ctrl_pressed = false
	up.meta_pressed = false
	Input.parse_input_event(up)
	await _rig.wait_frames(3)


func _prove_god_mode() -> bool:
	var health_before: int = Game.quarters
	var stamina_before: float = Game.stamina
	var magic_before: int = Game.magic
	var arrows_before: int = Game.arrows
	var charges_before: int = Game.charges

	Game.damage(K.QUARTER)
	var stamina_paid: bool = Game.spend_stamina(1.0)
	var magic_paid: bool = Game.spend_magic(1)
	var arrow_paid: bool = Game.spend_ammo(&"arrows")
	var charge_paid: bool = Game.spend_ammo(&"charges")

	if not _rig.check(Game.quarters == health_before,
			"god mode prevents health loss through Game.damage"):
		return false
	if not _rig.check(stamina_paid and Game.stamina == stamina_before,
			"god mode allows Game.spend_stamina without consumption"):
		return false
	if not _rig.check(magic_paid and Game.magic == magic_before,
			"god mode allows Game.spend_magic without consumption"):
		return false
	if not _rig.check(arrow_paid and charge_paid and Game.arrows == arrows_before
			and Game.charges == charges_before,
			"god mode allows both Game.spend_ammo routes without consumption"):
		return false
	return true


func _open_fixture(id: StringName) -> DevPuzzleRoom:
	# Mutation commands leave the console open; puzzle travel closes it. Reuse
	# the live surface when it is already up, and open it through backtick after
	# every fixture transition.
	if not DevConsole._root.visible:
		if not await _open_console():
			return null
	if not await _submit_console_command("/puzzle %s" % String(id)):
		return null
	var reached: bool = await _rig.until(func() -> bool:
		var current: Node = _rig.scene()
		return not Flow.busy and current is DevPuzzleRoom \
			and (current as DevPuzzleRoom).fixture_id() == id, 15.0)
	if not _rig.check(reached,
			"/puzzle %s completes its Flow transition" % String(id)):
		return null
	var room := _rig.scene() as DevPuzzleRoom
	if not _rig.check(room != null and room.scene_file_path == DEV_PUZZLE_SCENE,
			"/puzzle %s opens the DevPuzzleRoom scene" % String(id)):
		return null
	if not _rig.check(room.fixture_id() == id and room.fixture_root() != null,
			"DevPuzzleRoom exposes fixture %s and its root" % String(id)):
		return null
	await _rig.wait_frames(12)
	return room


func _prove_eye_fixture(room: DevPuzzleRoom) -> bool:
	var root: Node3D = room.fixture_root()
	var eyes: Array[PuzzleAtom] = _atoms_with_id(root, PuzzleAtoms.EYE_SWITCH)
	var gates: Array[PuzzleGate] = _gates(root)
	if not _rig.check(eyes.size() == 3 and gates.size() == 1,
			"eye_sequence contains exactly three eyes and one PuzzleGate"):
		return false
	if not _rig.check(gates[0].ordered,
			"eye_sequence gate enforces ordered solving"):
		return false
	if not _rig.check(_all_unsolved(eyes),
			"all three eye_sequence eyes begin unsolved"):
		return false
	return true


func _prove_lantern_fixture(room: DevPuzzleRoom) -> bool:
	var root: Node3D = room.fixture_root()
	var grids: Array[LanternGrid] = []
	for node: Node in _walk(root):
		if node is LanternGrid:
			grids.append(node as LanternGrid)
	var gates: Array[PuzzleGate] = _gates(root)
	if not _rig.check(grids.size() == 1,
			"lantern_coupling contains exactly one LanternGrid"):
		return false
	var cells: int = 0
	for child: Node in grids[0].get_children():
		if child is Lantern and child is PuzzleAtom:
			cells += 1
	if not _rig.check(cells == 9,
			"lantern_coupling grid contains nine Lantern/PuzzleAtom children"):
		return false
	if not _rig.check(not grids[0].is_lit_out(),
			"lantern_coupling does not begin already solved"):
		return false
	if not _rig.check(gates.size() == 1
			and gates[0].puzzle_id == &"lantern_coupling",
			"lantern_coupling has one PuzzleGate watching the fixture tag"):
		return false
	return true


func _prove_pillar_fixture(room: DevPuzzleRoom) -> bool:
	var root: Node3D = room.fixture_root()
	var rows: Array[ChainRow] = []
	for node: Node in _walk(root):
		if node is ChainRow:
			rows.append(node as ChainRow)
	var gates: Array[PuzzleGate] = _gates(root)
	if not _rig.check(rows.size() == 1,
			"pillar_chain contains exactly one ChainRow"):
		return false
	var links: Array[PuzzleAtom] = rows[0].links()
	var cracked_links: bool = links.size() == 5
	for link: PuzzleAtom in links:
		cracked_links = cracked_links and link.atom_id == PuzzleAtoms.CRACKED_PILLAR
	if not _rig.check(cracked_links,
			"pillar_chain has five cracked-pillar PuzzleAtom links"):
		return false
	var socket := rows[0].get_node_or_null(^"GapSocket") as MeshInstance3D
	if not _rig.check(socket != null and socket.is_visible_in_tree(),
			"pillar_chain exposes a visible GapSocket"):
		return false
	if not _rig.check(rows[0].problems().is_empty(),
			"pillar_chain geometry reports no gameplay problems"):
		return false
	if not _rig.check(gates.size() == 1,
			"pillar_chain contains exactly one PuzzleGate"):
		return false
	if not _rig.check(Game.has(&"burst") and Game.charges == Game.max_charges,
			"pillar_chain grants Burst and fills its charges"):
		return false
	return true


func _prove_plate_fixture(room: DevPuzzleRoom) -> bool:
	var root: Node3D = room.fixture_root()
	var plates: Array[PressurePlate] = []
	var blocks: Array[PushBlock] = []
	for node: Node in _walk(root):
		if node is PressurePlate:
			plates.append(node as PressurePlate)
		elif node is PushBlock:
			blocks.append(node as PushBlock)
	var gates: Array[PuzzleGate] = _gates(root)
	if not _rig.check(plates.size() == 1 and blocks.size() == 1
			and gates.size() == 1,
			"plate_nest contains one PressurePlate, one PushBlock, and one PuzzleGate"):
		return false
	if not _rig.check(blocks[0].puzzle_id != gates[0].puzzle_id,
			"plate_nest block is not independently tagged for the gate"):
		return false
	if not _rig.check(not gates[0].is_open(),
			"plate_nest gate starts shut"):
		return false
	return true


func _prove_stock_fixture(room: DevPuzzleRoom, atom_id: StringName) -> bool:
	if not _rig.check(room.fixture_id() == atom_id,
			"stock fixture exposes id %s" % String(atom_id)):
		return false
	var atoms: Array[PuzzleAtom] = _atoms(room.fixture_root())
	if not _rig.check(atoms.size() == 1,
			"%s contains exactly one PuzzleAtom" % String(atom_id)):
		return false
	var atom: PuzzleAtom = atoms[0]
	if not _rig.check(atom.atom_id == atom_id,
			"%s fixture contains its matching stock atom" % String(atom_id)):
		return false
	if not _rig.check(not atom.is_solved(),
			"%s stock atom begins unsolved" % String(atom_id)):
		return false

	var tier: int = PuzzleAtoms.tier(atom_id)
	var required_item: StringName = PuzzleAtoms.TIER_ITEM[tier]
	if required_item != &"" and not _rig.check(Game.has(required_item),
			"%s fixture grants authored tier item %s" % [atom_id, required_item]):
		return false

	var gates: Array[PuzzleGate] = _gates(room.fixture_root())
	var expected_gate_count: int = 1 if PuzzleAtoms.gates(atom_id) else 0
	if not _rig.check(gates.size() == expected_gate_count,
			"%s has authored gate count %d" % [atom_id, expected_gate_count]):
		return false
	if atom_id == PuzzleAtoms.SMALL_KEY and not _rig.check(gates[0].needs_key,
			"small_key fixture gate spends the collected key"):
		return false
	if atom_id == PuzzleAtoms.PUSH_BLOCK:
		var mark_offset: Vector3 = atom.get(&"mark_offset")
		if not _rig.check(mark_offset != Vector3.ZERO,
				"push_block fixture has an independent reachable mark"):
			return false
	return true


func _wait_for_scene(path: String, label: String) -> bool:
	var reached: bool = await _rig.until(func() -> bool:
		var current: Node = _rig.scene()
		return not Flow.busy and current != null \
			and current.scene_file_path == path, 20.0)
	return _rig.check(reached, label)


func _walk(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		out.append(node)
		for child: Node in node.get_children():
			stack.append(child)
	return out


func _gates(root: Node) -> Array[PuzzleGate]:
	var out: Array[PuzzleGate] = []
	for node: Node in _walk(root):
		if node is PuzzleGate:
			out.append(node as PuzzleGate)
	return out


func _atoms(root: Node) -> Array[PuzzleAtom]:
	var out: Array[PuzzleAtom] = []
	for node: Node in _walk(root):
		if node is PuzzleAtom:
			out.append(node as PuzzleAtom)
	return out


func _atoms_with_id(root: Node, atom_id: StringName) -> Array[PuzzleAtom]:
	var out: Array[PuzzleAtom] = []
	for node: Node in _walk(root):
		if node is PuzzleAtom and (node as PuzzleAtom).atom_id == atom_id:
			out.append(node as PuzzleAtom)
	return out


func _atom_at_index(atoms: Array[PuzzleAtom], index: int) -> PuzzleAtom:
	for atom: PuzzleAtom in atoms:
		if atom.index == index:
			return atom
	return null


func _all_unsolved(atoms: Array[PuzzleAtom]) -> bool:
	for atom: PuzzleAtom in atoms:
		if atom.is_solved():
			return false
	return true
