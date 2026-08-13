class_name DevPuzzleRoom
extends Node3D
## Playable developer-only host for the stable fixtures in `DevPuzzleCatalogue`.
## Re-enter the scene to rebuild; no production room planner references this file.

const FLOOR_Y := 0.02
const GATE_AT := Vector3(0.0, 0.0, -10.05)
const EYE_Y := 2.05
const EYE_WALL_Z := -9.45
const BLOCK_STEP := 1.2

const FIXTURE_SEEDS := {
	&"eye_sequence": 91001,
	&"lantern_coupling": 91002,
	&"pillar_chain": 91003,
	&"plate_nest": 91004,
}

var _fixture_id: StringName = &""
var _fixture: Node3D = null

@onready var _caption_title: Label = %FixtureTitle
@onready var _caption_description: Label = %FixtureDescription


func _ready() -> void:
	_fixture = Node3D.new()
	_fixture.name = "Fixture"
	add_child(_fixture)

	_fixture_id = Flow.dev_puzzle_id
	if _fixture_id == &"" or not DevPuzzleCatalogue.has_fixture(_fixture_id):
		_reject_fixture(_fixture_id)
		return

	# Developer scene entry is a hard reset. In particular, latching eyes and
	# pillars must not restore flags written by an earlier visit in the same run.
	PuzzleAtom.clear_run_flags()
	var fixture_seed: int = 92000 + PuzzleAtoms.all().find(_fixture_id)
	if FIXTURE_SEEDS.has(_fixture_id):
		fixture_seed = int(FIXTURE_SEEDS[_fixture_id])
	Run.rng.seed = fixture_seed
	_set_caption(DevPuzzleCatalogue.row(_fixture_id))
	if PuzzleAtoms.has_atom(_fixture_id):
		_build_stock_atom()
		return

	match _fixture_id:
		&"eye_sequence":
			_build_eye_sequence()
		&"lantern_coupling":
			_build_lantern_coupling()
		&"pillar_chain":
			_build_pillar_chain()
		&"plate_nest":
			_build_plate_nest()


func fixture_id() -> StringName:
	return _fixture_id


func fixture_root() -> Node3D:
	return _fixture


func _reject_fixture(id: StringName) -> void:
	var shown := "<empty>" if id == &"" else String(id)
	var message := "DevPuzzleRoom: unknown fixture '%s'; use /puzzles for valid ids" % shown
	push_error(message)
	_caption_title.text = "PUZZLE FIXTURE ERROR"
	_caption_description.text = message


func _set_caption(fixture: Dictionary) -> void:
	var item: StringName = fixture["required_item"]
	var requirement := "T%d" % int(fixture["required_tier"])
	if item != &"":
		requirement += " / %s" % item
	_caption_title.text = "%s  ·  %s" % [fixture["display_name"], fixture["id"]]
	_caption_description.text = "%s\nRequired: %s" % [
		fixture["description"], requirement,
	]


func _make_gate(tier: int, needs_key: bool = false) -> PuzzleGate:
	var gate := PuzzleGate.new()
	gate.name = "Gate"
	gate.position = GATE_AT
	gate.puzzle_id = _fixture_id
	gate.mark_tier = tier
	gate.needs_key = needs_key
	gate.label = String(DevPuzzleCatalogue.row(_fixture_id)["display_name"])
	gate.destination = StringName("dev_%s" % _fixture_id)
	_fixture.add_child(gate)
	return gate


func _build_stock_atom() -> void:
	var tier: int = PuzzleAtoms.tier(_fixture_id)
	var required_item: StringName = PuzzleAtoms.TIER_ITEM[tier]
	if required_item != &"":
		Game.grant(required_item)
		if required_item == &"bow":
			Game.add_arrows(Game.max_arrows - Game.arrows)
		elif required_item == &"burst":
			Game.add_charges(Game.max_charges - Game.charges)

	var atom := PuzzleAtoms.make(_fixture_id, _fixture_id) as PuzzleAtom
	if atom == null:
		push_error("DevPuzzleRoom: %s failed to build its stock atom" % _fixture_id)
		return
	atom.name = String(_fixture_id).to_pascal_case()
	_place_stock_atom(atom)
	_fixture.add_child(atom)

	if PuzzleAtoms.gates(_fixture_id):
		var gate: PuzzleGate = _make_gate(
			tier, _fixture_id == PuzzleAtoms.SMALL_KEY)
		gate.watch(atom)


func _place_stock_atom(atom: PuzzleAtom) -> void:
	atom.position = Vector3(0.0, FLOOR_Y, -1.0)
	if _fixture_id == PuzzleAtoms.SMALL_KEY:
		atom.position = Vector3(-2.0, FLOOR_Y, -0.5)
	elif _fixture_id == PuzzleAtoms.URN:
		atom.position = Vector3(-1.8, FLOOR_Y, -1.0)
	elif _fixture_id == PuzzleAtoms.PRESSURE_PLATE:
		atom.position = Vector3(0.0, FLOOR_Y, -1.8)
	elif _fixture_id == PuzzleAtoms.PUSH_BLOCK:
		atom.position = Vector3(0.0, FLOOR_Y, 1.2)
		atom.set(&"mark_offset", Vector3(0.0, 0.0, -BLOCK_STEP * 3.0))
	elif _fixture_id == PuzzleAtoms.EYE_SWITCH:
		atom.position = Vector3(-4.5, EYE_Y, EYE_WALL_Z)
		atom.rotation.y = PI
	elif _fixture_id == PuzzleAtoms.HOOK_RING:
		atom.position = Vector3(0.0, K.DOOR_H + 0.6, EYE_WALL_Z)
	elif _fixture_id == PuzzleAtoms.SUN_SOCKET:
		atom.position = Vector3(0.0, FLOOR_Y, -4.0)
		atom.rotation.y = PI


func _build_eye_sequence() -> void:
	Game.grant(&"bow")
	Game.add_arrows(Game.max_arrows - Game.arrows)

	var gate := _make_gate(PuzzleAtoms.T1)
	gate.ordered = true
	# Keep the row clear of the west foreground buttress and the wall torch beside
	# the gate. Index 0 is at screen-left for a hero looking north from the spawn.
	for i in 3:
		var eye := PuzzleAtoms.make(PuzzleAtoms.EYE_SWITCH, _fixture_id) as PuzzleAtom
		if eye == null:
			push_error("DevPuzzleRoom: eye_sequence failed to build eye %d" % i)
			continue
		eye.name = "Eye%d" % i
		eye.index = i
		eye.position = Vector3(-7.0 + float(i) * 2.5, EYE_Y, EYE_WALL_Z)
		eye.rotation.y = PI
		_fixture.add_child(eye)
		gate.watch(eye)


func _build_lantern_coupling() -> void:
	_make_gate(PuzzleAtoms.T0)
	var grid := LanternGrid.new()
	grid.name = "LanternGrid"
	grid.puzzle_id = _fixture_id
	grid.rows = 3
	grid.cols = 3
	# A fixed press count plus the fixture seed makes every rebuild the same
	# guaranteed-solvable, not-already-solved board.
	grid.presses = 2
	grid.position = Vector3(0.0, FLOOR_Y, -1.2)
	_fixture.add_child(grid)


func _build_pillar_chain() -> void:
	Game.grant(&"burst")
	Game.add_charges(Game.max_charges - Game.charges)

	_make_gate(PuzzleAtoms.T2)
	var row := ChainRow.new()
	row.name = "ChainRow"
	row.puzzle_id = _fixture_id
	# Default count, spacing, reach and gap are the authored two-cast shape.
	# Turn it across the chamber so the row and its socket read from the south
	# spawn instead of collapsing into one end-on pillar.
	row.position = Vector3(-3.25, FLOOR_Y, -1.0)
	row.rotation.y = PI * 0.5
	_fixture.add_child(row)


func _build_plate_nest() -> void:
	var gate := _make_gate(PuzzleAtoms.T0)
	var plate := PuzzleAtoms.make(PuzzleAtoms.PRESSURE_PLATE, _fixture_id) as PuzzleAtom
	if plate == null:
		push_error("DevPuzzleRoom: plate_nest failed to build its pressure plate")
		return
	plate.name = "PressurePlate"
	plate.position = Vector3(0.0, FLOOR_Y, -4.6)
	_fixture.add_child(plate)
	gate.watch(plate)

	var block := PuzzleAtoms.make(PuzzleAtoms.PUSH_BLOCK) as PuzzleAtom
	if block == null:
		push_error("DevPuzzleRoom: plate_nest failed to build its push block")
		return
	block.name = "PushBlock"
	block.position = plate.position + Vector3.LEFT * BLOCK_STEP * 3.0
	# Zero means movable furniture with weight: no mark, no independent solve,
	# and therefore no second atom for the gate to watch.
	block.set(&"mark_offset", Vector3.ZERO)
	_fixture.add_child(block)
